#!/bin/bash

echo "🔍 فحص حالة السيرفر..."
pm2 status

echo ""
echo "📋 عرض آخر 30 سطر من السجلات..."
pm2 logs aqar-server --lines 30 --nostream

echo ""
echo "🔍 فحص ملف index.js..."
grep -A 2 "bodyParser.json" /root/aqar-server/index.js

echo ""
echo "📂 فحص وجود المجلد public..."
ls -la /root/aqar-server/public/.well-known/

echo ""
echo "🌐 اختبار الرابط المباشر للملف..."
cat /root/aqar-server/public/.well-known/assetlinks.json

echo ""
echo "🔧 اختبار المنفذ..."
netstat -tlnp | grep 3001

echo ""
echo "✅ اختبار curl محلي..."
curl http://localhost:3001/.well-known/assetlinks.json
