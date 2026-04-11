import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerEditScreen extends StatefulWidget {
  final String workerId;
  final String firmaKey;

  const WorkerEditScreen({super.key, required this.workerId, required this.firmaKey, required Map<String, dynamic> currentData});

  @override
  State<WorkerEditScreen> createState() => _WorkerEditScreenState();
}

class _WorkerEditScreenState extends State<WorkerEditScreen> {
  final _nameCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  
  String _selectedRole = 'staff';
  String _baseBranch = ""; 
  List<String> _accessList = []; 
  List<String> _allBranches = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- PERSONEL VE ŞUBE BİLGİLERİNİ ÇEKME ---
  Future<void> _loadData() async {
    try {
      // 1. İşletmenin tüm şubelerini çek
      var bizDoc = await FirebaseFirestore.instance.collection('business').doc(widget.firmaKey).get();
      if (bizDoc.exists) {
        Map<String, dynamic> branches = bizDoc.data()?['branches'] ?? {};
        _allBranches = branches.keys.toList();
      }

      // 2. Personelin verilerini çek
      var workerDoc = await FirebaseFirestore.instance.collection('workers').doc(widget.workerId).get();
      if (workerDoc.exists) {
        var data = workerDoc.data() as Map<String, dynamic>;
        
        setState(() {
          _nameCtrl.text = data['name_surname'] ?? '';
          _userCtrl.text = data['username'] ?? '';
          _passCtrl.text = data['password'] ?? '';
          _emailCtrl.text = data['email'] ?? '';
          _ageCtrl.text = data['age']?.toString() ?? ''; 
          
          // KİTLEME VE GÜVENLİK (Kırmızı ekran hatasını çözen kısım)
          // Veritabanındaki rol, aşağıdaki 3 geçerli rolden biri değilse çökmemesi için 'staff' yap.
          String dbRole = data['role'] ?? 'staff';
          if (['staff', 'part_time', 'manager'].contains(dbRole)) {
            _selectedRole = dbRole;
          } else {
            _selectedRole = 'staff'; 
          }
          
          _baseBranch = data['branch_name'] ?? ''; 
          
          if (data['access'] != null) {
            _accessList = List<String>.from(data['access']);
          } else if (_baseBranch.isNotEmpty) {
            _accessList = [_baseBranch];
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Veri yükleme hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- KAYDETME ---
  Future<void> _updateWorker() async {
    if (_nameCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ad ve Şifre boş bırakılamaz!")));
      return;
    }
    if (_accessList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personele en az 1 şube yetkisi vermelisiniz!")));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('workers').doc(widget.workerId).update({
        'name_surname': _nameCtrl.text.trim(),
        'password': _passCtrl.text.trim(),
        'email': _emailCtrl.text.trim(), 
        'age': _ageCtrl.text.trim(),     
        'role': _selectedRole, // part_time da olsa güvenle kaydedilecek
        'access': _accessList,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Personel güncellendi!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("PERSONEL DÜZENLE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. KİŞİSEL BİLGİLER
                  _buildTextField(_nameCtrl, "Ad Soyad", Icons.person),
                  const SizedBox(height: 15),
                  
                  TextField(
                    controller: _userCtrl,
                    enabled: false, 
                    style: const TextStyle(color: Colors.white54),
                    decoration: InputDecoration(
                      labelText: "Kullanıcı Adı (Değiştirilemez)",
                      labelStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.alternate_email, color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E293B).withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  _buildTextField(_emailCtrl, "E-Posta Adresi", Icons.email_outlined, kbType: TextInputType.emailAddress),
                  const SizedBox(height: 15),
                  _buildTextField(_ageCtrl, "Yaş", Icons.cake_outlined, kbType: TextInputType.number),
                  const SizedBox(height: 15),
                  
                  _buildTextField(_passCtrl, "Şifre", Icons.lock),
                  const SizedBox(height: 25),

                  // 2. YETKİ ROLÜ (Yarı Zamanlı Seçeneği Eklendi)
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: "Yetki Rolü",
                      labelStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.blueAccent),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'staff', child: Text("STAFF (Tam Zamanlı)")),
                      DropdownMenuItem(value: 'part_time', child: Text("STAFF (Yarı Zamanlı)")), // YENİ ROL
                      DropdownMenuItem(value: 'manager', child: Text("MANAGER (Yönetici)")),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedRole = val!;
                        if (_selectedRole == 'manager') {
                          _accessList = List.from(_allBranches); // Hepsini seç
                        } else {
                          _accessList = _baseBranch.isNotEmpty ? [_baseBranch] : []; 
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 25),

                  // 3. ERİŞİM YETKİSİ
                  const Text("GİRİŞ YETKİSİ OLAN ŞUBELER", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  
                  if (_allBranches.isEmpty)
                    const Text("İşletmeye ait şube bulunamadı.", style: TextStyle(color: Colors.redAccent))
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B), 
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: _allBranches.map((bName) {
                          bool hasAccess = _accessList.contains(bName);
                          return CheckboxListTile(
                            title: Text(bName, style: TextStyle(color: hasAccess ? Colors.white : Colors.white54)),
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
                      onPressed: _updateWorker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: const Text("GÜNCELLEMELERİ KAYDET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // Özel Klavye Tipi İçin Güncellenmiş TextField Metodu
  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType kbType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: kbType, 
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}