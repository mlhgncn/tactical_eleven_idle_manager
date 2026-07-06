class AppException implements Exception {
  final String message;
  final bool isTransient;
  final bool isCritical;

  AppException(this.message, {this.isTransient = false, this.isCritical = false});

  @override
  String toString() => 'AppException: $message';

  factory AppException.network(String message) => AppException(message, isTransient: true);
  factory AppException.supabase(String message) => AppException(message);
  factory AppException.unexpected(String message) => AppException(message, isCritical: true);
}

String normalizeSupabaseMessage(String? raw) {
  if (raw == null) return 'Sunucu hatası oluştu.';
  var m = raw.trim();
  if (m.isEmpty) return 'Sunucu hatası oluştu.';

  // Common translations
  if (m.contains('Unauthenticated') || m.contains('authentication')) {
    return 'Oturumunuz geçersiz. Lütfen tekrar giriş yapın.';
  }

  if (m.contains('duplicate key') || m.contains('already')) {
    return 'Zaten mevcut olan bir kaynakla çakışma var.';
  }

  if (m.toLowerCase().contains('insufficient')) {
    return 'Yeterli bakiye yok.';
  }

  return m;
}
