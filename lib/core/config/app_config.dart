class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
    this.apiBaseUrl = defaultApiBaseUrl,
  });

  static const defaultApiBaseUrl =
      'https://proyecto-diplomado-angular-frontend.vercel.app/api/v1';
  final String apiBaseUrl;

  final String supabaseUrl;
  final String supabasePublishableKey;

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    ),
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  bool get isConfigured {
    final uri = Uri.tryParse(apiBaseUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}
