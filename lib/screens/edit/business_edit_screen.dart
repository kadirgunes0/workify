import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessEditScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> currentData;

  const BusinessEditScreen({
    super.key,
    required this.docId,
    required this.currentData,
  });

  @override
  State<BusinessEditScreen> createState() => _BusinessEditScreenState();
}

class _BusinessEditScreenState extends State<BusinessEditScreen> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.currentData['business_name'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("İŞLETMEYİ DÜZENLE"),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "İşletme Adı",
                labelStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(
                  Icons.business,
                  color: Colors.blueAccent,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('business')
                      .doc(widget.docId)
                      .update({'business_name': _nameCtrl.text.trim()});
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
                child: const Text("GÜNCELLEMELERİ KAYDET"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
