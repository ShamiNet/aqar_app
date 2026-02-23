#!/bin/bash

# ========================================
# 🚀 نص رفع assetlinks.json للسيرفر
# ========================================

echo "📁 إنشاء المجلد على السيرفر..."
ssh root@s313.store "mkdir -p /var/www/html/.well-known"

echo "📤 رفع ملف assetlinks.json..."
scp assetlinks.json root@s313.store:/var/www/html/.well-known/assetlinks.json

echo "🔧 ضبط الصلاحيات..."
ssh root@s313.store "chmod 644 /var/www/html/.well-known/assetlinks.json"

echo "✅ التحقق من رفع الملف..."
ssh root@s313.store "cat /var/www/html/.well-known/assetlinks.json"

echo ""
echo "🎉 تم رفع الملف بنجاح!"
echo "🔗 تحقق من الرابط: https://s313.store/.well-known/assetlinks.json"
