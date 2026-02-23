# ✅ ميزة حذف مشاهدات الإعلانات

## 📋 النظرة العامة

تمت إضافة ميزة شاملة لحذف وإدارة مشاهدات الإعلانات في لوحة تحكم المسؤول. يمكن حذف المشاهدات على المستويات التالية:

1. **حذف مشاهدة واحدة** - حذف مشاهدة مستخدم معين
2. **حذف جميع مشاهدات مستخدم** - حذف كل المشاهدات لمستخدم معين من الإعلان
3. **حذف جميع المشاهدات** - حذف جميع مشاهدات الإعلان بالكامل

---

## 🔧 التعديلات المنجزة

### 1️⃣ Backend (Node.js) - `FILE-SSH/routes/admin.js`

#### 📍 Endpoint 1: حذف مشاهدة واحدة
```
DELETE /admin/announcement-views/:viewId
```
**الوصف:** حذف مشاهدة واحدة لمستخدم معين

**المعاملات:**
- `viewId` (URL param) - معرف المشاهدة الفريد

**الاستجابة:**
```json
{
  "message": "تم حذف المشاهدة بنجاح"
}
```

---

#### 📍 Endpoint 2: حذف جميع مشاهدات الإعلان
```
DELETE /admin/announcement-views/bulk/all?announcementId=xxx
```
**الوصف:** حذف جميع مشاهدات إعلان معين

**المعاملات:**
- `announcementId` (query param) - معرف الإعلان

**الاستجابة:**
```json
{
  "message": "تم حذف xx مشاهدة بنجاح",
  "deletedCount": 25
}
```

---

#### 📍 Endpoint 3: حذف مشاهدات مستخدم معين
```
DELETE /admin/announcement-views/user/:userId?announcementId=xxx
```
**الوصف:** حذف جميع مشاهدات مستخدم معين من إعلان معين

**المعاملات:**
- `userId` (URL param) - معرف المستخدم
- `announcementId` (query param) - معرف الإعلان

**الاستجابة:**
```json
{
  "message": "تم حذف مشاهدات المستخدم بنجاح",
  "deletedCount": 1
}
```

---

### 2️⃣ Frontend APIs (Dart) - `lib/services/api_service.dart`

تمت إضافة 3 دوال جديدة:

#### 🔹 دالة 1: حذف مشاهدة واحدة
```dart
static Future<bool> deleteAnnouncementView(String viewId)
```
**الاستخدام:**
```dart
final success = await ApiService.deleteAnnouncementView(viewId);
if (success) {
  print('✅ تم الحذف بنجاح');
}
```

---

#### 🔹 دالة 2: حذف جميع المشاهدات
```dart
static Future<(bool, int)> deleteAllAnnouncementViews(String announcementId)
```
**الاستخدام:**
```dart
final (success, deletedCount) = 
  await ApiService.deleteAllAnnouncementViews(announcementId);

if (success) {
  print('✅ تم حذف $deletedCount مشاهدة');
}
```

---

#### 🔹 دالة 3: حذف مشاهدات مستخدم معين
```dart
static Future<(bool, int)> deleteUserAnnouncementViews(
  String userId,
  String announcementId,
)
```
**الاستخدام:**
```dart
final (success, deletedCount) = 
  await ApiService.deleteUserAnnouncementViews(userId, announcementId);

if (success) {
  print('✅ تم حذف $deletedCount مشاهدة للمستخدم');
}
```

---

### 3️⃣ Frontend UI - `lib/screens/admin_dashboard_screen.dart`

#### 🎨 التعديلات في الواجهة:

1. **زر حذف جميع المشاهدات** (في الأعلى بجانب العدد)
   - أيقونة: `Icons.delete_outline` (أحمر)
   - يظهر فقط عند وجود مشاهدات
   - ينقل إلى حوار تأكيد

2. **قائمة خيارات لكل مستخدم** (PopupMenu)
   - حذف هذه المشاهدة
   - حذف جميع مشاهدات المستخدم

3. **حوارات التأكيد (Dialogs)**:
   - ✋ حوار تأكيد حذف مشاهدة واحدة
   - ⚠️ حوار تأكيد حذف مشاهدات المستخدم
   - 🔴 حوار تحذيري حذف جميع المشاهدات

#### 🔧 الدوال المضافة:

```dart
// حذف مشاهدة واحدة
Future<void> _deleteView(String viewId, String username)

// حذف جميع مشاهدات المستخدم
Future<void> _deleteUserViews(String userId, String username)

// حذف جميع المشاهدات
Future<void> _deleteAllViews()

// حوارات التأكيد
void _showDeleteViewConfirmation(String viewId, String username)
void _showDeleteUserViewsConfirmation(String userId, String username)
void _showDeleteAllViewsConfirmation()
```

---

## 📊 Firestore Structure

البيانات المحذوفة من مجموعة `announcement_views`:

```json
{
  "id": "document_id",
  "announcementId": "announcement_id",
  "userId": "user_id",
  "viewedAt": "2024-02-22T10:30:00Z"
}
```

---

## 🎯 سير العمل (Workflow)

### عند حذف مشاهدة واحدة:
1. ✅ المسؤول يختار مستخدم من القائمة
2. 🔘 يضغط على "حذف هذه المشاهدة"
3. ⚠️ يظهر حوار تأكيد
4. 🗑️ عند التأكيد → حذف من Firestore
5. 🔄 تحديث القائمة تلقائياً

### عند حذف جميع مشاهدات المستخدم:
1. ✅ المسؤول يختار مستخدم
2. 🔘 يختار "حذف جميع مشاهدات المستخدم"
3. ⚠️ حوار تأكيد يظهر
4. 🗑️ حذف جميع مشاهداته من الإعلان
5. 🔄 تحديث القائمة

### عند حذف جميع المشاهدات:
1. 🔴 المسؤول يضغط أيقونة الحذف الحمراء في الأعلى
2. 🔴 حوار تحذيري يظهر (مع عرض العدد)
3. ⚠️ تحذير بعدم القدرة على التراجع
4. 🗑️ حذف الكل من Firestore
5. 🔄 تحديث القائمة (تصبح فارغة)

---

## 🔐 الأمان والصلاحيات

جميع الـ Endpoints محمية بـ:
- `verifyToken` - التحقق من صحة التوكن
- `checkAdmin` - التحقق من أن المستخدم مسؤول

---

## 💡 الملاحظات المهمة

1. **استخدام Batch Operations**: عند حذف مشاهدات متعددة، يتم استخدام `batch` لتحسين الأداء
2. **تحديث محلي فوري**: القائمة تحدث محلياً قبل التحديث من السيرفر
3. **رسائل تأكيد واضحة**: كل عملية حذف تعطي رد فعل واضح للمستخدم
4. **لا يمكن التراجع**: الحذف نهائي ولا يوجد خيار "Undo"

---

## 🚀 المزايا

✅ إدارة سهلة ومرنة للمشاهدات  
✅ خيارات متعددة المستويات (واحد/مستخدم/كل)  
✅ حوارات تأكيد آمنة  
✅ تحديث فوري للواجهة  
✅ استجابات خادم تفصيلية  
✅ معالجة أخطاء شاملة  

---

## 📝 أمثلة الاستخدام

### مثال كامل من الـ Admin Dashboard:

```dart
// عند الضغط على "حذف جميع المشاهدات"
ElevatedButton(
  onPressed: _showDeleteAllViewsConfirmation,
  child: const Text('حذف كل'),
)

// دالة عرض التأكيد
void _showDeleteAllViewsConfirmation() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('⚠️ تحذير'),
      content: Text('حذف ${_announcementViews.length} مشاهدة؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            _deleteAllViews();
          },
          child: const Text('حذف الكل'),
        ),
      ],
    ),
  );
}

// دالة الحذف الفعلية
Future<void> _deleteAllViews() async {
  final (success, deletedCount) = 
    await ApiService.deleteAllAnnouncementViews(_announcementId!);
  
  if (success) {
    setState(() => _announcementViews = []);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ تم حذف $deletedCount مشاهدة')),
    );
  }
}
```

---

## 🧪 الاختبار

للاختبار، استخدم Postman أو أي أداة API:

```bash
# حذف مشاهدة واحدة
DELETE http://localhost:3000/admin/announcement-views/view_id

# حذف جميع المشاهدات
DELETE http://localhost:3000/admin/announcement-views/bulk/all?announcementId=xxx

# حذف مشاهدات المستخدم
DELETE http://localhost:3000/admin/announcement-views/user/user_id?announcementId=xxx
```

---

**تم الإنجاز بنجاح! ✅**
