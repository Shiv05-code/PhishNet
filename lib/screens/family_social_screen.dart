import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class FamilySocialScreen extends StatelessWidget {
  const FamilySocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family/Social')),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text(
          'Family/Social screen — placeholder.\nContacts list goes here.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
