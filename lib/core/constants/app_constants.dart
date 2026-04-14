class AppConstants {
  // SharedPreferences keys
  static const kApiBaseUrl = 'api_base_url';
  static const kWsBaseUrl  = 'ws_base_url';
  static const kUserId     = 'user_id';
  static const kUserRole   = 'user_role';

  // Default local URLs
  // Android emulator → 10.0.2.2 maps to host machine localhost
  static const defaultHttpUrl = 'http://10.0.2.2:8084';
  static const defaultWsUrl   = 'ws://10.0.2.2:8084';

  // Chat service runs on 8084 directly (no Nginx locally)
  static const defaultUserId   = '1';
  static const defaultUserRole = 'USER'; // 'ADMIN' or 'USER'

  // Pagination
  static const defaultPageSize = 50;
  static const channelPageSize = 20;

  // Typing debounce
  static const typingDebounceMs = 500;
  static const typingTimeoutSec = 3;
}
