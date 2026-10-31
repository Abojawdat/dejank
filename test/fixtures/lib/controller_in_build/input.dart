import 'package:flutter/material.dart';

class Signup extends StatelessWidget {
  const Signup({super.key});

  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<FormState>(); // LINT
    return Form(
      key: key,
      child: Column(
        children: [
          TextField(controller: TextEditingController()), // LINT
          ListView(controller: ScrollController()), // LINT
          // Made in a tap handler: not flagged.
          ElevatedButton(
            onPressed: () {
              final c = TextEditingController();
              c.dispose();
            },
            child: const Text('ok'),
          ),
        ],
      ),
    );
  }
}

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(key: _formKey, child: TextField(controller: _name, focusNode: _focus));
  }
}
