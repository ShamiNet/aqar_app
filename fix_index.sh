#!/bin/bash

echo "🔧 إصلاح ملف index.js..."

# حذف جميع الأسطر الخاطئة
sed -i '/app\.use(express\.static(" public));/d' /root/aqar-server/index.js

echo "✅ تم الإصلاح. التحقق من الملف..."
grep -n "express.static" /root/aqar-server/index.js

echo ""
echo "🔄 إعادة تشغيل السيرفر..."
pm2 restart aqar-server

echo ""
echo "⏳ الانتظار 3 ثوان..."
sleep 3

echo ""
echo "✅ فحص حالة السيرفر..."
pm2 status aqar-server

echo ""
echo "🌐 اختبار الوصول للملف..."
curl http://localhost:3001/.well-known/assetlinks.json

echo ""
echo ""
echo "🌍 اختبار عبر HTTPS..."
curl https://s313.store/.well-known/assetlinks.json
