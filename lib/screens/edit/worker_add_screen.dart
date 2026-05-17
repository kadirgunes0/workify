import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WorkerAddScreen extends StatefulWidget {
  final String firmaKey;
  final String branchName;

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
  final _emailCtrl = TextEditingController();

  DateTime? _selectedBirthDate;
  int? _calculatedAge;

  String _selectedRole = 'staff';
  List<String> _accessList = [];
  List<String> _allBranches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

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
          _accessList = [widget.branchName];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Şubeler çekilemedi: $e");
      setState(() => _isLoading = false);
    }
  }

  // Doğum tarihinden yaş hesaplama fonksiyonu
  void _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    setState(() {
      _selectedBirthDate = birthDate;
      _calculatedAge = age;
    });
  }

  // Şifre Validasyon Kontrolü (Minimum 8 karakter ve en az 1 harf)
  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    final regex = RegExp(r'[a-zA-ZİıĞğÜüŞşÖöÇç]');
    return regex.hasMatch(password);
  }

  Future<void> _saveWorker() async {
    if (_nameCtrl.text.isEmpty ||
        _userCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty) {
      _showSnackBar("Lütfen tüm alanları doldurun!");
      return;
    }
    if (_selectedBirthDate == null) {
      _showSnackBar("Lütfen doğum tarihini seçin!");
      return;
    }
    if (!_isPasswordValid(_passCtrl.text.trim())) {
      _showSnackBar(
        "Şifre en az 8 karakter olmalı ve en az 1 harf içermelidir!",
      );
      return;
    }
    if (_accessList.isEmpty) {
      _showSnackBar("En az 1 şubeye giriş yetkisi vermelisiniz!");
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
            'email': _emailCtrl.text.trim(),
            'birth_date': _selectedBirthDate != null
                ? Timestamp.fromDate(_selectedBirthDate!)
                : null,
            'age': _calculatedAge, // Hesaplanan yaş kaydediliyor
            'role': _selectedRole,
            'business_id': widget.firmaKey,
            'branch_name': widget.branchName,
            'access': _accessList,
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
        _showSnackBar("Personel başarıyla eklendi!", isError: false);
      }
    } catch (e) {
      _showSnackBar("Hata: $e");
    }
  }

  void _showSnackBar(String m, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "YENİ PERSONEL",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(_nameCtrl, "Ad Soyad", Icons.person, context),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _userCtrl,
                    "Kullanıcı Adı",
                    Icons.alternate_email,
                    context,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _emailCtrl,
                    "E-Posta Adresi",
                    Icons.email_outlined,
                    context,
                    kbType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 15),

                  // YAŞ YERİNE DOĞUM TARİHİ SEÇİCİ (TEK TARİH)
                  Card(
                    elevation: 0,
                    color: theme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.cake_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        _selectedBirthDate == null
                            ? "Doğum Tarihi Seçin"
                            : DateFormat(
                                'dd.MM.yyyy',
                              ).format(_selectedBirthDate!),
                        style: TextStyle(
                          color: _selectedBirthDate == null
                              ? Colors.grey
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: _calculatedAge != null
                          ? Text("Hesaplanan Yaş: $_calculatedAge")
                          : null,

                      onTap: () async {
                        // SADECE TEK TARİH SEÇTİREN YAPILAR
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate:
                              _selectedBirthDate ??
                              DateTime(2000), // İlk açılış yılı default 2000
                          firstDate: DateTime(1950), // En eski 1950 seçilebilir
                          lastDate:
                              DateTime.now(), // Bugünden ileri tarih seçilemez
                        );
                        if (picked != null) {
                          _calculateAge(
                            picked,
                          ); // Yaş hesaplama fonksiyonunu tetikler
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    _passCtrl,
                    "Şifre (Min 8 Karakter, 1 Harf)",
                    Icons.lock,
                    context,
                  ),
                  const SizedBox(height: 25),

                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      labelText: "Yetki Rolü",
                      prefixIcon: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
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
                        if (_selectedRole == 'manager') {
                          _accessList = List.from(_allBranches);
                        } else {
                          _accessList = [widget.branchName];
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 30),
                  const Text(
                    "GİRİŞ YETKİSİ OLAN ŞUBELER",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: _allBranches.map((bName) {
                        bool hasAccess = _accessList.contains(bName);
                        return CheckboxListTile(
                          title: Text(
                            bName,
                            style: TextStyle(
                              fontSize: 14,
                              color: hasAccess
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                          activeColor: theme.colorScheme.primary,
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
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "PERSONELİ KAYDET",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    BuildContext context, {
    TextInputType kbType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: ctrl,
      keyboardType: kbType,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
