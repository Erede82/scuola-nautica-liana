import 'package:flutter/material.dart';
import 'pages/home_page.dart';

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
