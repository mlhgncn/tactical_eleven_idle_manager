class AppException implements Exception {
  final String message;
  final bool isTransient;
  final bool isCritical;

  AppException(this.message, {this.isTransient = false, this.isCritical = false});

  // No "AppException: " prefix - message is already normalized/user-facing
  // (see normalizeSupabaseMessage), and callers across the app show it
  // via error.toString().replaceAll('Exception: ', ''), which was written
  // for plain Exception('msg') objects (toString "Exception: msg") - with
  // a prefix here that pattern would only strip "Exception: " and leave a
  // stray "App" glued to the message.
  @override
  String toString() => message;

  factory AppException.network(String message) => AppException(message, isTransient: true);
  factory AppException.supabase(String message) => AppException(message);
  factory AppException.unexpected(String message) => AppException(message, isCritical: true);
}

// Exact-match translations for every RAISE EXCEPTION message used across
// the Postgres RPCs (supabase/migrations/*.sql). Checked before the looser
// substring heuristics below, since those were producing actively
// misleading text for some cases - e.g. "Player has already reached their
// potential" matched the generic 'already' -> "duplicate key" branch,
// which has nothing to do with what actually happened.
const Map<String, String> _exactSupabaseMessages = {
  'A club development upgrade is already in progress': 'Zaten devam eden bir kulüp geliştirmesi var.',
  'Asking price must be positive': 'İstenen fiyat sıfırdan büyük olmalı.',
  'Buyer club has insufficient budget': 'Alıcı kulübün yeterli bütçesi yok.',
  'Buyer club has insufficient reserved funds to complete transfer': 'Alıcı kulübün ayrılmış bütçesi transferi tamamlamaya yetmiyor.',
  'Buyer club not found': 'Alıcı kulüp bulunamadı.',
  'Cannot accept a bid from the same club': 'Kendi kulübünüzün teklifini kabul edemezsiniz.',
  'Cannot make an offer for your own player': 'Kendi oyuncunuza teklif veremezsiniz.',
  'Cannot withdraw a listing that already has a bid': 'Teklif almış bir listeleme geri çekilemez.',
  'Club not found or not owned by current user': 'Kulüp bulunamadı veya size ait değil.',
  'Insufficient available budget to make this offer': 'Bu teklifi vermek için yeterli kullanılabilir bütçeniz yok.',
  'Insufficient budget to sign this player': 'Bu oyuncuyu transfer etmek için yeterli bütçeniz yok.',
  'Invalid upgrade type': 'Geçersiz geliştirme türü.',
  'No active transfer offer exists for this player': 'Bu oyuncu için aktif bir transfer teklifi yok.',
  'Not enough budget for upgrade': 'Bu geliştirme için yeterli bütçeniz yok.',
  'Not enough budget to upgrade sponsor': 'Sponsorluğu yükseltmek için yeterli bütçeniz yok.',
  'Offer already resolved': 'Bu teklif zaten sonuçlandırıldı.',
  'Offer must be positive': 'Teklif tutarı sıfırdan büyük olmalı.',
  'Offer not found': 'Teklif bulunamadı.',
  'Only admin users can ban users': 'Bu işlem için yönetici yetkisi gerekiyor.',
  'Only admin users can create events': 'Bu işlem için yönetici yetkisi gerekiyor.',
  'Only admin users can create gift codes': 'Bu işlem için yönetici yetkisi gerekiyor.',
  'Only admin users can list clubs': 'Bu işlem için yönetici yetkisi gerekiyor.',
  'Only admin users can list users': 'Bu işlem için yönetici yetkisi gerekiyor.',
  'Only admin users can send push notifications': 'Bu işlem için yönetici yetkisi gerekiyor.',
  'Only admin users can update players': 'Bu işlem için yönetici yetkisi gerekiyor.',
  'Player development already in progress': 'Bu oyuncu için zaten bir gelişim sürüyor.',
  'Player has already reached their potential': 'Bu oyuncu zaten potansiyeline ulaştı.',
  'Player is a free agent, use sign_free_agent instead': 'Bu oyuncu serbest - teklif yerine doğrudan transfer edin.',
  'Player is not a free agent': 'Bu oyuncu serbest değil.',
  'Player must belong to a club to accept offers': 'Teklifi kabul edebilmesi için oyuncunun bir kulübü olmalı.',
  'Player not found or has no club': 'Oyuncu bulunamadı veya bir kulübe ait değil.',
  'Player not found or not owned by current user': 'Oyuncu bulunamadı veya size ait değil.',
  'Player not found': 'Oyuncu bulunamadı.',
  'Season not found': 'Sezon bulunamadı.',
  'Sponsor level cannot exceed 5': 'Sponsorluk seviyesi 5\'i geçemez.',
  'Sponsor upgrade already in progress': 'Zaten devam eden bir sponsorluk yükseltmesi var.',
  'Stadium capacity cannot exceed 100000': 'Stadyum kapasitesi 100.000\'i geçemez.',
  'Stadium capacity must be higher than current capacity': 'Yeni kapasite, mevcut kapasiteden büyük olmalı.',
  'This player is already listed for transfer': 'Bu oyuncu zaten transfer listesinde.',
  'This player is not currently listed for transfer': 'Bu oyuncu şu anda transfer listesinde değil.',
  'This user already owns a club': 'Zaten bir kulübünüz var.',
  'Ticket price level cannot exceed 10': 'Bilet fiyatı seviyesi 10\'u geçemez.',
  'Ticket price level must be higher than current level': 'Yeni seviye, mevcut seviyeden büyük olmalı.',
  'Ticket price must be higher than current price': 'Yeni bilet fiyatı, mevcut fiyattan yüksek olmalı.',
  'Training facility level cannot exceed 10': 'Tesis seviyesi 10\'u geçemez.',
  'Training facility level must be higher than current level': 'Yeni seviye, mevcut seviyeden büyük olmalı.',
  'Unknown pack': 'Paket bulunamadı.',
  'User does not own a club': 'Bir kulübünüz yok.',
  'User does not own the selling club': 'Satan kulüp size ait değil.',
  'You already have a pending offer for this player': 'Bu oyuncu için zaten bekleyen bir teklifiniz var.',
  'You do not own the selling club': 'Satan kulüp size ait değil.',
  'You do not own this offer': 'Bu teklif size ait değil.',
  'You do not own this player': 'Bu oyuncu size ait değil.',
};

String normalizeSupabaseMessage(String? raw) {
  if (raw == null) return 'Sunucu hatası oluştu.';
  final m = raw.trim();
  if (m.isEmpty) return 'Sunucu hatası oluştu.';

  final exact = _exactSupabaseMessages[m];
  if (exact != null) return exact;

  if (m.contains('Unauthenticated') || m.contains('authentication')) {
    return 'Oturumunuz geçersiz. Lütfen tekrar giriş yapın.';
  }

  if (m.toLowerCase().contains('insufficient') || m.toLowerCase().contains('not enough budget')) {
    return 'Yeterli bakiye yok.';
  }

  if (m.contains('duplicate key')) {
    if (m.toLowerCase().contains('username')) {
      return 'Bu kullanıcı adı zaten alınmış. Başka bir tane deneyin.';
    }
    return 'Zaten mevcut olan bir kaynakla çakışma var.';
  }

  // Anything else (including already-Turkish messages with a formatted
  // value, e.g. the position-group development conflict) is shown as-is
  // rather than forced through a generic bucket that might mislead.
  return m;
}
