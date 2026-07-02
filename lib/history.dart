import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String searchText = '';

  //Streams claims for current user
  // Orders by claim date (newest first)
  Stream<QuerySnapshot> _claimsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.empty();

    return FirebaseFirestore.instance
        .collection('claims')
        .where('receiverId', isEqualTo: uid)
        .orderBy('claimDate', descending: true)
        .snapshots();
  }

  Future<Map<String, dynamic>> _getPosterData(String posterId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(posterId)
          .get();

      if (doc.exists) {
        return doc.data() ?? {};
      }
    } catch (e) {
      print('Error fetching poster data: $e');
    }
    return {};
  }

  Future<void> _markPickedUp(DocumentSnapshot claimDoc) async {
    //show pickup confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFFFB4A2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm Pickup',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Please confirm that you have collected the food in front of the donor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8F1402),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Yes, Picked Up'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final claimRef = claimDoc.reference;
      final data = claimDoc.data() as Map<String, dynamic>;
      final foodId = data['foodId']?.toString() ?? '';

      if (foodId.isEmpty) {
        throw Exception('Invalid food ID');
      }

      // Update claim status
      await claimRef.update({
        'pickupStatus': 'Picked Up',
        'pickedUpAt': Timestamp.now(),
      });

      // update food status
      final foodRef = FirebaseFirestore.instance.collection('foods').doc(foodId);
      final foodDoc = await foodRef.get();

      if (foodDoc.exists) { //checked if fully redeemed
        final fdata = foodDoc.data() as Map<String, dynamic>;
        final currentRedeemed = (fdata['redeemedCount'] ?? 0) is int
            ? fdata['redeemedCount']
            : int.tryParse(fdata['redeemedCount'].toString()) ?? 0;
        final quantity = (fdata['quantity'] ?? 1) is int
            ? fdata['quantity']
            : int.tryParse(fdata['quantity'].toString()) ?? 1;

        // Update food status if all quantities are claimed
        if ((fdata['isRedeemed'] ?? false) != true && currentRedeemed >= quantity) {
          await foodRef.update({
            'isRedeemed': true,
            'redeemedAt': Timestamp.now(),
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as picked up successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error marking as picked up: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Failed to update pickup status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // build claim card
  Widget _buildClaimCard(
      DocumentSnapshot claimDoc,
      Map<String, dynamic> foodData,
      Map<String, dynamic> posterData,
      ) {
    final claimData = claimDoc.data() as Map<String, dynamic>;
    final status = claimData['pickupStatus']?.toString() ?? 'Pending';

    final foodName = foodData['foodName']?.toString() ?? 'Unknown';
    final location = foodData['pickupLocation']?.toString() ?? '';
    final exactLocation = foodData['exactLocation']?.toString() ?? '';
    final pickupDate = (foodData['pickupDate'] as Timestamp?)?.toDate();
    final pickupTime = foodData['pickupTimeRange']?.toString() ?? '';

    final posterName = posterData['name']?.toString() ?? 'Unknown';
    final posterPhone = posterData['phone']?.toString() ?? 'Not available';

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB4A2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Food Name: $foodName',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Location: $location',
            style: const TextStyle(fontSize: 14),
          ),
          if (exactLocation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Exact Location: $exactLocation',
              style: const TextStyle(fontSize: 14),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Pick-Up date: ${pickupDate != null ? dateFormat.format(pickupDate) : 'N/A'}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick-Up time: $pickupTime',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Divider(height: 16, color: Colors.black26),
          const SizedBox(height: 4),
          Text(
            'Food Donor: $posterName',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8F1402),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 16, color: Color(0xFF8F1402)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  posterPhone,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8F1402),
                  ),
                ),
              ),
            ],
          ),
          if (status == 'Pending') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _markPickedUp(claimDoc),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8F1402),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text('Mark as Picked Up'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Picked Up',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<List<Widget>> _buildClaimsList(List<QueryDocumentSnapshot> claims) async {
    List<Widget> widgets = [];
    List<Widget> pendingClaims = [];
    List<Widget> pastClaims = [];

    for (var claimDoc in claims) {
      final claimData = claimDoc.data() as Map<String, dynamic>;
      final foodId = claimData['foodId']?.toString() ?? '';
      final status = claimData['pickupStatus']?.toString() ?? 'Pending';

      if (foodId.isEmpty) continue;

      try {
        final foodDoc = await FirebaseFirestore.instance
            .collection('foods')
            .doc(foodId)
            .get();

        if (!foodDoc.exists) continue;

        final foodData = foodDoc.data() as Map<String, dynamic>;
        final foodName = (foodData['foodName'] ?? '').toString().toLowerCase();

        if (searchText.isNotEmpty && !foodName.contains(searchText)) {
          continue;
        }

        // Get poster information
        final posterId = foodData['postedBy']?.toString() ?? '';
        final posterData = await _getPosterData(posterId);

        final card = _buildClaimCard(claimDoc, foodData, posterData);

        if (status == 'Pending') {
          pendingClaims.add(card); //not picked up
        } else {
          pastClaims.add(card); //picked up
        }
      } catch (e) {
        print('Error loading food data: $e');
      }
    }

    //Separates into "Pending Pickup" and "Past Claim" sections
    if (pendingClaims.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Pending Pickup',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: pendingClaims),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    if (pastClaims.isNotEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Past Claim',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: pastClaims),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'Claim\nHistory',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _claimsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final claims = snapshot.data!.docs;

              if (claims.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No claims yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return FutureBuilder<List<Widget>>(
                future: _buildClaimsList(claims),
                builder: (context, listSnapshot) {
                  if (listSnapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error loading claims: ${listSnapshot.error}'),
                        ],
                      ),
                    );
                  }

                  if (!listSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final widgets = listSnapshot.data!;
                  if (widgets.isEmpty) {
                    return const Center(
                      child: Text('No claims found'),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widgets,
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
}