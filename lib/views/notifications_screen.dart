import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('الإشعارات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'وضع الكل كمقروء',
              onPressed: () => _markAllRead(user.uid),
            ),
        ],
      ),
      body: user == null
          ? Center(child: Text('يجب تسجيل الدخول لعرض الإشعارات.', style: GoogleFonts.cairo(color: Colors.grey)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 56, color: theme.colorScheme.primary.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text('لا توجد إشعارات.', style: GoogleFonts.cairo(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isRead = data['isRead'] == true;
                    final type = data['type'] ?? '';

                    IconData icon;
                    Color iconColor;
                    switch (type) {
                      case 'like':
                        icon = Icons.favorite;
                        iconColor = Colors.redAccent;
                        break;
                      case 'comment':
                        icon = Icons.chat_bubble_outline;
                        iconColor = Colors.blueAccent;
                        break;
                      case 'rating':
                        icon = Icons.star;
                        iconColor = Colors.amber;
                        break;
                      default:
                        icon = Icons.notifications_outlined;
                        iconColor = theme.colorScheme.primary;
                    }

                    return InkWell(
                      onTap: () {
                        if (!isRead) doc.reference.update({'isRead': true});
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isRead
                              ? theme.colorScheme.surface
                              : theme.colorScheme.primary.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRead
                                ? Colors.transparent
                                : theme.colorScheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: iconColor.withOpacity(0.12),
                              child: Icon(icon, size: 18, color: iconColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                data['message'] ?? '',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              data['createdAt'] != null ? _formatTimestamp(data['createdAt']) : '',
                              style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.day}/${date.month}';
    }
    return '';
  }
}
