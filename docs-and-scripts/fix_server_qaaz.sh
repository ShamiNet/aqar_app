#!/bin/bash

echo "🔧 إصلاح ملف index.js..."

# حذف السطر الخاطئ
sed -i '/app\.use(express\.static(" public));/d' /root/aqar-server/index.js

echo "✅ تم حذف السطر الخاطئ"

echo ""
echo "📝 التحقق من الأسطر المتبقية:"
grep -n "express.static" /root/aqar-server/index.js

echo ""
echo "🔄 إعادة تشغيل السيرفر..."
pm2 restart aqar-server

echo ""
echo "⏳ الانتظار 3 ثوان..."
sleep 3

echo ""
echo "✅ حالة السيرفر:"
pm2 list

echo ""
echo "🌐 اختبار الوصول للملف محلياً:"
curl -s http://localhost:3001/.well-known/assetlinks.json

echo ""
echo ""
echo "🌍 اختبار عبر HTTPS:"
curl -s https://s313.store/.well-known/assetlinks.json
