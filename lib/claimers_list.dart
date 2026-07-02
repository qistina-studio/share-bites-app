import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClaimersListScreen extends StatelessWidget {
  final String foodId;

  const ClaimersListScreen({Key? key, required this.foodId}) : super(key: key);

  Stream<QuerySnapshot> _claimersStream() {
    //Streams all claims for specific food
    return FirebaseFirestore.instance
        .collection('claims')
        .where('foodId', isEqualTo: foodId)
        .snapshots();
  }

  //Fetches claimer's user data
  // Returns name and phone number
  Future<Map<String, dynamic>> _getUserData(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data() ?? {};
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6E7D8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8F1402),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
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
      body: Column(
        children: [
          const SizedBox(height: 30),
          const Text(
            'Claimers',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _claimersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('Stream error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text('Error loading claimers'),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Text('No data available'),
                  );
                }

                final claims = snapshot.data!.docs;

                if (claims.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No one has claimed this food yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: claims.length,
                  itemBuilder: (context, index) {
                    final claimData = claims[index].data() as Map<String, dynamic>;
                    final receiverId = claimData['receiverId'] ?? '';
                    final status = claimData['pickupStatus'] ?? 'Pending';

                    if (receiverId.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return FutureBuilder<Map<String, dynamic>>(
                      future: _getUserData(receiverId),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB4A2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }

                        final userData = userSnapshot.data ?? {};
                        final userName = userData['name'] ?? 'Unknown User';
                        final userPhone = userData['phone'] ?? 'No phone';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB4A2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Claimer's Name: $userName",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Phone: $userPhone",
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Status: $status",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: status == 'Picked Up'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: status == 'Picked Up'
                                      ? Colors.green[800]
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}