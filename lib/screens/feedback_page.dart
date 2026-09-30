import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:complaint_system/models/complaint_model.dart';
import 'package:complaint_system/services/user_collection_bridge.dart';
import '../services/app_localizations.dart';

class FeedbackPage extends StatefulWidget {
  final Complaint complaint;

  const FeedbackPage({super.key, required this.complaint});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {

  double selectedPoints = 0;
  final UserCollectionBridge _userBridge = UserCollectionBridge();
  final TextEditingController feedbackController =
  TextEditingController();

  double convertPointsToRating(double points) {
    return points / 20; // 100 → 5 star
  }

  Future<void> submitFeedback() async {
    double rating = convertPointsToRating(selectedPoints);

    // ✅ Update Complaint
    await FirebaseFirestore.instance
        .collection('complaints')
        .doc(widget.complaint.complaintId)
        .update({
      'rating': rating,
      'feedback': feedbackController.text,
      'pointsGiven': selectedPoints,
    });

    // ✅ Update Official Rating
    final officialDoc = await _userBridge.findUserByEmail(widget.complaint.assignedTo);

    if (officialDoc != null) {
      final doc = officialDoc;

      double currentRating =
      (doc['averageRating'] ?? 0).toDouble();
      int totalReviews =
      (doc['totalReviews'] ?? 0);

      double newAverage =
          ((currentRating * totalReviews) + rating) /
              (totalReviews + 1);

      await doc.reference.update({
        'averageRating': newAverage,
        'totalReviews': totalReviews + 1,
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)?.translate('give_feedback') ?? "Give Feedback")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            const Text("Give Points (0-100)",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),

            const SizedBox(height: 20),

            Slider(
              value: selectedPoints,
              min: 0,
              max: 100,
              divisions: 20,
              label: selectedPoints.round().toString(),
              onChanged: (value) {
                setState(() {
                  selectedPoints = value;
                });
              },
            ),

            Text(
              "Rating: ${convertPointsToRating(selectedPoints).toStringAsFixed(1)} ⭐",
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Write feedback",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: selectedPoints == 0
                  ? null
                  : submitFeedback,
              child: Text(AppLocalizations.of(context)?.translate('submit') ?? "Submit"),
            ),
          ],
        ),
      ),
    );
  }
}