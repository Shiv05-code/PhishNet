import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.red.shade50,
            child: const ListTile(
              leading: Icon(Icons.cancel, color: Colors.red),
              title: Text('Scam Detected'),
              subtitle: Text('85% confidence'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Why this might be a scam',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Unknown Sender')),
              Chip(label: Text('Urgent Language')),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'What should you do?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Do Not Click Links')),
              Chip(label: Text('Block Sender')),
              Chip(label: Text('Report Message')),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Still unsure?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              // Placeholder — wire up "send to family/trusted contact" later.
            },
            child: const Text('Get a second opinion'),
          ),
        ],
      ),
    );
  }
}
