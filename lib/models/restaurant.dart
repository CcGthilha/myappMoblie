import 'package:cloud_firestore/cloud_firestore.dart';

// หมวดหมู่อาหารสำหรับ Dropdown
const List<String> categories = [
  'ก๋วยเตี๋ยว',
  'อีสาน',
  'ชาบู/ปิ้งย่าง',
  'คาเฟ่/ของหวาน',
  'ข้าวราดแกง',
  'อาหารตามสั่ง',
  'อื่นๆ',
];

// Model ร้านอาหาร (Firestore) — id เป็น String (document id)
class Restaurant {
  String? id;
  String userId;
  String name;
  String category;
  String review;
  double rating;
  DateTime? createdAt;

  Restaurant({
    this.id,
    this.userId = '',
    required this.name,
    required this.category,
    required this.review,
    required this.rating,
    this.createdAt,
  });

  factory Restaurant.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Restaurant(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      name: d['name'] as String? ?? '',
      category: d['category'] as String? ?? 'อื่นๆ',
      review: d['review'] as String? ?? '',
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

// Model สำหรับเมนูอาหารจาก API (TheMealDB)
class MealSuggestion {
  final String id;
  final String name;
  final String category;
  final String instructions;

  MealSuggestion({
    required this.id,
    required this.name,
    required this.category,
    required this.instructions,
  });

  factory MealSuggestion.fromJson(Map<String, dynamic> json) {
    return MealSuggestion(
      id: json['idMeal']?.toString() ?? '',
      name: json['strMeal']?.toString() ?? 'ไม่ระบุชื่อเมนู',
      category: json['strCategory']?.toString() ?? 'อาหารทั่วไป',
      instructions: json['strInstructions']?.toString() ?? 'ไม่มีรายละเอียด',
    );
  }
}