import 'package:flutter/material.dart';

import '../../core/l10n/languages.dart';
import '../../core/l10n/strings.dart';
import '../controllers/list_view_options.dart';

/// AppBar actions to filter a list by one value and to change its order.
class ListSortFilterActions extends StatelessWidget {
  const ListSortFilterActions({
    super.key,
    required this.options,
    required this.filterOptions,
    required this.onChanged,
    required this.lang,
  });

  final ListViewOptions options;

  /// Values the list can be filtered by (platforms or categories).
  final List<String> filterOptions;
  final ValueChanged<ListViewOptions> onChanged;
  final AppLanguage lang;

  static const _allKey = '\u0000all';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final active = options.filter != null;

    PopupMenuItem<T> checked<T>(T value, String label, bool selected) =>
        PopupMenuItem<T>(
          value: value,
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: selected
                    ? Icon(Icons.check, size: 20, color: primary)
                    : null,
              ),
              Flexible(child: Text(label)),
            ],
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          key: const Key('list-filter'),
          tooltip: lang.tr('list.filter'),
          icon: Badge(
            isLabelVisible: active,
            smallSize: 8,
            child: Icon(Icons.filter_list, color: active ? primary : null),
          ),
          onSelected: (value) =>
              onChanged(options.withFilter(value == _allKey ? null : value)),
          itemBuilder: (_) => [
            checked(_allKey, lang.tr('list.filterAll'), !active),
            for (final value in filterOptions)
              checked(value, value, options.filter == value),
          ],
        ),
        PopupMenuButton<ListSort>(
          key: const Key('list-sort'),
          tooltip: lang.tr('list.sort'),
          icon: const Icon(Icons.sort),
          onSelected: (sort) => onChanged(options.withSort(sort)),
          itemBuilder: (_) => [
            for (final (sort, key) in const [
              (ListSort.newest, 'list.sortNewest'),
              (ListSort.oldest, 'list.sortOldest'),
              (ListSort.highest, 'list.sortHighest'),
              (ListSort.lowest, 'list.sortLowest'),
            ])
              checked(sort, lang.tr(key), options.sort == sort),
          ],
        ),
      ],
    );
  }
}

/// Shown when a filter leaves the list empty.
class FilteredEmptyState extends StatelessWidget {
  const FilteredEmptyState(
      {super.key, required this.lang, required this.onClear});

  final AppLanguage lang;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(lang.tr('list.noResults'),
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          TextButton(
              onPressed: onClear, child: Text(lang.tr('list.clearFilter'))),
        ],
      ),
    );
  }
}
