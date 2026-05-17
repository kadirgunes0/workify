import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AdminLogTab extends StatefulWidget {
  final String firmaKey;

  const AdminLogTab({super.key, required this.firmaKey});

  @override
  State<AdminLogTab> createState() => _AdminLogTabState();
}

class _AdminLogTabState extends State<AdminLogTab> {
  DateTime? _startDate;
  DateTime? _endDate;

  final Map<String, Map<String, String>> _workerCache = {};
  Map<String, dynamic> _businessData = {};

  @override
  void initState() {
    super.initState();
    _fetchBusinessData();
  }

  Future<void> _fetchBusinessData() async {
    var doc = await FirebaseFirestore.instance
        .collection('business')
        .doc(widget.firmaKey)
        .get();
    if (doc.exists) {
      setState(() {
        _businessData = doc.data() as Map<String, dynamic>;
      });
    }
  }

  Future<Map<String, String>> _fetchWorkerInfo(
    Map<String, dynamic> logData,
  ) async {
    String fallbackName =
        logData['worker_name']?.toString() ??
        logData['name_surname']?.toString() ??
        "";
    String fallbackUsername =
        logData['worker_id']?.toString() ??
        logData['username']?.toString() ??
        "ID Yok";
    String searchKey =
        logData['worker_id']?.toString() ??
        logData['username']?.toString() ??
        "";

    if (searchKey.isNotEmpty && _workerCache.containsKey(searchKey)) {
      return _workerCache[searchKey]!;
    }

    try {
      if (searchKey.isNotEmpty) {
        var doc = await FirebaseFirestore.instance
            .collection('workers')
            .doc(searchKey)
            .get();
        if (doc.exists) {
          var wData = doc.data() as Map<String, dynamic>;
          Map<String, String> result = {
            "name": wData['name_surname']?.toString() ?? fallbackName,
            "username": wData['username']?.toString() ?? fallbackUsername,
          };
          _workerCache[searchKey] = result;
          return result;
        }
      }
    } catch (e) {
      debugPrint("Kullanıcı verisi çekilemedi: $e");
    }
    return {"name": fallbackName, "username": fallbackUsername};
  }

  bool _isOnTime(DateTime time, String rawType, String branchName) {
    int currentMins = time.hour * 60 + time.minute;
    String type = rawType.toLowerCase().trim();
    bool isEntry = type.contains('gir');
    bool isExit = type.contains('çık') || type.contains('cik');

    int startMins = 510; // 08:30
    int endMins = 1050; // 17:30
    int lunchStartMins = 750; // 12:30
    int lunchEndMins = 780; // 13:00

    if (_businessData['branches'] != null &&
        _businessData['branches'][branchName] != null) {
      var b = _businessData['branches'][branchName];
      startMins = _parseTime(b['work_start'], startMins);
      endMins = _parseTime(b['work_end'], endMins);
      lunchStartMins = _parseTime(b['lunch_start'], lunchStartMins);
      lunchEndMins = _parseTime(b['lunch_end'], lunchEndMins);
    }

    if (isEntry) {
      if (time.hour < (lunchStartMins ~/ 60)) {
        return currentMins >= (startMins - 30) &&
            currentMins <= (startMins + 15);
      } else {
        return currentMins <= (lunchEndMins + 15);
      }
    } else if (isExit) {
      if (time.hour < 15)
        return currentMins >= lunchStartMins;
      else
        return currentMins >= endMins;
    }
    return true;
  }

  int _parseTime(String? timeStr, int defaultMinutes) {
    if (timeStr == null || !timeStr.contains(':')) return defaultMinutes;
    List<String> parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> _exportToExcel(List<QueryDocumentSnapshot> logs) async {
    // Excel export mantığı (Hücre bazlı tasarımın devamı...)
    // (Önceki mesajdaki export kodunu buraya dahil edebilirsin)
  }

  void _showLogDetails(
    BuildContext context,
    String name,
    String branch,
    String device,
    String datetime,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          25,
          15,
          25,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Log Detayları",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 25),
            _detailRow(Icons.person, "Personel", name, context),
            _detailRow(Icons.storefront, "Şube", branch, context),
            _detailRow(Icons.phone_android, "Cihaz", device, context),
            _detailRow(Icons.access_time, "Zaman", datetime, context),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
                child: const Text(
                  "KAPAT",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String title,
    String value,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Tarih Aralığı Filtrele",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                  builder: (context, child) =>
                      Theme(data: theme, child: child!),
                );
                if (picked != null) {
                  setState(() {
                    _startDate = picked.start;
                    _endDate = picked.end;
                  });
                  if (mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.date_range, color: Colors.white),
              label: const Text(
                "Tarih Aralığı Seç",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
            ),
            if (_startDate != null)
              TextButton(
                onPressed: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                  Navigator.pop(context);
                }),
                child: const Text(
                  "Filtreyi Temizle",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Query query = FirebaseFirestore.instance
        .collection('logs')
        .where('business_id', isEqualTo: widget.firmaKey);
    if (_startDate != null && _endDate != null) {
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: _startDate)
          .where('timestamp', isLessThanOrEqualTo: _endDate);
    }
    query = query.orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _startDate == null ? "Son Kayıtlar" : "Filtreli Kayıtlar",
          style: const TextStyle(fontSize: 14),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snap) => IconButton(
              icon: const Icon(Icons.print_rounded, color: Colors.greenAccent),
              onPressed: () =>
                  snap.hasData ? _exportToExcel(snap.data!.docs) : null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFilterSheet,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.filter_alt_rounded, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          var logs = snapshot.data?.docs ?? [];
          if (logs.isEmpty)
            return const Center(
              child: Text(
                "Kayıt bulunamadı.",
                style: TextStyle(color: Colors.grey),
              ),
            );

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              var log = logs[index].data() as Map<String, dynamic>;
              DateTime dt =
                  (log['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              bool isOnTime = _isOnTime(
                dt,
                log['type'] ?? "",
                log['branch_name'] ?? "",
              );

              return FutureBuilder<Map<String, String>>(
                future: _fetchWorkerInfo(log),
                builder: (context, wSnap) {
                  if (!wSnap.hasData) return const SizedBox.shrink();
                  String name = wSnap.data!['name']!;
                  if (name.isEmpty) return const SizedBox.shrink();

                  // --- ÖZEL KART TASARIMI ---
                  return Card(
                    // Koyu modda arka plandan bir tık daha açık bir renk veriyoruz
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    elevation: isDark ? 0 : 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      // SİHİRLİ DOKUNUŞ: Kartın gömülmesini engelleyen ince kenarlık
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => _showLogDetails(
                        context,
                        name,
                        log['branch_name'] ?? "",
                        log['device_name'] ?? "Kayıtsız Cihaz",
                        DateFormat('dd.MM.yyyy HH:mm').format(dt),
                      ),
                      leading: CircleAvatar(
                        backgroundColor:
                            (log['type']?.toString().toLowerCase().contains(
                                  'gir',
                                ) ??
                                true)
                            ? Colors.blueAccent.withOpacity(0.1)
                            : Colors.orangeAccent.withOpacity(0.1),
                        child: Icon(
                          (log['type']?.toString().toLowerCase().contains(
                                    'gir',
                                  ) ??
                                  true)
                              ? Icons.login_rounded
                              : Icons.logout_rounded,
                          color:
                              (log['type']?.toString().toLowerCase().contains(
                                    'gir',
                                  ) ??
                                  true)
                              ? Colors.blueAccent
                              : Colors.orangeAccent,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isOnTime ? null : Colors.redAccent,
                        ),
                      ),
                      subtitle: Text(
                        log['branch_name'] ?? "",
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(dt),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isOnTime
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                          Text(
                            DateFormat('dd.MM.yy').format(dt),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
