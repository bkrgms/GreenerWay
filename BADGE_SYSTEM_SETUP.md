# GreenerWay Rozet Sistemi - Kurulum Rehberi

## ✅ Eklenen Dosyalar

### 1. Models/Badge.swift
- 20+ rozet tanımı
- UserStats modeli (Firebase)
- BadgeDefinitions sınıfı

### 2. ViewModels/BadgeViewModel.swift
- Firebase entegrasyonu
- Otomatik rozet kontrolü
- Seviye ve puan sistemi

### 3. Views/BadgesView.swift
- Rozet listesi ekranı
- Seviye kartı
- İstatistik grid

## 📱 Değiştirilen Dosyalar

### 1. RouteSearchView.swift
- ✅ Rozet butonu eklendi (🏆 turuncu ikon)
- ✅ Üst bar sadeleştirildi
- ✅ İkon boyutları küçültüldü (40px → 36px)

### 2. RouteDetailView.swift
- ✅ BadgeViewModel entegrasyonu
- ✅ Harita section kaldırıldı (daha sade)
- ✅ AI Insight kartı yeniden tasarlandı
- ✅ Route Header sadeleştirildi
- ✅ Weather kartı sadeleştirildi
- ✅ Yolculuk kaydedildiğinde rozet sistemi tetikleniyor

### 3. ProfileSettings.swift
- ✅ "Tüm Rozetleri Gör" butonu eklendi
- ✅ BadgeRowView güncellenedi

## 🔥 Firebase Yapısı

```
Firestore:
  userStats/
    {userId}/
      - totalJourneys: 0
      - totalEmissionSaved: 0.0
      - totalDistance: 0.0
      - walkingDistance: 0.0
      - transitCount: 0
      - carCount: 0
      - walkingCount: 0
      - aiRecommendationUsed: 0
      - consecutiveDays: 0
      - lastJourneyDate: null
      - totalPoints: 0
      - unlockedBadgeIds: []
```

## 🧪 Test Adımları

1. **Projeyi Derle**
   - Xcode'da Product > Build (⌘B)

2. **Rozet Sayfasına Git**
   - Ana sayfada sağ üstte 🏆 turuncu ikona tıkla
   - Seviye, puan ve rozetleri gör

3. **Rozet Kazanma**
   - Rota oluştur
   - "Akıllı Öneri" veya "Tercihim" butonuna bas
   - İlk yolculukta "🎉 Yeni Rozet!" alert'i çıkacak

4. **Profil Sayfası**
   - Profil > "Tüm Rozetleri Gör" butonuna tıkla

## 🎨 UI İyileştirmeleri

### Ana Sayfa
- Rozet butonu eklendi
- Üst bar daha temiz ve sade
- İkonlar küçültüldü

### Rota Detayı
- Harita kaldırıldı (daha az karmaşık)
- Kartlar sadeleştirildi
- AI önerisi daha okunabilir
- Modern istatistik kartları (6 adet)

## 📊 Rozet Kategorileri

1. **Yolculuk** (Mavi) - Toplam yolculuk sayısı
2. **Çevre** (Yeşil) - CO₂ tasarrufu
3. **Seri** (Turuncu) - Ardışık günler
4. **Ulaşım** (Mor) - Mod bazlı
5. **Özel** (Sarı) - AI kullanımı vb.

## 🏆 Seviye Sistemi

| Seviye | Unvan | Puan |
|--------|-------|------|
| 1 | Başlangıç | 0 |
| 2 | Çaylak | 200 |
| 3 | Gezgin | 500 |
| 4 | Kaşif | 1000 |
| 5 | Yolcu | 1500 |
| 6 | Uzman | 2000 |
| 7 | Usta | 2500 |
| 8 | Efsane | 3000 |
| 9 | Şampiyon | 4000 |
| 10 | Gezegen Koruyucu | 5000 |

## ✨ Özellikler

- ✅ Firebase otomatik senkronizasyon
- ✅ Rozet açma alert'i
- ✅ İlerleme çubukları
- ✅ Kategori filtreleme
- ✅ Puan sistemi
- ✅ Ardışık gün takibi
- ✅ AI kullanım istatistiği

## 🚀 Kullanım

Tüm dosyalar eklendi ve hazır. Xcode'da derleme yapabilirsin. Rozet sistemi otomatik çalışacak ve her yolculuk kaydedildiğinde rozetler kontrol edilip açılacak.
