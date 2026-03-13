# Reaktionsspiel

Eine Flutter-App für ein Multiplayer-Reaktionsspiel über Firebase.

## Setup

1. Firebase-Projekt erstellen: https://console.firebase.google.com/
2. Realtime Database aktivieren.
3. Für Android: google-services.json herunterladen und in `android/app/` platzieren.
4. Für iOS: GoogleService-Info.plist in `ios/Runner/` platzieren.
5. Für Web: Firebase-Konfiguration hinzufügen.
   - Am einfachsten: `flutterfire configure` ausführen (benötigt das FlutterFire CLI).
   - Alternativ: `firebaseConfig` aus der Firebase-Konsole kopieren und in `web/index.html` einfügen (wie in der Firebase-Dokumentation beschrieben).

## Spielregeln

- Mehrere Spieler treten einem Raum bei.
- Ein Spieler startet das Spiel.
- Nach Countdown erscheint eine zufällige Farbe.
- Wer die Farbe am schnellsten anklickt, bekommt einen Punkt.
- Wer zu früh klickt, scheidet aus.

## Ausführen

```bash
flutter pub get
flutter run
```
