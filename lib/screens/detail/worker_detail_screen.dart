import 'package:buildgym/screens/edit/worker_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerDetailScreen extends StatefulWidget {
  final String workerId;
  final String firmaKey;
  final String branchName;

  const WorkerDetailScreen({
    super.key,
    required this.workerId,
    required this.firmaKey,
    required this.branchName,
  });

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  // SİLME FONKSİYONU
  Future<void> _deleteWorker(String workerName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Personeli Sil",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "$workerName sistemden tamamen silinecektir. Emin misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("İPTAL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text("SİL", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Workers koleksiyonundan sil
        await FirebaseFirestore.instance
            .collection('workers')
            .doc(widget.workerId)
            .delete();

        // 2. Business altındaki şube listesinden ismini kaldır
        await FirebaseFirestore.instance
            .collection('business')
            .doc(widget.firmaKey)
            .update({
              'branches.${widget.branchName}.workers': FieldValue.arrayRemove([
                workerName,
              ]),
            });

        // 3. Log kaydı
        await FirebaseFirestore.instance.collection('logs').add({
          'action': "$workerName personeli admin tarafından silindi.",
          'business_id': widget.firmaKey,
          'timestamp': FieldValue.serverTimestamp(),
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Personel başarıyla silindi")),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Personel Detayları", style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workers')
            .doc(widget.workerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Veri bulunamadı."));
          }

          var worker = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _infoCard("Ad Soyad", worker['name_surname'], Icons.person),
                _infoCard(
                  "Kullanıcı Adı",
                  worker['username'],
                  Icons.alternate_email,
                ),
                _infoCard("E-posta", worker['email'], Icons.email_outlined),
                _infoCard("Şifre", worker['password'], Icons.lock_outline),
                _infoCard(
                  "Yetki Rolü",
                  worker['role']?.toUpperCase() ?? "STAFF",
                  Icons.admin_panel_settings,
                ),

                const Spacer(),

                // DÜZENLE BUTONU
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => WorkerEditScreen(
                            firmaKey: widget.firmaKey,
                            workerId: widget.workerId,
                            currentData: worker,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text(
                      "PERSONELİ DÜZENLE",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // SİL BUTONU
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    onPressed: () => _deleteWorker(worker['name_surname']),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("PERSONELİ SİSTEMDEN SİL"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent, size: 20),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
