import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class BranchAddScreen extends StatefulWidget {
  final String firmaKey;
  const BranchAddScreen({super.key, required this.firmaKey});

  @override
  State<BranchAddScreen> createState() => _BranchAddScreenState();
}

class _BranchAddScreenState extends State<BranchAddScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _coordsController = TextEditingController();

  final MapController _mapController = MapController();
  LatLng _selectedLoc = const LatLng(40.8016, 29.4325); // Varsayılan: Gebze

  // Mesai saatleri
  TimeOfDay _workStart = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _workEnd = const TimeOfDay(hour: 17, minute: 30);
  TimeOfDay _lunchStart = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay _lunchEnd = const TimeOfDay(hour: 13, minute: 0);

  @override
  void initState() {
    super.initState();
    _coordsController.text =
        "${_selectedLoc.latitude}, ${_selectedLoc.longitude}";
  }

  void _updateMapFromInput(String val) {
    try {
      var parts = val.split(",");
      if (parts.length == 2) {
        double lat = double.parse(parts[0].trim());
        double lon = double.parse(parts[1].trim());
        setState(() {
          _selectedLoc = LatLng(lat, lon);
        });
        _mapController.move(_selectedLoc, 15.0);
      }
    } catch (e) {
      // Hatalı formatta haritayı oynatma
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initialTime,
    Function(TimeOfDay) onPicked,
  ) async {
    final theme = Theme.of(context);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Theme(
        // Saat seçiciyi uygulamanın genel temasına uyduruyoruz
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: theme.colorScheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveBranch() async {
    if (_nameController.text.isEmpty) {
      _showSnackBar("Lütfen şube adını girin!", isError: true);
      return;
    }

    try {
      String branchName = _nameController.text.trim();

      await FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .update({
            'branches.$branchName': {
              'lat': _selectedLoc.latitude,
              'lon': _selectedLoc.longitude,
              'address': _addressController.text.trim(),
              'workers': [],
              'qr_data_giris': "${widget.firmaKey}_${branchName}_giris",
              'work_start': _formatTime(_workStart),
              'work_end': _formatTime(_workEnd),
              'lunch_start': _formatTime(_lunchStart),
              'lunch_end': _formatTime(_lunchEnd),
            },
          });

      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("Şube başarıyla eklendi!", isError: false);
      }
    } catch (e) {
      if (mounted) _showSnackBar("Hata: $e", isError: true);
    }
  }

  void _showSnackBar(String m, {required bool isError}) {
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
          "Yeni Şube Tanımla",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInput(
              _nameController,
              "Şube Adı",
              Icons.store_rounded,
              context,
            ),
            const SizedBox(height: 15),
            _buildInput(
              _addressController,
              "Açık Adres / Tarif",
              Icons.map_rounded,
              context,
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _coordsController,
              onChanged: _updateMapFromInput,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: _inputDecoration(
                "Koordinatlar (Enlem, Boylam)",
                Icons.location_searching_rounded,
                context,
              ),
            ),
            const SizedBox(height: 20),

            // HARİTA
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLoc,
                    initialZoom: 14,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLoc = point;
                        _coordsController.text =
                            "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kadir.workify',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLoc,
                          width: 50,
                          height: 50,
                          child: Icon(
                            Icons.location_on,
                            color:
                                theme.colorScheme.primary, // Koyu Mavi Marker
                            size: 45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ÇALIŞMA SAATLERİ MENÜSÜ
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "ÇALIŞMA SAATLERİ",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
            ),
            Divider(color: theme.dividerColor.withOpacity(0.2)),

            _buildTimeSelector(
              "Mesai Başlangıç",
              _workStart,
              (t) => _workStart = t,
              context,
            ),
            _buildTimeSelector(
              "Mesai Bitiş",
              _workEnd,
              (t) => _workEnd = t,
              context,
            ),
            _buildTimeSelector(
              "Öğle Arası Başlangıç",
              _lunchStart,
              (t) => _lunchStart = t,
              context,
            ),
            _buildTimeSelector(
              "Öğle Arası Bitiş",
              _lunchEnd,
              (t) => _lunchEnd = t,
              context,
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveBranch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, // Koyu Mavi Buton
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "ŞUBEYİ SİSTEME KAYDET",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(
    String title,
    TimeOfDay time,
    Function(TimeOfDay) onPicked,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _formatTime(time),
            style: TextStyle(
              color: theme.textTheme.headlineLarge?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _pickTime(context, time, onPicked),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController c,
    String l,
    IconData i,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    return TextField(
      controller: c,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: _inputDecoration(l, i, context),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: theme.colorScheme.primary),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
      ),
    );
  }
}
