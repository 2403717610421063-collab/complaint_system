import 'package:flutter/material.dart';
import '../services/gamification_service.dart';
import '../models/user_model.dart';
import '../services/app_localizations.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gamificationService = GamificationService();
    const primaryColor = Color(0xFF4A148C);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('leaderboard') ?? "Civic Leaderboard"),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: gamificationService.getLeaderboard(),
        builder: (context, snapshot) {

          // ERROR STATE
          if (snapshot.hasError) {
            debugPrint("❌ Leaderboard Error: ${snapshot.error}");
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.error_outline, color: Colors.red, size: 60),
                  SizedBox(height: 10),
                  Text("Error loading leaderboard"),
                ],
              ),
            );
          }

          // LOADING STATE
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint("⏳ Loading leaderboard...");
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // EMPTY STATE
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            debugPrint("⚠️ No users found for leaderboard");
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No users available yet!",
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ],
              ),
            );
          }

          // SUCCESS STATE
          final users = snapshot.data!;
          debugPrint("✅ Leaderboard loaded: ${users.length} users");

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: primaryColor.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                    SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)?.translate('top_contributors') ?? "Top Contributors",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                          _getRankColor(index, primaryColor),
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(

                          user.email,
                          style:
                          const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        subtitle: const Text("Civic Connect Member"),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${user.points} Pts",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Highlight top 3 ranks
  Color _getRankColor(int index, Color defaultColor) {
    if (index == 0) return Colors.amber; // Gold
    if (index == 1) return Colors.grey; // Silver
    if (index == 2) return Colors.brown; // Bronze
    return defaultColor;
  }
}
