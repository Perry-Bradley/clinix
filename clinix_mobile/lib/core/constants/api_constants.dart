/// ─── API Configuration ────────────────────────────────────────────────────
///
/// Switch between emulator and real device testing by commenting/uncommenting
/// the appropriate BASE_URL below. Then do a hot restart.
///
class ApiConstants {
  // ✅ Use this for Android Emulator (localhost shortcut)
  // static const String _host = 'http://10.0.2.2:8000';

  // ✅ Use this for a real phone on the same Wi-Fi as your PC
  static const String _host = 'http://192.168.1.165:8000';

  static const String baseUrl = '$_host/api/v1/';
  static const String accounts = 'auth/';
  static const String providers = 'providers/';
  static const String appointments = 'appointments/';
  static const String consultations = 'consultations/';
  static const String aiEngine = 'ai/';
}
