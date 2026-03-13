import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'home_page.dart';

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
      debugPrint('Firebase init error: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reaktionsspiel',
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
