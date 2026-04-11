# 🚀 Workify - İş ve Görev Yönetim Uygulaması

Workify, Flutter ile geliştirilmiş, kullanıcıların iş süreçlerini dijital ortamda organize etmelerine, görev takibi yapmalarına ve verimliliklerini artırmalarına olanak tanıyan modern bir mobil uygulamadır.



## ✨ Özellikler

* **Görev Yönetimi:** Günlük görevlerinizi ekleyin, düzenleyin ve tamamlandığında işaretleyin.
* **Kategori Filtreleme:** İşlerinizi türlerine göre gruplandırın.
* **Modern Arayüz:** Kullanıcı dostu, sade ve hızlı UI/UX deneyimi.
* **Veri Modelleri:** Tip güvenli (Type-safe) Dart modelleri ile tutarlı veri yapısı.

## 🛠 Kullanılan Teknolojiler & Kütüphaneler

* **Framework:** [Flutter](https://flutter.dev/)
* **Dil:** [Dart](https://dart.dev/)
* **Mimari:** Layered Architecture (Katmanlı Mimari)
* **Durum Yönetimi (State Management):** (Provider/Bloc/GetX hangisini kullanıyorsan buraya ekle)
* **İkonlar:** Cupertino & Material Icons

## 📂 Proje Yapısı

Proje, temiz kod (clean code) prensiplerine uygun olarak şu şekilde organize edilmiştir:

```text
## 📱 Uygulama Modülleri ve Ekran Yapısı

Proje, kullanıcı rollerine göre özelleştirilmiş dinamik bir yapıya sahiptir:

### 🔐 Yetkilendirme ve Ana Ekranlar (`main_screen`)
* **Multi-Role Login:** Kullanıcı tipine (Root, Admin, Worker) göre otomatik yönlendirme.
* **Root Panel:** Sistem genelindeki tüm işletmelerin yönetildiği üst düzey yetkili ekranı.
* **Admin Dashboard:** Şube ve çalışan istatistiklerinin, günlük raporların izlendiği yönetici paneli.
* **Worker Panel:** Personelin kendi görevlerini ve giriş-çıkışlarını takip ettiği kullanıcı ekranı.

### 🏢 Yönetim ve Düzenleme (`edit`)
* **Şube Yönetimi:** Yeni şube tanımlama ve mevcut şube bilgilerini güncelleme.
* **Personel Yönetimi:** Çalışan ekleme, yetkilendirme ve profil düzenleme modülleri.
* **İşletme Ayarları:** Kurumsal bilgilerin ve genel sistem konfigürasyonlarının yönetimi.

### 🔍 Detay ve İzleme (`detail`)
* **Admin Log Sistemi:** Sistem üzerinde yapılan tüm kritik işlemlerin kronolojik olarak takibi.
* **QR Scanner:** İşçi giriş-çıkışları veya varlık takibi için entegre QR kod okuma modülü.
* **Gelişmiş Detay Sayfaları:** Şube ve çalışan bazlı özelleştirilmiş veri görünümü.

## 📂 Klasör Yapısı

```text
lib/
├── screens/
│   ├── main_screen/  # Rol tabanlı ana giriş panelleri
│   ├── edit/         # Ekleme ve düzenleme formları (CRUD)
│   └── detail/       # Detay analiz ve QR takip ekranları
├── models/           # İşletme, Şube ve Çalışan modelleri
├── services/         # Veritabanı ve yetkilendirme servisleri
└── widgets/          # Ortak UI bileşenleri
