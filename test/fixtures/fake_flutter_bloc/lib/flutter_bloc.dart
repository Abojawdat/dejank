import 'package:flutter/widgets.dart';

abstract class Cubit<S> {
  Cubit(this.state);
  S state;
}

class BlocBuilder<B, S> extends StatelessWidget {
  const BlocBuilder({super.key, required this.builder, this.buildWhen});
  final Widget Function(BuildContext context, S state) builder;
  final bool Function(S previous, S current)? buildWhen;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

class BlocSelector<B, S, T> extends StatelessWidget {
  const BlocSelector({super.key, required this.selector, required this.builder});
  final T Function(S state) selector;
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

extension WatchContext on BuildContext {
  T watch<T>() => throw UnimplementedError();
}

extension SelectContext on BuildContext {
  R select<T, R>(R Function(T value) selector) => throw UnimplementedError();
}

extension ReadContext on BuildContext {
  T read<T>() => throw UnimplementedError();
}
