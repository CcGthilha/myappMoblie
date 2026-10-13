import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// หน้าล็อกอิน/สมัครสมาชิก (สลับโหมดในหน้าเดียว)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  bool _hidePass = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await AuthService.instance.register(_emailCtrl.text, _passCtrl.text);
      } else {
        await AuthService.instance.login(_emailCtrl.text, _passCtrl.text);
      }
      // สำเร็จแล้ว AuthGate จะพาไปหน้าข้อมูลเอง
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.deepOrange,
                      child: Icon(Icons.restaurant, size: 46, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('FoodReview',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_isRegister ? 'สมัครสมาชิกใหม่' : 'เข้าสู่ระบบเพื่อดูรีวิวของคุณ',
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'อีเมล',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'กรุณากรอกอีเมล';
                        if (!v.contains('@')) return 'รูปแบบอีเมลไม่ถูกต้อง';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _hidePass,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_hidePass ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _hidePass = !_hidePass),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                        if (_isRegister && v.length < 6) {
                          return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: cs.onErrorContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: TextStyle(color: cs.onErrorContainer)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : Text(_isRegister ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                                style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _isRegister = !_isRegister;
                                _error = null;
                              }),
                      child: Text(_isRegister
                          ? 'มีบัญชีแล้ว? เข้าสู่ระบบ'
                          : 'ยังไม่มีบัญชี? สมัครสมาชิก'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}