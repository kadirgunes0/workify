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

      var workerQuery = await FirebaseFirestore.instance
          .collection('workers')
          .where('username', isEqualTo: widget.userData['username'])
          .limit(1)
          .get();

      if (workerQuery.docs.isEmpty) {
        _showStatusDialog("Hata", "Personel kaydı bulunamadı.", Colors.red);
        return;
      }

      var workerDoc = workerQuery.docs.first;
      var workerData = workerDoc.data();

      // Yetki Kontrolü
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

      // Cihaz Bilgisi
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
        'worker_id': widget.userData['username'],
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
              } else if (_selectedIndex == 1)
                _cameraController.start();
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

  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    return SafeArea(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workers')
            .where('username', isEqualTo: widget.userData['username'])
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
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
                        .where(
                          'worker_id',
                          isEqualTo: widget.userData['username'],
                        )
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, logSnap) {
                      if (!logSnap.hasData) return const SizedBox();
                      return ListView.builder(
                        itemCount: logSnap.data!.docs.length,
                        itemBuilder: (context, index) {
                          var log =
                              logSnap.data!.docs[index].data()
                                  as Map<String, dynamic>;
                          bool isEntry = log['type'] == 'GİRİŞ';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: Icon(
                                isEntry ? Icons.login : Icons.logout,
                                color: isEntry ? Colors.green : Colors.orange,
                              ),
                              title: Text(
                                log['type'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(log['branch_name'] ?? ""),
                              trailing: Text(
                                log['timestamp'] != null
                                    ? "${(log['timestamp'] as Timestamp).toDate().hour}:${(log['timestamp'] as Timestamp).toDate().minute}"
                                    : "",
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

  Widget _buildProfileTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.userData['name_surname'] ?? "",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _profileTile("İşletme", widget.firmaKey, Icons.business),
                _profileTile(
                  "Kullanıcı",
                  widget.userData['username'],
                  Icons.person_pin,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (c) => const LoginPage()),
                  ),
                  child: const Text("ÇIKIŞ YAP"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileTile(String t, String v, IconData i) {
    return Card(
      child: ListTile(
        leading: Icon(i, color: Theme.of(context).colorScheme.primary),
        title: Text(
          t,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        subtitle: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
