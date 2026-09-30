import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_NotifItem> _notifications = [
    _NotifItem(
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
      title: 'Complaint Resolved',
      body: 'Your complaint C-ABC123 has been resolved by the assigned officer.',
      time: '2 hours ago',
      isRead: false,
    ),
    _NotifItem(
      icon: Icons.assignment_ind_rounded,
      color: AppColors.statusAssigned,
      title: 'Officer Assigned',
      body: 'An officer has been assigned to your complaint C-DEF456.',
      time: '1 day ago',
      isRead: false,
    ),
    _NotifItem(
      icon: Icons.pending_actions_rounded,
      color: AppColors.statusInProgress,
      title: 'Work In Progress',
      body: 'The field team has started working on your reported issue.',
      time: '2 days ago',
      isRead: true,
    ),
    _NotifItem(
      icon: Icons.info_outline_rounded,
      color: AppColors.primary,
      title: 'Complaint Received',
      body: 'Your complaint has been successfully submitted and is under review.',
      time: '3 days ago',
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: GradientAppBar(
        title: 'Notifications',
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (final n in _notifications) n.isRead = true;
              });
            },
            child: Text('Mark all read',
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.notifications_off_outlined,
              title: 'No Notifications',
              subtitle: 'You\'re all caught up! Check back later for updates on your complaints.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final notif = _notifications[i];
                return Dismissible(
                  key: Key('notif_$i'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  ),
                  onDismissed: (_) => setState(() => _notifications.removeAt(i)),
                  child: GestureDetector(
                    onTap: () => setState(() => notif.isRead = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: notif.isRead ? Colors.white : AppColors.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: notif.isRead ? AppColors.borderColor : AppColors.primary.withValues(alpha: 0.2),
                        ),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: notif.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(notif.icon, color: notif.color, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(notif.title,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        )),
                                  ),
                                  if (!notif.isRead)
                                    Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                    ),
                                ]),
                                const SizedBox(height: 4),
                                Text(notif.body,
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                                const SizedBox(height: 6),
                                Text(notif.time,
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NotifItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  bool isRead;

  _NotifItem({required this.icon, required this.color, required this.title, required this.body, required this.time, required this.isRead});
}
