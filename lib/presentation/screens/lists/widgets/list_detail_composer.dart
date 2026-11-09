import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/lists/widgets/add_suggestion_panel.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Typing pauses this long before the offers are asked (one request per
/// pause, not per key).
const Duration _queryDebounce = Duration(milliseconds: 300);

/// Offers are looked up from this many characters on (Konzept 11 §2.2).
const int _minQueryLength = 2;

/// The field gets the focus back after a route only when it lost it this
/// shortly before the route opened (a panel row that opened `/stores/region`
/// closes the keyboard first, A-C4).
const Duration _refocusWindow = Duration(seconds: 1);

/// The add field of the list (D2 "Bottom-Accessory", Konzept 11 §2): Teil
/// A's [AddItemAccessory] with the sum of the saved prices at the end and
/// the suggestion panel above it ([AddSuggestionPanel]): before the first
/// letter the start suggestions (Konzept 17 §9.8), while typing Teil B's
/// offers. No mic until B's speech service exists (owner 07.11.2026).
///
/// Return or the plus circle hand the trimmed text to [onSubmitted]; the
/// screen parses it ("2 Milch", "Milch, Eier") and clears the field. A start
/// suggestion goes to [onSubmitted] as typed text. A tapped offer is added
/// by Teil B itself, then the field is cleared here. When a route opened
/// while the field had the keyboard (the panel's "Postleitzahl festlegen"),
/// the field gets the focus back on return, unless [refocusAllowed] says no
/// (the person closed the keyboard on purpose). Never a fixed height: the
/// accessory grows with Dynamic Type (A3).
class ListDetailComposer extends ConsumerStatefulWidget {
  const ListDetailComposer({
    super.key,
    required this.listId,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.totalText,
    this.refocusAllowed,
  });

  final String listId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  /// "≈ 23,80 €", or null to show nothing.
  final String? totalText;

  /// Asked when the list's route comes back; false keeps the keyboard
  /// closed. Null always allows it.
  final bool Function()? refocusAllowed;

  @override
  ConsumerState<ListDetailComposer> createState() => _ListDetailComposerState();
}

class _ListDetailComposerState extends ConsumerState<ListDetailComposer> {
  Timer? _debounce;
  String _query = '';
  bool _empty = true;
  bool _focused = false;

  bool? _routeCurrent;
  DateTime? _focusLostAt;
  bool _refocusOnReturn = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    widget.focusNode.addListener(_onFocus);
    _empty = widget.controller.text.isEmpty;
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant ListDetailComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuilt when the route stops or starts being the current one.
    final current = ModalRoute.isCurrentOf(context) ?? true;
    final was = _routeCurrent;
    _routeCurrent = current;
    if (was == null || was == current) return;
    if (!current) {
      final lost = _focusLostAt;
      _refocusOnReturn =
          widget.focusNode.hasFocus ||
          (lost != null && DateTime.now().difference(lost) < _refocusWindow);
      return;
    }
    if (!_refocusOnReturn) return;
    _refocusOnReturn = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(ModalRoute.isCurrentOf(context) ?? true)) return;
      if (widget.refocusAllowed?.call() ?? true) {
        widget.focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onText);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    final focused = widget.focusNode.hasFocus;
    if (!focused) _focusLostAt = DateTime.now();
    if (focused != _focused && mounted) setState(() => _focused = focused);
  }

  void _onText() {
    final raw = widget.controller.text;
    if (raw.isEmpty != _empty && mounted) {
      setState(() => _empty = raw.isEmpty);
    }
    final text = raw.trim();
    _debounce?.cancel();
    if (text.length < _minQueryLength) {
      // Clearing hides the suggestions at once.
      _setQuery('');
      return;
    }
    _debounce = Timer(_queryDebounce, () => _setQuery(text));
  }

  void _setQuery(String value) {
    if (value == _query || !mounted) return;
    setState(() => _query = value);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final showStarts = _focused && _empty;
    final starts = showStarts
        ? startSuggestionsFor(
            ref,
            listId: widget.listId,
            defaults: defaultStartSuggestions(context),
          )
        : const <String>[];
    final offers = query.isEmpty
        ? null
        : OfferSuggestionsBar(
            listId: widget.listId,
            query: query,
            onAdded: widget.controller.clear,
          );
    return AddItemAccessory(
      placeholder: context.tr('list_detail_add_placeholder'),
      semanticHint: context.tr('list_detail_add_hint'),
      controller: widget.controller,
      focusNode: widget.focusNode,
      onSubmitted: widget.onSubmitted,
      trailingText: widget.totalText,
      above: offers == null && starts.isEmpty
          ? null
          : AddSuggestionPanel(
              offers: offers,
              starts: starts,
              onPick: widget.onSubmitted,
            ),
    );
  }
}
