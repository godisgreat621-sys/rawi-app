import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_first_app/view_models/auth_view_model.dart';
import 'package:my_first_app/providers/theme_provider.dart';
import 'package:my_first_app/repositories/user_repository.dart';
import 'admin_screen.dart';
import 'package:my_first_app/providers/novels_provider.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  // دالة لاختيار ورفع الصورة باستخدام المستودع الذي أنشأناه
  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploading = true);
    try {
      final url = await UserRepository.uploadProfilePicture();
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث الصورة الشخصية بنجاح ✅', style: GoogleFonts.cairo()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الرفع ❌', style: GoogleFonts.cairo()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // نافذة تعديل الاسم
  void _showEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل الاسم', style: GoogleFonts.cairo()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "أدخل اسمك الجديد", hintStyle: GoogleFonts.cairo()),
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo())),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await UserRepository.updateDisplayName(controller.text.trim());
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  // نافذة الدعم الفني
  void _showSupportDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'مشكلة تقنية';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الدعم الفني 🎧', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: ['مشكلة تقنية', 'اقتراح', 'استفسار عن النقاط', 'أخرى']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.cairo())))
                  .toList(),
              onChanged: (v) => selectedType = v!,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleController,
              decoration: InputDecoration(hintText: "عنوان المشكلة", hintStyle: GoogleFonts.cairo(), border: const OutlineInputBorder()),
              style: GoogleFonts.cairo(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: InputDecoration(hintText: "اشرح لنا بالتفصيل...", hintStyle: GoogleFonts.cairo(), border: const OutlineInputBorder()),
              style: GoogleFonts.cairo(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await context.read<NovelsProvider>().sendSupportRequest(
                    title: titleController.text,
                    type: selectedType,
                    description: descController.text,
                  );
                  if (mounted) Navigator.pop(ctx);
                },
                child: Text('إرسال الطلب', style: GoogleFonts.cairo()),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    if (user == null) return const Scaffold(body: Center(child: Text('يرجى تسجيل الدخول')));

    return Scaffold(
      appBar: AppBar(
        title: Text('ملفي الشخصي', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final name = userData?['displayName'] ?? 'مستخدم';
          final email = userData?['email'] ?? '';
          final profilePic = userData?['profilePicture'];
          final points = userData?['points'] ?? 0;
          final role = userData?['role'] ?? 'user';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // عرض الصورة الشخصية مع زر الكاميرا للرفع
                Center(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.colorScheme.primary, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 65,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                          child: profilePic == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '؟',
                                  style: GoogleFonts.cairo(fontSize: 45, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                )
                              : null,
                        ),
                      ),
                      if (_isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          radius: 20,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                            onPressed: _isUploading ? null : _pickAndUploadImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(name, style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(email, style: GoogleFonts.cairo(color: Colors.grey)),
                const SizedBox(height: 15),
                
                // --- نظام النقاط المستعاد ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, color: theme.colorScheme.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '$points نقطة',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                _buildMenuTile(Icons.person_outline, 'تعديل البيانات', () => _showEditNameDialog(name)),
                if (role == 'admin')
                  _buildMenuTile(Icons.admin_panel_settings_outlined, 'لوحة الإدارة', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
                  }),
                _buildMenuTile(Icons.help_outline, 'الدعم الفني', _showSupportDialog),
                _buildMenuTile(Icons.info_outline, 'عن المنصة', () {
                  showAboutDialog(context: context, applicationName: "منصة راوي", applicationVersion: "1.0.0");
                }),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.read<AuthViewModel>().logout(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('تسجيل الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: GoogleFonts.cairo()),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}