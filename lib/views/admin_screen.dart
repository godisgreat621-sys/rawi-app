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
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final adminName = userDoc.data()?['displayName'] ?? user.email ?? 'الأدمن';

    await context.read<NovelsProvider>().resolveSupportRequest(
      requestId,
      status,
      'تم ${status == 'approved' ? 'الموافقة' : 'الرفض'} من قبل الأدمن $adminName.',
      user.uid,
      adminName,
    );
  }

  Widget _buildSupportRequestsTab(BuildContext context) {
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
            child: Text(
              'لا توجد طلبات دعم حالياً.',
              style: GoogleFonts.cairo(color: Colors.grey),
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                    Text(
                      'النوع: ${data['type'] ?? 'عام'}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data['description'] ?? '',
                      style: GoogleFonts.cairo(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'الكاتب: ${data['authorName'] ?? data['authorEmail'] ?? 'مستخدم'}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (status == 'pending')
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _resolveRequest(context, doc.id, 'approved'),
                              child: Text(
                                'الموافقة',
                                style: GoogleFonts.cairo(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                              ),
                              onPressed: () =>
                                  _resolveRequest(context, doc.id, 'rejected'),
                              child: Text('الرفض', style: GoogleFonts.cairo()),
                            ),
                          ),
                        ],
                      ),
                    if (status != 'pending') ...[
                      Text(
                        'الرد: ${data['response'] ?? '—'}',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContentManagementTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'إدارة الروايات',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('novels')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'لا توجد روايات حتى الآن.',
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                );
              }
              final novels = snapshot.data!.docs;
              return Column(
                children: novels.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'active';
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? 'بدون عنوان',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الكاتب: ${data['authorName'] ?? data['authorEmail'] ?? 'مجهول'}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الحالة: ${status == 'active' ? 'نشطة' : 'مكتملة'}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (status == 'active')
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final error = await context
                                          .read<NovelsProvider>()
                                          .setNovelStatus(doc.id, 'completed');
                                      if (error != null && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              error,
                                              style: GoogleFonts.cairo(),
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      'وضع كمكتملة',
                                      style: GoogleFonts.cairo(),
                                    ),
                                  ),
                                ),
                              if (status != 'active')
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      final error = await context
                                          .read<NovelsProvider>()
                                          .setNovelStatus(doc.id, 'active');
                                      if (error != null && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              error,
                                              style: GoogleFonts.cairo(),
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      'إعادة تفعيل',
                                      style: GoogleFonts.cairo(),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    final error = await context
                                        .read<NovelsProvider>()
                                        .deleteNovel(doc.id);
                                    if (error != null && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            error,
                                            style: GoogleFonts.cairo(),
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'حذف الرواية',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'إدارة المؤلفين',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('displayName', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'لا توجد مستخدمين بعد.',
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                );
              }
              final users = snapshot.data!.docs;
              return Column(
                children: users.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = data['role'] ?? 'user';
                  final isActive = data['isActive'] ?? true;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['displayName'] ??
                                data['email'] ??
                                'مستخدم غير معروف',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'البريد: ${data['email'] ?? 'غير متوفر'}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الدور: ${role == 'admin' ? 'مشرف' : 'مستخدم'}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الحالة: ${isActive ? 'نشط' : 'موقوف'}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final error = await context
                                        .read<NovelsProvider>()
                                        .setUserRole(
                                          doc.id,
                                          role == 'admin' ? 'user' : 'admin',
                                        );
                                    if (error != null && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            error,
                                            style: GoogleFonts.cairo(),
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    role == 'admin'
                                        ? 'خفض إلى مستخدم'
                                        : 'ترقية لمشرف',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isActive
                                        ? Colors.redAccent
                                        : theme.colorScheme.primary,
                                  ),
                                  onPressed: () async {
                                    final error = await context
                                        .read<NovelsProvider>()
                                        .setUserActive(doc.id, !isActive);
                                    if (error != null && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            error,
                                            style: GoogleFonts.cairo(),
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'لوحة الأدمن',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'طلبات الدعم'),
              Tab(text: 'إدارة المحتوى'),
            ],
          ),
        ),
        body: user == null
            ? Center(
                child: Text(
                  'يجب تسجيل الدخول للوصول إلى لوحة الأدمن.',
                  style: GoogleFonts.cairo(color: Colors.grey),
                ),
              )
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  final userData =
                      userSnap.data?.data() as Map<String, dynamic>?;
                  final isAdmin =
                      userData != null && userData['role'] == 'admin';

                  if (!isAdmin) {
                    return Center(
                      child: Text(
                        'هذه الصفحة مخصصة للمشرفين فقط.',
                        style: GoogleFonts.cairo(color: Colors.grey),
                      ),
                    );
                  }

                  return TabBarView(
                    children: [
                      _buildSupportRequestsTab(context),
                      _buildContentManagementTab(context),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
