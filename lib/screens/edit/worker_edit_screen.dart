import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerEditScreen extends StatefulWidget {
  final String workerId;
  final String firmaKey;

  const WorkerEditScreen({
    super.key,
    required this.workerId,
    required this.firmaKey,
    required Map<String, dynamic> currentData,
  });

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

  Future<void> _loadData() async {
    try {
      var bizDoc = await FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .get();
      if (bizDoc.exists) {
        Map<String, dynamic> branches = bizDoc.data()?['branches'] ?? {};
        _allBranches = branches.keys.toList();
      }

      var workerDoc = await FirebaseFirestore.instance
          .collection('workers')
          .doc(widget.workerId)
          .get();
      if (workerDoc.exists) {
        var data = workerDoc.data() as Map<String, dynamic>;

        setState(() {
          _nameCtrl.text = data['name_surname'] ?? '';
          _userCtrl.text = data['username'] ?? '';
          _passCtrl.text = data['password'] ?? '';
          _emailCtrl.text = data['email'] ?? '';
          _ageCtrl.text = data['age']?.toString() ?? '';

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

  Future<void> _updateWorker() async {
    if (_nameCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showSnack("Ad ve Şifre boş bırakılamaz!");
      return;
    }
    if (_accessList.isEmpty) {
      _showSnack("En az 1 şube yetkisi vermelisiniz!");
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(widget.workerId)
          .update({
            'name_surname': _nameCtrl.text.trim(),
            'password': _passCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'age': _ageCtrl.text.trim(),
            'role': _selectedRole,
            'access': _accessList,
            'updated_at': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context);
        _showSnack("Personel güncellendi!", isError: false);
      }
    } catch (e) {
      if (mounted) _showSnack("Hata: $e");
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
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
          "PERSONEL DÜZENLE",
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

                  TextField(
                    controller: _userCtrl,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: "Kullanıcı Adı (Değiştirilemez)",
                      prefixIcon: const Icon(Icons.alternate_email),
                      filled: true,
                      fillColor: theme.disabledColor.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
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
                  _buildTextField(
                    _ageCtrl,
                    "Yaş",
                    Icons.cake_outlined,
                    context,
                    kbType: TextInputType.number,
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(_passCtrl, "Şifre", Icons.lock, context),
                  const SizedBox(height: 25),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
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
                        child: Text("STAFF (Tam Zamanlı)"),
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
                          _accessList = _baseBranch.isNotEmpty
                              ? [_baseBranch]
                              : [];
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 25),

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

                  if (_allBranches.isEmpty)
                    const Text(
                      "Şube bulunamadı.",
                      style: TextStyle(color: Colors.redAccent),
                    )
                  else
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
                      onPressed: _updateWorker,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            theme.colorScheme.primary, // Koyu Mavi Buton
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "GÜNCELLEMELERİ KAYDET",
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
