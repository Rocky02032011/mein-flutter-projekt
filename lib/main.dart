import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math';

import 'firebase_options.dart';

void main() {
  runApp(const ReactionApp());
}

class ReactionApp extends StatefulWidget {
  const ReactionApp({super.key});

  @override
  State<ReactionApp> createState() => _ReactionAppState();
}

class _ReactionAppState extends State<ReactionApp> {
  late final Future<void> _initFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      _error = e.toString();
      // ignore: avoid_print
      print('Firebase init error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reaktionsspiel v1',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Fehler')),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Firebase konnte nicht initialisiert werden.',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    Text(_error!),
                    const SizedBox(height: 20),
                    const Text(
                      'Stelle sicher, dass du Firebase für diese Plattform konfiguriert hast.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return const HomePage();
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reaktionsspiel v1')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Dein Name'),
            ),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(labelText: 'Raum-ID'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty &&
                    _roomController.text.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GamePage(
                        playerName: _nameController.text,
                        roomId: _roomController.text,
                      ),
                    ),
                  );
                }
              },
              child: const Text('Beitreten'),
            ),
            Text("V2"),
          ],
        ),
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  final String playerName;
  final String roomId;

  const GamePage({super.key, required this.playerName, required this.roomId});

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  late DatabaseReference _roomRef;
  late DatabaseReference _playersRef;
  late DatabaseReference _gameRef;

  String _status = 'Warten auf Spielstart...';
  Color _currentColor = Colors.grey;
  bool _canClick = false;
  int _reactionTime = 0;
  final Stopwatch _stopwatch = Stopwatch();
  bool _disqualified = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _roomRef = _database.child('rooms/${widget.roomId}');
    _playersRef = _roomRef.child('players');
    _gameRef = _roomRef.child('game');

    _joinRoom();
    _listenToGame();
  }

  void _joinRoom() {
    _playersRef.child(widget.playerName).set({
      'name': widget.playerName,
      'score': 0,
      'disqualified': false,
      'reactionTime': -1,
    });
  }

  void _listenToGame() {
    _gameRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          _status = data['status'] ?? 'Warten...';
          _canClick = data['canClick'] ?? false;
          if (_canClick && !_disqualified) {
            _stopwatch.start();
          } else {
            _stopwatch.stop();
          }
          // Farbe setzen
          String colorStr = data['color'] ?? 'grey';
          _currentColor = _getColorFromString(colorStr);
        });
      }
    });
  }

  Color _getColorFromString(String color) {
    switch (color) {
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  void _startGame() {
    _gameRef.set({'status': 'Bereit...', 'canClick': false, 'color': 'grey'});

    // Kurze Wartezeit, bevor die Farbe angezeigt wird (ohne sichtbaren Countdown).
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      _showColor();
    });
  }

  void _showColor() {
    List<String> colors = ['red', 'blue', 'green', 'yellow'];
    String randomColor = colors[Random().nextInt(colors.length)];
    _gameRef.update({
      'status': 'Klick die Farbe!',
      'canClick': true,
      'color': randomColor,
    });
    // Nach 2 Sekunden zurücksetzen
    Timer(const Duration(seconds: 2), () {
      _gameRef.update({
        'status': 'Runde vorbei',
        'canClick': false,
        'color': 'grey',
      });
      _calculateWinner();
    });
  }

  void _calculateWinner() {
    _playersRef.once().then((event) {
      final players = event.snapshot.value as Map?;
      if (players != null) {
        String winner = '';
        int bestTime = 999999;
        players.forEach((key, value) {
          final player = value as Map;
          int time = player['reactionTime'] ?? 999999;
          bool disqualified = player['disqualified'] ?? false;
          if (!disqualified && time > 0 && time < bestTime) {
            bestTime = time;
            winner = key;
          }
        });
        if (winner.isNotEmpty) {
          _playersRef.child(winner).update({'score': ServerValue.increment(1)});
          setState(() {
            _status = 'Gewinner: $winner (${bestTime}ms)';
          });
        }
      }
    });
    Timer(const Duration(seconds: 3), () {
      _gameRef.set({
        'status': 'Warten auf nächsten Start...',
        'canClick': false,
        'color': 'grey',
      });
      setState(() {
        _reactionTime = 0;
        _disqualified = false;
      });
    });
  }

  void _onTap() {
    if (_disqualified) return;
    if (!_canClick) {
      // Zu früh geklickt
      setState(() {
        _disqualified = true;
        _status = 'Disqualifiziert!';
      });
      _playersRef.child(widget.playerName).update({'disqualified': true});
    } else {
      // Geklickt
      _stopwatch.stop();
      _reactionTime = _stopwatch.elapsedMilliseconds;
      _playersRef.child(widget.playerName).update({
        'reactionTime': _reactionTime,
      });
      setState(() {
        _status = 'Reaktionszeit: ${_reactionTime}ms';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Raum: ${widget.roomId}')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startGame,
              child: const Text('Spiel starten'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _onTap,
              child: Container(
                width: 200,
                height: 200,
                color: _currentColor,
                child: const Center(child: Text('Klick mich!')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
