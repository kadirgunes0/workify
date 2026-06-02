import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
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

  // Yerel donanim katmanindan benzersiz donanim ID'sini ceken fonksiyon
  Future<String?> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isIOS) {
        var iosDeviceInfo = await deviceInfo.iosInfo;
        return iosDeviceInfo.identifierForVendor;
      } else if (Platform.isAndroid) {
        var androidDeviceInfo = await deviceInfo.androidInfo;
        return androidDeviceInfo.id;
      }
    } catch (e) {
      debugPrint("Cihaz kimliği okunamadı: $e");
    }
    return null;
  }

  Future<void> _handleLogin() async {
    // Veri Ön Isleme ve Temizleme (Data Sanitization)
    final String username = _userController.text.trim().toLowerCase();
    final String password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError("Lütfen tüm alanları doldurun.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_tabController.index == 0) {
        // role kontrolü ve yönetici giriş kontrolü
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
        // workers ve device_id kontrolü
        QuerySnapshot staffQuery = await FirebaseFirestore.instance
            .collection('workers')
            .where('username', isEqualTo: username)
            .where('password', isEqualTo: password)
            .get();

        if (staffQuery.docs.isNotEmpty) {
          var doc = staffQuery.docs.first;
          var data = doc.data() as Map<String, dynamic>;
          String workerDocId = doc.id;

          String? currentDeviceId = await _getDeviceId();

          if (currentDeviceId == null) {
            _showError("Güvenlik Hatası: Cihaz kimliği alınamadı.");
            setState(() => _isLoading = false);
            return;
          }

          String? registeredDeviceId = data['device_id'];
          // Hesap Paylasimini Önleyen Kritik Eslesme Algoritmasi
          if (registeredDeviceId == null || registeredDeviceId.isEmpty) {
            // worker kullanici olusturuldugunda "device_id" bos kalir ilk giris yapilan cihazin "id"si alinir
            await FirebaseFirestore.instance
                .collection('workers')
                .doc(workerDocId)
                .update({'device_id': currentDeviceId});
            data['device_id'] = currentDeviceId; // Lokal veriyi de besleyelim
          } else if (registeredDeviceId != currentDeviceId) {
            // Farkli cihazdan erisim engeller
            _showError("Bu hesap başka bir cihaza kayıtlı.");
            setState(() => _isLoading = false);
            return;
          }

          String firmaKey = data['business_id'] ?? "";
          data['username'] = username;

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
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold, TabBar ve Giris Formu Yapisi
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(35),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apartment_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 15),
              Text(
                "WORKIFY",
                style: TextStyle(
                  color: theme.textTheme.headlineLarge?.color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: isDark ? Colors.white30 : Colors.black38,
                tabs: const [
                  Tab(text: "YÖNETİCİ"),
                  Tab(text: "PERSONEL"),
                ],
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _userController,
                decoration: _inputDecoration(
                  "Kullanıcı Adı",
                  Icons.person_outline,
                  context,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: _inputDecoration(
                  "Şifre",
                  Icons.lock_outline,
                  context,
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? CircularProgressIndicator(color: theme.colorScheme.primary)
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        child: const Text(
                          "GİRİŞ YAP",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
    );
  }
}
