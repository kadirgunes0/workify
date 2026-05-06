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
    final theme = Theme.of(context);
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Personeli Sil"),
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
        await FirebaseFirestore.instance
            .collection('workers')
            .doc(widget.workerId)
            .delete();

        await FirebaseFirestore.instance
            .collection('business')
            .doc(widget.firmaKey)
            .update({
              'branches.${widget.branchName}.workers': FieldValue.arrayRemove([
                workerName,
              ]),
            });

        await FirebaseFirestore.instance.collection('logs').add({
          'action': "$workerName personeli admin tarafından silindi.",
          'business_id': widget.firmaKey,
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Personel başarıyla silindi")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Hata: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Personel Detayları",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workers')
            .doc(widget.workerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Veri bulunamadı."));
          }

          var worker = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _infoCard(
                  "Ad Soyad",
                  worker['name_surname'],
                  Icons.person,
                  context,
                ),
                _infoCard(
                  "Kullanıcı Adı",
                  worker['username'],
                  Icons.alternate_email,
                  context,
                ),
                _infoCard(
                  "E-posta",
                  worker['email'] ?? "-",
                  Icons.email_outlined,
                  context,
                ),
                _infoCard(
                  "Şifre",
                  worker['password'],
                  Icons.lock_outline,
                  context,
                ),
                _infoCard(
                  "Yetki Rolü",
                  worker['role']?.toUpperCase() ?? "STAFF",
                  Icons.admin_panel_settings,
                  context,
                ),

                const Spacer(),

                // DÜZENLE BUTONU (Koyu Mavi Standardı)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
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
                    icon: const Icon(Icons.edit),
                    label: const Text(
                      "PERSONELİ DÜZENLE",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // SİL BUTONU
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () => _deleteWorker(worker['name_surname']),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text(
                      "PERSONELİ SİSTEMDEN SİL",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard(
    String label,
    String value,
    IconData icon,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
