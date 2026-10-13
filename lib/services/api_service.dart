import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/restaurant.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // API ตัวที่ 1: สุ่มเมนูอาหารจาก TheMealDB
  Future<MealSuggestion> fetchRandomMeal() async {
    final url = Uri.parse('https://www.themealdb.com/api/json/v1/1/random.php');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List meals = data['meals'];
        if (meals.isNotEmpty) {
          return MealSuggestion.fromJson(meals[0]);
        } else {
          throw Exception('ไม่พบข้อมูลเมนูอาหาร');
        }
      } else {
        throw Exception('เซิร์ฟเวอร์ตอบกลับผิดพลาด (${response.statusCode})');
      }
    } on SocketException {
      throw Exception('ไม่สามารถเชื่อมต่อเน็ตได้ กรุณาตรวจสอบสัญญาณอินเทอร์เน็ต');
    } on TimeoutException {
      throw Exception('การเชื่อมต่อหมดเวลา (Timeout) กรุณาลองใหม่อีกครั้ง');
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // API ตัวที่ 2 (โบนัส): คำคม
  Future<String> fetchDailyQuote() async {
    const fallback = '"อาหารที่ดี คือจุดเริ่มต้นของความสุขในทุกๆ วัน"';
    final url = Uri.parse('https://api.quotable.io/random');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        return '"${data['content']}"\n— ${data['author']}';
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}