import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'food_model.dart';
import 'upload_food.dart';
import 'food_details.dart';
import 'history.dart';
import 'profile.dart';
import 'edit_profile.dart';
import 'about.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String searchText = '';
  String selectedLocation = 'All';

  final List<String> locations = [
    'All',
    'Murni',
    'Amanah',
    'Cendi',
    'Ilmu',
    'Upten',
    'Masjid UNITEN',
    'DSS',
    'COE Food Court',
  ];

  void _onItemTapped(int idx) => setState(() => _selectedIndex = idx);

  bool isVisible(FoodModel f) {
    final now = DateTime.now();

    if (f.isRedeemed) {
      if (f.redeemedAt == null) return false;
      final diff = now.difference(f.redeemedAt!).inHours;
      return diff < 24;
    }

    final expiry = f.expiryOption['type']?.toString() ?? 'today';
    if (expiry == 'today' || expiry == 'none') {
      final created = f.postedAt;
      final endOfDay = DateTime(created.year, created.month, created.day, 23, 59, 59);
      return now.isBefore(endOfDay);
    } else if (expiry == 'hours') {
      final v = f.expiryOption['value'];
      final hours = int.tryParse(v?.toString() ?? '') ?? 0;
      final expiryAt = f.postedAt.add(Duration(hours: hours));
      return now.isBefore(expiryAt);
    } else if (expiry == 'days') {
      final v = f.expiryOption['value'];
      final days = int.tryParse(v?.toString() ?? '') ?? 0;
      final expiryAt = f.postedAt.add(Duration(days: days));
      return now.isBefore(expiryAt);
    } else if (expiry == 'date') {
      final v = f.expiryOption['value'];
      DateTime? expiryAt;
      if (v is String) expiryAt = DateTime.tryParse(v);
      if (v is Timestamp) expiryAt = (v as Timestamp).toDate();
      if (expiryAt == null) return true;
      return now.isBefore(expiryAt);
    }
    return true;
  }

  Widget _homeContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search food...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => searchText = v.trim().toLowerCase()),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: DropdownButtonFormField<String>(
            value: selectedLocation,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
            onChanged: (v) => setState(() => selectedLocation = v ?? 'All'),
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('foods').orderBy('postedAt', descending: true).snapshots(), // to change post sequence
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              final foods = docs.map((d) => FoodModel.fromDoc(d)).where((f) {
                if (!isVisible(f)) return false;
                if (selectedLocation != 'All' && f.pickupLocation != selectedLocation) return false;
                if (searchText.isNotEmpty && !f.foodName.toLowerCase().contains(searchText)) return false;
                return true;
              }).toList();

              if (foods.isEmpty) {
                return const Center(child: Text('No food posts found.'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // numbers of columns
                  crossAxisSpacing: 12, //12 pixels of space horizontally
                  mainAxisSpacing: 12, //12 pixels of space vertically
                  childAspectRatio: 0.7, // Card height/width ratio
                ),
                itemCount: foods.length,
                itemBuilder: (context, i) {
                  final f = foods[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FoodDetailsScreen(foodId: f.id))),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect( //a rounded rectangle shape (image)
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: AspectRatio(
                                  aspectRatio: 1.3,
                                  child: f.imageUrl.isNotEmpty
                                      ? Image.network(
                                    f.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                                      );
                                    },
                                  )
                                      : Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.foodName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            f.pickupLocation,
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (f.isHalal)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Halal',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (f.isRedeemed) //change redeemed placement
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'FULLY REDEEMED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
// page index
  Widget _pageForIndex() {
    switch (_selectedIndex) {
      case 0:
        return _homeContent();
      case 1:
        return UploadFoodScreen();
      case 2:
        return const HistoryPage();
      case 3:
        return ProfilePage(scaffoldKey: _scaffoldKey);
      default:
        return _homeContent();
    }
  }

  Future<void> _handleLogout() async {   // Signs user out of Firebase
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Navigate to landing screen after logout
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false); // goes to landing after log out
      }
    } catch (e) {
      print('Logout error: $e');
      // Even if there's an error, still navigate to landing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF6E7D8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF8F1402),
        title: Row(
          children: const [
            Icon(Icons.restaurant, color: Colors.white),
            SizedBox(width: 8),
            Text('Share Bites', style: TextStyle(color: Colors.white))
          ],
        ),

        //bottom navigation
        actions: [
          if (_selectedIndex == 3)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
        ],
      ),
      endDrawer: _selectedIndex == 3 ? _buildDrawer() : null,
      body: _pageForIndex(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF8F1402),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }
 //side drawer menu (hamburger)
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFFF6E7D8),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 50),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF8F1402)),
              title: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF8F1402)),
              title: const Text('About', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Log Out', style: TextStyle(fontSize: 16, color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Close drawer first
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}