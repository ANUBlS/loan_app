/// Address of the Loan API (github.com/ANUBlS/loan_api).
///
/// Default: the production server smartfinance.az:42420.
/// Override at build time:
///   flutter build apk --dart-define=API_BASE_URL=http://192.168.2.93
/// or change it in the app (Register screen or More > Server).
/// For the Android emulator against a local API use http://10.0.2.2:8000.
const String kDefaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://smartfinance.az:42420',
);
