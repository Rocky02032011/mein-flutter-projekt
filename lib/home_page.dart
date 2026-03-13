import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:gittest/game_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isJoining = false;
  String? _errorMessage;

  Future<void> _joinRoom() async {
    final name = _nameController.text.trim();
    final roomId = _roomController.text.trim();

    if (name.isEmpty || roomId.isEmpty) return;

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final playerRef = FirebaseDatabase.instance.ref(
        'rooms/$roomId/players/$name',
      );

      // Pruefen ob Name bereits vergeben
      final snapshot = await playerRef.get();
      if (snapshot.exists) {
        setState(() {
          _errorMessage = 'Dieser Name ist in dem Raum bereits vergeben!';
          _isJoining = false;
        });
        return;
      }

      // Spieler dem Raum hinzufuegen
      await playerRef.set({
        'name': name,
        'score': 0,
        'disqualified': false,
        'reactionTime': -1,
        'ready': false,
      });

      // Beim Verlassen der App den Spieler entfernen
      await playerRef.onDisconnect().remove();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GamePage(playerName: name, roomId: roomId),
          ),
        ).then((_) {
          // Spieler entfernen wenn zurueck zur HomePage
          playerRef.remove();
          setState(() => _isJoining = false);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler beim Beitreten: $e';
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reaktionsspiel')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Reaktionsspiel',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Dein Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Raum-ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.meeting_room),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isJoining ? null : _joinRoom,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isJoining
                    ? const CircularProgressIndicator()
                    : const Text('Beitreten', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Erstelle einen Raum oder tritt einem bestehenden bei,\nindem du dieselbe Raum-ID verwendest.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
