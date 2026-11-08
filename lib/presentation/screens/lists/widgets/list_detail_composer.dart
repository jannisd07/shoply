import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/add_item_accessory.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Typing pauses this long before the offers are asked (one request per
/// pause, not per key).
const Duration _queryDebounce = Duration(milliseconds: 300);

/// Offers are looked up from this many characters on (Konzept 11 §2.2).
const int _minQueryLength = 2;

/// The add field of the list (D2 "Bottom-Accessory", Konzept 11 §2): Teil
/// A's [AddItemAccessory] with the sum of the saved prices at the end and,
/// while typing, Teil B's offer suggestions above it. No mic until B's
/// speech service exists (owner 07.11.2026).
///
/// Return or the plus circle hand the trimmed text to [onSubmitted]; the
/// screen parses it ("2 Milch", "Milch, Eier") and clears the field. A
/// tapped offer is added by Teil B itself, then the field is cleared here.
/// Never a fixed height: the accessory grows with Dynamic Type (A3).
class ListDetailComposer extends StatefulWidget {
  const ListDetailComposer({
    super.key,
    required this.listId,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.totalText,
  });

  final String listId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  /// "≈ 23,80 €", or null to show nothing.
  final String? totalText;

  @override
  State<ListDetailComposer> createState() => _ListDetailComposerState();
}

class _ListDetailComposerState extends State<ListDetailComposer> {
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(covariant ListDetailComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onText);
    super.dispose();
  }

  void _onText() {
    final text = widget.controller.text.trim();
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
    return AddItemAccessory(
      placeholder: context.tr('list_detail_add_placeholder'),
      semanticHint: context.tr('list_detail_add_hint'),
      controller: widget.controller,
      focusNode: widget.focusNode,
      onSubmitted: widget.onSubmitted,
      trailingText: widget.totalText,
      above: query.isEmpty
          ? null
          : OfferSuggestionsBar(
              listId: widget.listId,
              query: query,
              onAdded: widget.controller.clear,
            ),
    );
  }
}
