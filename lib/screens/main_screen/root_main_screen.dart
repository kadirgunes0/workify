import 'package:buildgym/screens/edit/business_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'login.dart';

class RootMainScreen extends StatefulWidget {
  const RootMainScreen({
    super.key,
    required firmaKey,
    required Map<String, dynamic> adminData,
  });

  @override
  State<RootMainScreen> createState() => _RootMainScreenState();
}

class _RootMainScreenState extends State<RootMainScreen> {
  int _selectedIndex = 0;

  // Form Kontrolcüleri
  final _adminNameCtrl = TextEditingController();
  final _adminUsernameCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // KRİTİK DÜZELTME: Sayfa listesi ve Navigasyon indeksi 1-1 eşleşmeli (Toplam 2 sayfa)
    final List<Widget> pages = [
      _buildBusinessTab(),
      _buildProfileTab(), // İndeks 1: Profil Sayfası
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          "ROOT KONTROL PANELİ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => const LoginPage()),
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showCreateBusinessDialog,
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text("YENİ İŞLETME"),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white30,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center_rounded),
            label: "İşletmeler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_pin_rounded),
            label: "Profil",
          ),
        ],
      ),
    );
  }

  // --- 1. İŞLETME LİSTESİ ---
  Widget _buildBusinessTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('business').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "Kayıtlı işletme bulunamadı.",
              style: TextStyle(color: Colors.white38),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.business,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
                title: Text(
                  data['business_name']?.toUpperCase() ?? "İSİMSİZ",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  "ID: ${data['business_id']}",
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white10,
                ),
                onTap: () => _showBusinessDetails(doc.id, data),
              ),
            );
          },
        );
      },
    );
  }

  // --- 2. PROFİL TAB (ÇIKIŞ BUTONU BURADA) ---
  Widget _buildProfileTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 80,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "SİSTEM YÖNETİCİSİ",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              "Root Yetkili Erişimi",
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 60),

            // İşte o beklenen Çıkış Butonu
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
                  "SİSTEMDEN GÜVENLİ ÇIKIŞ YAP",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  side: const BorderSide(color: Colors.redAccent, width: 0.8),
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

  // --- YARDIMCI METOTLAR (DİALOGLAR VE DİĞERLERİ) ---
  void _showBusinessDetails(String docId, Map<String, dynamic> businessData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        int branchCount = (businessData['branches'] as Map? ?? {}).length;
        return Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                businessData['business_name']?.toUpperCase() ?? "",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white10, height: 30),
              _sheetRow(
                Icons.storefront,
                "Şube Sayısı",
                branchCount.toString(),
              ),
              _sheetRow(
                Icons.vpn_key,
                "Business ID",
                businessData['business_id'],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => BusinessEditScreen(
                          docId: docId,
                          currentData: businessData,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("DÜZENLE"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _confirmDelete(docId),
                icon: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                  size: 20,
                ),
                label: const Text(
                  "İŞLETMEYİ SİSTEMDEN SİL",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateBusinessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Yeni İşletme Kur",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_businessNameCtrl, "İşletme Adı", Icons.business),
              _field(_adminNameCtrl, "Admin Ad Soyad", Icons.person),
              _field(
                _adminUsernameCtrl,
                "Admin Kullanıcı Adı",
                Icons.alternate_email,
              ),
              _field(_adminPasswordCtrl, "Admin Şifre", Icons.lock),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İPTAL", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: _setupNewBusiness,
            child: const Text("SİSTEMİ KUR"),
          ),
        ],
      ),
    );
  }

  Future<void> _setupNewBusiness() async {
    String businessId = "WRK${Random().nextInt(9000) + 1000}";
    String docName = _businessNameCtrl.text.toLowerCase().replaceAll(' ', '_');
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch
          .set(FirebaseFirestore.instance.collection('business').doc(docName), {
            'business_id': businessId,
            'business_name': _businessNameCtrl.text.trim(),
            'branches': {},
          });
      batch.set(FirebaseFirestore.instance.collection('admins').doc(docName), {
        'business_id': businessId,
        'name_surname': _adminNameCtrl.text.trim(),
        'username': _adminUsernameCtrl.text.trim(),
        'password': _adminPasswordCtrl.text.trim(),
        'role': 'admin',
      });
      await batch.commit();
      Navigator.pop(context);
      _clear();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Emin misiniz?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Tüm veriler (adminler ve şubeler) silinecektir.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("VAZGEÇ"),
          ),
          ElevatedButton(
            onPressed: () async {
              WriteBatch batch = FirebaseFirestore.instance.batch();
              batch.delete(
                FirebaseFirestore.instance.collection('business').doc(docId),
              );
              batch.delete(
                FirebaseFirestore.instance.collection('admins').doc(docId),
              );
              await batch.commit();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("SİL"),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String l, IconData i) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: l,
        labelStyle: const TextStyle(color: Colors.white30, fontSize: 12),
        prefixIcon: Icon(i, color: Colors.blueAccent, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _sheetRow(IconData i, String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(i, color: Colors.white24, size: 18),
        const SizedBox(width: 15),
        Text(
          "$l: ",
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Text(
          v,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );

  void _clear() {
    _adminNameCtrl.clear();
    _adminUsernameCtrl.clear();
    _adminPasswordCtrl.clear();
    _businessNameCtrl.clear();
  }
}
