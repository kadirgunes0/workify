import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart'; // YENİ EKLENDİ
import 'package:buildgym/screens/main_screen/admin_main_screen.dart';
import 'worker_main_screen.dart';
import 'root_main_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- YENİ: CİHAZ KİMLİĞİ ALMA FONKSİYONU ---
  Future<String?> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isIOS) {
        var iosDeviceInfo = await deviceInfo.iosInfo;
        return iosDeviceInfo.identifierForVendor; // iOS için benzersiz kimlik
      } else if (Platform.isAndroid) {
        var androidDeviceInfo = await deviceInfo.androidInfo;
        return androidDeviceInfo.id; // Android için benzersiz kimlik
      }
    } catch (e) {
      debugPrint("Cihaz kimliği okunamadı: $e");
    }
    return null;
  }

  // --- GİRİŞ MANTIĞI ---
  Future<void> _handleLogin() async {
    final String username = _userController.text.trim();
    final String password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError("Lütfen tüm alanları doldurun.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_tabController.index == 0) {
        // --- YÖNETİCİ / ROOT GİRİŞİ (Cihaz kısıtlaması yok) ---
        QuerySnapshot adminQuery = await FirebaseFirestore.instance
            .collection('admins')
            .where('username', isEqualTo: username)
            .where('password', isEqualTo: password)
            .get();

        if (adminQuery.docs.isNotEmpty) {
          var doc = adminQuery.docs.first;
          var data = doc.data() as Map<String, dynamic>;
          String role = (data['role'] ?? "admin").toString().toLowerCase();

          if (!mounted) return;

          if (role == "root") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RootMainScreen(
                  adminData: data,
                  firmaKey: data['business_id'] ?? doc.id,
                ),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AdminMainScreen(adminData: data, firmaKey: doc.id),
              ),
            );
          }
        } else {
          _showError("Yönetici bilgileri hatalı.");
        }
      } else {
        // --- PERSONEL GİRİŞİ (CİHAZ KİLİDİ BURADA) ---
        QuerySnapshot staffQuery = await FirebaseFirestore.instance
            .collection('workers')
            .where('username', isEqualTo: username)
            .where('password', isEqualTo: password)
            .get();

        if (staffQuery.docs.isNotEmpty) {
          var doc = staffQuery.docs.first;
          var data = doc.data() as Map<String, dynamic>;
          String workerDocId = doc.id; // Güncelleme yapmak için belgenin ID'si

          // 1. O anki cihazın kimliğini al
          String? currentDeviceId = await _getDeviceId();

          if (currentDeviceId == null) {
            _showError("Güvenlik Hatası: Cihaz kimliği alınamadı.");
            setState(() => _isLoading = false);
            return;
          }

          // 2. Veritabanındaki kayıtlı cihaz kimliğine bak
          String? registeredDeviceId = data['device_id'];

          if (registeredDeviceId == null || registeredDeviceId.isEmpty) {
            // İLK GİRİŞ: Cihazı veritabanına kaydet
            await FirebaseFirestore.instance
                .collection('workers')
                .doc(workerDocId)
                .update({'device_id': currentDeviceId});
          } else if (registeredDeviceId != currentDeviceId) {
            // FARKLI CİHAZ: Girişi engelle
            _showError(
              "Bu hesap başka bir cihaza kayıtlı. Lütfen yöneticinizle iletişime geçin.",
            );
            setState(() => _isLoading = false);
            return; // FONKSİYONU BURADA KES, GİRİŞE İZİN VERME!
          }

          // Eşleşme başarılı veya ilk kayıt yapıldıysa içeri al
          String firmaKey = data['business_id'] ?? "";

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  UserMainScreen(userData: data, firmaKey: firmaKey),
            ),
          );
        } else {
          _showError("Personel bilgileri hatalı.");
        }
      }
    } catch (e) {
      _showError("Bir hata oluştu: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(35),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.apartment_rounded,
                size: 80,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 15),
              const Text(
                "WORKIFY",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.blueAccent,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.white30,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: "YÖNETİCİ"),
                  Tab(text: "PERSONEL"),
                ],
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _userController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  "Kullanıcı Adı",
                  Icons.person_outline,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Şifre", Icons.lock_outline),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.blueAccent)
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          "GİRİŞ YAP",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white30),
      prefixIcon: Icon(icon, color: Colors.white30),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
    );
  }
}
