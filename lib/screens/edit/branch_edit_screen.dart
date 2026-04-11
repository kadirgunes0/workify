import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class BranchEditScreen extends StatefulWidget {
  final String firmaKey;
  final String branchName;
  final Map<String, dynamic> branchData;

  const BranchEditScreen({
    super.key,
    required this.firmaKey,
    required this.branchName,
    required this.branchData,
  });

  @override
  State<BranchEditScreen> createState() => _BranchEditScreenState();
}

class _BranchEditScreenState extends State<BranchEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _coordsController;
  late MapController _mapController;
  late LatLng _currentLocation;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.branchName);
    _addressController = TextEditingController(
      text: widget.branchData['address'] ?? "",
    );

    double lat = widget.branchData['lat'] ?? 40.8016;
    double lon = widget.branchData['lon'] ?? 29.4325;
    _currentLocation = LatLng(lat, lon);

    _coordsController = TextEditingController(text: "$lat, $lon");
    _mapController = MapController();
  }

  Future<void> _updateBranch() async {
    try {
      var parts = _coordsController.text.split(",");
      double lat = double.parse(parts[0].trim());
      double lon = double.parse(parts[1].trim());

      // Eğer isim değiştiyse, eski kaydı silip yenisini oluşturmamız gerekir (Firebase Map yapısı gereği)
      if (_nameController.text.trim() != widget.branchName) {
        await FirebaseFirestore.instance
            .collection('business')
            .doc(widget.firmaKey)
            .update({'branches.${widget.branchName}': FieldValue.delete()});
      }

      await FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .update({
            'branches.${_nameController.text.trim()}': {
              'address': _addressController.text.trim(),
              'lat': lat,
              'lon': lon,
              'qr_data_giris':
                  "${widget.firmaKey}_${_nameController.text.trim()}_giris",
            },
          });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Şube güncellendi"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Güncelleme hatası!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Şubeyi Düzenle", style: TextStyle(fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            onPressed: _updateBranch,
            icon: const Icon(Icons.check, color: Colors.greenAccent),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _editField(_nameController, "Şube Adı", Icons.store),
            const SizedBox(height: 15),
            _editField(_addressController, "Adres Tarifi", Icons.description),
            const SizedBox(height: 15),
            _editField(_coordsController, "Koordinatlar (Lat, Lon)", Icons.map),
            const SizedBox(height: 20),
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: 15.0,
                    onTap: (tap, point) {
                      setState(() {
                        _currentLocation = point;
                        _coordsController.text =
                            "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png', // Daha hızlı sunucu
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName:
                          'com.kadir.buildgym', // Burası senin paket adın olmalı
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(TextEditingController c, String l, IconData i) => TextField(
    controller: c,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: l,
      labelStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(i, color: Colors.blueAccent),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
