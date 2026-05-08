import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => _error = 'Kullanıcı adı ve şifre girin.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final user = await AuthService.login(u, p);
    if (!mounted) return;
    setState(() => _loading = false);
    if (user != null) {
      context.read<AppStateProvider>().setUser(user);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() => _error = 'Kullanıcı adı veya şifre hatalı!');
    }
  }

  void _quickLogin(String u, String p) {
    _userCtrl.text = u;
    _passCtrl.text = p;
    _login();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1A0505), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Brand
                  const Text('🔥', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 8),
                  const Text(
                    'FIRECOORD',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Yangın Koordinasyon ve Takip Sistemi',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 32),

                  // Login Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.08),
                          blurRadius: 40,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sisteme Giriş',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 20),

                        // Username
                        _label('KULLANICI ADI'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _userCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          onSubmitted: (_) => _login(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted, size: 18),
                            hintText: 'kullanici_adi',
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password
                        _label('ŞİFRE'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          style: const TextStyle(color: AppColors.textPrimary),
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.textMuted, size: 18,
                              ),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                            ),
                            child: Text(_error!,
                                style: const TextStyle(color: AppColors.danger, fontSize: 12),
                                textAlign: TextAlign.center),
                          ),
                        ],

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Giriş Yap →'),
                          ),
                        ),

                        // Quick Login
                        const SizedBox(height: 20),
                        Row(children: [
                          const Expanded(child: Divider(color: AppColors.border)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('HIZLI GİRİŞ',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.8)),
                          ),
                          const Expanded(child: Divider(color: AppColors.border)),
                        ]),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _quickBtn('🏢', 'Merkez', 'admin/1234', () => _quickLogin('admin', '1234')),
                            const SizedBox(width: 8),
                            _quickBtn('👨‍🚒', 'İtf. Şef', 'ahmet/1234', () => _quickLogin('ahmet', '1234')),
                            const SizedBox(width: 8),
                            _quickBtn('🧑‍🤝‍🧑', 'Ekip', 'ekip1/1234', () => _quickLogin('ekip1', '1234')),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Status bar
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statusDot(AppColors.success), const SizedBox(width: 5),
                      const Text('Sistem Aktif', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 20),
                      _statusDot(AppColors.primary), const SizedBox(width: 5),
                      const Text('2 Aktif Yangın', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 20),
                      _statusDot(AppColors.warning), const SizedBox(width: 5),
                      const Text('3 Ekip Uygun', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 0.8),
      );

  Widget _quickBtn(String icon, String role, String cred, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(role, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
              Text(cred, style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusDot(Color color) => Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
