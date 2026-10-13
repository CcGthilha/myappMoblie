import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // สร้างโดยคำสั่ง: flutterfire configure
import 'models/restaurant.dart';
import 'pages/login_page.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodReview',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepOrange),
      home: const AuthGate(),
    );
  }
}

// ==========================================
// ก3: AuthGate — ล็อกอินอยู่ไปหน้าข้อมูล / ไม่อยู่ไปหน้า login
// ==========================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          // ใช้ key = uid เพื่อให้สร้างหน้าใหม่ทุกครั้งที่เปลี่ยนบัญชี
          return MainPage(key: ValueKey(snapshot.data!.uid));
        }
        return const LoginPage();
      },
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
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'รีวิวของฉัน'),
          BottomNavigationBarItem(icon: Icon(Icons.travel_explore), label: 'สุ่มเมนู (API)'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'เกี่ยวกับ'),
        ],
      ),
    );
  }
}

// ==========================================
// หน้ารายการรีวิว (Firestore CRUD + Realtime)
// ==========================================
class RestaurantListPage extends StatefulWidget {
  const RestaurantListPage({super.key});

  @override
  State<RestaurantListPage> createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage> {
  late final Stream<List<Restaurant>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = DatabaseService.instance.watchMine(); // ข2, ข5
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _openForm({Restaurant? existing}) async {
    final result = await Navigator.push<Restaurant>(
      context,
      MaterialPageRoute(builder: (_) => RestaurantFormPage(restaurant: existing)),
    );
    if (result == null) return;

    try {
      if (existing == null) {
        await DatabaseService.instance.insert(result); // ข1
      } else {
        await DatabaseService.instance.update(result); // ข3
      }
    } catch (e) {
      _showMsg('บันทึกไม่สำเร็จ: $e', error: true);
    }
  }

  Future<void> _confirmDelete(Restaurant r) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบรีวิวร้าน "${r.name}" ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบข้อมูล'),
          ),
        ],
      ),
    );

    if (ok == true && r.id != null) {
      try {
        await DatabaseService.instance.delete(r.id!); // ข4
      } catch (e) {
        _showMsg('ลบไม่สำเร็จ: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodReview: รีวิวร้านอาหาร'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () => AuthService.instance.logout(),
          ),
        ],
      ),
      body: StreamBuilder<List<Restaurant>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          if (list.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final item = list[i];
              return Card(
                elevation: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.restaurant,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('[${item.category}] ${item.review}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(item.rating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
              child: Icon(Icons.restaurant_outlined,
                  size: 72, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 20),
            const Text('ยังไม่มีรีวิวร้านอาหาร',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
// หน้าสุ่มเมนูอาหาร (API + บันทึกลง Firestore)
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

  void _fetchNewMeal() {
    setState(() {
      _mealFuture = ApiService.instance.fetchRandomMeal();
    });
  }

  Future<void> _saveToDb(MealSuggestion meal) async {
    final shortDesc = meal.instructions.length > 70
        ? '${meal.instructions.substring(0, 70)}...'
        : meal.instructions;

    try {
      await DatabaseService.instance.insert(Restaurant(
        name: meal.name,
        category: 'อื่นๆ',
        review: 'เมนูแนะนำจากเน็ต: $shortDesc',
        rating: 5.0,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึก "${meal.name}" ลงในหน้ารีวิวแล้ว!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $e'), backgroundColor: Colors.red),
      );
    }
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

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 72, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text('ไม่สามารถเชื่อมต่อได้',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    Text(meal.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Divider(height: 28),
                    const Text('คำแนะนำ/วิธีการปรุงโดยย่อ:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      meal.instructions,
                      style: TextStyle(color: Colors.grey.shade800, height: 1.4),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.bookmark_add),
                        label: const Text('บันทึกเมนูนี้เป็นร้านที่อยากลอง (ลง Firestore)'),
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
// ฟอร์มเพิ่ม/แก้ไขรีวิว
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
    if (!categories.contains(_category)) _category = 'อื่นๆ';
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
      appBar: AppBar(title: Text(isEditing ? 'แก้ไขรีวิว' : 'เพิ่มรีวิวร้านอาหาร')),
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
                      Text(_rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text(' / 5.0', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              Slider(
                value: _rating.clamp(1.0, 5.0),
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
                  label: Text(isEditing ? 'บันทึกการแก้ไข' : 'บันทึกข้อมูล',
                      style: const TextStyle(fontSize: 16)),
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
// หน้าเกี่ยวกับ (แสดงอีเมลผู้ใช้ + ออกจากระบบ + API ตัวที่ 2)
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
    final email = AuthService.instance.currentUser?.email ?? '-';
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
              const Text('FoodReview',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('แอปบันทึกรีวิวร้านอาหารส่วนตัว'),
              const SizedBox(height: 4),
              const Text('สร้างโดย นางสาวช่อทิพย์ ลือจันดา'),
              const Text('รหัสนักศึกษา 67011212113'),
              const SizedBox(height: 8),
              const Text('เวอร์ชัน 4.0 (Firebase Auth + Firestore)',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: const Text('บัญชีที่ล็อกอินอยู่'),
                  subtitle: Text(email),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('ออกจากระบบ'),
                  onPressed: () => AuthService.instance.logout(),
                ),
              ),
              const SizedBox(height: 24),
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