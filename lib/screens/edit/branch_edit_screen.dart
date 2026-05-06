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

      // Eğer isim değiştiyse, eski kaydı silip yenisini oluşturuyoruz
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Şube başarıyla güncellendi"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Güncelleme sırasında bir hata oluştu!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Şubeyi Düzenle",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _updateBranch,
            icon: const Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _editField(_nameController, "Şube Adı", Icons.store, context),
            const SizedBox(height: 15),
            _editField(
              _addressController,
              "Adres Tarifi",
              Icons.description,
              context,
            ),
            const SizedBox(height: 15),
            _editField(
              _coordsController,
              "Koordinatlar (Lat, Lon)",
              Icons.map,
              context,
            ),
            const SizedBox(height: 20),

            // Harita Konteynırı
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
                          'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.kadir.workify',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation,
                          width: 50,
                          height: 50,
                          child: Icon(
                            Icons.location_on,
                            color: theme
                                .colorScheme
                                .primary, // Senin koyu mavi tonun
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

            // Kaydet Butonu (Alternatif erişim)
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _updateBranch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, // Koyu Mavi Buton
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "GÜNCELLEMEYİ KAYDET",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(
    TextEditingController c,
    String l,
    IconData i,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    return TextField(
      controller: c,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: l,
        prefixIcon: Icon(i, color: theme.colorScheme.primary),
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
      ),
    );
  }
}
