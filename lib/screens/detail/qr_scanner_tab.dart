import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:math' show cos, sqrt, asin;

class QrScannerTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String firmaKey;

  const QrScannerTab({
    super.key,
    required this.userData,
    required this.firmaKey,
  });

  @override
  State<QrScannerTab> createState() => _QrScannerTabState();
}

class _QrScannerTabState extends State<QrScannerTab> {
  bool isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();

  // --- MESAFE HESAPLAMA ---
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    var p = 0.017453292519943295;
    var c = cos;
    var a =
        0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  // --- ANA QR İŞLEME FONKSİYONU ---
  void _processQrCode(String qrBase64) async {
    if (isProcessing) return;
    setState(() => isProcessing = true);

    try {
      debugPrint("--- QR İŞLEMİ BAŞLADI ---");

      // ADIM 1: QR KODU ÇÖZ
      String decoded = utf8.decode(base64.decode(qrBase64.trim()));

      List<String> parts = decoded.contains('|')
          ? decoded.split('|')
          : decoded.split('_');

      if (parts.length < 2) {
        throw Exception("Geçersiz QR Formatı.");
      }

      String qrFirmaId = parts[0].trim();
      String qrBranchName = parts[1].trim();

      if (qrFirmaId != widget.firmaKey) {
        _handleError("Firma Hatası", "Bu QR kod başka bir işletmeye aittir.");
        return;
      }

      _showLoadingDialog("Yetkileriniz kontrol ediliyor...");

      // ADIM 2: DB'DEN CANLI KULLANICI BİLGİSİNİ ÇEK
      String workerUsername = widget.userData['username'];
      var workerQuery = await FirebaseFirestore.instance
          .collection('workers')
          .where('username', isEqualTo: workerUsername)
          .where('business_id', isEqualTo: widget.firmaKey)
          .limit(1)
          .get();

      if (workerQuery.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        _handleError(
          "Kayıt Hatası",
          "Veritabanında personel kaydınız bulunamadı.",
        );
        return;
      }

      var workerDoc = workerQuery.docs.first;
      var liveWorkerData = workerDoc.data();

      // ADIM 3: SADECE YETKİ (ACCESS) KONTROLÜ
      List<dynamic> rawAccessList = liveWorkerData['access'] ?? [];

      // Eski veritabanı kayıtlarında access listesi hiç oluşturulmamışsa diye güvenlik önlemi:
      // (En azından kendi kayıtlı şubesine girebilsin)
      if (rawAccessList.isEmpty && liveWorkerData['branch_name'] != null) {
        rawAccessList.add(liveWorkerData['branch_name']);
      }

      // Uyuşmazlıkları önlemek için tüm harfleri küçültüp baş/son boşlukları (trim) siliyoruz
      List<String> normalizedAccessList = rawAccessList
          .map((e) => e.toString().trim().toLowerCase())
          .toList();

      String normalizedQrBranch = qrBranchName.trim().toLowerCase();

      // KURAL: Okutulan şube "access" listesinde var mı?
      bool hasPermission = normalizedAccessList.contains(normalizedQrBranch);

      // Eğer listede yoksa, kapıdan döndür! (Rolü manager olsa bile listede yoksa giremez)
      if (!hasPermission) {
        if (mounted) Navigator.pop(context);
        _handleError(
          "Yetki İhlali",
          "Bu şubede işlem yapmak için yetkiniz bulunmamaktadır.\nOkutulan Şube: $qrBranchName",
        );
        return;
      }

      // ADIM 4: KONUM KONTROLÜ
      var bizDoc = await FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .get();
      Map<String, dynamic> branches = bizDoc.data()?['branches'] ?? {};
      var branchInfo = branches[qrBranchName];

      if (branchInfo == null) {
        if (mounted) Navigator.pop(context);
        _handleError(
          "Şube Hatası",
          "Veritabanında '$qrBranchName' isimli bir şube bulunamadı.",
        );
        return;
      }

      double bLat = (branchInfo['lat'] as num).toDouble();
      double bLon = (branchInfo['lon'] as num).toDouble();

      Position currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      double distance = _calculateDistance(
        currentPos.latitude,
        currentPos.longitude,
        bLat,
        bLon,
      );

      if (mounted) Navigator.pop(context);

      if (distance > 150) {
        _handleError(
          "Mesafe Hatası",
          "Şubeye çok uzaktasınız (${distance.toInt()} metre).\nİşlem yapabilmek için şubeye yaklaşın.",
        );
        return;
      }

      // ADIM 5: GİRİŞ / ÇIKIŞ KARARI VE KAYIT
      String lastStatus = liveWorkerData['lastStatus'] ?? 'cikis';
      String newAction = (lastStatus == 'cikis') ? 'giris' : 'cikis';
      String actionTextForLog = newAction == 'giris' ? 'Giriş' : 'Çıkış';

      WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.update(workerDoc.reference, {
        'lastStatus': newAction,
        'lastActionTime': FieldValue.serverTimestamp(),
      });

      DocumentReference logRef = FirebaseFirestore.instance
          .collection('logs')
          .doc();
      batch.set(logRef, {
        'business_id': widget.firmaKey,
        'branch_name': qrBranchName,
        'worker_name': liveWorkerData['name_surname'],
        'worker_id': workerUsername,
        'device_name':
            liveWorkerData['device_model'] ??
            liveWorkerData['device_name'] ??
            widget.userData['device_model'] ??
            widget.userData['device_name'] ??
            "Kayıtlı Cihaz",
        'action':
            "${liveWorkerData['name_surname']} • $qrBranchName ($actionTextForLog)",
        'type': actionTextForLog,
        'timestamp': FieldValue.serverTimestamp(),
        'distance': "${distance.toInt()}m",
      });

      await batch.commit();

      HapticFeedback.mediumImpact();
      _showStatusDialog(
        newAction == "giris" ? "GİRİŞ BAŞARILI" : "ÇIKIŞ BAŞARILI",
        "$qrBranchName şubesinde $actionTextForLog işleminiz onaylandı.\nMesafe: ${distance.toInt()}m",
        newAction == "giris" ? Colors.greenAccent : Colors.orangeAccent,
        newAction == "giris" ? Icons.check_circle : Icons.logout,
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _handleError(
        "Okuma Hatası",
        "Geçersiz QR Kod. Lütfen şubenizin güncel QR kodunu okutun.",
      );
      debugPrint("QR İŞLEME HATASI: $e");
    }
  }

  // --- GÖRSEL YARDIMCILAR ---
  void _showLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.blueAccent),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleError(String title, String message) {
    HapticFeedback.heavyImpact();
    _showStatusDialog(title, message, Colors.redAccent, Icons.error_outline);
  }

  void _showStatusDialog(
    String title,
    String message,
    Color color,
    IconData icon,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => isProcessing = false);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "TAMAM",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (!isProcessing && capture.barcodes.isNotEmpty) {
              final String? code = capture.barcodes.first.rawValue;
              if (code != null) _processQrCode(code);
            }
          },
        ),
        _buildOverlay(context),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(alpha: 0.7),
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
          const Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              "QR Kodu karenin içine hizalayın\nİşlem otomatik algılanacaktır",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
