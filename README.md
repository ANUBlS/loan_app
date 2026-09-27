# Loan App (Flutter, mock data)

Screens: Register -> Biometric lock -> My loans -> Payment schedule -> Order a loan.

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

## Swapping mock data for the real API
All data goes through lib/data/loan_repository.dart. Replace MockData.loans()
and submitApplication() with HTTP calls; screens stay unchanged.
