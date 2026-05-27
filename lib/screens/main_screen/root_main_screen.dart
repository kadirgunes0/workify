import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'login.dart';

class RootMainScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;

  const RootMainScreen({
    super.key,
    required String firmaKey,
    required this.adminData,
  });

  @override
  State<RootMainScreen> createState() => _RootMainScreenState();
}

class _RootMainScreenState extends State<RootMainScreen> {
  int _selectedIndex = 0;

  // Form Kontrolcüleri
  final _businessNameCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminUsernameCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  DateTime? _adminBirthDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<Widget> pages = [_buildBusinessTab(), _buildProfileTab()];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ROOT KONTROL PANELİ",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        if (!snapshot.hasData)
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        var docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(
            child: Text(
              "Kayıtlı işletme bulunamadı.",
              style: TextStyle(color: Colors.grey),
            ),
          );

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
                  child: Icon(Icons.business, color: theme.colorScheme.primary),
                ),
                title: Text(
                  data['business_name']?.toUpperCase() ?? "İSİMSİZ",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "ID: ${data['business_id']}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
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
    var profile = widget.adminData;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          Icon(
            Icons.admin_panel_settings_rounded,
            size: 70,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            profile['name_surname']?.toString().toUpperCase() ??
                "SİSTEM YÖNETİCİSİ",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text(
            "Sistem Root Yetkili Erişimi",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 30),

          _profileInfoCard(
            "Kullanıcı Adı",
            "@${profile['username'] ?? 'root'}",
            Icons.alternate_email,
            context,
          ),
          _profileInfoCard(
            "E-Posta Adresi",
            profile['email'] ?? "root@workify.com",
            Icons.email_outlined,
            context,
          ),

          if (profile['birth_date'] != null)
            _profileInfoCard(
              "Doğum Tarihi",
              DateTime.fromMillisecondsSinceEpoch(
                (profile['birth_date'] as Timestamp).millisecondsSinceEpoch,
              ).toLocal().toString().split(' ')[0],
              Icons.cake_outlined,
              context,
            ),
        ],
      ),
    );
  }

  Widget _profileInfoCard(
    String label,
    String value,
    IconData icon,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  // --- İŞLETME DETAY, GÜNCELLEME VE SİLME PANELİ (BOTTOM SHEET) ---
  void _showBusinessDetails(
    String docId,
    Map<String, dynamic> businessData,
  ) async {
    final theme = Theme.of(context);
    String bId = businessData['business_id'] ?? "";

    _businessNameCtrl.text = businessData['business_name'] ?? "";
    _adminNameCtrl.clear();
    _adminUsernameCtrl.clear();
    _adminPasswordCtrl.clear();

    var adminQuery = await FirebaseFirestore.instance
        .collection('admins')
        .where('business_id', isEqualTo: bId)
        .limit(1)
        .get();

    Map<String, dynamic> adminData = {};
    String adminDocId = "";

    if (adminQuery.docs.isNotEmpty) {
      adminDocId = adminQuery.docs.first.id;
      adminData = adminQuery.docs.first.data();
      _adminNameCtrl.text = adminData['name_surname'] ?? "";
      _adminUsernameCtrl.text = adminData['username'] ?? "";
      _adminPasswordCtrl.text = adminData['password'] ?? "";
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        int branchCount = (businessData['branches'] as Map? ?? {}).length;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            30,
            25,
            30,
            MediaQuery.of(context).viewInsets.bottom + 30,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "${businessData['business_name']?.toUpperCase()} - YÖNETİM",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // KAN KIRMIZISI GÜVENLİ SİLME BUTONU
                    IconButton(
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.redAccent,
                        size: 26,
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Önce alt paneli kapat
                        _confirmDeleteBusiness(
                          docId,
                          adminDocId,
                          businessData['business_name'] ?? "",
                        );
                      },
                    ),
                  ],
                ),
                const Divider(height: 20),

                _sheetRow(
                  Icons.storefront,
                  "Şube Sayısı",
                  branchCount.toString(),
                ),
                _sheetRow(Icons.vpn_key, "Business ID", bId),
                const SizedBox(height: 15),

                _field(_businessNameCtrl, "İşletme Adı", Icons.business),
                _field(_adminNameCtrl, "Admin Ad Soyad", Icons.person),
                _field(
                  _adminUsernameCtrl,
                  "Admin Kullanıcı Adı",
                  Icons.alternate_email,
                ),
                _field(
                  _adminPasswordCtrl,
                  "Admin Şifre (Min 8 Karakter, 1 Harf)",
                  Icons.lock,
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateBusinessAndAdmin(docId, adminDocId),
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    label: const Text(
                      "DEĞİŞİKLİKLERİ KAYDET",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- SİLME ONAY DİYALOGU ---
  void _confirmDeleteBusiness(
    String bDocId,
    String aDocId,
    String businessName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("İşletmeyi Sil?"),
          ],
        ),
        content: Text(
          "$businessName işletmesi ve buna bağlı tüm admin hesapları kalıcı olarak silinecektir. Bu işlem geri alınamaz!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İPTAL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBusinessAndAdmin(bDocId, aDocId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              "EVET, SİL",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FIREBASE BATCH SİLME FONKSİYONU ---
  Future<void> _deleteBusinessAndAdmin(String bDocId, String aDocId) async {
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Business dokümanını kuyruğa ekle
      DocumentReference businessRef = FirebaseFirestore.instance
          .collection('business')
          .doc(bDocId);
      batch.delete(businessRef);

      // 2. Admin dokümanı varsa kuyruğa ekle
      if (aDocId.isNotEmpty) {
        DocumentReference adminRef = FirebaseFirestore.instance
            .collection('admins')
            .doc(aDocId);
        batch.delete(adminRef);
      }

      // İkisini aynı anda atomik olarak sil
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("İşletme ve ilgili admin başarıyla silindi."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Silme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Silme işlemi başarısız: $e")));
      }
    }
  }

  // --- BATCH GÜNCELLEME FONKSİYONU ---
  Future<void> _updateBusinessAndAdmin(String bDocId, String aDocId) async {
    if (_businessNameCtrl.text.isEmpty ||
        _adminNameCtrl.text.isEmpty ||
        _adminUsernameCtrl.text.isEmpty ||
        _adminPasswordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen hiçbir alanı boş bırakmayın!")),
      );
      return;
    }

    String inputPass = _adminPasswordCtrl.text.trim();
    if (inputPass.length < 8 ||
        !RegExp(r'[a-zA-ZİıĞğÜüŞşÖöÇç]').hasMatch(inputPass)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Yeni şifre en az 8 karakter olmalı ve en az 1 harf içermelidir!",
          ),
        ),
      );
      return;
    }

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference businessRef = FirebaseFirestore.instance
          .collection('business')
          .doc(bDocId);
      batch.update(businessRef, {
        'business_name': _businessNameCtrl.text.trim(),
      });

      if (aDocId.isNotEmpty) {
        DocumentReference adminRef = FirebaseFirestore.instance
            .collection('admins')
            .doc(aDocId);
        batch.update(adminRef, {
          'name_surname': _adminNameCtrl.text.trim(),
          'username': _adminUsernameCtrl.text.trim(),
          'password': inputPass,
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bilgiler başarıyla güncellendi!"),
            backgroundColor: Colors.green,
          ),
        );
        _businessNameCtrl.clear();
        _adminNameCtrl.clear();
        _adminUsernameCtrl.clear();
        _adminPasswordCtrl.clear();
      }
    } catch (e) {
      debugPrint("Güncelleme hatası: $e");
    }
  }

  // --- YENİ İŞLETME KURMA DİYALOGU ---
  void _showCreateBusinessDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Yeni İşletme Kur"),
          scrollable: true,
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_businessNameCtrl, "İşletme Adı", Icons.business),
                _field(_adminNameCtrl, "Admin Ad Soyad", Icons.person),
                _field(_adminEmailCtrl, "Admin E-Posta", Icons.email_outlined),

                Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.cake_outlined),
                    title: Text(
                      _adminBirthDate == null
                          ? "Admin Doğum Tarihi"
                          : _adminBirthDate!.toLocal().toString().split(' ')[0],
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(1995),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => _adminBirthDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  _adminUsernameCtrl,
                  "Admin Kullanıcı Adı",
                  Icons.alternate_email,
                ),
                _field(
                  _adminPasswordCtrl,
                  "Admin Şifre (Min 8 Karakter, 1 Harf)",
                  Icons.lock,
                ),
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
      ),
    );
  }

  Widget _field(TextEditingController c, String l, IconData i) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
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
    if (_businessNameCtrl.text.isEmpty ||
        _adminNameCtrl.text.isEmpty ||
        _adminEmailCtrl.text.isEmpty ||
        _adminUsernameCtrl.text.isEmpty ||
        _adminPasswordCtrl.text.isEmpty ||
        _adminBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurun!")),
      );
      return;
    }

    if (_adminPasswordCtrl.text.length < 8 ||
        !RegExp(r'[a-zA-ZİıĞğÜüŞşÖöÇç]').hasMatch(_adminPasswordCtrl.text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Şifre kurallara uymuyor!")));
      return;
    }

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
        'email': _adminEmailCtrl.text.trim(),
        'birth_date': Timestamp.fromDate(_adminBirthDate!),
        'username': _adminUsernameCtrl.text.trim(),
        'password': _adminPasswordCtrl.text.trim(),
        'role': 'admin',
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        _adminNameCtrl.clear();
        _adminEmailCtrl.clear();
        _adminUsernameCtrl.clear();
        _adminPasswordCtrl.clear();
        _businessNameCtrl.clear();
        setState(() => _adminBirthDate = null);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
