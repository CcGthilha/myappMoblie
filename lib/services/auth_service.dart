import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ก1: สมัครสมาชิก
  Future<void> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_message(e.code));
    }
  }

  // ก2: เข้าสู่ระบบ
  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_message(e.code));
    }
  }

  // ก2: ออกจากระบบ
  Future<void> logout() => _auth.signOut();

  // ก4: แปลง error code เป็นข้อความที่เข้าใจง่าย
  String _message(String code) {
    switch (code) {
      case 'weak-password':
        return 'รหัสผ่านสั้นเกินไป (ต้องมีอย่างน้อย 6 ตัวอักษร)';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้สมัครแล้ว กรุณาใช้อีเมลอื่นหรือเข้าสู่ระบบ';
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'user-not-found':
        return 'ไม่พบบัญชีนี้ กรุณาสมัครสมาชิกก่อน';
      case 'wrong-password':
      case 'invalid-credential':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'user-disabled':
        return 'บัญชีนี้ถูกระงับการใช้งาน';
      case 'too-many-requests':
        return 'ลองผิดหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่';
      case 'network-request-failed':
        return 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้';
      default:
        return 'เกิดข้อผิดพลาด ($code)';
    }
  }
}