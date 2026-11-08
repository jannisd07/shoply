import Foundation
import HealthKit

/// `shoply/health`: Apple Health without a package (concept 15, ch. 4).
///
/// Writes food (correlation of energy, protein, carbohydrates, fat), water,
/// body mass and workouts. Every object carries the app's entry id as
/// `HKMetadataKeySyncIdentifier` plus `HKMetadataKeySyncVersion`, so a write
/// with a higher version replaces the old object and `delete` finds it again.
/// Nutrient samples inside a food correlation use `<id>.kcal`, `<id>.protein`,
/// `<id>.carbs`, `<id>.fat`; the workout's energy sample uses `<id>.energy`.
///
/// Reads body mass, height, water, workouts and the date of birth, never the
/// nutrition other apps wrote (it would be counted twice). Read permission
/// cannot be queried on iOS: refused reads just return nothing.
///
/// The system dialog appears only in `requestAuthorization`.
final class HealthKitChannel: NativeMethodHandler {
  private lazy var store = HKHealthStore()

  // MARK: Types

  private static let energy = HKQuantityType(.dietaryEnergyConsumed)
  private static let protein = HKQuantityType(.dietaryProtein)
  private static let carbs = HKQuantityType(.dietaryCarbohydrates)
  private static let fat = HKQuantityType(.dietaryFatTotal)
  private static let water = HKQuantityType(.dietaryWater)
  private static let bodyMass = HKQuantityType(.bodyMass)
  private static let height = HKQuantityType(.height)
  private static let activeEnergy = HKQuantityType(.activeEnergyBurned)
  private static let food = HKCorrelationType(.food)
  private static let workout = HKObjectType.workoutType()

  private static let shareTypes: Set<HKSampleType> = [
    energy, protein, carbs, fat, water, bodyMass, activeEnergy, workout,
  ]

  /// No dietary energy or macros here: other apps' food stays out.
  private static let readTypes: Set<HKObjectType> = [
    bodyMass, height, water, workout, activeEnergy, HKCharacteristicType(.dateOfBirth),
  ]

  private static let millilitre = HKUnit.literUnit(with: .milli)
  private static let kilogram = HKUnit.gramUnit(with: .kilo)
  private static let centimetre = HKUnit.meterUnit(with: .centi)

  /// Dart names of `HealthWorkoutActivity`; the first match wins when reading.
  private static let activities: [(String, HKWorkoutActivityType)] = [
    ("running", .running),
    ("walking", .walking),
    ("cycling", .cycling),
    ("swimming", .swimming),
    ("strength", .traditionalStrengthTraining),
    ("strength", .functionalStrengthTraining),
    ("yoga", .yoga),
    ("hiit", .highIntensityIntervalTraining),
    ("hiking", .hiking),
    ("dance", .cardioDance),
    ("dance", .socialDance),
    ("other", .other),
  ]

  private static let methods: Set<String> = [
    "requestAuthorization", "writeStatus", "writeFood", "writeWater", "writeBodyMass",
    "writeWorkout", "delete", "readBodyMass", "readWater", "readLatestHeight",
    "readWorkouts", "readDateOfBirth",
  ]

  // MARK: Dispatch

  func handle(method: String, arguments: Any?, result: @escaping NativeResult) {
    if method == "isAvailable" {
      result(.value(HKHealthStore.isHealthDataAvailable()))
      return
    }
    guard Self.methods.contains(method) else {
      result(.notImplemented)
      return
    }
    guard HKHealthStore.isHealthDataAvailable() else {
      result(.error(.unavailable, "Health data is not available on this device"))
      return
    }
    let args = NativeArguments(arguments)
    switch method {
    case "requestAuthorization": requestAuthorization(result)
    case "writeStatus": result(.value(writeStatus()))
    case "writeFood": writeFood(args, result)
    case "writeWater":
      writeQuantity(Self.water, unit: Self.millilitre, key: "ml", range: 1...10_000, args, result)
    case "writeBodyMass":
      writeQuantity(Self.bodyMass, unit: Self.kilogram, key: "kg", range: 1...500, args, result)
    case "writeWorkout": writeWorkout(args, result)
    case "delete": delete(args, result)
    case "readBodyMass": readQuantities(Self.bodyMass, unit: Self.kilogram, args, result)
    case "readWater": readQuantities(Self.water, unit: Self.millilitre, args, result)
    case "readLatestHeight": readLatestHeight(result)
    case "readWorkouts": readWorkouts(args, result)
    case "readDateOfBirth": readDateOfBirth(result)
    default: result(.notImplemented)
    }
  }

  // MARK: Permission

  private func requestAuthorization(_ result: @escaping NativeResult) {
    store.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes) { success, error in
      if let error {
        Self.fail(result, error)
      } else {
        result(.value(success))
      }
    }
  }

  private func writeStatus() -> [String: String] {
    func status(_ type: HKObjectType) -> String {
      switch store.authorizationStatus(for: type) {
      case .sharingAuthorized: return "authorized"
      case .sharingDenied: return "denied"
      case .notDetermined: return "notDetermined"
      @unknown default: return "notDetermined"
      }
    }
    return [
      "food": status(Self.energy),
      "water": status(Self.water),
      "bodyMass": status(Self.bodyMass),
      "workout": status(Self.workout),
    ]
  }

  // MARK: Writing

  private struct SyncIdentity {
    let id: String
    let version: Int

    init?(_ args: NativeArguments) {
      guard let id = args.string("syncId"), let version = args.int("syncVersion"), version >= 1
      else { return nil }
      self.id = id
      self.version = version
    }

    var metadata: [String: Any] { metadata(for: id) }

    func child(_ suffix: String) -> String { "\(id).\(suffix)" }

    func metadata(for syncId: String) -> [String: Any] {
      [HKMetadataKeySyncIdentifier: syncId, HKMetadataKeySyncVersion: NSNumber(value: version)]
    }
  }

  private func writeFood(_ args: NativeArguments, _ result: @escaping NativeResult) {
    guard let sync = SyncIdentity(args), let date = args.date("date"),
      let kcal = args.double("kcal"), (0...20_000).contains(kcal)
    else {
      result(.error(.invalidArgs, "writeFood needs syncId, syncVersion, date and kcal"))
      return
    }
    let nutrients: [(HKQuantityType, String, Double?, HKUnit)] = [
      (Self.energy, "kcal", kcal, .kilocalorie()),
      (Self.protein, "protein", args.double("proteinG"), .gram()),
      (Self.carbs, "carbs", args.double("carbsG"), .gram()),
      (Self.fat, "fat", args.double("fatG"), .gram()),
    ]
    guard isAllowed(Self.energy) else {
      result(.error(.permissionDenied, "Writing food energy to Health is not allowed"))
      return
    }
    let name = args.string("name")
    var samples = Set<HKSample>()
    var stale: [(HKObjectType, [String])] = []
    // Nutrients the person switched off in Health are left out; with them the
    // whole correlation would be refused.
    for (type, suffix, value, unit) in nutrients where isAllowed(type) {
      let childId = sync.child(suffix)
      guard let value, value >= 0 else {
        // An update that dropped this nutrient must not leave the old one.
        stale.append((type, [childId]))
        continue
      }
      var metadata = sync.metadata(for: childId)
      if let name { metadata[HKMetadataKeyFoodType] = name }
      samples.insert(
        HKQuantitySample(
          type: type, quantity: HKQuantity(unit: unit, doubleValue: value),
          start: date, end: date, metadata: metadata))
    }
    var metadata = sync.metadata
    if let name { metadata[HKMetadataKeyFoodType] = name }
    let correlation = HKCorrelation(
      type: Self.food, start: date, end: date, objects: samples, metadata: metadata)
    let staleNutrients = stale
    store.save(correlation) { [self] saved, error in
      guard saved else { return Self.fail(result, error) }
      deleteObjects(staleNutrients) { _ in result(.value(correlation.uuid.uuidString)) }
    }
  }

  private func writeQuantity(
    _ type: HKQuantityType, unit: HKUnit, key: String, range: ClosedRange<Double>,
    _ args: NativeArguments, _ result: @escaping NativeResult
  ) {
    guard let sync = SyncIdentity(args), let date = args.date("date"),
      let value = args.double(key), range.contains(value)
    else {
      result(.error(.invalidArgs, "write needs syncId, syncVersion, date and \(key) in range"))
      return
    }
    let sample = HKQuantitySample(
      type: type, quantity: HKQuantity(unit: unit, doubleValue: value),
      start: date, end: date, metadata: sync.metadata)
    store.save(sample) { saved, error in
      saved ? result(.value(sample.uuid.uuidString)) : Self.fail(result, error)
    }
  }

  private func writeWorkout(_ args: NativeArguments, _ result: @escaping NativeResult) {
    guard let sync = SyncIdentity(args), let start = args.date("start"),
      let end = args.date("end"), end > start,
      let activity = Self.activities.first(where: { $0.0 == args.string("activity") })?.1
    else {
      result(.error(.invalidArgs, "writeWorkout needs syncId, syncVersion, activity, start < end"))
      return
    }
    let kcal = args.double("kcal").flatMap { (0...20_000).contains($0) ? $0 : nil }
      .flatMap { isAllowed(Self.activeEnergy) ? $0 : nil }
    let energyId = sync.child("energy")
    let energySamples: [HKSample] = kcal.map {
      [
        HKQuantitySample(
          type: Self.activeEnergy, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: $0),
          start: start, end: end, metadata: sync.metadata(for: energyId))
      ]
    } ?? []

    let configuration = HKWorkoutConfiguration()
    configuration.activityType = activity
    let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

    func abort(_ error: Error?) {
      builder.discardWorkout()
      Self.fail(result, error)
    }

    builder.beginCollection(withStart: start) { [self] began, error in
      guard began else { return abort(error) }
      builder.addMetadata(sync.metadata) { added, error in
        guard added else { return abort(error) }
        self.addSamples(energySamples, to: builder) { added, error in
          guard added else { return abort(error) }
          builder.endCollection(withEnd: end) { ended, error in
            guard ended else { return abort(error) }
            builder.finishWorkout { workout, error in
              guard let workout else { return Self.fail(result, error) }
              let stale: [(HKObjectType, [String])] =
                kcal == nil && self.isAllowed(Self.activeEnergy)
                ? [(Self.activeEnergy, [energyId])] : []
              self.deleteObjects(stale) { _ in result(.value(workout.uuid.uuidString)) }
            }
          }
        }
      }
    }
  }

  private func isAllowed(_ type: HKObjectType) -> Bool {
    store.authorizationStatus(for: type) == .sharingAuthorized
  }

  private func addSamples(
    _ samples: [HKSample], to builder: HKWorkoutBuilder,
    completion: @escaping (Bool, Error?) -> Void
  ) {
    guard !samples.isEmpty else { return completion(true, nil) }
    builder.add(samples, completion: completion)
  }

  // MARK: Deleting

  private func delete(_ args: NativeArguments, _ result: @escaping NativeResult) {
    guard let type = args.string("type"), let id = args.string("syncId") else {
      result(.error(.invalidArgs, "delete needs type and syncId"))
      return
    }
    let targets: [(HKObjectType, [String])]
    switch type {
    case "food":
      targets = [
        (Self.energy, ["\(id).kcal"]), (Self.protein, ["\(id).protein"]),
        (Self.carbs, ["\(id).carbs"]), (Self.fat, ["\(id).fat"]),
      ]
    case "water": targets = [(Self.water, [id])]
    case "bodyMass": targets = [(Self.bodyMass, [id])]
    case "workout": targets = [(Self.workout, [id]), (Self.activeEnergy, ["\(id).energy"])]
    default:
      result(.error(.invalidArgs, "unknown type"))
      return
    }
    let allowed = targets.filter { isAllowed($0.0) }
    guard !allowed.isEmpty else {
      result(.error(.permissionDenied, "Deleting from Health is not allowed"))
      return
    }
    let deleteSamples = { [self] in
      deleteObjects(allowed) { error in
        error == nil ? result(.value(true)) : Self.fail(result, error)
      }
    }
    guard type == "food" else { return deleteSamples() }
    // Deleting the nutrients leaves the correlation itself; remove it first.
    deleteCorrelations(syncId: id) { deleteSamples() }
  }

  private func deleteCorrelations(syncId: String, completion: @escaping () -> Void) {
    let query = HKSampleQuery(
      sampleType: Self.food, predicate: Self.syncPredicate([syncId]),
      limit: HKObjectQueryNoLimit, sortDescriptors: nil
    ) { [self] _, samples, error in
      guard error == nil, let samples, !samples.isEmpty else {
        if error != nil { nativeLog("⚠️ [HEALTH] food correlation lookup failed") }
        return completion()
      }
      store.delete(samples) { deleted, _ in
        if !deleted { nativeLog("⚠️ [HEALTH] food correlation delete failed") }
        completion()
      }
    }
    store.execute(query)
  }

  /// Deletes this app's objects with the given sync identifiers; reports the
  /// first error.
  private func deleteObjects(
    _ targets: [(HKObjectType, [String])], completion: @escaping (Error?) -> Void
  ) {
    guard !targets.isEmpty else { return completion(nil) }
    let group = DispatchGroup()
    let lock = NSLock()
    var firstError: Error?
    for (type, ids) in targets {
      group.enter()
      store.deleteObjects(of: type, predicate: Self.syncPredicate(ids)) { _, _, error in
        if let error {
          lock.lock()
          if firstError == nil { firstError = error }
          lock.unlock()
        }
        group.leave()
      }
    }
    group.notify(queue: .global(qos: .userInitiated)) { completion(firstError) }
  }

  private static func syncPredicate(_ ids: [String]) -> NSPredicate {
    HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: ids)
  }

  // MARK: Reading

  private func readQuantities(
    _ type: HKQuantityType, unit: HKUnit, _ args: NativeArguments,
    _ result: @escaping NativeResult
  ) {
    guard let predicate = Self.rangePredicate(args) else {
      result(.error(.invalidArgs, "read needs from <= to"))
      return
    }
    let query = HKSampleQuery(
      sampleType: type, predicate: predicate, limit: 1000, sortDescriptors: [Self.newestFirst]
    ) { _, samples, error in
      if let error, !Self.isAuthorizationError(error) { return Self.fail(result, error) }
      let rows = (samples as? [HKQuantitySample] ?? []).map { Self.row($0, unit: unit) }
      result(.value(rows))
    }
    store.execute(query)
  }

  private func readLatestHeight(_ result: @escaping NativeResult) {
    let query = HKSampleQuery(
      sampleType: Self.height, predicate: nil, limit: 1, sortDescriptors: [Self.newestFirst]
    ) { _, samples, error in
      if let error, !Self.isAuthorizationError(error) { return Self.fail(result, error) }
      let sample = (samples as? [HKQuantitySample])?.first
      result(.value(sample.map { Self.row($0, unit: Self.centimetre) }))
    }
    store.execute(query)
  }

  private func readWorkouts(_ args: NativeArguments, _ result: @escaping NativeResult) {
    guard let predicate = Self.rangePredicate(args) else {
      result(.error(.invalidArgs, "read needs from <= to"))
      return
    }
    let query = HKSampleQuery(
      sampleType: Self.workout, predicate: predicate, limit: 500,
      sortDescriptors: [Self.newestFirst]
    ) { _, samples, error in
      if let error, !Self.isAuthorizationError(error) { return Self.fail(result, error) }
      result(.value((samples as? [HKWorkout] ?? []).map(Self.workoutRow)))
    }
    store.execute(query)
  }

  private func readDateOfBirth(_ result: @escaping NativeResult) {
    // Throws when the person did not allow it or never entered a birthday.
    guard let components = try? store.dateOfBirthComponents(),
      let year = components.year, let month = components.month, let day = components.day
    else { return result(.value(nil)) }
    result(.value(["year": year, "month": month, "day": day]))
  }

  private static let newestFirst = NSSortDescriptor(
    key: HKSampleSortIdentifierStartDate, ascending: false)

  private static func rangePredicate(_ args: NativeArguments) -> NSPredicate? {
    guard let from = args.date("from"), let to = args.date("to"), from <= to else { return nil }
    return HKQuery.predicateForSamples(withStart: from, end: to, options: [])
  }

  private static func isOwn(_ object: HKObject) -> Bool {
    object.sourceRevision.source.bundleIdentifier == HKSource.default().bundleIdentifier
  }

  private static func baseRow(_ object: HKObject) -> [String: Any] {
    var row: [String: Any] = [
      "uuid": object.uuid.uuidString,
      "sourceName": object.sourceRevision.source.name,
      "isOwn": isOwn(object),
    ]
    if let device = object.device?.name { row["deviceName"] = device }
    if let syncId = object.metadata?[HKMetadataKeySyncIdentifier] as? String {
      row["syncId"] = syncId
    }
    return row
  }

  private static func row(_ sample: HKQuantitySample, unit: HKUnit) -> [String: Any] {
    var row = baseRow(sample)
    row["date"] = sample.startDate.millisecondsSinceEpoch
    row["value"] = sample.quantity.doubleValue(for: unit)
    return row
  }

  private static func workoutRow(_ workout: HKWorkout) -> [String: Any] {
    var row = baseRow(workout)
    row["activity"] =
      activities.first(where: { $0.1 == workout.workoutActivityType })?.0 ?? "other"
    row["start"] = workout.startDate.millisecondsSinceEpoch
    row["end"] = workout.endDate.millisecondsSinceEpoch
    if let kcal = energy(of: workout) { row["kcal"] = kcal }
    return row
  }

  private static func energy(of workout: HKWorkout) -> Double? {
    if #available(iOS 16.0, *) {
      return workout.statistics(for: activeEnergy)?.sumQuantity()?
        .doubleValue(for: .kilocalorie())
    }
    return workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
  }

  // MARK: Errors

  private static func isAuthorizationError(_ error: Error) -> Bool {
    guard let error = error as? HKError else { return false }
    return error.code == .errorAuthorizationDenied || error.code == .errorAuthorizationNotDetermined
  }

  private static func fail(_ result: NativeResult, _ error: Error?) {
    let code: NativeErrorCode
    switch (error as? HKError)?.code {
    case .errorAuthorizationDenied?, .errorAuthorizationNotDetermined?: code = .permissionDenied
    case .errorHealthDataUnavailable?, .errorHealthDataRestricted?: code = .unavailable
    case .errorInvalidArgument?: code = .invalidArgs
    case .errorUserCanceled?: code = .cancelled
    default: code = .failed
    }
    nativeLog("❌ [HEALTH] \(code.rawValue)")
    result(.error(code, error?.localizedDescription))
  }
}
