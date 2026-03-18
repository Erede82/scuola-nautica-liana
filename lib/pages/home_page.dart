import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scuola Nautica Liana'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Benvenuto nella tua app per i quiz nautici',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
            _menuButton(
              context,
              title: 'Login',
              icon: Icons.login,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _menuButton(
              context,
              title: 'Lezioni',
              icon: Icons.menu_book,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _menuButton(
              context,
              title: 'Quiz Esame',
              icon: Icons.quiz,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _menuButton(
              context,
              title: 'Statistiche',
              icon: Icons.bar_chart,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 26),
        label: Text(title, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
