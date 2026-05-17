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
    final theme = Theme.of(context);

    final List<Widget> pages = [_buildBusinessTab(), _buildProfileTab()];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ROOT KONTROL PANELİ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
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
              backgroundColor: theme.colorScheme.primary,
              icon: const Icon(Icons.add_business_rounded, color: Colors.white),
              label: const Text(
                "YENİ İŞLETME",
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.unselectedWidgetColor.withOpacity(0.3),
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
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('business').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "Kayıtlı işletme bulunamadı.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.business,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  data['business_name']?.toUpperCase() ?? "İSİMSİZ",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  "ID: ${data['business_id']}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () => _showBusinessDetails(docs[index].id, data),
              ),
            );
          },
        );
      },
    );
  }

  // --- 2. PROFİL TAB ---
  Widget _buildProfileTab() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings_rounded,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              "SİSTEM YÖNETİCİSİ",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "Root Yetkili Erişimi",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (c) => const LoginPage()),
              ),
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text("SİSTEMDEN GÜVENLİ ÇIKIŞ YAP"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HATAYI ÇÖZEN DÜZELTİLMİŞ DİYALOG ---
  void _showCreateBusinessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni İşletme Kur"),
        scrollable:
            true, // İÇERİĞİN KAYDIRILABİLİR OLMASINI SAĞLAR (REKOR KIRAN HATAYI ÇÖZER)
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize:
                MainAxisSize.min, // COLUMN'UN SONSUZA GİTMESİNİ ENGELLER
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
            child: const Text("İPTAL"),
          ),
          ElevatedButton(
            onPressed: _setupNewBusiness,
            child: const Text("SİSTEMİ KUR"),
          ),
        ],
      ),
    );
  }

  // --- DÜZELTİLMİŞ YARDIMCI METOTLAR ---
  Widget _field(TextEditingController c, String l, IconData i) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: l,
          prefixIcon: Icon(i, color: theme.colorScheme.primary),
          filled: true,
          fillColor: theme.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ... (Geri kalan yardımcı metotlar ve Firebase işlemleri aynı kalıyor)
  // Detay gösterme, Silme teyidi vb. kodlarını buraya ekleyebilirsin.

  void _showBusinessDetails(String docId, Map<String, dynamic> businessData) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 30),
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
              ElevatedButton.icon(
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
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetRow(IconData i, String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(i, color: Colors.grey, size: 18),
        const SizedBox(width: 15),
        Text("$l: $v", style: const TextStyle(fontSize: 13)),
      ],
    ),
  );

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
      if (mounted) {
        Navigator.pop(context);
        _adminNameCtrl.clear();
        _adminUsernameCtrl.clear();
        _adminPasswordCtrl.clear();
        _businessNameCtrl.clear();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
