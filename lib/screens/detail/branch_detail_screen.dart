import 'package:buildgym/screens/detail/worker_detail_screen.dart';
import 'package:buildgym/screens/edit/worker_add_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class BranchDetailsScreen extends StatelessWidget {
  final String firmaKey;
  final String branchName;

  const BranchDetailsScreen({
    super.key,
    required this.firmaKey,
    required this.branchName,
  });

  // --- ŞUBEYE ÖZEL SABİT QR VERİSİ ---
  // BranchDetailsScreen.dart içindeki ilgili kısım
  String _generateStaticQrData() {
    // Alt tire yerine dik çizgi (|) kullanıyoruz
    String rawData = "$firmaKey|$branchName";
    return base64.encode(utf8.encode(rawData));
  }

  // --- ŞUBE VE BAĞLI PERSONELLERİ SİLME ---
  Future<void> _deleteBranch(BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Şubeyi Sil?", style: TextStyle(color: Colors.white)),
        content: Text(
          "$branchName şubesi ve bağlı TÜM PERSONELLER silinecektir. Bu işlem geri alınamaz.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("VAZGEÇ"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              "EVET, HER ŞEYİ SİL",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        var workersQuery = await FirebaseFirestore.instance
            .collection('workers')
            .where('business_id', isEqualTo: firmaKey)
            .where('branch_name', isEqualTo: branchName)
            .get();
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in workersQuery.docs) {
          batch.delete(doc.reference);
        }

        batch.update(
          FirebaseFirestore.instance.collection('business').doc(firmaKey),
          {'branches.$branchName': FieldValue.delete()},
        );
        await batch.commit();

        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        debugPrint("Hata: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          branchName.toUpperCase(),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('business')
            .doc(firmaKey)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(
              child: Text(
                "Veri bulunamadı",
                style: TextStyle(color: Colors.white24),
              ),
            );
          }

          var bData = snapshot.data!.data() as Map<String, dynamic>;
          var branches = bData['branches'] as Map<String, dynamic>?;
          var currentBranch = branches?[branchName];

          if (currentBranch == null) {
            return const Center(
              child: Text(
                "Şube bulunamadı.",
                style: TextStyle(color: Colors.white24),
              ),
            );
          }
          List workers = currentBranch['workers'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ŞUBE BİLGİ PANELİ
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      _infoItem(
                        Icons.map_rounded,
                        "Adres",
                        currentBranch['address'] ?? "Girilmemiş",
                      ),
                      const SizedBox(height: 12),
                      _infoItem(
                        Icons.people_alt_rounded,
                        "Kayıtlı Personel",
                        "${workers.length} Kişi",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 2. SABİT QR KOD PANELİ
                Center(
                  child: Column(
                    children: [
                      const Text(
                        "ŞUBE QR KODU",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: _generateStaticQrData(),
                          version: QrVersions.auto,
                          size: 180.0,
                          gapless: false,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Giriş ve Çıkış işlemleri sistem tarafından otomatik algılanır",
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // 3. HARİTA ÖNİZLEME
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            currentBranch['lat'],
                            currentBranch['lon'],
                          ),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.kadir.buildgym',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  currentBranch['lat'],
                                  currentBranch['lon'],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 35),

                // 4. PERSONEL LİSTESİ
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "KAYITLI PERSONELLER",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (workers.isEmpty)
                        const Center(
                          child: Text(
                            "Henüz personel eklenmemiş.",
                            style: TextStyle(
                              color: Colors.white12,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ...workers
                            .map((wName) => _buildWorkerTile(context, wName))
                            ,
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      // ALT BUTONLAR (Ekle/Sil)
      bottomSheet: Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => WorkerAddScreen(
                      firmaKey: firmaKey,
                      branchName: branchName,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  "YENİ PERSONEL EKLE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _deleteBranch(context),
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                label: const Text(
                  "ŞUBEYİ SİSTEMDEN SİL",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerTile(BuildContext context, String wName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.white10,
          child: Icon(Icons.person, color: Colors.white60, size: 18),
        ),
        title: Text(
          wName,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white12,
        ),
        onTap: () async {
          var query = await FirebaseFirestore.instance
              .collection('workers')
              .where('name_surname', isEqualTo: wName)
              .where('business_id', isEqualTo: firmaKey)
              .get();
          if (query.docs.isNotEmpty && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => WorkerDetailScreen(
                  workerId: query.docs.first.id,
                  firmaKey: firmaKey,
                  branchName: branchName,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
