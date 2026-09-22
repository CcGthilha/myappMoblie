import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

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

// ==========================================
// 1. Models (SQLite Model & API Model)
// ==========================================

// Model สำหรับร้านอาหาร (SQLite)
class Restaurant {
  int? id;
  String name;
  String category;
  String review;
  double rating;

  Restaurant({
    this.id,
    required this.name,
    required this.category,
    required this.review,
    required this.rating,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'category': category,
      'review': review,
      'rating': rating,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String,
      review: map['review'] as String,
      rating: (map['rating'] as num).toDouble(),
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

// ==========================================
// 2. Database Helper (SQLite)
// ==========================================
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  Future<Database> get db async => _db ??= await _init();

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'foodreview.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE restaurants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            review TEXT NOT NULL,
            rating REAL NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insert(Restaurant r) async {
    final client = await db;
    return await client.insert('restaurants', r.toMap());
  }

  Future<List<Restaurant>> getAll() async {
    final client = await db;
    final records = await client.query('restaurants', orderBy: 'id DESC');
    return records.map((item) => Restaurant.fromMap(item)).toList();
  }

  Future<int> update(Restaurant r) async {
    final client = await db;
    return await client.update(
      'restaurants',
      r.toMap(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  Future<int> delete(int id) async {
    final client = await db;
    return await client.delete(
      'restaurants',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// ==========================================
// 3. ApiService (ดึงข้อมูล API 2 ตัว + Timeout + Try-Catch)
// ==========================================
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

  // API ตัวที่ 2 (โบนัส): ดึงคำคม/เกร็ดความรู้ชวนกิน
  Future<String> fetchDailyQuote() async {
    final url = Uri.parse('https://api.quotable.io/random');
    try {
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        return '"${data['content']}"\n— ${data['author']}';
      }
      return '"อาหารที่ดี คือจุดเริ่มต้นของความสุขในทุกๆ วัน"';
    } catch (_) {
      return '"อาหารที่ดี คือจุดเริ่มต้นของความสุขในทุกๆ วัน"';
    }
  }
}

// ==========================================
// 4. App Main Widget
// ==========================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodReview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
      ),
      home: const MainPage(),
    );
  }
}

// หน้าควบคุม BottomNavigationBar 3 แท็บ
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = const [
    RestaurantListPage(),
    ExplorePage(),
    AboutPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'รีวิวของฉัน',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.travel_explore),
            label: 'สุ่มเมนู (API)',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: 'เกี่ยวกับ',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. หน้ารายการรีวิว (SQLite CRUD เดิม)
// ==========================================
class RestaurantListPage extends StatefulWidget {
  const RestaurantListPage({super.key});

  @override
  State<RestaurantListPage> createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage> {
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await DatabaseHelper.instance.getAll();
    setState(() {
      _restaurants = data;
      _isLoading = false;
    });
  }

  Future<void> _openForm({Restaurant? existing}) async {
    final result = await Navigator.push<Restaurant>(
      context,
      MaterialPageRoute(builder: (_) => RestaurantFormPage(restaurant: existing)),
    );

    if (result == null) return;

    if (existing == null) {
      await DatabaseHelper.instance.insert(result);
    } else {
      await DatabaseHelper.instance.update(result);
    }
    _loadData();
  }

  Future<void> _confirmDelete(Restaurant r) async {
    final bool? isConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรีวิวร้าน "${r.name}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบข้อมูล'),
          ),
        ],
      ),
    );

    if (isConfirm == true && r.id != null) {
      await DatabaseHelper.instance.delete(r.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodReview: รีวิวร้านอาหาร'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _restaurants.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _restaurants.length,
                  itemBuilder: (context, i) {
                    final item = _restaurants[i];
                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.restaurant,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '[${item.category}] ${item.review}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              item.rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _confirmDelete(item),
                            ),
                          ],
                        ),
                        onTap: () => _openForm(existing: item),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มร้านใหม่'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ยังไม่มีรีวิวร้านอาหาร',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'กดปุ่ม "เพิ่มร้านใหม่" หรือไปที่แท็บ "สุ่มเมนู (API)" เพื่อบันทึกเมนูแนะนำ',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. หน้าค้นหา/สุ่มเมนูอาหาร (ดึง API + FutureBuilder + บันทึกลง SQLite)
// ==========================================
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late Future<MealSuggestion> _mealFuture;

  @override
  void initState() {
    super.initState();
    _fetchNewMeal();
  }

  // รีเฟรช/ดึงข้อมูลใหม่ (เกณฑ์ ค2)
  void _fetchNewMeal() {
    setState(() {
      _mealFuture = ApiService.instance.fetchRandomMeal();
    });
  }

  // โบนัส (+1): นำข้อมูลจาก API บันทึกลง SQLite ทันที
  Future<void> _saveToDb(MealSuggestion meal) async {
    final shortDesc = meal.instructions.length > 70
        ? '${meal.instructions.substring(0, 70)}...'
        : meal.instructions;

    final newRestaurant = Restaurant(
      name: meal.name,
      category: 'อื่นๆ',
      review: 'เมนูแนะนำจากเน็ต: $shortDesc',
      rating: 5.0,
    );

    await DatabaseHelper.instance.insert(newRestaurant);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('บันทึก "${meal.name}" ลงในหน้ารีวิวแล้ว!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ไอเดียเมนูอาหาร (Online API)'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'สุ่มใหม่',
            onPressed: _fetchNewMeal,
          ),
        ],
      ),
      body: FutureBuilder<MealSuggestion>(
        future: _mealFuture,
        builder: (context, snapshot) {
          // เกณฑ์ ข1: แสดง CircularProgressIndicator ขณะโหลด
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('กำลังเชื่อมต่ออินเทอร์เน็ตเพื่อค้นหาเมนู...'),
                ],
              ),
            );
          }

          // เกณฑ์ ข2: จัดการ Error เมื่อปิดเน็ตแล้วไม่ Crash + แสดงข้อความสุภาพ
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 72, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'ไม่สามารถเชื่อมต่อได้',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _fetchNewMeal,
                      icon: const Icon(Icons.replay),
                      label: const Text('ลองใหม่อีกครั้ง'),
                    )
                  ],
                ),
              ),
            );
          }

          // เกณฑ์ ก4: นำข้อมูลจากอินเทอร์เน็ตมาแสดงจริงบนหน้าจอ
          final meal = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fastfood, color: Colors.deepOrange),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(meal.category),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      meal.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 28),
                    const Text(
                      'คำแนะนำ/วิธีการปรุงโดยย่อ:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meal.instructions,
                      style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    // ปุ่มบันทึกเข้า SQLite
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.bookmark_add),
                        label: const Text('บันทึกเมนูนี้เป็นร้านที่อยากลอง (ลง DB)'),
                        onPressed: () => _saveToDb(meal),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 7. ฟอร์มเพิ่ม/แก้ไขรีวิว (TextFormField + Dropdown + Slider)
// ==========================================
class RestaurantFormPage extends StatefulWidget {
  final Restaurant? restaurant;
  const RestaurantFormPage({super.key, this.restaurant});

  @override
  State<RestaurantFormPage> createState() => _RestaurantFormPageState();
}

class _RestaurantFormPageState extends State<RestaurantFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _reviewCtrl;
  late String _category;
  late double _rating;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.restaurant?.name ?? '');
    _reviewCtrl = TextEditingController(text: widget.restaurant?.review ?? '');
    _category = widget.restaurant?.category ?? categories.first;
    _rating = widget.restaurant?.rating ?? 4.0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.restaurant != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'แก้ไขรีวิว' : 'เพิ่มรีวิวร้านอาหาร'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'ชื่อร้านอาหาร *',
                  hintText: 'เช่น ข้าวขาหมูบางหว้า, ส้มตำป้าณี',
                  prefixIcon: Icon(Icons.storefront),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'กรุณากรอกชื่อร้านอาหาร' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'หมวดหมู่อาหาร',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reviewCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ความคิดเห็น / เมนูแนะนำ *',
                  hintText: 'เช่น คอหมูย่างนุ่มมาก น้ำจิ้มเด็ด...',
                  prefixIcon: Icon(Icons.rate_review_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'กรุณากรอกรีวิว' : null,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('คะแนนความอร่อย:', style: TextStyle(fontSize: 16)),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 24),
                      const SizedBox(width: 4),
                      Text(
                        _rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Text(' / 5.0', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              Slider(
                value: _rating,
                min: 1.0,
                max: 5.0,
                divisions: 8,
                label: _rating.toStringAsFixed(1),
                onChanged: (val) => setState(() => _rating = val),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(
                    isEditing ? 'บันทึกการแก้ไข' : 'บันทึกข้อมูล',
                    style: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;

                    final item = Restaurant(
                      id: widget.restaurant?.id,
                      name: _nameCtrl.text.trim(),
                      category: _category,
                      review: _reviewCtrl.text.trim(),
                      rating: _rating,
                    );
                    Navigator.pop(context, item);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 8. หน้าเกี่ยวกับ (ดึง API ตัวที่ 2 - แสดงข้ามหน้า)
// ==========================================
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late Future<String> _quoteFuture;

  @override
  void initState() {
    super.initState();
    _quoteFuture = ApiService.instance.fetchDailyQuote();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เกี่ยวกับ'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 46,
                backgroundColor: Colors.deepOrange,
                child: Icon(Icons.restaurant, size: 46, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'FoodReview',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('แอปบันทึกรีวิวร้านอาหารส่วนตัว'),
              const SizedBox(height: 4),
              const Text('สร้างโดย นางสาวช่อทิพย์ ลือจันดา'),
              const Text('รหัสนักศึกษา 67011212113'),
              const SizedBox(height: 8),
              const Text('เวอร์ชัน 3.0 (SQLite + Online API)', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),

              // API ตัวที่ 2 (โบนัส): ดึงข้อความ/คำคมจากอินเทอร์เน็ต
              FutureBuilder<String>(
                future: _quoteFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepOrange.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.format_quote, color: Colors.deepOrange),
                        const SizedBox(height: 4),
                        Text(
                          snapshot.data ?? 'อาหารคือความสุขที่แบ่งปันได้',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}