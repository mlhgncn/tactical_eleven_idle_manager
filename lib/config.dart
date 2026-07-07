class Config {
  // AdMob
  static const String admobAppId = 'ca-app-pub-3621419452103208~8380492399';
  static const String rewardedAdUnitId = 'ca-app-pub-3621419452103208/5064063910';
  static const String interstitialAdUnitId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: '');

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}
