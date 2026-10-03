/// Address of the Loan API (github.com/ANUBlS/loan_api).
///
/// Set it at build time:
///   flutter build apk --dart-define=API_BASE_URL=http://192.168.1.10:8000
/// or change it in the app (Register screen or More > Server).
/// The default reaches a server on the same PC from the Android emulator.
const String kDefaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);
