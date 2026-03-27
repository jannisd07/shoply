import Flutter
import UIKit
import Intents
import IntentsUI

@available(iOS 12.0, *)
public class VoiceAssistantPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.shoply.voice_assistant", binaryMessenger: registrar.messenger())
        let instance = VoiceAssistantPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "registerSiriShortcut":
            registerSiriShortcut(call: call, result: result)
        case "donateSiriShortcut":
            donateSiriShortcut(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func registerSiriShortcut(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let phrase = args["phrase"] as? String,
              let action = args["action"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        let parameters = args["parameters"] as? [String: Any]
        
        // Create intent based on action
        let intent: INIntent
        switch action {
        case "addItemToList":
            intent = createAddItemIntent(parameters: parameters)
        case "createList":
            intent = createListIntent(parameters: parameters)
        case "viewList":
            intent = createViewListIntent(parameters: parameters)
        default:
            result(FlutterError(code: "UNKNOWN_ACTION", message: "Unknown action: \(action)", details: nil))
            return
        }
        
        // Create shortcut
        let shortcut = INShortcut(intent: intent)
        
        // Present shortcut view controller
        if let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut) {
            viewController.delegate = self
            
            // Get root view controller
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                rootVC.present(viewController, animated: true, completion: nil)
                result(true)
            } else {
                result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Could not find root view controller", details: nil))
            }
        } else {
            result(FlutterError(code: "SHORTCUT_CREATION_FAILED", message: "Failed to create shortcut", details: nil))
        }
    }
    
    private func donateSiriShortcut(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let action = args["action"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        let parameters = args["parameters"] as? [String: Any]
        
        // Create intent based on action
        let intent: INIntent
        switch action {
        case "addItemToList":
            intent = createAddItemIntent(parameters: parameters)
        case "createList":
            intent = createListIntent(parameters: parameters)
        case "viewList":
            intent = createViewListIntent(parameters: parameters)
        default:
            result(FlutterError(code: "UNKNOWN_ACTION", message: "Unknown action: \(action)", details: nil))
            return
        }
        
        // Donate interaction
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                result(FlutterError(code: "DONATION_FAILED", message: error.localizedDescription, details: nil))
            } else {
                result(true)
            }
        }
    }
    
    private func createAddItemIntent(parameters: [String: Any]?) -> INIntent {
        // Create a custom intent for adding items
        // Note: You'll need to create this in Intents.intentdefinition
        let intent = AddItemIntent()
        if let itemName = parameters?["itemName"] as? String {
            intent.itemName = itemName
        }
        if let listName = parameters?["listName"] as? String {
            intent.listName = listName
        }
        intent.suggestedInvocationPhrase = "Add to shopping list"
        return intent
    }
    
    private func createListIntent(parameters: [String: Any]?) -> INIntent {
        let intent = CreateListIntent()
        if let listName = parameters?["listName"] as? String {
            intent.listName = listName
        }
        intent.suggestedInvocationPhrase = "Create shopping list"
        return intent
    }
    
    private func createViewListIntent(parameters: [String: Any]?) -> INIntent {
        let intent = ViewListIntent()
        if let listName = parameters?["listName"] as? String {
            intent.listName = listName
        }
        intent.suggestedInvocationPhrase = "Show shopping list"
        return intent
    }
}

// MARK: - INUIAddVoiceShortcutViewControllerDelegate
@available(iOS 12.0, *)
extension VoiceAssistantPlugin: INUIAddVoiceShortcutViewControllerDelegate {
    public func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    public func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

// MARK: - Intent Definitions (Placeholder - create in Intents.intentdefinition)
@available(iOS 12.0, *)
class AddItemIntent: INIntent {
    var itemName: String?
    var listName: String?
}

@available(iOS 12.0, *)
class CreateListIntent: INIntent {
    var listName: String?
}

@available(iOS 12.0, *)
class ViewListIntent: INIntent {
    var listName: String?
}
