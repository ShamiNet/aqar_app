/**
 * Script لتحديث العقارات القديمة بإضافة حقل propertyType
 * يجب تشغيله مرة واحدة فقط لإصلاح البيانات القديمة
 * 
 * الاستخدام:
 * node update_property_types.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// تهيئة Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updatePropertyTypes() {
  console.log('🔄 بدء تحديث أنواع العقارات...\n');

  try {
    const propertiesSnapshot = await db.collection('properties').get();
    let updatedCount = 0;
    let skippedCount = 0;
    let errorCount = 0;

    console.log(`📊 العدد الإجمالي للعقارات: ${propertiesSnapshot.size}\n`);

    for (const doc of propertiesSnapshot.docs) {
      const data = doc.data();

      // تخطي العقارات التي لديها propertyType بالفعل
      if (data.propertyType && data.propertyType.trim() !== '') {
        skippedCount++;
        console.log(`⏩ تخطي ${doc.id} - يحتوي بالفعل على نوع: ${data.propertyType}`);
        continue;
      }

      // محاولة استنتاج النوع من العنوان
      const title = (data.title || '').toLowerCase();
      let propertyType = 'بيت'; // القيمة الافتراضية

      if (title.includes('فيلا')) {
        propertyType = 'فيلا';
      } else if (title.includes('بناية') || title.includes('عمارة')) {
        propertyType = 'بناية';
      } else if (title.includes('ارض') || title.includes('أرض')) {
        propertyType = 'ارض';
      } else if (title.includes('دكان') || title.includes('محل')) {
        propertyType = 'دكان';
      }

      try {
        await db.collection('properties').doc(doc.id).update({
          propertyType: propertyType
        });
        updatedCount++;
        console.log(`✅ تم تحديث ${doc.id} → ${propertyType}`);
      } catch (error) {
        errorCount++;
        console.error(`❌ فشل تحديث ${doc.id}:`, error.message);
      }
    }

    console.log('\n' + '='.repeat(50));
    console.log('📈 ملخص التحديث:');
    console.log(`   ✅ تم التحديث: ${updatedCount} عقار`);
    console.log(`   ⏩ تم التخطي: ${skippedCount} عقار`);
    console.log(`   ❌ أخطاء: ${errorCount} عقار`);
    console.log('='.repeat(50) + '\n');

    process.exit(0);
  } catch (error) {
    console.error('💥 خطأ في تحديث العقارات:', error);
    process.exit(1);
  }
}

// تشغيل الـ script
updatePropertyTypes();
