# 💡 نصائح سريعة لتجنب مشاكل تحميل البيانات

## 🎯 أفضل الممارسات في Flutter:

### 1. استخدم `RefreshIndicator` دائماً لـ API data
```dart
✅ صحيح:
RefreshIndicator(
  onRefresh: _refresh,
  child: FutureBuilder(...),
)

❌ خطأ:
FutureBuilder(...)  // بدون RefreshIndicator
```

### 2. معالجة الأخطاء الكاملة
```dart
✅ صحيح:
try {
  final data = await apiCall();
  if (mounted) setState(() { ... });
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'))
    );
  }
}

❌ خطأ:
final data = await apiCall();  // بدون try-catch
setState(() { ... });  // بدون mounted check
```

### 3. التحقق من `mounted` دائماً
```dart
✅ صحيح:
Future<void> _load() async {
  final data = await apiCall();
  if (mounted) setState(() { ... });  // ✅
}

❌ خطأ:
Future<void> _load() async {
  final data = await apiCall();
  setState(() { ... });  // ❌ قد يفشل
}
```

### 4. استخدم `late` بحذر
```dart
✅ صحيح:
late Future<Data> _dataFuture;

@override
void initState() {
  _dataFuture = _loadData();
  _dataFuture.catch(print);  // معالجة أخطاء
}

❌ خطأ:
late Future<Data> _dataFuture;  // بدون معالجة أخطاء
```

### 5. أضف سجلات Debug واضحة
```dart
✅ صحيح:
print('📥 جاري تحميل البيانات...');
final data = await apiCall();
print('✅ تم تحميل ${data.length} عناصر');

❌ خطأ:
final data = await apiCall();  // بدون سجلات
```

---

## 🚀 نمط الـ Stateful Widget الموصى به:

```dart
class MyTab extends StatefulWidget {
  const MyTab({super.key});

  @override
  State<MyTab> createState() => _MyTabState();
}

class _MyTabState extends State<MyTab> {
  late Future<List<Data>> _dataFuture;
  
  @override
  void initState() {
    super.initState();
    _loadData();  // ✅ استدعاء منفصل
  }

  void _loadData() {
    _dataFuture = _fetchDataSafely();
  }

  Future<List<Data>> _fetchDataSafely() async {
    try {
      print('📥 جاري التحميل...');
      final data = await ApiService.fetchData();
      print('✅ تم التحميل: ${data.length} عناصر');
      return data;
    } catch (e) {
      print('❌ خطأ: $e');
      rethrow;  // ✅ لـ FutureBuilder يعالجه
    }
  }

  Future<void> _refresh() async {
    setState(() => _loadData());
    await _dataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Data>>(
        future: _dataFuture,
        builder: (ctx, snapshot) {
          // ✅ معالجة جميع الحالات
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('خطأ: ${snapshot.error}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: Text('إعادة محاولة'),
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('لا توجد بيانات'),
            );
          }
          
          // ✅ عرض البيانات
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (ctx, index) {
              return _buildItem(snapshot.data![index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildItem(Data item) {
    // عرض العنصر
    return Text(item.toString());
  }
}
```

---

## 🧠 الذاكرة والتنظيف:

```dart
✅ صحيح - نظف الموارد:
class MyTab extends StatefulWidget {
  const MyTab({super.key});

  @override
  State<MyTab> createState() => _MyTabState();
}

class _MyTabState extends State<MyTab> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();  // ✅ تنظيف
    super.dispose();
  }

  void _onScroll() { ... }
}

❌ خطأ - تسرب موارد:
// بدون dispose
```

---

## 🔧 حل مشاكل شائعة:

### المشكلة: "The Future is already completed"
```dart
❌ خطأ:
setState(() {
  _future = ApiService.fetch();
});
// إذا استدعيت هذا مرتين بسرعة!

✅ حل:
void _refresh() {
  setState(() {
    _loadData();  // استدعاء الدالة مرة واحدة
  });
}

void _loadData() {
  _future = ApiService.fetch();
}
```

### المشكلة: "setState called after dispose"
```dart
❌ خطأ:
Future<void> _load() async {
  final data = await apiCall();
  setState(() { ... });  // قد يكون Widget معطلاً
}

✅ حل:
Future<void> _load() async {
  final data = await apiCall();
  if (mounted) setState(() { ... });  // ✅ تحقق أولاً
}
```

### المشكلة: "No data appears until I logout/login"
```dart
❌ السبب:
- بدون RefreshIndicator
- بدون معالجة أخطاء
- Future لم يُحدّث

✅ الحل:
- أضف RefreshIndicator
- أضف try-catch
- أضف _refresh() method
```

---

## 📋 Checklist قبل Deploy:

- [ ] جميع API calls لديها try-catch
- [ ] جميع setState لديها mounted check
- [ ] جميع data lists لديها RefreshIndicator
- [ ] جميع controllers لديها dispose
- [ ] Error messages واضحة للمستخدم
- [ ] اختبرت بدون إنترنت
- [ ] اختبرت مع تأخير الشبكة
- [ ] لا توجد logs في الـ Production

---

## 🎯 الخلاصة:

**تذكّر دائماً:**
1. Wrap API calls في try-catch
2. Check mounted قبل setState
3. استخدم RefreshIndicator للـ Future data
4. عرّض أخطاء واضحة
5. نظّف الموارد في dispose
6. اختبر الحالات التي تفشل
