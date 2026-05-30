import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  Future<void> _markAsRead(DocumentReference ref) async {
    await ref.update({'isRead': true});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          ? Center(
              child: Text('يجب تسجيل الدخول لعرض الإشعارات.', style: GoogleFonts.cairo(color: Colors.grey)),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text('لا توجد إشعارات جديدة.', style: GoogleFonts.cairo(color: Colors.grey)),
                  );
                }

                final notifications = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isRead = data['isRead'] == true;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      tileColor: isRead ? null : Colors.amber.withOpacity(0.08),
                      title: Text(data['title'] ?? 'تنبيه', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                      subtitle: Text(data['body'] ?? '', style: GoogleFonts.cairo()),
                      trailing: Text(
                        data['createdAt'] != null
                            ? _formatTimestamp(data['createdAt'])
                            : '',
                        style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey),
                      ),
                      onTap: () {
                        if (!isRead) _markAsRead(doc.reference);
                      },
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
      return '${date.day}/${date.month}/${date.year}';
    }
    return '';
  }
}
