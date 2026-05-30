import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/providers/novels_provider.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _resolveRequest(
    BuildContext context,
    String requestId,
    String status,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final adminName = userDoc.data()?['displayName'] ?? user.email ?? 'الأدمن';

    await context.read<NovelsProvider>().resolveSupportRequest(
          requestId,
          status,
          'تم ${status == 'approved' ? 'الموافقة' : 'الرفض'} من قبل الأدمن $adminName.',
          user.uid,
          adminName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة الأدمن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
      ),
      body: user == null
          ? Center(child: Text('يجب تسجيل الدخول للوصول إلى لوحة الأدمن.', style: GoogleFonts.cairo(color: Colors.grey)))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data() as Map<String, dynamic>?;
                final isAdmin = userData != null && userData['role'] == 'admin';

                if (!isAdmin) {
                  return Center(
                    child: Text('هذه الصفحة مخصصة للمشرفين فقط.', style: GoogleFonts.cairo(color: Colors.grey)),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('support_requests')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text('لا توجد طلبات دعم حالياً.', style: GoogleFonts.cairo(color: Colors.grey)),
                      );
                    }

                    final requests = snapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final doc = requests[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'] ?? 'pending';
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      data['title'] ?? 'طلب دعم',
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      status == 'pending'
                                          ? 'قيد الانتظار'
                                          : status == 'approved'
                                              ? 'تم الموافقة'
                                              : 'مرفوض',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        color: status == 'approved'
                                            ? Colors.green
                                            : status == 'rejected'
                                                ? Colors.redAccent
                                                : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('النوع: ${data['type'] ?? 'عام'}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Text(data['description'] ?? '', style: GoogleFonts.cairo(fontSize: 14)),
                                const SizedBox(height: 10),
                                Text('الكاتب: ${data['authorName'] ?? data['authorEmail'] ?? 'مستخدم'}',
                                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 12),
                                if (status == 'pending')
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _resolveRequest(context, doc.id, 'approved'),
                                          child: Text('الموافقة', style: GoogleFonts.cairo()),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                                          onPressed: () => _resolveRequest(context, doc.id, 'rejected'),
                                          child: Text('الرفض', style: GoogleFonts.cairo()),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (status != 'pending') ...[
                                  Text('الرد: ${data['response'] ?? '—'}', style: GoogleFonts.cairo(fontSize: 13, color: Colors.black87)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
