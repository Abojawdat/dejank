import 'package:flutter/widgets.dart';

class BlocBuilder<B, S> extends StatelessWidget {
  const BlocBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, S state) builder;

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
