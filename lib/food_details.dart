import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'food_model.dart';

class FoodDetailsScreen extends StatefulWidget {
  final String foodId;
  const FoodDetailsScreen({Key? key, required this.foodId}) : super(key: key);

  @override
  State<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  bool isClaiming = false;
  bool userHasClaimed = false;

  Future<FoodModel> _fetchFood() async {
    final doc = await FirebaseFirestore.instance.collection('foods').doc(widget.foodId).get();
    return FoodModel.fromDoc(doc);
  }

  Future<void> _checkIfUserClaimed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final claim = await FirebaseFirestore.instance
          .collection('claims')
          .where('foodId', isEqualTo: widget.foodId)
          .where('receiverId', isEqualTo: uid)
          .limit(1)
          .get();

      setState(() {
        userHasClaimed = claim.docs.isNotEmpty;
      });
    } catch (e) {
      print('Error checking claim: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkIfUserClaimed();
  }

  Future<void> _claimFood(FoodModel food) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Prevent poster from claiming own food
    if (food.postedBy == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot claim your own food post')),
      );
      return;
    }

    setState(() => isClaiming = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Checks if user already claimed this food
      final existingClaim = await FirebaseFirestore.instance
          .collection('claims')
          .where('foodId', isEqualTo: food.id)
          .where('receiverId', isEqualTo: uid)
          .get();

      if (existingClaim.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already claimed this food')),
        );
        setState(() => isClaiming = false);
        return;
      }

      final claimRef = FirebaseFirestore.instance.collection('claims').doc();
      final foodRef = FirebaseFirestore.instance.collection('foods').doc(food.id);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        // Get fresh data
        final fresh = await tx.get(foodRef);
        final data = fresh.data() as Map<String, dynamic>;
        //Check if still available
        final currentRedeemed = (data['redeemedCount'] ?? 0) is int
            ? data['redeemedCount']
            : int.tryParse(data['redeemedCount'].toString()) ?? 0;
        final quantity = (data['quantity'] ?? 1) is int
            ? data['quantity']
            : int.tryParse(data['quantity'].toString()) ?? 1;

        if ((data['isRedeemed'] ?? false) == true) {
          throw Exception('Already fully redeemed');
        }

        if (currentRedeemed >= quantity) {
          throw Exception('No more available');
        }

        //Create claim record
        tx.set(claimRef, {
          'foodId': food.id,
          'receiverId': uid,
          'claimDate': Timestamp.now(),
          'pickupStatus': 'Pending',
          'pickedUpAt': null,
        });
        //Update food count
        final newCount = currentRedeemed + 1;
        final updates = {'redeemedCount': newCount};
        // Mark as fully redeemed if needed
        if (newCount >= quantity) {
          updates['isRedeemed'] = true;
          updates['redeemedAt'] = Timestamp.now();
        }
        tx.update(foodRef, updates);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim successful — check History'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh claim status
      _checkIfUserClaimed();

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Claim failed: $e')),
      );
    } finally {
      setState(() => isClaiming = false);
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF8F1402)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getExpiryText(FoodModel food) {
    final expiry = food.expiryOption['type']?.toString() ?? 'none';

    if (expiry == 'none' || expiry == 'today') {
      return 'Today';
    } else if (expiry == 'hours') {
      final hours = food.expiryOption['value']?.toString() ?? '0';
      return '$hours hours from posting time';
    } else if (expiry == 'days') {
      final days = food.expiryOption['value']?.toString() ?? '0';
      return '$days days from posting time';
    } else if (expiry == 'date') {
      final v = food.expiryOption['value'];
      DateTime? expiryDate;

      if (v is Timestamp) {
        expiryDate = v.toDate();
      } else if (v is String) {
        expiryDate = DateTime.tryParse(v);
      }

      if (expiryDate != null) {
        final dateFormat = DateFormat('dd MMM yyyy');
        return dateFormat.format(expiryDate);
      }
    }

    return 'Not specified';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<FoodModel>(
      future: _fetchFood(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF6E7D8),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final food = snap.data!;
        final dateFormat = DateFormat('dd MMM yyyy');
        final available = food.quantity - food.redeemedCount;
        final isOwnPost = food.postedBy == currentUserId;

        return Scaffold(
          backgroundColor: const Color(0xFFF6E7D8),
          appBar: AppBar(
            backgroundColor: const Color(0xFF8F1402),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: const [
                Icon(Icons.restaurant, color: Colors.white),
                SizedBox(width: 8),
                Text('Share Bites', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (food.imageUrl.isNotEmpty)
                  Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.grey[300],
                    child: Image.network(
                      food.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.fastfood, size: 80, color: Colors.grey),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.grey[300],
                    child: const Icon(Icons.fastfood, size: 80, color: Colors.grey),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              food.foodName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (food.isRedeemed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'FULLY REDEEMED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (available > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$available LEFT',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (food.isHalal)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'Halal',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        food.description.isNotEmpty ? food.description : 'No description provided',
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      const Text(
                        'Pickup Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildInfoRow(
                        Icons.calendar_today,
                        'Date',
                        dateFormat.format(food.pickupDate),
                      ),
                      _buildInfoRow(
                        Icons.access_time,
                        'Time',
                        food.pickupTimeRange,
                      ),
                      _buildInfoRow(
                        Icons.location_on,
                        'Location',
                        food.pickupLocation,
                      ),
                      if (food.exactLocation.isNotEmpty)
                        _buildInfoRow(
                          Icons.place,
                          'Exact Location',
                          food.exactLocation,
                        ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      _buildInfoRow(
                        Icons.shopping_basket,
                        'Quantity',
                        '${food.redeemedCount}/${food.quantity} claimed',
                      ),

                      //Show expiry information
                      _buildInfoRow(
                        Icons.timer_outlined,
                        'Expiry',
                        _getExpiryText(food),
                      ),

                      const SizedBox(height: 30),

                      // Show different messages based on user status
                      if (isOwnPost)
                      // User is the poster
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'This is your food post',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (userHasClaimed)
                      // User has already claimed this food
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                Text(
                                  'You have claimed this food',
                                  style: TextStyle(
                                    color: Colors.green[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (food.isRedeemed || available <= 0)
                        // Food is fully redeemed
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'This food is no longer available',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                        // User can claim
                          Center(
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isClaiming ? null : () => _claimFood(food),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8F1402),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: isClaiming
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  'Claim This Food',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}