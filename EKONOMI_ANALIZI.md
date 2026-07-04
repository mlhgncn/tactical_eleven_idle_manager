# Ekonomi Sistemi Analizi - Tactical Eleven: Idle Manager

## 📊 Özet

Oyundaki ekonomi sistemi **basit bir match-to-budget modeli** üzerine kurulu. Ana gelir kaynağı maç sonuçlarından kazanılan para ve tesis yükseltmeleri ile yapılan yatırımlar.

---

## 1️⃣ PARA KAYNAKLARI (Income Sources)

### 1.1 Maç Sonucu Geliri ⚽
**Dosya:** [lib/providers/game_provider.dart](lib/providers/game_provider.dart#L231)

Formül: `500 + (homeScore × 100)`

| Skor | Gelir (GP) |
|------|-----------|
| 0-0  | 500      |
| 1-0  | 600      |
| 2-0  | 700      |
| 3-0  | 800      |
| 4-0  | 900      |
| 5-0  | 1000     |
| 6-0  | 1100     |

**Özellikler:**
- Ev sahibi takımı sadece kendi golleri konunca gelir kazanır
- Deplasman maçlarından gelir yok
- Minimum gelir: 500 GP (hiç gol atmasan bile)
- Maximum gelir: 1100 GP (6 gol)
- Match engine'de maksimum 6 gol sınırı var

**Konum:** [GameProvider.playNextFixture()](lib/providers/game_provider.dart#L231)

### 1.2 Stadyum Müşteri Geliri ❌
- **BULUNMADI** - Stadyum kapasitesi ve bilet fiyatı mevcut ama birbirlerine bağlı kullanılmıyor
- `stadiumCapacity` ve `ticketPrice` ayrı ayrı saklanıyor ama kombinasyon kullanılmıyor
- Potansiyel formula: `stadiumCapacity × ticketPrice` (henüz implement edilmemiş)

### 1.3 Sponsor Geliri ❌
- **BULUNMADI** - Sponsor sistemi kodda yok

### 1.4 Diğer Gelirler ❌
- **BULUNMADI** - Başka gelir kaynağı yok

---

## 2️⃣ PARA ÇIKIŞLARI (Expenses)

### 2.1 Tesis Yükseltme Maliyetleri

**Dosya:** [lib/screens/development_screen.dart](lib/screens/development_screen.dart#L28-L70)  
**Maliyeti Ayarlayan:** [lib/providers/game_provider.dart](lib/providers/game_provider.dart#L365)

| Yükseltme Türü | Maliyet | Artış Miktarı |
|---|---|---|
| Stadyum Kapasitesi | 500 GP | +500 kapasitelik |
| Tesis Seviyesi | 500 GP | +1 seviye |
| Bilet Fiyatı | 500 GP | +10 GP |

**Mekanizm:**
1. Tesis yükseltme başlatılır
2. Kulüp bütçesinden 500 GP düşülür
3. İlgili alan güncellenmiş versiyonla değiştirilir

### 2.2 Oyuncu Transferi Maliyeti 💰

**Dosya:** [lib/providers/game_provider.dart](lib/providers/game_provider.dart#L327-L345)

**Maliyeti Hesaplama:**
- Transfer ücreti = Oyuncuya yapılan **en yüksek teklif miktarı**
- Teklif artış adımı: 100 GP (her teklif artışında)

**Örnek Senaryo:**
```
Oyuncu A için transfer pazarına çıkıyor
- İlk teklif: 100 GP
- İkinci teklif: 200 GP
- Üçüncü teklif: 300 GP
- ...
- En yüksek teklif: 10,000 GP (bu fiyattan satın alınıyor)
```

**Koşul:** Yeterli bütçe varsa (newBudget ≥ 0) transfer kabul edilebilir

**Konum:** [GameProvider.acceptTransferOffer()](lib/providers/game_provider.dart#L327)

### 2.3 Işgücü/Bakım Masrafları ❌
- **BULUNMADI** - Sabit bakım maliyeti yok

---

## 3️⃣ BEKLEME SÜRELERI & PROGRESSION RATES

### 3.1 Maç Takvimi 🗓️
**Dosya:** [lib/providers/game_provider.dart](lib/providers/game_provider.dart#L110-L130)

```dart
// 5 maç oluşturuluyor, 2-8 gün arasında aralıklarla
matchDate = now.add(Duration(days: 2 + index * 3));
```

| Maç # | Gün Aralığı |
|---|---|
| 1 | +2 gün |
| 2 | +5 gün |
| 3 | +8 gün |
| 4 | +11 gün |
| 5 | +14 gün |

### 3.2 Tesis Yükseltme Süresi ⏱️
- **Anında yükseltilir** (gerçek zamanlı bekleme yok)
- Yükseltme yapılır ve hemen uygulanır

### 3.3 Transfer Pazarı Süresi 📋
**Dosya:** [supabase/schema.sql](supabase/schema.sql)

```sql
end_time TIMESTAMPTZ NOT NULL DEFAULT now() + interval '1 day'
```

- Açık açık transfer listesi: **1 gün**
- 1 gün sonunda müzayede sona erer ve oyuncu en yüksek teklifi verene satılır

### 3.4 Oyuncu Gelişim Hızı ❌
- **BULUNMADI** - Oyuncu istatistikleri otomatik gelişmiyor
- Oyuncu `currentAbility` ve `potentialAbility` statik değerler
- Zaman içinde değişim mekanizması yok

### 3.5 Stadyum Kapasitesi Artış Hızı 📈
- **Yapay sınır yok** - 500 GP'ye istediğin zaman yükseltebilir
- Ekonomik darboğaz yoktur

---

## 4️⃣ BAŞLANGIÇ DURUMU

### 4.1 Başlangıç Bütçesi 💵

**Dosya:** [supabase/seed_all.sql](supabase/seed_all.sql#L1)

```sql
INSERT INTO public.clubs(...) VALUES
  ('...', 'LFC Reds', now(), 10000000, 15000, 20, 1, NULL),
  ...
```

| Alan | Başlangıç Değeri |
|---|---|
| **Bütçe** | **10,000,000 GP** |
| Stadyum Kapasitesi | 15,000 |
| Bilet Fiyatı | 20 GP |
| Tesis Seviyesi | 1 |
| Taraftar Sayısı | 0 |

### 4.2 Başlangıç Geliri
- **İlk maçta:** 500-1100 GP (skor sonucuna bağlı)

### 4.3 Başlangıç Harcama Oranları
```
Bütçe = 10,000,000 GP
Her yükseltme = 500 GP

Breakeven Point:
- 10,000,000 / 500 = 20,000 yükseltme yapabilir
- Ortalama maç geliri (650 GP) ile:
  - Bitiş zamanı: ~30,769 maç (∞ yıllar)
```

### 4.4 İlk Oyuncu Kadrosu
- Henüz belirtilmemiş - seed'de player datası var ama nasıl atandığı net değil

---

## 5️⃣ VERI DOSYA KONUMLARI

### 5.1 Model Tanımları
| Model | Dosya | Saklanan Veriler |
|---|---|---|
| **ClubInfo** | [lib/models/club_info.dart](lib/models/club_info.dart) | `budget`, `stadiumCapacity`, `ticketPrice`, `trainingFacilityLevel` |
| **PlayerFM** | [lib/models/player_fm.dart](lib/models/player_fm.dart) | `currentAbility`, `potentialAbility`, `morale`, `fitness` vb. |
| **MatchResult** | [lib/models/match_result.dart](lib/models/match_result.dart) | `homeScore`, `awayScore`, `homeShots`, `awayShots` |
| **TransferMarketItem** | [lib/models/transfer_market_item.dart](lib/models/transfer_market_item.dart) | `currentHighestBid`, `endTime` |

### 5.2 İş Mantığı Dosyaları

| İşlem | Dosya | Metod |
|---|---|---|
| **Maç Simülasyonu** | [lib/repositories/match_repository.dart](lib/repositories/match_repository.dart) | `simulateMatch()` |
| **Maç Oynama + Gelir** | [lib/providers/game_provider.dart](lib/providers/game_provider.dart#L201) | `playNextFixture()` |
| **Tesis Yükseltme** | [lib/providers/game_provider.dart](lib/providers/game_provider.dart#L355) | `upgradeClub()` |
| **Transfer Teklifi** | [lib/repositories/supabase_repository.dart](lib/repositories/supabase_repository.dart#L136) | `placeBid()` |
| **Transfer Kabul** | [lib/repositories/supabase_repository.dart](lib/repositories/supabase_repository.dart#L146) | `acceptTransferOffer()` |

### 5.3 Veritabanı Şeması
| Tablo | Dosya | Ekonomi İlgili Kolonlar |
|---|---|---|
| `clubs` | [supabase/schema.sql](supabase/schema.sql) | `budget`, `stadium_capacity` |
| `transfer_market` | [supabase/schema.sql](supabase/schema.sql) | `current_highest_bid`, `end_time` |
| **Seed Datası** | [supabase/seed_all.sql](supabase/seed_all.sql#L1) | İlk club değerleri |

---

## 6️⃣ HESAPLAMA ÖRNEKLERİ

### 6.1 Maç Geliri Örneği
```
Başlangıç: 10,000,000 GP

Maç 1: 2-0 Kazandı
  Gelir = 500 + (2 × 100) = 700 GP
  Bütçe = 10,000,700 GP

Maç 2: 1-1 Beraber (kendi golü)
  Gelir = 500 + (1 × 100) = 600 GP
  Bütçe = 10,001,300 GP

Maç 3: 3-2 Kazandı
  Gelir = 500 + (3 × 100) = 800 GP
  Bütçe = 10,002,100 GP
```

### 6.2 Tesis Yükseltme Örneği
```
Başlangıç:
  Stadyum: 15,000
  Bilet: 20 GP
  Bütçe: 10,000,000 GP

Stadyum Yükselt (+500 kapasitelik, -500 GP):
  Stadyum: 15,500
  Bütçe: 9,999,500 GP

Bilet Fiyatını Yükselt (+10 GP, -500 GP):
  Bilet: 30 GP
  Bütçe: 9,999,000 GP

Tesis Seviyesi Yükselt (+1 level, -500 GP):
  Tesis Level: 2
  Bütçe: 9,998,500 GP
```

### 6.3 Transfer Örneği
```
Transfer Pazarında Oyuncu A Satışa Çıkıyor:
  
Club 1: Teklif Ver → 1,000 GP
Club 2: Teklif Ver → 1,100 GP
Club 3: Teklif Ver → 1,200 GP
Club 2: Teklif Ver → 1,300 GP

1 Gün Sonra (müzayede sona eriyor):
  En Yüksek Teklif: 1,300 GP (Club 2 tarafından)
  
Oyuncu A satılır, Club 2'nin bütçesinden 1,300 GP düşülür
Club 1 ve Club 3'ün teklifleri geri alınır (ama para iade edilmez!)
```

---

## 7️⃣ EKSIK VE POTENSİYEL ÖZELLIKLER

| Özellik | Durum | Açıklama |
|---|---|---|
| Stadyum Geliri | ❌ Eksik | `stadiumCapacity` × `ticketPrice` kullanılmıyor |
| Sponsor Sistemi | ❌ Eksik | Kod yok |
| Oyuncu Geliştirme | ❌ Eksik | İstatistikler statik kalıyor |
| Bakım Maliyetleri | ❌ Eksik | Sabit haftalık/aylık harcama yok |
| Kayıp Penaltisi | ❌ Eksik | Yenilgi geliri yoksa malı bir etkisi yok |
| Oyuncu Yaşlanması | ❌ Eksik | Oyuncu yaşı değişmiyor |
| Moral Sistemi | ❌ Kısmi | Oyuncu morali var ama etkileri sınırlı |
| Sakatlık Sistemi | ❌ Kısmi | Model'de `injury_duration_weeks` var ama kullanılmıyor |

---

## 8️⃣ İŞLEYİŞ AKIŞI

```
┌─────────────────┐
│ Oyun Başla      │
│ Budget: 10M GP  │
└────────┬────────┘
         │
    ┌────▼─────────┐
    │ Maç Oynan    │
    │ +500-1100 GP │
    └────┬─────────┘
         │
    ┌────▼──────────┐
    │ Gelir Elde    │
    │ Inbox Mesaj   │
    └────┬──────────┘
         │
    ┌────▼──────────────────┐
    │ Yükseltme Yapılır?    │
    │ - Stadyum: 500 GP     │
    │ - Tesis: 500 GP       │
    │ - Bilet: 500 GP       │
    │ - Transfer: Dinamik   │
    └────┬──────────────────┘
         │
    ┌────▼─────────────┐
    │ Bütçe Güncel     │
    │ İnbox Güncelle   │
    │ Listener Haberda │
    └────┬─────────────┘
         │
    ┌────▼────────────┐
    │ Sonraki Maçta?  │
    │ Evet → Tekrar  │
    │ Hayır → Bekle  │
    └─────────────────┘
```

---

## ✅ ÖZET TABLOSU

| Kategori | Tip | Açıklama | Miktar |
|---|---|---|---|
| **Gelir** | Maç Sonucu | 500-1100 GP/maç | Açık |
| **Harcama** | Tesis | 500 GP/yükseltme | Sınırsız |
| **Harcama** | Transfer | 100-∞ GP | Oyuncu bağımlı |
| **Başlangıç** | Bütçe | 10M GP | Sabit |
| **Dönem** | Maç Aralığı | 2-14 gün | Sabit |
| **Dönem** | Transfer Süresi | 1 gün | Sabit |

---

## 📝 Notlar

1. **Ekonomi sistemi basit**: Temelde maç kazanç → tesis yükseltme döngüsü
2. **Bütçe sınırlaması zayıf**: 10M GP ile binlerce yükseltme yapılabilir
3. **Gelir kanalı tek**: Sadece maç sonuçlarına bağlı
4. **Geliştirme alanları**:
   - Stadyum gelirini aktifleştir
   - Sponsor sistemi ekle
   - Oyuncu geliştirme mekanizması
   - Haftalık bakım maliyetleri
   - Başarı bonusları (kupa kazanma vb)

---

**Son Güncelleme:** 2026-07-04  
**Analiz Kapsamı:** Tüm ekonomi mekanikleri
