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
  Map<String, dynamic> _businessData =
      {}; // branch çalışma saatlerini tutmak için boş dict.

  @override
  void initState() {
    super.initState();
    _fetchBusinessData();
  }

  // db'den saatleri çekme
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
    String searchName = logData['worker_name']?.toString() ?? "";

    if (searchKey.isNotEmpty && _workerCache.containsKey(searchKey)) {
      return _workerCache[searchKey]!;
    }
    if (searchKey.isEmpty &&
        searchName.isNotEmpty &&
        _workerCache.containsKey(searchName)) {
      return _workerCache[searchName]!;
    }

    try {
      if (searchKey.isNotEmpty) {
        var doc = await FirebaseFirestore.instance
            .collection('workers')
            .doc(searchKey)
            .get();
        if (doc.exists) {
          var wData = doc.data() as Map<String, dynamic>;
          Map<String, String> result = <String, String>{
            "name": wData['name_surname']?.toString() ?? fallbackName,
            "username": wData['username']?.toString() ?? fallbackUsername,
          };
          _workerCache[searchKey] = result;
          return result;
        }

        var query = await FirebaseFirestore.instance
            .collection('workers')
            .where('username', isEqualTo: searchKey)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          var wData = query.docs.first.data();
          Map<String, String> result = <String, String>{
            "name": wData['name_surname']?.toString() ?? fallbackName,
            "username": wData['username']?.toString() ?? fallbackUsername,
          };
          _workerCache[searchKey] = result;
          return result;
        }
      }

      if (searchName.isNotEmpty) {
        var nameQuery = await FirebaseFirestore.instance
            .collection('workers')
            .where('name_surname', isEqualTo: searchName)
            .limit(1)
            .get();

        if (nameQuery.docs.isNotEmpty) {
          var wData = nameQuery.docs.first.data();
          Map<String, String> result = <String, String>{
            "name": wData['name_surname']?.toString() ?? fallbackName,
            "username": wData['username']?.toString() ?? "ID Yok",
          };
          _workerCache[searchName] = result;
          return result;
        }
      }
    } catch (e) {
      debugPrint("Kullanıcı verisi çekilemedi: $e");
    }

    return {"name": fallbackName, "username": fallbackUsername};
  }

  // Zamansal String'i (Örn: "08:30") dakikaya çevirir
  int _parseTime(String? timeStr, int defaultMinutes) {
    if (timeStr == null || !timeStr.contains(':')) return defaultMinutes;
    List<String> parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // yoklama sistemi ama saatin güncelleştirilmiş versiyonu
  bool _isOnTime(DateTime time, String rawType, String branchName) {
    int currentMins = time.hour * 60 + time.minute;
    String type = rawType.toLowerCase().trim();

    bool isEntry =
        type.contains('gir') ||
        type.contains('gır') ||
        type == 'giriş' ||
        type == 'giris';
    bool isExit =
        type.contains('çık') ||
        type.contains('cik') ||
        type == 'çıkış' ||
        type == 'cikis';

    // db'de yoksa default (08.30 - 17.30 , 12.30 - 13.00)
    int startMins = 510;
    int endMins = 1050;
    int lunchStartMins = 750;
    int lunchEndMins = 780;

    // Şubeye özel saat tanımlanmışsa (override)
    if (_businessData['branches'] != null &&
        _businessData['branches'][branchName] != null) {
      var b = _businessData['branches'][branchName];
      startMins = _parseTime(b['work_start'], startMins);
      endMins = _parseTime(b['work_end'], endMins);
      lunchStartMins = _parseTime(b['lunch_start'], lunchStartMins);
      lunchEndMins = _parseTime(b['lunch_end'], lunchEndMins);
    }

    if (isEntry) {
      // ÖĞLEDEN ÖNCE Mİ, SONRA MI?
      if (time.hour < (lunchStartMins ~/ 60)) {
        // SABAH GİRİŞİ: max 30dk erken veya 15dk geç
        return currentMins >= (startMins - 30) &&
            currentMins <= (startMins + 15);
      } else {
        // ÖĞLE DÖNÜŞÜ: max 15dk geç gelebilir
        return currentMins <= (lunchEndMins + 15);
      }
    } else if (isExit) {
      if (time.hour < 15) {
        // ÖĞLE ÇIKIŞI: erken çıkamaz.
        return currentMins >= lunchStartMins;
      } else {
        // AKŞAM ÇIKIŞI: erken çıkamaz. 
        return currentMins >= endMins;
      }
    }
    return true;
  }

  // --- EXCEL ÇIKTISI (Hücre Bazlı Özel Tasarım) ---
  Future<void> _exportToExcel(List<QueryDocumentSnapshot> logs) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dışa aktarılacak veri yok!")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Excel oluşturuluyor, lütfen bekleyin..."),
        duration: Duration(seconds: 2),
      ),
    );

    var excel = Excel.createExcel();
    Sheet sheet = excel['Kayıtlar'];
    excel.setDefaultSheet('Kayıtlar');

    String titleDateRange = "Tüm Zamanlar";
    String fileNameRange = "Tum-Zamanlar";
    if (_startDate != null && _endDate != null) {
      String start = DateFormat('dd.MM.yyyy').format(_startDate!);
      String end = DateFormat('dd.MM.yyyy').format(_endDate!);
      titleDateRange = "$start - $end";
      fileNameRange = "$start-$end".replaceAll('.', '');
    }

    // A1 Hücresine Tarih Yazdırılıyor
    var a1 = sheet.cell(CellIndex.indexByString("A1"));
    a1.value = TextCellValue(titleDateRange);
    a1.cellStyle = CellStyle(bold: true, fontSize: 12);

    // A3 Hücresine Başlık
    var a3 = sheet.cell(CellIndex.indexByString("A3"));
    a3.value = TextCellValue("İsim - Soyisim");
    a3.cellStyle = CellStyle(bold: true);

    // Tüm Şubeleri Çek ve Başlıkları (A3 yanına) Diz
    Set<String> branchSet = {};
    for (var doc in logs) {
      var data = doc.data() as Map<String, dynamic>;
      branchSet.add(data['branch_name']?.toString() ?? 'Bilinmeyen Şube');
    }
    List<String> sortedBranches = branchSet.toList()..sort();

    int colIndex = 1; // B Sütunundan başlayacağız
    for (String branch in sortedBranches) {
      // Şubeye özel saatleri al
      String wStart = "08:30";
      String wEnd = "17:30";
      String lStart = "12:30";
      String lEnd = "13:00";

      if (_businessData['branches'] != null &&
          _businessData['branches'][branch] != null) {
        var b = _businessData['branches'][branch];
        wStart = b['work_start'] ?? wStart;
        wEnd = b['work_end'] ?? wEnd;
        lStart = b['lunch_start'] ?? lStart;
        lEnd = b['lunch_end'] ?? lEnd;
      }

      // Üst Başlık (Şube Adı) - B2, D2...
      var branchTitle1 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 1),
      );
      branchTitle1.value = TextCellValue(branch);
      branchTitle1.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      var branchTitle2 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex + 1, rowIndex: 1),
      );
      branchTitle2.value = TextCellValue(branch);
      branchTitle2.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Alt Başlık (Saatler) - B3, C3...
      var timeCell1 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 2),
      );
      timeCell1.value = TextCellValue("$wStart - $wEnd");
      timeCell1.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      var timeCell2 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: colIndex + 1, rowIndex: 2),
      );
      timeCell2.value = TextCellValue("$lStart - $lEnd");
      timeCell2.cellStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      colIndex += 2;
    }

    // En Sağa "Cihaz Adı" (Row 3, Son Sütun)
    var deviceHeader = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: 2),
    );
    deviceHeader.value = TextCellValue("Cihaz Adı");
    deviceHeader.cellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );

    // TÜM SÜTUNLARI 6.5 CM (Yaklaşık 25 Birim Genişliğe) AYARLA
    for (int i = 0; i <= colIndex; i++) {
      sheet.setColumnWidth(i, 25.0);
    }

    // Verileri Grupla
    Map<String, Map<String, dynamic>> dailyRecords = {};

    for (var doc in logs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['timestamp'] == null) continue;

      var workerInfo = await _fetchWorkerInfo(data);
      String realName = workerInfo['name']!;
      if (realName.trim().isEmpty) continue;

      String realUsername = workerInfo['username']!;
      DateTime t = (data['timestamp'] as Timestamp).toDate();
      String dateKey = DateFormat('yyyy-MM-dd').format(t);
      String mapKey = "${realUsername}_$dateKey";
      String branch = data['branch_name']?.toString() ?? 'Bilinmeyen Şube';

      if (!dailyRecords.containsKey(mapKey)) {
        dailyRecords[mapKey] = {
          'name': realName,
          'device':
              data['device_name'] ?? data['device_model'] ?? 'Cihaz Kayıtsız',
          'branches': <String, Map<String, String>>{},
        };
      }

      if (!dailyRecords[mapKey]!['branches'].containsKey(branch)) {
        dailyRecords[mapKey]!['branches'][branch] = {
          'morning_in': '☐',
          'evening_out': '☐',
          'lunch_out': '☐',
          'lunch_in': '☐',
        };
      }

      String typeStr = (data['type'] ?? '').toString().toLowerCase();
      bool isEntry = typeStr.contains('gir') || typeStr.contains('gır');
      bool isExit = typeStr.contains('çık') || typeStr.contains('cik');

      bool isOnTime = _isOnTime(t, typeStr, branch);
      String checkMark = isOnTime ? '☑' : '☒';

      if (isEntry) {
        if (t.hour < 12) {
          dailyRecords[mapKey]!['branches'][branch]['morning_in'] = checkMark;
        } else if (t.hour >= 12 && t.hour < 15) {
          dailyRecords[mapKey]!['branches'][branch]['lunch_in'] = checkMark;
        }
      } else if (isExit) {
        if (t.hour < 15) {
          dailyRecords[mapKey]!['branches'][branch]['lunch_out'] = checkMark;
        } else {
          dailyRecords[mapKey]!['branches'][branch]['evening_out'] = checkMark;
        }
      }
    }

    // Verileri Excel Hücrelerine Bas (Row 4'ten itibaren)
    int currentRow = 3; // 0 index tabanlı, Row 4 = index 3
    dailyRecords.forEach((key, record) {
      // A Sütunu (İsim)
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
          )
          .value = TextCellValue(
        record['name'],
      );

      int cIndex = 1;
      for (String branch in sortedBranches) {
        if (record['branches'].containsKey(branch)) {
          var bData = record['branches'][branch];

          var cellMorn = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: cIndex,
              rowIndex: currentRow,
            ),
          );
          cellMorn.value = TextCellValue(
            "${bData['morning_in']}          -          ${bData['evening_out']}",
          );
          cellMorn.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
          );

          var cellLunch = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: cIndex + 1,
              rowIndex: currentRow,
            ),
          );
          cellLunch.value = TextCellValue(
            "${bData['lunch_out']}          -          ${bData['lunch_in']}",
          );
          cellLunch.cellStyle = CellStyle(
            horizontalAlign: HorizontalAlign.Center,
          );
        } else {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: cIndex,
                  rowIndex: currentRow,
                ),
              )
              .value = TextCellValue(
            "☐          -          ☐",
          );
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: cIndex + 1,
                  rowIndex: currentRow,
                ),
              )
              .value = TextCellValue(
            "☐          -          ☐",
          );
        }
        cIndex += 2;
      }

      // Son Sütun (Cihaz Adı)
      var cellDevice = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: cIndex, rowIndex: currentRow),
      );
      cellDevice.value = TextCellValue(record['device']);
      cellDevice.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

      currentRow++;
    });

    try {
      var fileBytes = excel.save();
      final directory = await getApplicationDocumentsDirectory();
      String filePath = "${directory.path}/logKaydi-$fileNameRange.xlsx";

      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Dosya hazır! Paylaşım ekranı açılıyor..."),
            backgroundColor: Colors.green,
          ),
        );
      }

      await Share.shareXFiles([
        XFile(filePath),
      ], text: "Yoklama Raporu ($titleDateRange)");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- DETAY GÖSTERİMİ VE UI KODLARI BURANIN DEVAMINDA ---
  // --- DETAY GÖSTERİMİ (BOTTOM SHEET) ---
  void _showLogDetails(
    BuildContext context,
    String name,
    String branch,
    String device,
    String datetime,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // SİHİRLİ DOKUNUŞ 1: İçeriğin boyutuna göre esnemesine izin verir
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          // SİHİRLİ DOKUNUŞ 2: Alt navigasyon çubuğuyla çakışmayı önler
          child: SingleChildScrollView(
            // SİHİRLİ DOKUNUŞ 3: Ekran küçükse kaydırma özelliği ekler
            child: Padding(
              padding: EdgeInsets.only(
                left: 25,
                right: 25,
                top: 25,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    25, // Klavye vs. açılırsa üstte kalsın
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Log Detayları",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 25),

                  _detailRow(Icons.person, "Personel", name),
                  _detailRow(Icons.storefront, "Şube Adı", branch),
                  _detailRow(Icons.phone_android, "Cihaz Adı", device),
                  _detailRow(Icons.access_time, "Tarih ve Saat", datetime),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    DateTime tempStart =
        _startDate ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime tempEnd = _endDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Tarih Aralığı Filtrele",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  ListTile(
                    tileColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: const Icon(
                      Icons.date_range,
                      color: Colors.blueAccent,
                    ),
                    title: const Text(
                      "Başlangıç Tarihi",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy - HH:mm').format(tempStart),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: tempStart,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(tempStart),
                        );
                        if (pickedTime != null) {
                          setSheetState(
                            () => tempStart = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  ListTile(
                    tileColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: const Icon(
                      Icons.date_range,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      "Bitiş Tarihi",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    subtitle: Text(
                      DateFormat('dd.MM.yyyy - HH:mm').format(tempEnd),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: tempEnd,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(tempEnd),
                        );
                        if (pickedTime != null) {
                          setSheetState(
                            () => tempEnd = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _startDate = tempStart;
                          _endDate = tempEnd;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "FİLTREYİ UYGULA",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Filtreyi Temizle",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: const Color(0xFF0F172A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _startDate == null ? "Son Kayıtlar" : "Filtrelenmiş Kayıtlar",
            style: const TextStyle(fontSize: 15, color: Colors.white70),
          ),
          actions: [
            StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                return IconButton(
                  icon: const Icon(
                    Icons.print_rounded,
                    color: Colors.greenAccent,
                  ),
                  tooltip: "Excel'e Aktar",
                  onPressed: () {
                    if (snapshot.hasData) _exportToExcel(snapshot.data!.docs);
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFilterSheet,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.filter_alt_rounded, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Hata: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          var logs = snapshot.data?.docs ?? [];
          if (logs.isEmpty) {
            return const Center(
              child: Text(
                "Kayıt bulunamadı.",
                style: TextStyle(color: Colors.white38),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 80),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              var log = logs[index].data() as Map<String, dynamic>;

              String typeStr = (log['type'] ?? "İşlem")
                  .toString()
                  .toLowerCase();
              bool isEntry = typeStr.contains('gir') || typeStr.contains('gır');
              String branchName =
                  log['branch_name']?.toString() ?? 'Bilinmeyen Şube';

              DateTime dt = log['timestamp'] != null
                  ? (log['timestamp'] as Timestamp).toDate()
                  : DateTime.now();
              String dateStr = DateFormat('dd.MM.yyyy').format(dt);
              String timeStr = DateFormat('HH:mm').format(dt);

              bool isOnTime = _isOnTime(dt, typeStr, branchName);

              return FutureBuilder<Map<String, String>>(
                future: _fetchWorkerInfo(log),
                builder: (context, workerSnapshot) {
                  if (!workerSnapshot.hasData) return const SizedBox.shrink();

                  String name = workerSnapshot.data!['name']!;
                  String username = workerSnapshot.data!['username']!;
                  String deviceName =
                      log['device_name'] ??
                      log['device_model'] ??
                      log['device_id'] ??
                      "";

                  if (name.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        _showLogDetails(
                          context,
                          name,
                          branchName,
                          deviceName.isNotEmpty ? deviceName : 'Kayıtsız Cihaz',
                          "$dateStr - $timeStr",
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    (isEntry
                                            ? Colors.blueAccent
                                            : Colors.orangeAccent)
                                        .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isEntry
                                    ? Icons.login_rounded
                                    : Icons.logout_rounded,
                                color: isEntry
                                    ? Colors.blueAccent
                                    : Colors.orangeAccent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (name.isNotEmpty) ...[
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: isOnTime
                                            ? Colors.white
                                            : Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  Text(
                                    "@$username",
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),

                                  if (deviceName.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.phone_android_rounded,
                                          size: 12,
                                          color: Colors.white38,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          deviceName,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: isOnTime
                                        ? Colors.white
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Icon(
                                  isOnTime
                                      ? Icons.check_box_rounded
                                      : Icons.disabled_by_default_rounded,
                                  color: isOnTime
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  size: 24,
                                ),
                              ],
                            ),
                          ],
                        ),
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
