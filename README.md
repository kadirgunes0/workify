# 🚀 Workify - İş ve Görev Yönetim Uygulaması

Workify, Flutter ile geliştirilmiş, kullanıcıların iş süreçlerini dijital ortamda organize etmelerine, görev takibi yapmalarına ve verimliliklerini artırmalarına olanak tanıyan modern bir mobil uygulamadır.



## Özellikler

* **Görev Yönetimi:** Günlük görevlerinizi ekleyin, düzenleyin ve tamamlandığında işaretleyin.
* **Kategori Filtreleme:** İşlerinizi türlerine göre gruplandırın.
* **Modern Arayüz:** Kullanıcı dostu, sade ve hızlı UI/UX deneyimi.
* **Veri Modelleri:** Tip güvenli (Type-safe) Dart modelleri ile tutarlı veri yapısı.

## Kullanılan Teknolojiler & Kütüphaneler

* **Framework:** [Flutter](https://flutter.dev/)
* **Dil:** [Dart](https://dart.dev/)
* **Mimari:** Layered Architecture (Katmanlı Mimari)
* **Durum Yönetimi (State Management):** (Provider/Bloc/GetX hangisini kullanıyorsan buraya ekle)
* **İkonlar:** Cupertino & Material Icons

## 1. Bilgisayar Kurulum Gereksinimleri (Ön Hazırlık)

İlk önce projeyi git clone ile çekelim:
```bash
git clone [https://github.com/kadirgunes0/workify.git](https://github.com/kadirgunes0/workify.git)
cd workify
```

Projeyi bilgisayarınızda derleyebilmek için aşağıdaki yerel geliştirme araçlarının yüklü olması gerekir:

1. **Flutter SDK:** Bilgisayarınızda Flutter yüklü değilse [Flutter Resmi Sitesinden](https://docs.flutter.dev/get-started/install) işletim sisteminize uygun stabil sürümü indirin ve `PATH` ortam değişkenlerine ekleyin.
2. **Java Development Kit (JDK):** Android derlemesi için bilgisayarınızda **JDK 11 veya JDK 17** yüklü olmalıdır.
3. **Android Studio / VS Code:** Kodları çalıştırmak ve sanal cihaz (Emulator) ayağa kaldırmak için dilediğiniz editörü kurun. Android Studio kullanıyorsanız `Android SDK Command-line Tools` bileşeninin yüklü olduğundan emin olun.

Komut satırından kurulumların doğruluğunu test edin:
```bash
flutter doctor
```
Paketleri yüklemek için:
```bash
flutter pub clean
flutter pub get
```
Firebase kurulumu adım adım:
```bash
npm install -g firebase-tools
```
Firebase hesabınıza terminalden giriş yapın
```bash
firebase login
```
Projeyi firebase'e bağlamak için flutterfire_cli aktifleştirin
```bash
dart pub global activate flutterfire_cli
```
Projenin ana dizinindeyken bu komutu çalıştırarak veri tabanınızı seçin
```bash
flutterfire configure
```

## Proje Yapısı

Proje, temiz kod (clean code) prensiplerine uygun olarak şu şekilde organize edilmiştir:

```text
## Uygulama Modülleri ve Ekran Yapısı

Proje, kullanıcı rollerine göre özelleştirilmiş dinamik bir yapıya sahiptir:

### Yetkilendirme ve Ana Ekranlar (`main_screen`)
* **Multi-Role Login:** Kullanıcı tipine (Root, Admin, Worker) göre otomatik yönlendirme.
* **Root Panel:** Sistem genelindeki tüm işletmelerin yönetildiği üst düzey yetkili ekranı.
* **Admin Dashboard:** Şube ve çalışan istatistiklerinin, günlük raporların izlendiği yönetici paneli.
* **Worker Panel:** Personelin kendi görevlerini ve giriş-çıkışlarını takip ettiği kullanıcı ekranı.

### Yönetim ve Düzenleme (`edit`)
* **Şube Yönetimi:** Yeni şube tanımlama ve mevcut şube bilgilerini güncelleme.
* **Personel Yönetimi:** Çalışan ekleme, yetkilendirme ve profil düzenleme modülleri.
* **İşletme Ayarları:** Kurumsal bilgilerin ve genel sistem konfigürasyonlarının yönetimi.

### Detay ve İzleme (`detail`)
* **Admin Log Sistemi:** Sistem üzerinde yapılan tüm kritik işlemlerin kronolojik olarak takibi.
* **QR Scanner:** İşçi giriş-çıkışları veya varlık takibi için entegre QR kod okuma modülü.
* **Gelişmiş Detay Sayfaları:** Şube ve çalışan bazlı özelleştirilmiş veri görünümü.

## Klasör Yapısı

```text
lib/
├── screens/
│   ├── main_screen/  # Rol tabanlı ana giriş panelleri
│   ├── edit/         # Ekleme ve düzenleme formları (CRUD)
│   └── detail/       # Detay analiz ve QR takip ekranları
├── models/           # İşletme, Şube ve Çalışan modelleri
├── services/         # Veritabanı ve yetkilendirme servisleri
└── widgets/          # Ortak UI bileşenleri
