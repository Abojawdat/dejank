import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum Status { idle, busy }

class WalletState {
  const WalletState({required this.balance, required this.status, required this.history, required this.name});
  final double balance;
  final Status status;
  final List<double> history;
  final String name;
}

class WalletCubit extends Cubit<WalletState> {
  WalletCubit() : super(const WalletState(balance: 0, status: Status.idle, history: [], name: ''));
}

String describe(WalletState s) => s.name;

class Wallet extends StatelessWidget {
  const Wallet({super.key});

  @override
  Widget build(BuildContext context) {
    final balance = context.select((WalletCubit it) => it.state.balance); // LINT
    return Column(
      children: [
        BlocSelector<WalletCubit, WalletState, double>( // LINT
          selector: (state) => state.balance,
          builder: (context, balance) => Card(child: Padding(padding: const EdgeInsets.all(8), child: Text('$balance'))),
        ),
        BlocBuilder<WalletCubit, WalletState>( // LINT
          buildWhen: (previous, current) => previous.name != current.name || previous.status != current.status,
          builder: (context, state) => Card(child: Row(children: [Text(state.name), Text('${state.status}')])),
        ),
        // Suggest only: a list can be changed in place.
        BlocBuilder<WalletCubit, WalletState>( // LINT
          builder: (context, state) => Card(child: Column(children: [for (final h in state.history) Text('$h')])),
        ),

        // Suggest only: the builder also reads the cubit directly.
        BlocBuilder<WalletCubit, WalletState>( // LINT
          builder: (context, state) => Card(child: Row(children: [Text('${state.balance}'), Text(context.read<WalletCubit>().state.name)])),
        ),

        // Must not change.
        BlocBuilder<WalletCubit, WalletState>(
          buildWhen: (p, c) => p.balance != c.balance,
          builder: (context, state) => Card(child: Center(child: Text('${state.balance}'))),
        ),
        BlocBuilder<WalletCubit, WalletState>(
          builder: (context, state) => Card(child: Center(child: Text(describe(state)))),
        ),
        BlocBuilder<WalletCubit, WalletState>(builder: (context, state) => Text(state.name)),
        Text('$balance'),
        // Watching a cubit and reading .state is the same as selecting it.
        Text('${context.watch<WalletCubit>().state}'),
      ],
    );
  }
}
