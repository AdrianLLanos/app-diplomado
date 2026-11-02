import 'package:flutter/material.dart';

class ClinicModule {
  const ClinicModule(this.name, this.description, this.icon, this.endpoint);
  final String name;
  final String description;
  final IconData icon;
  final String endpoint;
}

class ModuleScreen extends StatelessWidget {
  const ModuleScreen({super.key, required this.module});
  final ClinicModule module;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(module.name)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(module.icon, size: 56, color: const Color(0xFF006B72)),
              const SizedBox(height: 16),
              Text(
                module.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(module.description, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              const Text(
                'Esta pantalla esta pendiente de implementacion.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
