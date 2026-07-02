import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UploadFoodScreen extends StatefulWidget {
  @override
  State<UploadFoodScreen> createState() => _UploadFoodScreenState();
}

class _UploadFoodScreenState extends State<UploadFoodScreen> {
  Uint8List? imageBytes;
  XFile? pickedImage;
  final picker = ImagePicker();

  final TextEditingController foodName = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController exactLocation = TextEditingController();
  final TextEditingController expiryHours = TextEditingController();
  final TextEditingController expiryDays = TextEditingController();

  bool isHalal = false;
  int quantity = 1;

  String pickupLocation = "Murni";
  DateTime? pickupDate;
  TimeOfDay? pickupStart;
  TimeOfDay? pickupEnd;

  String expiryType = "none";
  DateTime? expiryDate;

  bool isLoading = false;
  String uploadStatus = '';
  double uploadProgress = 0.0;

  final List<String> locations = [
    'Murni',
    'Amanah',
    'Cendi',
    'Ilmu',
    'Upten',
    'Masjid UNITEN',
    'DSS',
    'COE Food Court',
  ];

  //open gallery to pick image
  Future<void> pickImage() async {
    try {
      final XFile? img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (img == null) return;

      setState(() => uploadStatus = 'Processing image...');
      //compress image
      if (kIsWeb) {
        imageBytes = await img.readAsBytes();
      } else {
        final compressed = await FlutterImageCompress.compressWithFile( //flutter plug in
          img.path,
          minWidth: 800,
          minHeight: 800,
          quality: 70,
          format: CompressFormat.jpeg,
        );

        imageBytes = compressed ?? await File(img.path).readAsBytes();
      }

      pickedImage = img;

      //display image size
      final sizeKB = (imageBytes!.length / 1024).toStringAsFixed(1);
      print('✓ Image ready: $sizeKB KB');

      setState(() => uploadStatus = '✓ Ready: $sizeKB KB');

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => uploadStatus = '');
      });
    } catch (e) {
      print('✗ Image error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image error: $e')),
        );
      }
    }
  }

  String formatTime(TimeOfDay t) {
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }

  Future<void> uploadFood() async {
    // Validation
    if (imageBytes == null ||
        foodName.text.isEmpty ||
        description.text.isEmpty ||
        pickupDate == null ||
        pickupStart == null ||
        pickupEnd == null ||
        exactLocation.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    // Time validation
    final start = DateTime(2000, 1, 1, pickupStart!.hour, pickupStart!.minute);
    final end = DateTime(2000, 1, 1, pickupEnd!.hour, pickupEnd!.minute);
    if (end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      uploadStatus = 'Starting upload...';
      uploadProgress = 0.0;
    });

    //upload loading screen
    print('Starting upload - Image: ${(imageBytes!.length / 1024).toStringAsFixed(1)} KB');
    final uploadStartTime = DateTime.now();

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      // Prepare expiry data
      dynamic expiryValue;
      if (expiryType == "date" && expiryDate != null) {
        expiryValue = Timestamp.fromDate(expiryDate!);
      } else if (expiryType == "hours") {
        expiryValue = int.tryParse(expiryHours.text) ?? 0;
      } else if (expiryType == "days") {
        expiryValue = int.tryParse(expiryDays.text) ?? 0;
      }

      Map<String, dynamic> expiryData = {
        "type": expiryType,
        "value": expiryValue,
      };

      setState(() => uploadStatus = 'Uploading image...');

      // Upload to Firebase Storage with public metadata
      String fileName = "food_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final storageRef = FirebaseStorage.instance.ref().child("foods/$fileName");

      print('Uploading to Firebase Storage...');

      final uploadTask = storageRef.putData(
        imageBytes!,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );

      // Track progress
      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted && snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          final percent = (progress * 100).toInt();
          print('Upload: $percent%');
          setState(() {
            uploadProgress = progress;
            uploadStatus = 'Uploading: $percent%';
          });
        }
      });

      print('Waiting for upload...');
      final snapshot = await uploadTask;

      final elapsed = DateTime.now().difference(uploadStartTime).inSeconds;
      print('Upload complete in $elapsed seconds!');

      setState(() => uploadStatus = 'Getting URL...');
      final imageUrl = await snapshot.ref.getDownloadURL();
      print('Got URL: $imageUrl');

      setState(() => uploadStatus = 'Saving to database...');

      // Save to Firestore
      await FirebaseFirestore.instance.collection("foods").add({
        "foodName": foodName.text.trim(),
        "description": description.text.trim(),
        "pickupLocation": pickupLocation,
        "exactLocation": exactLocation.text.trim(),
        "pickupDate": Timestamp.fromDate(pickupDate!),
        "pickupTimeRange": "${formatTime(pickupStart!)} - ${formatTime(pickupEnd!)}",
        "isHalal": isHalal,
        "quantity": quantity,
        "imageUrl": imageUrl,
        "postedAt": Timestamp.now(),
        "postedBy": currentUserId,
        "redeemedCount": 0,
        "isRedeemed": false,
        "expiryOption": expiryData,
      });

      print('Saved to Firestore');
      final totalElapsed = DateTime.now().difference(uploadStartTime).inSeconds;
      print('Total time: $totalElapsed seconds');

      if (mounted) {
        setState(() {
          isLoading = false;
          uploadStatus = '';
          uploadProgress = 0.0;
        });

        // Show success message after food done upload
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Food uploaded successfully! (${totalElapsed}s)"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to home screen (index 0) - THIS FIXES THE NAVIGATION ISSUE
        // We can't directly navigate here, but we can use a callback
        // The home.dart file will handle this via _onItemTapped

        // Instead, we'll use a workaround: navigate and replace with home
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
              (route) => false,
        );
      }
    } catch (e) {
      print('Upload error: $e');
      final elapsed = DateTime.now().difference(uploadStartTime).inSeconds;
      print('Failed after $elapsed seconds');

      if (mounted) {
        setState(() {
          isLoading = false;
          uploadStatus = '';
          uploadProgress = 0.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6E7D8),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Upload Food',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Image picker + upload image
                GestureDetector(
                  onTap: isLoading ? null : pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: imageBytes != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(imageBytes!, fit: BoxFit.cover),
                    )
                        : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text("Tap to upload image", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (uploadStatus.isNotEmpty && !isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      uploadStatus,
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 20),

                //food name
                TextField(
                  controller: foodName,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: "Food Name *",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                //description
                TextField(
                  controller: description,
                  enabled: !isLoading,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Description *",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                //pickup date
                const Text("Pickup Date *", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : () async {
                    DateTime? d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => pickupDate = d);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(pickupDate == null ? "Select Date" : pickupDate!.toString().split(" ")[0]),
                ),
                const SizedBox(height: 16),

                // pickup time
                const Text("Pickup Time *", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : () async {
                          TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (t != null) setState(() => pickupStart = t);
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(pickupStart == null ? "Start" : formatTime(pickupStart!)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : () async {
                          TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (t != null) setState(() => pickupEnd = t);
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(pickupEnd == null ? "End" : formatTime(pickupEnd!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                //dropdown location
                const Text("Location *", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: pickupLocation,
                  decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                  items: locations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: isLoading ? null : (v) => setState(() => pickupLocation = v!),
                ),
                const SizedBox(height: 12),

                //exact location
                TextField(
                  controller: exactLocation,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: "Exact Location *",
                    hintText: "e.g., m2-01-01, Guard house",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                //halal
                SwitchListTile(
                  title: const Text("Halal"),
                  value: isHalal,
                  onChanged: isLoading ? null : (v) => setState(() => isHalal = v),
                  activeColor: const Color(0xFF8F1402),
                ),

                //Quantity
                ListTile(
                  title: const Text("Quantity"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: isLoading || quantity <= 1 ? null : () => setState(() => quantity--),
                      ),
                      Text(quantity.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: isLoading ? null : () => setState(() => quantity++),
                      ),
                    ],
                  ),
                ),

                //expiry option
                const Divider(),
                const Text("Expiry Option", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                RadioListTile<String>(
                  title: const Text("Today"),
                  value: "none",
                  groupValue: expiryType,
                  onChanged: isLoading ? null : (v) => setState(() => expiryType = v!),
                ),

                RadioListTile<String>(
                  title: const Text("Specific Date"),
                  value: "date",
                  groupValue: expiryType,
                  onChanged: isLoading ? null : (v) => setState(() => expiryType = v!),
                ),
                if (expiryType == "date")
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: OutlinedButton(
                      onPressed: isLoading ? null : () async {
                        DateTime? d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(), // now.subtract(Duration(days: 365 * 10)),  // 10 years ago // DateTime(2020, 1, 1),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035), // now.add(Duration(days: 365 * 20)),        // 20 years future //  DateTime(2030, 12, 31), change datepicker-8
                        );
                        if (d != null) setState(() => expiryDate = d);
                      },
                      child: Text(expiryDate == null ? "Select Date" : expiryDate.toString().split(" ")[0]),
                    ),
                  ),

                RadioListTile<String>(
                  title: const Text("Hours from now"),
                  value: "hours",
                  groupValue: expiryType,
                  onChanged: isLoading ? null : (v) => setState(() => expiryType = v!),
                ),
                if (expiryType == "hours")
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: TextField(
                      controller: expiryHours,
                      enabled: !isLoading,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Hours", filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                    ),
                  ),

                RadioListTile<String>(
                  title: const Text("Days from now"),
                  value: "days",
                  groupValue: expiryType,
                  onChanged: isLoading ? null : (v) => setState(() => expiryType = v!),
                ),
                if (expiryType == "days")
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: TextField(
                      controller: expiryDays,
                      enabled: !isLoading,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Days", filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                    ),
                  ),

                // upload button
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8F1402),
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: isLoading ? null : uploadFood,
                    child: const Text("Upload Food", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Loading overlay progress
          if (isLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF8F1402)),
                        const SizedBox(height: 24),
                        Text(
                          uploadStatus,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        if (uploadProgress > 0) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 220,
                            child: LinearProgressIndicator(
                              value: uploadProgress,
                              backgroundColor: Colors.grey[300],
                              color: const Color(0xFF8F1402),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('${(uploadProgress * 100).toInt()}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}