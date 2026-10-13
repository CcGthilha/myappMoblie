import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/restaurant.dart';

/// ไฟล์ฐานข้อมูล (Firestore) — แทน DatabaseHelper (SQLite) เดิม
/// ทุกข้อมูลผูกกับ userId ของผู้ใช้ที่ล็อกอินอยู่
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('restaurants');

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบก่อน');
    return user.uid;
  }

  // ---------- READ (Realtime) : เฉพาะของตัวเอง ----------
  // เรียงลำดับฝั่งแอปแทน orderBy เพื่อไม่ต้องสร้าง Composite Index
  Stream<List<Restaurant>> watchMine() {
    return _col.where('userId', isEqualTo: _uid).snapshots().map((snap) {
      final list = snap.docs.map(Restaurant.fromDoc).toList();
      list.sort((a, b) {
        final ta = a.createdAt ?? DateTime.now();
        final tb = b.createdAt ?? DateTime.now();
        return tb.compareTo(ta); // ใหม่สุดขึ้นก่อน
      });
      return list;
    });
  }

  // ---------- CREATE : เพิ่มพร้อม userId ----------
  Future<void> insert(Restaurant r) async {
    await _col.add({
      'userId': _uid,
      'name': r.name,
      'category': r.category,
      'review': r.review,
      'rating': r.rating,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- UPDATE ----------
  Future<void> update(Restaurant r) async {
    if (r.id == null) return;
    await _col.doc(r.id).update({
      'name': r.name,
      'category': r.category,
      'review': r.review,
      'rating': r.rating,
    });
  }

  // ---------- DELETE ----------
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}