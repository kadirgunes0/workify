import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;
import 'dart:io'; // Cihaz işletim sistemi kontrolü için
import 'package:device_info_plus/device_info_plus.dart'; // Cihaz ismi için
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

  // --- HUAWEİ & ANDROID GÜVENLİ KONUM ALMA ---
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
        desiredAccuracy: LocationAccuracy.medium,
        forceAndroidLocationManager: true,
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

  // --- ANA QR İŞLEME VE GÜVENLİK AKIŞI ---
  void _processQrCode(String scannedBase64) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    _cameraController.stop();
    _showSnackBar("QR okundu, yetki kontrol ediliyor...");

    try {
      // 1. QR KODUNU ÇÖZ VE PARÇALA
      String decoded = utf8.decode(base64.decode(scannedBase64.trim()));
      List<String> parts = decoded.split('|');

      if (parts.length < 2) {
        parts = decoded.split('_');
      }
      if (parts.length < 2) throw "Geçersiz veya Eski QR Formatı";

      String qrFirma = parts[0].trim();
      String qrSube = parts[1].trim();

      if (qrFirma != widget.firmaKey) {
        _showStatusDialog(
          "Firma Hatası",
          "Bu QR kod sizin işletmenize ait değil.",
          Colors.red,
        );
        return;
      }

      // 2. KULLANICIYI DB'DEN ÇEK
      var workerQuery = await FirebaseFirestore.instance
          .collection('workers')
          .where('username', isEqualTo: widget.userData['username'])
          .limit(1)
          .get();

      if (workerQuery.docs.isEmpty) {
        _showStatusDialog(
          "Kayıt Hatası",
          "Sisteme kayıtlı personel profiliniz bulunamadı!",
          Colors.red,
        );
        return;
      }

      var workerDoc = workerQuery.docs.first;
      var workerData = workerDoc.data();
      var workerRef = workerDoc.reference;

      // 3. SADECE YETKİ (ACCESS) KONTROLÜ
      List<dynamic> rawAccessList = workerData['access'] ?? [];

      if (rawAccessList.isEmpty && workerData['branch_name'] != null) {
        rawAccessList.add(workerData['branch_name']);
      }

      List<String> normalizedAccessList = rawAccessList
          .map((e) => e.toString().trim().toLowerCase())
          .toList();
      String normalizedQrBranch = qrSube.trim().toLowerCase();
      bool hasPermission = normalizedAccessList.contains(normalizedQrBranch);

      if (!hasPermission) {
        _showStatusDialog(
          "Yetki İhlali",
          "Bu şubede işlem yapmak için yetkiniz bulunmamaktadır.\nOkutulan Şube: $qrSube",
          Colors.redAccent,
        );
        return;
      }

      // 4. KONUM KONTROLÜ
      _showSnackBar("Yetki onaylandı, konum doğrulanıyor...");

      Position? pos = await _getSafeLocation();
      if (pos == null) {
        _showStatusDialog(
          "Konum Hatası",
          "GPS sinyali alınamadı. Lütfen konumunuzun açık olduğundan emin olun.",
          Colors.red,
        );
        return;
      }

      var bDoc = await FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .get();
      if (!bDoc.exists) {
        _showStatusDialog("Hata", "İşletme kaydı bulunamadı.", Colors.red);
        return;
      }

      var branchInfo = bDoc.data()?['branches']?[qrSube];
      if (branchInfo == null) {
        _showStatusDialog("Hata", "Şube ($qrSube) bulunamadı.", Colors.red);
        return;
      }

      double dist = _calculateDistance(
        pos.latitude,
        pos.longitude,
        (branchInfo['lat'] as num).toDouble(),
        (branchInfo['lon'] as num).toDouble(),
      );

      if (dist > 150) {
        _showStatusDialog(
          "Uzaklık Hatası",
          "Şubeye ${dist.toInt()}m uzaktasınız. İşlem yapabilmek için şubeye yaklaşın.",
          Colors.redAccent,
        );
        return;
      }

      // 5. GİRİŞ/ÇIKIŞ KAYDINI OLUŞTUR VE CANLI CİHAZ BİLGİSİNİ AL
      String currentStatus = workerData['lastStatus'] ?? 'cikis';
      String newStatus = (currentStatus == 'giris') ? 'cikis' : 'giris';
      String statusLabel = (newStatus == 'giris') ? "GİRİŞ" : "ÇIKIŞ";

      // --- YENİ EKLENEN CANLI CİHAZ İSMİ ALMA MANTIĞI ---
      String liveDeviceName = "Bilinmeyen Cihaz";
      try {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          liveDeviceName =
              "${androidInfo.brand} ${androidInfo.model}"; // Örn: samsung SM-G991B
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          liveDeviceName = iosInfo.name; // Örn: iPhone 13 Pro
        }
      } catch (e) {
        // Hata olursa (izin vs.) eski usul db'den al
        liveDeviceName =
            workerData['device_model'] ??
            widget.userData['device_model'] ??
            "Kayıtlı Cihaz";
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.update(workerRef, {
        'lastStatus': newStatus,
        'lastActionTime': FieldValue.serverTimestamp(),
      });

      DocumentReference logRef = FirebaseFirestore.instance
          .collection('logs')
          .doc();
      batch.set(logRef, {
        'business_id': widget.firmaKey,
        'branch_name': qrSube,
        'worker_name': widget.userData['name_surname'],
        'worker_id': widget.userData['username'],
        'device_name': liveDeviceName, // GERÇEK CİHAZ İSMİ KAYDEDİLİYOR
        'type': statusLabel,
        'timestamp': FieldValue.serverTimestamp(),
        'dist': "${dist.toInt()}m",
      });

      await batch.commit();

      HapticFeedback.heavyImpact();
      _showStatusDialog(
        "Başarılı",
        "$qrSube şubesinde $statusLabel kaydınız onaylandı.",
        Colors.greenAccent,
        isSuccess: true,
      );
    } catch (e) {
      _showStatusDialog("Sistem Hatası", e.toString(), Colors.red);
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

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
  );

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
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              if (isSuccess) {
                setState(() => _selectedIndex = 0);
              } else {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted && _selectedIndex == 1) _cameraController.start();
                });
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
      backgroundColor: const Color(0xFF0F172A),
      body: IndexedStack(
        index: _selectedIndex,
        children: [_buildHomeTab(), _buildQRScannerTab(), _buildProfileTab()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (_selectedIndex == index) return;
          setState(() => _selectedIndex = index);
          if (index == 1) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) _cameraController.start();
            });
          } else {
            _cameraController.stop();
          }
        },
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white30,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: "Panel",
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

  // --- 1. HOME TAB ---
  Widget _buildHomeTab() {
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workers')
            .where('username', isEqualTo: widget.userData['username'])
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Kullanıcı verisi bulunamadı.",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          var workerData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          String lastStatus = workerData['lastStatus'] ?? 'cikis';
          bool isInside = lastStatus == 'giris';
          String currentBranch = workerData['branch_name'] ?? 'Şube Atanmadı';
          String userRole = (workerData['role'] ?? 'staff')
              .toString()
              .toUpperCase();

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Merhaba, ${widget.userData['name_surname']?.split(' ')[0]} 👋",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 25,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isInside
                          ? [Colors.green.shade600, Colors.green.shade900]
                          : [Colors.orange.shade600, Colors.orange.shade900],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: (isInside ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isInside
                            ? Icons.storefront_rounded
                            : Icons.directions_run_rounded,
                        color: Colors.white,
                        size: 45,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isInside
                            ? "ŞU AN MESAİDESİNİZ"
                            : "ŞU AN MESAİ DIŞINDASINIZ",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        userRole == 'MANAGER'
                            ? "Yetki: YÖNETİCİ (Tüm Şubeler)"
                            : "Kayıtlı Şube: $currentBranch",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 35),
                const Text(
                  "Son Hareketleriniz",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 15),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('logs')
                        .where(
                          'worker_name',
                          isEqualTo: widget.userData['name_surname'],
                        )
                        .where('business_id', isEqualTo: widget.firmaKey)
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, logSnap) {
                      if (logSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!logSnap.hasData || logSnap.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            "Henüz bir hareketiniz yok.",
                            style: TextStyle(color: Colors.white38),
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: logSnap.data!.docs.length,
                        itemBuilder: (context, index) {
                          var log =
                              logSnap.data!.docs[index].data()
                                  as Map<String, dynamic>;
                          bool isEntry =
                              log['type'] == 'GİRİŞ' || log['type'] == 'Giriş';
                          String timeText = "-";
                          if (log['timestamp'] != null) {
                            DateTime dt = (log['timestamp'] as Timestamp)
                                .toDate();
                            timeText =
                                "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                          }
                          return Card(
                            color: const Color(0xFF1E293B),
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      (isEntry
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent)
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isEntry
                                      ? Icons.login_rounded
                                      : Icons.logout_rounded,
                                  color: isEntry
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                log['type'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                timeText,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Text(
                                log['branch_name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
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

  // --- 2. QR SCANNER TAB ---
  Widget _buildQRScannerTab() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController,
          errorBuilder: (context, error) => const Center(
            child: Text(
              "Kamera başlatılamadı.",
              style: TextStyle(color: Colors.red),
            ),
          ),
          onDetect: (capture) {
            if (!isProcessing && capture.barcodes.isNotEmpty) {
              _processQrCode(capture.barcodes.first.rawValue ?? "");
            }
          },
        ),
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 50),
            child: Text(
              "Şubenin QR Kodunu Çerçeveye Hizalayın",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- 3. PROFILE TAB ---
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 70, 20, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF1D4ED8),
                  Color(0xFF1E1B4B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white24,
                  child: Text(
                    widget.userData['name_surname']?[0]?.toUpperCase() ?? "P",
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  widget.userData['name_surname']?.toUpperCase() ?? "PERSONEL",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.userData['email'] ?? "",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "HESAP BİLGİLERİ",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 15),
                _profileRow(
                  "İşletme Kodu",
                  widget.firmaKey.toUpperCase(),
                  Icons.business,
                  Colors.orangeAccent,
                ),
                _profileRow(
                  "Kullanıcı Adı",
                  widget.userData['username'],
                  Icons.alternate_email,
                  Colors.blueAccent,
                ),
                _profileRow(
                  "Kayıtlı Şube",
                  widget.userData['branch_name'] ?? "Atanmadı",
                  Icons.storefront_rounded,
                  Colors.purpleAccent,
                ),
                _profileRow(
                  "Yetki Türü",
                  (widget.userData['role'] ?? "Staff").toString().toUpperCase(),
                  Icons.security_rounded,
                  Colors.pinkAccent,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (c) => const LoginPage()),
                    ),
                    icon: const Icon(Icons.power_settings_new_rounded),
                    label: const Text(
                      "GÜVENLİ ÇIKIŞ YAP",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileRow(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
