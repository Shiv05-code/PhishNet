import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import 'results_screen.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture')),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Tap to Upload', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            InkWell(
              onTap: () {
                // Placeholder — wire up image/file picker later.
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.blue.shade300,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.upload, size: 48, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ResultsScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Scan'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                // Placeholder — wire up clipboard paste later.
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Copy/Paste'),
            ),
          ],
        ),
      ),
    );
  }
}
