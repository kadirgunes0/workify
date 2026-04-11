import 'package:buildgym/screens/detail/admin_log_tab.dart';
import 'package:buildgym/screens/detail/branch_detail_screen.dart';
import 'package:buildgym/screens/edit/branch_add_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

class AdminMainScreen extends StatefulWidget {
  final Map<String, dynamic> adminData;
  final String firmaKey;

  const AdminMainScreen({
    super.key,
    required this.adminData,
    required this.firmaKey,
  });

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          "${widget.firmaKey.toUpperCase()} - YÖNETİM",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => const LoginPage()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildBranchesTab(),
          _buildLogsTab(), // İsteğin üzerine ismi ve içeriği güncellendi
          _buildProfileTab(),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: Colors.blueAccent,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => BranchAddScreen(firmaKey: widget.firmaKey),
                ),
              ),
              child: const Icon(
                Icons.add_business_rounded,
                color: Colors.white,
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.white30,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            label: "Şubeler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: "Loglar",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: "Profil",
          ),
        ],
      ),
    );
  }

  // --- 1. ŞUBELER SEKME TASARIMI ---
  Widget _buildBranchesTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var data = snapshot.data!.data() as Map<String, dynamic>?;
        Map<String, dynamic> branches = data?['branches'] ?? {};

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: branches.length,
          itemBuilder: (context, index) {
            String bName = branches.keys.elementAt(index);
            var bData = branches[bName];
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.location_city_rounded,
                  color: Colors.blueAccent,
                ),
                title: Text(
                  bName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "${(bData['workers'] as List?)?.length ?? 0} Personel Kayıtlı",
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white10,
                  size: 14,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => BranchDetailsScreen(
                      firmaKey: widget.firmaKey,
                      branchName: bName,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- LOGLAR SEKME TASARIMI (NULL KORUMALI) ---
  Widget _buildLogsTab() {
    return AdminLogTab(firmaKey: widget.firmaKey);
  }

  // --- 3. PROFİL SEKME TASARIMI ---
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF1D4ED8),
                  Color(0xFF1E1B4B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white24,
                  child: Text(
                    widget.adminData['name_surname']?[0]?.toUpperCase() ?? "A",
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  widget.adminData['name_surname']?.toUpperCase() ?? "YÖNETİCİ",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.adminData['role']?.toUpperCase() ?? "ADMIN",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profileDataRow(
                  "İşletme Kimliği",
                  widget.firmaKey,
                  Icons.business_center_rounded,
                  Colors.orangeAccent,
                ),
                _profileDataRow(
                  "Kullanıcı Adı",
                  widget.adminData['username'] ?? "-",
                  Icons.alternate_email_rounded,
                  Colors.greenAccent,
                ),
                _profileDataRow(
                  "E-posta Adresi",
                  widget.adminData['email'] ?? "-",
                  Icons.email_outlined,
                  Colors.purpleAccent,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileDataRow(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
