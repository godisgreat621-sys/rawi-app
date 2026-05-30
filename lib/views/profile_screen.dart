import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/view_models/auth_view_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    final user = authViewModel.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 30),

              // صورة الملف الشخصي
              CircleAvatar(
                radius: 50,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                child: Icon(Icons.person, size: 50, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 16),

              // البريد الإلكتروني الحقيقي
              Text(
                user?.email ?? 'زائر',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'عضو في منصة راوي ✍️',
                style: GoogleFonts.cairo(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // إعدادات
              _buildMenuItem(
                context,
                icon: Icons.book_outlined,
                label: 'رواياتي',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.favorite_outline,
                label: 'المفضلة',
                onTap: () {},
              ),
              _buildMenuItem(
                context,
                icon: Icons.settings_outlined,
                label: 'الإعدادات',
                onTap: () {},
              ),

              const Spacer(),

              // زر تسجيل الخروج
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => authViewModel.logout(),
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: Text(
                    'تسجيل الخروج',
                    style: GoogleFonts.cairo(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: GoogleFonts.cairo()),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}