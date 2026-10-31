import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TripList extends StatelessWidget {
  const TripList({super.key, required this.prices});
  final List<double> prices;

  @override
  Widget build(BuildContext context) {
    // Once per build of the whole list, not per item.
    final header = DateFormat('yMd');
    return Column(
      children: [
        Text(header.format(DateTime.now())),
        Expanded(child: ListView.builder(itemCount: prices.length, itemBuilder: (_, i) => TripTile(price: prices[i]))),
        Expanded(child: ListView.builder(itemCount: prices.length, itemBuilder: _row)),
      ],
    );
  }

  Widget _row(BuildContext context, int i) => Text(DateFormat.yMd().format(DateTime.now())); // LINT
}

class TripTile extends StatelessWidget {
  static final _regExp = RegExp(r'^\d+(\.\d+)?$');

  const TripTile({super.key, required this.price});
  final double price;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(_price()),
      subtitle: Text(_valid('$price') ? 'ok' : 'bad'),
      // A tap is rare: not flagged.
      onTap: () => debugPrint(DateFormat('Hm').format(DateTime.now())),
    );
  }

  String _price() => NumberFormat.currency(symbol: r'$').format(price); // LINT

  bool _valid(String s) => _regExp.hasMatch(s); // LINT
}

class Pulse extends StatelessWidget {
  const Pulse({super.key, required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final painter = TextPainter( // LINT
          text: TextSpan(text: '${animation.value}'),
          textDirection: TextDirection.ltr,
        )..layout();
        return SizedBox(width: painter.width, child: child);
      },
    );
  }
}

class Dial extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final label = TextPainter(text: const TextSpan(text: '12'), textDirection: TextDirection.ltr); // LINT
    label.layout();
    label.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(Dial oldDelegate) => false;
}

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  late final RegExp _digits;

  @override
  void initState() {
    super.initState();
    _digits = RegExp(r'\d');
  }

  @override
  Widget build(BuildContext context) => Text('${_digits.hasMatch('1')}');
}
