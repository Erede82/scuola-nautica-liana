import 'package:flutter/material.dart';

void main() {
  runApp(const ScuolaNauticaLianaApp());
}

class ScuolaNauticaLianaApp extends StatelessWidget {
  const ScuolaNauticaLianaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scuola Nautica Liana',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scuola Nautica Liana'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Benvenuto nella tua app per i quiz nautici',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}