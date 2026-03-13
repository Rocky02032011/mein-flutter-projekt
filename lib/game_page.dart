import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math';

class GamePage extends StatefulWidget {
  final String playerName;
  final String roomId;

  const GamePage({super.key, required this.playerName, required this.roomId});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final DatabaseReference _roomRef;
  late final DatabaseReference _playersRef;
  late final DatabaseReference _gameRef;

  StreamSubscription? _gameSub;
  StreamSubscription? _playersSub;

  String _status = 'Warten auf Spieler...';
  Color _currentColor = Colors.grey;
  bool _canClick = false;
  bool _hasClicked = false;
  bool _disqualified = false;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  Map<String, dynamic> _players = {};

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instance.ref('rooms/${widget.roomId}');
    _playersRef = _roomRef.child('players');
    _gameRef = _roomRef.child('game');
    _listenToGame();
    _listenToPlayers();
  }

  void _listenToGame() {
    _gameSub = _gameRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final bool canClick = data['canClick'] ?? false;
      final String colorStr = data['color'] ?? 'grey';
      final String status = data['status'] ?? '';
      setState(() {
        _status = status;
        _canClick = canClick;
        _currentColor = _colorFromString(colorStr);
        if (canClick && !_disqualified && !_hasClicked) {
          _stopwatch.reset();
          _stopwatch.start();
        } else if (!canClick) {
          _stopwatch.stop();
        }
        if (status == 'Warten auf naechsten Start...') {
          _hasClicked = false;
          _disqualified = false;
          _stopwatch.reset();
        }
      });
    });
  }

  void _listenToPlayers() {
    _playersSub = _playersRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        _players = Map<String, dynamic>.from(data);
      });
    });
  }

  Color _colorFromString(String color) {
    switch (color) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'yellow': return Colors.yellow;
      default: return Colors.grey;
    }
  }

  void _startGame() {
    _timer?.cancel();
    _gameRef.set({'status': 'Bereit machen...', 'canClick': false, 'color': 'grey'});
    _players.forEach((name, _) {
      _playersRef.child(name).update({'disqualified': false, 'reactionTime': -1});
    });
    final delay = Duration(milliseconds: 1000 + Random().nextInt(3000));
    _timer = Timer(delay, _showColor);
  }

  void _showColor() {
    const colors = ['red', 'blue', 'green', 'yellow'];
    final randomColor = colors[Random().nextInt(colors.length)];
    _gameRef.update({'status': 'Klick jetzt!', 'canClick': true, 'color': randomColor});
    _timer = Timer(const Duration(seconds: 3), () {
      _gameRef.update({'status': 'Runde vorbei', 'canClick': false, 'color': 'grey'});
      _calculateWinner();
    });
  }

  void _calculateWinner() {
    _playersRef.once().then((event) {
      final players = event.snapshot.value as Map?;
      if (players == null) return;
      String winner = '';
      int bestTime = 999999;
      players.forEach((key, value) {
        final player = value as Map;
        final int time = player['reactionTime'] ?? -1;
        final bool disqualified = player['disqualified'] ?? false;
        if (!disqualified && time > 0 && time < bestTime) {
          bestTime = time;
          winner = key.toString();
        }
      });
      if (winner.isNotEmpty) {
        _playersRef.child(winner).update({'score': ServerValue.increment(1)});
        _gameRef.update({'status': 'Gewinner: $winner (${bestTime}ms)'});
      } else {
        _gameRef.update({'status': 'Kein Gewinner dieser Runde'});
      }
      _timer = Timer(const Duration(seconds: 3), () {
        _gameRef.set({'status': 'Warten auf naechsten Start...', 'canClick': false, 'color': 'grey'});
      });
    });
  }

  void _onTap() {
    if (_disqualified || _hasClicked) return;
    if (!_canClick) {
      setState(() {
        _disqualified = true;
        _hasClicked = true;
        _status = 'Zu frueh! Du bist disqualifiziert.';
      });
      _playersRef.child(widget.playerName).update({'disqualified': true});
    } else {
      _stopwatch.stop();
      final time = _stopwatch.elapsedMilliseconds;
      setState(() {
        _hasClicked = true;
        _status = 'Deine Zeit: ${time}ms - Warte auf andere...';
      });
      _playersRef.child(widget.playerName).update({'reactionTime': time});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Raum: ${widget.roomId}')),
      body: Column(
        children: [
          _buildPlayerList(),
          const Divider(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_status, style: const TextStyle(fontSize: 20), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: _currentColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _currentColor.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text('KLICK!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Runde starten'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList() {
    final sorted = _players.entries.toList()
      ..sort((a, b) {
        final scoreA = (a.value as Map)['score'] ?? 0;
        final scoreB = (b.value as Map)['score'] ?? 0;
        return (scoreB as int).compareTo(scoreA as int);
      });
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spieler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (sorted.isEmpty)
            const Text('Keine Spieler im Raum')
          else
            Wrap(
              spacing: 8,
              children: sorted.map((entry) {
                final name = entry.key;
                final data = entry.value as Map;
                final score = data['score'] ?? 0;
                final disq = data['disqualified'] ?? false;
                final reactionTime = data['reactionTime'] ?? -1;
                final isMe = name == widget.playerName;
                return Chip(
                  avatar: disq ? const Icon(Icons.block, size: 16, color: Colors.red) : const Icon(Icons.person, size: 16),
                  label: Text('$name  $score${reactionTime > 0 ? '  ${reactionTime}ms' : ''}'),
                  backgroundColor: isMe ? Colors.blue.shade100 : disq ? Colors.red.shade100 : null,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gameSub?.cancel();
    _playersSub?.cancel();
    super.dispose();
  }
}
