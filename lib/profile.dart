import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_food.dart';
import 'claimers_list.dart';
import 'edit_profile.dart';

class ProfilePage extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const ProfilePage({Key? key, required this.scaffoldKey}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String name = '';
  String email = '';
  String searchText = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  //Fetches user info from Firestore users collection
  // Falls back to FirebaseAuth if Firestore doc doesn't exist
  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          name = data['name']?.toString() ?? '';
          email = data['email']?.toString() ?? FirebaseAuth.instance.currentUser?.email ?? '';
        });
      } else {
        setState(() {
          name = FirebaseAuth.instance.currentUser?.displayName ?? '';
          email = FirebaseAuth.instance.currentUser?.email ?? '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        name = FirebaseAuth.instance.currentUser?.displayName ?? '';
        email = FirebaseAuth.instance.currentUser?.email ?? '';
      });
    }
  }

  Stream<QuerySnapshot> _myFoodsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.empty();

    //Streams only foods posted by current user
    // Orders by posting date (newest first)
    return FirebaseFirestore.instance
        .collection('foods')
        .where('postedBy', isEqualTo: uid)
        .orderBy('postedAt', descending: true) // to change food post order
        .snapshots();
  }

  Future<void> _deleteFood(String foodId) async {
    // Check if anyone has claimed
    final claims = await FirebaseFirestore.instance
        .collection('claims')
        .where('foodId', isEqualTo: foodId)
        .get();

    //cant delete if already claim
    if (claims.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Food has been claimed')),
      );
      return;
    }

    // delete food
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Food'),
        content: const Text('Are you sure you want to delete this food post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('foods').doc(foodId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food post deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                name.isNotEmpty ? name : 'User', // display user name
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // to edit profile
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  );
                },
                icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                label: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8F1402),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'search',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => searchText = value.toLowerCase()),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _myFoodsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No food posts yet'),
                );
              }

              var foods = snapshot.data!.docs;

              if (searchText.isNotEmpty) {
                foods = foods.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['foodName'] ?? '').toString().toLowerCase();
                  return name.contains(searchText);
                }).toList();
              }

              if (foods.isEmpty) {
                return const Center(
                  child: Text('No matching food posts'),
                );
              }

              //food grid
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: foods.length,
                itemBuilder: (context, index) {
                  final doc = foods[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final foodName = data['foodName']?.toString() ?? 'Unnamed';
                  final imageUrl = data['imageUrl']?.toString() ?? '';
                  final redeemedCount = data['redeemedCount'] ?? 0;
                  final quantity = data['quantity'] ?? 1;
                  final isFullyRedeemed = redeemedCount >= quantity;

                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        //food card
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: AspectRatio(
                                aspectRatio: 1.5,
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.fastfood, size: 40),
                                    );
                                  },
                                )
                                    : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.fastfood, size: 40),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                foodName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                '$redeemedCount/$quantity claimed',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                            const Spacer(),// create space between widger
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  //show claimed list
                                  IconButton(
                                    icon: const Icon(Icons.visibility, size: 20),
                                    color: const Color(0xFF8F1402),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ClaimersListScreen(foodId: doc.id),
                                        ),
                                      );
                                    },
                                  ),
                                  //allows edit if no claimed yet
                                  if (redeemedCount == 0)
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      color: const Color(0xFF8F1402),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditFoodScreen(foodId: doc.id),
                                          ),
                                        );
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    color: Colors.red,
                                    onPressed: () => _deleteFood(doc.id),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // show badge if fully redeemed badge
                      if (isFullyRedeemed)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Fully Redeemed',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}