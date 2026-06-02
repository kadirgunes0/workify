import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;
import 'package:device_info_plus/device_info_plus.dart';
import 'login.dart';

class UserMainScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String firmaKey;

  const UserMainScreen({
    super.key,
    required this.firmaKey,
    required this.userData,
  });

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _selectedIndex = 0;
  bool isProcessing = false;
  final MobileScannerController _cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    await Geolocator.requestPermission();
  }

  Future<Position?> _getSafeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      return await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.medium,
        // ignore: deprecated_member_use
        forceAndroidLocationManager: true,
        // ignore: deprecated_member_use
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      try {
        return await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
      } catch (e2) {
        return null;
      }
    }
  }

  void _processQrCode(String scannedBase64) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    _cameraController.stop();
    _showSnackBar("QR okundu, işlem yapılıyor...");

    try {
      String decoded = utf8.decode(base64.decode(scannedBase64.trim()));
      List<String> parts = decoded.contains('|')
          ? decoded.split('|')
          : decoded.split('_');
      if (parts.length < 2) throw "Geçersiz QR Formatı";

      String qrFirma = parts[0].trim();
      String qrSube = parts[1].trim();

      if (qrFirma != widget.firmaKey) {
        _showStatusDialog(
          "Hata",
          "Bu QR kod işletmenize ait değil.",
          Colors.red,
        );
        return;
      }

      String currentUsername = (widget.userData['username'] ?? "")
          .toString()
          .toLowerCase()
          .trim();

      var workerQuery = await FirebaseFirestore.instance
          .collection('workers')
          .where('username', isEqualTo: currentUsername)
          .limit(1)
          .get();

      if (workerQuery.docs.isEmpty) {
        _showStatusDialog("Hata", "Personel kaydı bulunamadı.", Colors.red);
        return;
      }

      var workerDoc = workerQuery.docs.first;
      var workerData = workerDoc.data();

      List<dynamic> access = workerData['access'] ?? [];
      if (access.isEmpty && workerData['branch_name'] != null) {
        access.add(workerData['branch_name']);
      }

      if (!access.any(
        (e) => e.toString().toLowerCase() == qrSube.toLowerCase(),
      )) {
        _showStatusDialog(
          "Yetki Hatası",
          "Bu şubede yetkiniz yok.",
          Colors.redAccent,
        );
        return;
      }

      Position? pos = await _getSafeLocation();
      if (pos == null) {
        _showStatusDialog("Konum Hatası", "GPS sinyali alınamadı.", Colors.red);
        return;
      }

      var bDoc = await FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .get();
      var branchInfo = bDoc.data()?['branches']?[qrSube];

      double dist = _calculateDistance(
        pos.latitude,
        pos.longitude,
        (branchInfo['lat'] as num).toDouble(),
        (branchInfo['lon'] as num).toDouble(),
      );

      if (dist > 150) {
        _showStatusDialog(
          "Uzaklık Hatası",
          "Şubeye çok uzaktasınız (${dist.toInt()}m).",
          Colors.redAccent,
        );
        return;
      }

      String newStatus = (workerData['lastStatus'] ?? 'cikis') == 'giris'
          ? 'cikis'
          : 'giris';
      String statusLabel = (newStatus == 'giris') ? "GİRİŞ" : "ÇIKIŞ";

      String liveDevice = "Bilinmeyen Cihaz";
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        var info = await deviceInfo.androidInfo;
        liveDevice = "${info.brand} ${info.model}";
      } else if (Platform.isIOS) {
        var info = await deviceInfo.iosInfo;
        liveDevice = info.name;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.update(workerDoc.reference, {
        'lastStatus': newStatus,
        'lastActionTime': FieldValue.serverTimestamp(),
      });

      batch.set(FirebaseFirestore.instance.collection('logs').doc(), {
        'business_id': widget.firmaKey,
        'branch_name': qrSube,
        'worker_name': widget.userData['name_surname'],
        'worker_id': currentUsername,
        'device_name': liveDevice,
        'type': statusLabel,
        'timestamp': FieldValue.serverTimestamp(),
        'dist': "${dist.toInt()}m",
      });

      await batch.commit();
      HapticFeedback.heavyImpact();
      _showStatusDialog(
        "Başarılı",
        "$statusLabel işleminiz tamamlandı.",
        Colors.green,
        isSuccess: true,
      );
    } catch (e) {
      _showStatusDialog("Hata", e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    var p = 0.017453292519943295;
    var a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  void _showSnackBar(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _showStatusDialog(
    String title,
    String msg,
    Color color, {
    bool isSuccess = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              if (isSuccess) {
                setState(() => _selectedIndex = 0);
              } else if (_selectedIndex == 1) {
                _cameraController.start();
              }
            },
            child: const Text("TAMAM"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [_buildHomeTab(), _buildQRScannerTab(), _buildProfileTab()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            _cameraController.start();
          } else {
            _cameraController.stop();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: "Ana Menü",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: "QR Okut",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: "Profil",
          ),
        ],
      ),
    );
  }

  // --- ANLIK HAREKETLERİN AKTIĞI ANA SAYFA TABI ---
  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String currentUsername = (widget.userData['username'] ?? "")
        .toString()
        .toLowerCase()
        .trim();

    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workers')
            .where('username', isEqualTo: currentUsername)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Personel dökümanı bulunamadı."));
          }

          var workerData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          bool isInside = (workerData['lastStatus'] ?? 'cikis') == 'giris';

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Merhaba, ${widget.userData['name_surname']?.split(' ')[0]} 👋",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isInside
                          ? [Colors.green.shade600, Colors.green.shade800]
                          : [Colors.orange.shade600, Colors.orange.shade800],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isInside
                            ? Icons.storefront_rounded
                            : Icons.directions_run_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isInside
                            ? "ŞU AN MESAİDESİNİZ"
                            : "ŞU AN MESAİ DIŞINDASINIZ",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Son Hareketler",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('logs')
                        .where('worker_id', isEqualTo: currentUsername)
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, logSnap) {
                      if (logSnap.hasError) {
                        return const Center(
                          child: Text("Hareketler yüklenemedi."),
                        );
                      }
                      if (logSnap.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                        );
                      }

                      var docs = logSnap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            "Henüz bir hareket kaydı bulunmuyor.\n(ID: $currentUsername)",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var log = docs[index].data() as Map<String, dynamic>;
                          String logType = (log['type'] ?? "")
                              .toString()
                              .toUpperCase();
                          bool isEntry =
                              logType.contains('GİR') || logType == 'GİRİŞ';
                          DateTime dt =
                              (log['timestamp'] as Timestamp?)?.toDate() ??
                              DateTime.now();

                          return Card(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            elevation: isDark ? 0 : 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.05),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isEntry
                                    ? Colors.blueAccent.withOpacity(0.1)
                                    : Colors.orangeAccent.withOpacity(0.1),
                                child: Icon(
                                  isEntry
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                  color: isEntry
                                      ? Colors.blueAccent
                                      : Colors.orangeAccent,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                isEntry ? "GİRİŞ" : "ÇIKIŞ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                log['branch_name'] ?? "",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQRScannerTab() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: (capture) {
            if (!isProcessing && capture.barcodes.isNotEmpty) {
              _processQrCode(capture.barcodes.first.rawValue ?? "");
            }
          },
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  // --- GELİŞMİŞ VE ZENGİNLEŞTİRİLMİŞ PROFİL TABI ---
  Widget _buildProfileTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String name = widget.userData['name_surname'] ?? "Bilinmeyen Personel";
    String username = widget.userData['username'] ?? "---";
    String email = widget.userData['email'] ?? "E-Posta Tanımlanmamış";
    String role = widget.userData['role'] ?? "staff";
    String ageStr = widget.userData['age']?.toString() ?? "---";

    String roleLabel = "STAFF (Personel)";
    if (role == 'manager') roleLabel = "MANAGER (Yönetici)";
    if (role == 'part_time') roleLabel = "PART-TIME (Yarı Zamanlı)";

    String birthDateStr = "Seçilmemiş";
    if (widget.userData['birth_date'] != null) {
      try {
        if (widget.userData['birth_date'] is Timestamp) {
          DateTime dt = (widget.userData['birth_date'] as Timestamp).toDate();
          birthDateStr =
              "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}";
        } else {
          birthDateStr = widget.userData['birth_date'].toString().split(' ')[0];
        }
      } catch (e) {
        birthDateStr = "Format Hatası";
      }
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(
                    Icons.person,
                    size: 45,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _profileTile("Adı Soyadı", name, Icons.badge_outlined, isDark),
                _profileTile(
                  "Kullanıcı Adı",
                  "@$username",
                  Icons.alternate_email_rounded,
                  isDark,
                ),
                _profileTile(
                  "E-Posta Adresi",
                  email,
                  Icons.email_outlined,
                  isDark,
                ),
                _profileTile(
                  "Doğum Tarihi",
                  birthDateStr,
                  Icons.cake_outlined,
                  isDark,
                ),
                _profileTile(
                  "Yaş",
                  "$ageStr Yaşında",
                  Icons.calendar_today_rounded,
                  isDark,
                ),
                _profileTile(
                  "Yetki Rolü",
                  roleLabel,
                  Icons.admin_panel_settings_outlined,
                  isDark,
                ),
                _profileTile(
                  "İşletme Anahtarı",
                  widget.firmaKey,
                  Icons.vpn_key_outlined,
                  isDark,
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (c) => const LoginPage()),
                    ),
                    icon: const Icon(Icons.power_settings_new_rounded),
                    label: const Text("SİSTEMDEN GÜVENLİ ÇIKIŞ"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      side: const BorderSide(
                        color: Colors.redAccent,
                        width: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileTile(String title, String value, IconData icon, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: isDark ? 0 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
