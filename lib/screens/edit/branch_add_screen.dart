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

 //saat ekleme kısmı
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
      // Hatalı format girilirse haritayı oynatma
    }
  }

  //saat seçme yeri
  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initialTime,
    Function(TimeOfDay) onPicked,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  //db save yeri saatler dahil 
  Future<void> _saveBranch() async {
    if (_nameController.text.isEmpty) return;

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
              //saatin db de kaydedilcek ismi
              'work_start': _formatTime(_workStart),
              'work_end': _formatTime(_workEnd),
              'lunch_start': _formatTime(_lunchStart),
              'lunch_end': _formatTime(_lunchEnd),
            },
          });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Şube başarıyla eklendi!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // UI saat kutusu
  Widget _buildTimeSelector(
    String title,
    TimeOfDay time,
    Function(TimeOfDay) onPicked,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
        ),
        onPressed: () => _pickTime(context, time, onPicked),
        child: Text(
          _formatTime(time),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Yeni Şube Tanımla", style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInput(_nameController, "Şube Adı", Icons.store_rounded),
            const SizedBox(height: 15),
            _buildInput(
              _addressController,
              "Açık Adres / Tarif",
              Icons.map_rounded,
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _coordsController,
              onChanged: _updateMapFromInput,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration(
                "Koordinatlar (Enlem, Boylam)",
                Icons.location_searching_rounded,
              ),
            ),
            const SizedBox(height: 20),

            // İNTERAKTİF HARİTA
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
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
                      userAgentPackageName: 'com.kadir.buildgym',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLoc,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
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

            // saat menü
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "ÇALIŞMA SAATLERİ",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            _buildTimeSelector(
              "Mesai Başlangıç",
              _workStart,
              (t) => _workStart = t,
            ),
            _buildTimeSelector("Mesai Bitiş",
             _workEnd,
              (t) => _workEnd = t,
              ),
            _buildTimeSelector(
              "Öğle Arası Çıkış",
              _lunchStart,
              (t) => _lunchStart = t,
            ),
            _buildTimeSelector(
              "Öğle Arası Dönüş",
              _lunchEnd,
              (t) => _lunchEnd = t,
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveBranch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "ŞUBEYİ SİSTEME KAYDET",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController c, String l, IconData i) {
    return TextField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(l, i),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
    );
  }
}
