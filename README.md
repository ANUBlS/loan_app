# Loan App (Flutter)

Screens: Register (SMS code) -> Passcode / biometrics -> My loans -> Payment schedule -> Order a loan.

## 1. Create the project shell
    flutter create --org com.example --platforms android,ios loan_app

## 2. Copy these files over the generated ones
    pubspec.yaml
    lib/                      (whole folder)
    test/widget_test.dart
    android/app/src/main/AndroidManifest.xml
    android/app/src/main/kotlin/com/example/loan_app/MainActivity.kt

If you used a different --org, keep the `package` line of your own MainActivity.kt
and only change the class to extend FlutterFragmentActivity.

## 3. Run on Android
    cd loan_app
    flutter pub get
    flutter run

Emulator: Settings > Security > Fingerprint (set a PIN first, then add a fingerprint).
When the prompt appears, open emulator ... > Extended controls > Fingerprint > Touch sensor.

Release APK:
    flutter build apk --release

## 4. iOS (later)
Add to ios/Runner/Info.plist inside <dict>:

    <key>NSFaceIDUsageDescription</key>
    <string>Face ID is used to unlock your loans.</string>

Then:
    cd ios && pod install && cd ..
    flutter run

Simulator: Features > Face ID > Enrolled, then Matching Face when prompted.

## Server (Loan API)
The app works with the backend in github.com/ANUBlS/loan_api (FastAPI + PostgreSQL).

Sign-in: name + phone -> SMS code (POST /api/v1/auth/otp/request, /otp/verify)
-> 6-digit passcode on the phone. Loans, schedules, payments, applications and
documents all come from the API through lib/data/loan_repository.dart and
lib/data/api_client.dart (dart:io, no extra packages).

Server address:
- In the app: Register screen (server icon) or More > Server, with "Check connection".
- At build time: `flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.10:8000`
- Default: http://10.0.2.2:8000 (the PC from the Android emulator).

Run the API on your PC so a phone on the same Wi-Fi can reach it:

    uvicorn app.main:app --host 0.0.0.0 --port 8000

then use http://<PC-IP>:8000 in the app (allow port 8000 in Windows Firewall).
A development server returns the SMS code in its answer, and the app shows it
under the code field as "Test server code".

## Languages
All texts live in assets/i18n/translations.json (English, Azerbaijani, Russian).
Edit the texts there, keep keys and {placeholders} unchanged.
To add a language, add its code under "languages" and a text for it in every key.
The chosen language is saved on the device and kept after sign out.
