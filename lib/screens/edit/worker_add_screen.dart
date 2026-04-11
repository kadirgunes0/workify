import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerAddScreen extends StatefulWidget {
  final String firmaKey;
  final String branchName; // Personelin ana şubesi

  const WorkerAddScreen({
    super.key,
    required this.firmaKey,
    required this.branchName,
  });

  @override
  State<WorkerAddScreen> createState() => _WorkerAddScreenState();
}

class _WorkerAddScreenState extends State<WorkerAddScreen> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  // YENİ EKLENEN KONTROLCÜLER
  final _emailCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  String _selectedRole = 'staff';
  List<String> _accessList = [];
  List<String> _allBranches =
      []; // İşletmenin tüm şubelerini hafızada tutacağız
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBranches(); // Sayfa açılırken şubeleri çek
  }

  // --- ŞUBELERİ DB'DEN ÇEKME ---
  Future<void> _fetchBranches() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .get();
      if (doc.exists) {
        Map<String, dynamic> branches = doc.data()?['branches'] ?? {};
        setState(() {
          _allBranches = branches.keys.toList();
          // Varsayılan rol 'staff' olduğu için sadece kendi şubesini işaretliyoruz
          _accessList = [widget.branchName];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Şubeler çekilemedi: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- KAYDETME ---
  Future<void> _saveWorker() async {
    if (_nameCtrl.text.isEmpty ||
        _userCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ad, Kullanıcı Adı ve Şifre boş bırakılamaz!"),
        ),
      );
      return;
    }
    if (_accessList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("En az 1 şubeye giriş yetkisi vermelisiniz!"),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(_userCtrl.text.trim())
          .set({
            'name_surname': _nameCtrl.text.trim(),
            'username': _userCtrl.text.trim(),
            'password': _passCtrl.text.trim(),
            'email': _emailCtrl.text.trim(), // E-Posta DB'ye yazılıyor
            'age': _ageCtrl.text.trim(), // Yaş DB'ye yazılıyor
            'role': _selectedRole,
            'business_id': widget.firmaKey,
            'branch_name': widget.branchName, // Ana şubesi
            'access': _accessList, // Tikli olan tüm şubeler
            'created_at': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .update({
            'branches.${widget.branchName}.workers': FieldValue.arrayUnion([
              _nameCtrl.text.trim(),
            ]),
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Personel başarıyla eklendi!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          "YENİ PERSONEL",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KİŞİSEL BİLGİLER
                  _buildTextField(_nameCtrl, "Ad Soyad", Icons.person),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _userCtrl,
                    "Kullanıcı Adı",
                    Icons.alternate_email,
                  ),
                  const SizedBox(height: 15),

                  // YENİ EKLENEN ALANLAR (E-Posta ve Yaş)
                  _buildTextField(
                    _emailCtrl,
                    "E-Posta Adresi",
                    Icons.email_outlined,
                    kbType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _ageCtrl,
                    "Yaş",
                    Icons.cake_outlined,
                    kbType: TextInputType.number,
                  ),
                  const SizedBox(height: 15),

                  _buildTextField(_passCtrl, "Şifre", Icons.lock),
                  const SizedBox(height: 25),

                  // YETKİ ROLÜ (OTOMASYON BURADA ÇALIŞIYOR)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: "Yetki Rolü",
                      labelStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.blueAccent,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'staff',
                        child: Text("STAFF (Personel)"),
                      ),
                      DropdownMenuItem(
                        value: 'part_time',
                        child: Text("STAFF (Yarı Zamanlı)"),
                      ),
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text("MANAGER (Yönetici)"),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedRole = val!;
                        // SİHİRLİ DOKUNUŞ: Rol değiştiğinde Checkbox'ları otomatik güncelle
                        if (_selectedRole == 'manager') {
                          _accessList = List.from(
                            _allBranches,
                          ); // Tüm şubeleri seç
                        } else {
                          _accessList = [
                            widget.branchName,
                          ]; // Sadece ana şubeyi seç
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 30),
                  const Text(
                    "GİRİŞ YETKİSİ OLAN ŞUBELER",
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // CHECKBOX LİSTESİ
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      children: _allBranches.map((bName) {
                        bool hasAccess = _accessList.contains(bName);
                        return CheckboxListTile(
                          title: Text(
                            bName,
                            style: TextStyle(
                              color: hasAccess ? Colors.white : Colors.white54,
                            ),
                          ),
                          activeColor: Colors.blueAccent,
                          checkColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          value: hasAccess,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _accessList.add(bName);
                              } else {
                                _accessList.remove(bName);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveWorker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "PERSONELİ KAYDET",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30), // Alt boşluk
                ],
              ),
            ),
    );
  }

  // Özel Klavye Tipi İçin Güncellenmiş TextField Metodu
  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType kbType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType:
          kbType, // Klavyeyi dinamik olarak değiştirir (Sayı veya Metin)
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
