import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditFoodScreen extends StatefulWidget {
  final String foodId;

  const EditFoodScreen({Key? key, required this.foodId}) : super(key: key);

  @override
  State<EditFoodScreen> createState() => _EditFoodScreenState();
}

class _EditFoodScreenState extends State<EditFoodScreen> {
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

  String existingImageUrl = '';
  bool isLoading = false;
  bool imageChanged = false;
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

  @override
  void initState() {
    super.initState();
    _loadFoodData();
  }

  //Loads existing food data from Firestore
  Future<void> _loadFoodData() async {
    final doc = await FirebaseFirestore.instance
        .collection('foods')
        .doc(widget.foodId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    setState(() {
      foodName.text = data['foodName'] ?? '';
      description.text = data['description'] ?? '';
      exactLocation.text = data['exactLocation'] ?? '';
      pickupLocation = data['pickupLocation'] ?? 'Murni';
      isHalal = data['isHalal'] ?? false;
      quantity = data['quantity'] ?? 1;
      existingImageUrl = data['imageUrl'] ?? '';

      // Parse pickup date
      if (data['pickupDate'] != null) {
        pickupDate = (data['pickupDate'] as Timestamp).toDate();
      }

      // Parse time range
      final timeRange = data['pickupTimeRange'] ?? '';
      if (timeRange.isNotEmpty) {
        final parts = timeRange.split(' - ');
        if (parts.length == 2) {
          final start = parts[0].split(':');
          final end = parts[1].split(':');
          pickupStart = TimeOfDay(
            hour: int.parse(start[0]),
            minute: int.parse(start[1]),
          );
          pickupEnd = TimeOfDay(
            hour: int.parse(end[0]),
            minute: int.parse(end[1]),
          );
        }
      }

      // Parse expiry
      final expiry = data['expiryOption'] as Map<String, dynamic>?;
      if (expiry != null) {
        expiryType = expiry['type'] ?? 'none';
        if (expiryType == 'date' && expiry['value'] != null) {
          if (expiry['value'] is Timestamp) {
            expiryDate = (expiry['value'] as Timestamp).toDate();
          }
        } else if (expiryType == 'hours') {
          expiryHours.text = expiry['value']?.toString() ?? '';
        } else if (expiryType == 'days') {
          expiryDays.text = expiry['value']?.toString() ?? '';
        }
      }
    });
  }
//pick image from gallery
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
        final compressed = await FlutterImageCompress.compressWithFile(
          img.path,
          minWidth: 800,
          minHeight: 800,
          quality: 70,
          format: CompressFormat.jpeg,
        );

        imageBytes = compressed ?? await File(img.path).readAsBytes();
      }

      pickedImage = img;
      imageChanged = true;

      // display image size
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

  Future<void> updateFood() async {
    if (foodName.text.isEmpty ||
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
      uploadStatus = 'Starting update...';
      uploadProgress = 0.0;
    });

    try {
      String imageUrl = existingImageUrl;

      // Upload new image if changed
      if (imageChanged && imageBytes != null) {
        setState(() => uploadStatus = 'Uploading image...');

        String fileName =
            "food_${DateTime.now().millisecondsSinceEpoch.toString()}.jpg";
        final storageRef =
        FirebaseStorage.instance.ref().child("foods/$fileName");

        final uploadTask = storageRef.putData(
          imageBytes!,
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'public, max-age=31536000',
          ),
        );

        // Track upload progress
        uploadTask.snapshotEvents.listen((snapshot) {
          if (mounted && snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            final percent = (progress * 100).toInt();
            setState(() {
              uploadProgress = progress;
              uploadStatus = 'Uploading: $percent%';
            });
          }
        });

        final snapshot = await uploadTask;
        setState(() => uploadStatus = 'Getting URL...');
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      setState(() => uploadStatus = 'Saving to database...');

      // Build expiry data
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

      await FirebaseFirestore.instance
          .collection("foods")
          .doc(widget.foodId)
          .update({
        "foodName": foodName.text.trim(),
        "description": description.text.trim(),
        "pickupLocation": pickupLocation,
        "exactLocation": exactLocation.text.trim(),
        "pickupDate": Timestamp.fromDate(pickupDate!),
        "pickupTimeRange":
        "${formatTime(pickupStart!)} - ${formatTime(pickupEnd!)}",
        "isHalal": isHalal,
        "quantity": quantity,
        "imageUrl": imageUrl,
        "expiryOption": expiryData,
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Food updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }

    setState(() => isLoading = false);
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Edit Food',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Image upload picker
                GestureDetector(
                  onTap: isLoading ? null : pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageBytes != null
                          ? Image.memory(imageBytes!, fit: BoxFit.cover)
                          : existingImageUrl.isNotEmpty
                          ? Image.network(existingImageUrl,
                          fit: BoxFit.cover)
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_photo_alternate,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 8),
                          Text("Tap to change image",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (uploadStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    uploadStatus,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),

                // Food Name
                const Text("Food Name *",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: foodName,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    hintText: "e.g., Nasi Lemak",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                const Text("Description *",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  enabled: !isLoading,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Describe the food...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Pickup Date
                const Text("Pickup Date *",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                    DateTime? d = await showDatePicker(
                      context: context,
                      initialDate: pickupDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => pickupDate = d);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    pickupDate == null
                        ? "Select Date"
                        : pickupDate!.toString().split(" ")[0],
                  ),
                ),
                const SizedBox(height: 16),

                // Pickup Time
                const Text("Pickup Time *",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                          TimeOfDay? t = await showTimePicker(
                            context: context,
                            initialTime: pickupStart ?? TimeOfDay.now(),
                          );
                          if (t != null) setState(() => pickupStart = t);
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(pickupStart == null
                            ? "Start"
                            : formatTime(pickupStart!)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                          TimeOfDay? t = await showTimePicker(
                            context: context,
                            initialTime: pickupEnd ?? TimeOfDay.now(),
                          );
                          if (t != null) setState(() => pickupEnd = t);
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(
                            pickupEnd == null ? "End" : formatTime(pickupEnd!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Location
                const Text("Location *",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: pickupLocation,
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  items: locations
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: isLoading ? null : (v) => setState(() => pickupLocation = v!),
                ),
                const SizedBox(height: 12),

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

                // Halal Switch
                SwitchListTile(
                  title: const Text("Halal"),
                  value: isHalal,
                  onChanged: isLoading ? null : (v) => setState(() => isHalal = v),
                  activeColor: const Color(0xFF8F1402),
                ),

                // Quantity
                ListTile(
                  title: const Text("Quantity"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: isLoading || quantity <= 1
                            ? null
                            : () => setState(() => quantity--),
                      ),
                      Text(quantity.toString(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: isLoading ? null : () => setState(() => quantity++),
                      ),
                    ],
                  ),
                ),

                // expiry option
                const Divider(),
                const Text("Expiry Option",
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

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
                      onPressed: isLoading
                          ? null
                          : () async {
                        DateTime? d = await showDatePicker(
                          context: context,
                          initialDate: expiryDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );
                        if (d != null) setState(() => expiryDate = d);
                      },
                      child: Text(expiryDate == null
                          ? "Select Date"
                          : expiryDate.toString().split(" ")[0]),
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
                      decoration: const InputDecoration(
                        labelText: "Hours",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
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
                      decoration: const InputDecoration(
                        labelText: "Days",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                // update food button
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8F1402),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: isLoading ? null : updateFood,
                    child: const Text(
                      "Update Food",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFF8F1402),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          uploadStatus,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                          Text(
                            '${(uploadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  @override
  void dispose() {
    foodName.dispose();
    description.dispose();
    exactLocation.dispose();
    expiryHours.dispose();
    expiryDays.dispose();
    super.dispose();
  }
}