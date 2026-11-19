// Rebuilds once a minute so day/night visuals turn over while the app stays
// open.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/part_of_day.dart';

class PartOfDayBuilder extends ConsumerStatefulWidget {
  const PartOfDayBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, PartOfDay period) builder;

  @override
  ConsumerState<PartOfDayBuilder> createState() => _PartOfDayBuilderState();
}

class _PartOfDayBuilderState extends ConsumerState<PartOfDayBuilder> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker =
        Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, PartOfDay.of(ref.watch(clockProvider)()));
}
