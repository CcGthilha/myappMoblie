import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() => runApp(const MyApp());

const categories = ['ก๋วยเตี๋ยว', 'อีสาน', 'ชาบู/ปิ้งย่าง', 'คาเฟ่/ของหวาน', 'ข้าวราดแกง', 'อื่นๆ'];

// แม่พิมพ์ร้านอาหาร
class Restaurant {
  int? id;
  String name, category, review;
  double rating; // 0-5
  Restaurant({
    this.id,
    required this.name,
    required this.category,
    required this.review,
    required this.rating,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'review': review,
        'rating': rating,
      };

  factory Restaurant.fromMap(Map<String, dynamic> m) => Restaurant(
        id: m['id'] as int?,
        name: m['name'] as String,
        category: m['category'] as String,
        review: m['review'] as String,
        rating: m['rating'] as double,
      );
}

// จัดการ SQLite แยกออกมาเป็นคลาสของตัวเอง
class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();
  Database? _db;

  Future<Database> get db async => _db ??= await _init();

  Future<Database> _init() async {
    final path = p.join(await getDatabasesPath(), 'foodreview.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) => db.execute('''
        CREATE TABLE restaurants(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT, category TEXT, review TEXT, rating REAL
        )
      '''),
    );
  }

  Future<int> insert(Restaurant r) async =>
      (await db).insert('restaurants', r.toMap()..remove('id'));

  Future<List<Restaurant>> getAll() async =>
      (await (await db).query('restaurants')).map(Restaurant.fromMap).toList();

  Future<int> update(Restaurant r) async =>
      (await db).update('restaurants', r.toMap(), where: 'id = ?', whereArgs: [r.id]);

  Future<int> delete(int id) async =>
      (await db).delete('restaurants', where: 'id = ?', whereArgs: [id]);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodReview',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
      home: const MainPage(),
    );
  }
}

// หน้าหลัก ควบคุมเมนูล่าง
class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [const RestaurantListPage(), const AboutPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: 'รีวิว'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'เกี่ยวกับ'),
        ],
      ),
    );
  }
}

// หน้าเกี่ยวกับ (ไม่แก้ไขจากเดิม)
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เกี่ยวกับ')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.deepOrange,
                child: Icon(Icons.restaurant, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text('FoodReview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('แอปรีวิวร้านอาหารส่วนตัว'),
              const SizedBox(height: 4),
              const Text('สร้างโดย นางสาวช่อทิพย์ ลือจันดา'),
              const Text('รหัสนักศึกษา 67011212113'),
              const SizedBox(height: 16),
              const Text('เวอร์ชัน 1.0', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// หน้ารายการร้านอาหาร — ตอนนี้เป็น StatefulWidget + โหลด/บันทึกผ่าน SQLite
class RestaurantListPage extends StatefulWidget {
  const RestaurantListPage({super.key});
  @override
  State<RestaurantListPage> createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage> {
  List<Restaurant> restaurants = [];
  final colors = [Colors.deepOrange, Colors.teal, Colors.purple, Colors.pink, Colors.green];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getAll();
    setState(() => restaurants = data);
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
    _load();
  }

  Future<void> _delete(Restaurant r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบร้านนี้?'),
        content: Text('ต้องการลบ "${r.name}" ใช่หรือไม่'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.delete(r.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รีวิวร้านอาหารของฉัน')),
      body: restaurants.isEmpty
          ? const Center(
              child: Text('ยังไม่มีรีวิว กดปุ่ม + เพื่อเพิ่มร้านแรก',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          : ListView.builder(
              itemCount: restaurants.length,
              itemBuilder: (context, i) {
                final r = restaurants[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Icon(Icons.restaurant, color: colors[i % colors.length]),
                    title: Text(r.name),
                    subtitle: Text('${r.category} • ${r.review}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        Text(r.rating.toString()),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _delete(r),
                        ),
                      ],
                    ),
                    onTap: () => _openForm(existing: r),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ฟอร์มเพิ่ม/แก้ไขรีวิว
class RestaurantFormPage extends StatefulWidget {
  final Restaurant? restaurant;
  const RestaurantFormPage({super.key, this.restaurant});
  @override
  State<RestaurantFormPage> createState() => _RestaurantFormPageState();
}

class _RestaurantFormPageState extends State<RestaurantFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.restaurant?.name);
  late final _reviewCtrl = TextEditingController(text: widget.restaurant?.review);
  late String _category = widget.restaurant?.category ?? categories.first;
  late double _rating = widget.restaurant?.rating ?? 3.0;

  @override
  Widget build(BuildContext context) {
    final editing = widget.restaurant != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'แก้ไขรีวิว' : 'เพิ่มรีวิว')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'ชื่อร้าน'),
                validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อร้าน' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reviewCtrl,
                decoration: const InputDecoration(labelText: 'รีวิว'),
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกรีวิว' : null,
              ),
              const SizedBox(height: 16),
              Text('คะแนน: ${_rating.toStringAsFixed(1)}'),
              Slider(
                value: _rating,
                min: 0,
                max: 5,
                divisions: 10,
                label: _rating.toStringAsFixed(1),
                onChanged: (v) => setState(() => _rating = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    Restaurant(
                      id: widget.restaurant?.id,
                      name: _nameCtrl.text.trim(),
                      category: _category,
                      review: _reviewCtrl.text.trim(),
                      rating: _rating,
                    ),
                  );
                },
                child: Text(editing ? 'บันทึก' : 'เพิ่ม'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}