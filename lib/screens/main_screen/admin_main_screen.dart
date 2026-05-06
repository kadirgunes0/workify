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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.firmaKey.toUpperCase()} - YÖNETİM",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
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
        children: [_buildBranchesTab(), _buildLogsTab(), _buildProfileTab()],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              backgroundColor: theme.colorScheme.primary, // Koyu Mavi
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
        backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
        selectedItemColor: theme.textTheme.headlineLarge?.color,
        unselectedItemColor: theme.unselectedWidgetColor.withOpacity(0.3),
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
    final theme = Theme.of(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('business')
          .doc(widget.firmaKey)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
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
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.location_city_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  bName.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${(bData['workers'] as List?)?.length ?? 0} Personel Kayıtlı",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
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

  Widget _buildLogsTab() {
    return AdminLogTab(firmaKey: widget.firmaKey);
  }

  // --- 3. PROFİL SEKME TASARIMI ---
  Widget _buildProfileTab() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary, // Profili ana renk yaptık
              borderRadius: const BorderRadius.only(
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          title,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }
}
