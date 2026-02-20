# 📝 ورقة غش سريعة - أوامر Evolution API & Bot

## 🚀 بدء سريع (Quick Start)

### على السيرفر (VPS):

```bash
# 1. نقل الملفات للسيرفر
scp get_qr.py test_evolution.py setup_whatsapp.sh root@YOUR_SERVER:/root/

# 2. الاتصال بالسيرفر
ssh root@YOUR_SERVER

# 3. تفعيل البيئة الافتراضية
source aqar_env/bin/activate

# 4. تشغيل أداة الإعداد التفاعلية
chmod +x setup_whatsapp.sh
./setup_whatsapp.sh
```

---

## 🐳 أوامر Docker

```bash
# عرض الـ containers العاملة
docker ps

# إعادة تشغيل Evolution API
docker restart evolution_api

# إيقاف
docker stop evolution_api

# تشغيل
docker start evolution_api

# مراقبة Logs (مباشر)
docker logs -f evolution_api

# آخر 100 سطر من Logs
docker logs --tail 100 evolution_api

# حالة الذاكرة
docker stats evolution_api --no-stream
```

---

## 🔧 أوامر Evolution API (curl)

### إنشاء Instance:
```bash
curl -X POST http://localhost:8080/instance/create \
  -H "apikey: shami_secret_key_123" \
  -H "Content-Type: application/json" \
  -d '{"instanceName": "aqar_bot", "qrcode": true}'
```

### حذف Instance:
```bash
curl -X DELETE http://localhost:8080/instance/delete/aqar_bot \
  -H "apikey: shami_secret_key_123"
```

### فحص الحالة:
```bash
curl -X GET http://localhost:8080/instance/connectionState/aqar_bot \
  -H "apikey: shami_secret_key_123"
```

### استخراج QR Code:
```bash
curl -X GET http://localhost:8080/instance/connect/aqar_bot \
  -H "apikey: shami_secret_key_123"
```

### قائمة كل Instances:
```bash
curl -X GET http://localhost:8080/instance/fetchInstances \
  -H "apikey: shami_secret_key_123"
```

### إرسال رسالة نصية:
```bash
curl -X POST http://localhost:8080/message/sendText/aqar_bot \
  -H "apikey: shami_secret_key_123" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "966501234567@s.whatsapp.net",
    "text": "مرحباً من عقار بلس!"
  }'
```

### إرسال صورة:
```bash
curl -X POST http://localhost:8080/message/sendMedia/aqar_bot \
  -H "apikey: shami_secret_key_123" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "966501234567@s.whatsapp.net",
    "mediatype": "image",
    "mimetype": "image/jpeg",
    "media": "https://example.com/image.jpg",
    "caption": "عقار مميز!"
  }'
```

---

## 🐍 أوامر Python Scripts

### تشغيل سكريبت استخراج QR:
```bash
python3 get_qr.py
```

### تشغيل اختبارات شاملة:
```bash
python3 test_evolution.py
```

### تشغيل البوت يدوياً (للاختبار):
```bash
python3 noteShami.py
```

---

## 🔄 إدارة خدمة البوت (Systemd)

```bash
# حالة الخدمة
systemctl status aqar_new.service

# بدء الخدمة
systemctl start aqar_new.service

# إيقاف الخدمة
systemctl stop aqar_new.service

# إعادة تشغيل
systemctl restart aqar_new.service

# تفعيل البدء التلقائي
systemctl enable aqar_new.service

# مراقبة Logs
journalctl -u aqar_new.service -f

# آخر 50 سطر
journalctl -u aqar_new.service -n 50
```

---

## 🛠️ استكشاف الأخطاء

### المشكلة: QR Code لا يظهر

```bash
# 1. تحقق من RAM
free -h

# 2. أعد تشغيل Evolution API
docker restart evolution_api

# 3. راقب Logs
docker logs -f evolution_api

# 4. احذف Instance وأعد إنشاءه
curl -X DELETE http://localhost:8080/instance/delete/aqar_bot \
  -H "apikey: shami_secret_key_123"

curl -X POST http://localhost:8080/instance/create \
  -H "apikey: shami_secret_key_123" \
  -H "Content-Type: application/json" \
  -d '{"instanceName": "aqar_bot", "qrcode": true}'

# 5. حاول مرة أخرى
python3 get_qr.py
```

### المشكلة: فشل إرسال الرسائل

```bash
# 1. تحقق من حالة Instance
curl -X GET http://localhost:8080/instance/connectionState/aqar_bot \
  -H "apikey: shami_secret_key_123" | jq

# 2. تحقق من الرقم (يجب أن ينتهي بـ @s.whatsapp.net)
# ✅ صحيح: 966501234567@s.whatsapp.net
# ❌ خطأ: +966501234567@s.whatsapp.net

# 3. جرّب إرسال تجريبي
python3 test_evolution.py
```

### المشكلة: البوت لا يرسل تلقائياً

```bash
# 1. تحقق من أن الخدمة تعمل
systemctl status aqar_new.service

# 2. راجع Logs
journalctl -u aqar_new.service -f

# 3. أعد تشغيل الخدمة
systemctl restart aqar_new.service
```

---

## 📊 فحص صحة النظام

### Checklist كامل في أمر واحد:
```bash
echo "=== Docker Status ===" && \
docker ps | grep evolution && \
echo -e "\n=== Evolution API Health ===" && \
curl -s http://localhost:8080/ | head -c 100 && \
echo -e "\n\n=== Bot Service Status ===" && \
systemctl status aqar_new.service | grep Active && \
echo -e "\n=== RAM Usage ===" && \
free -h | grep Mem
```

---

## 🎯 سيناريوهات شائعة

### إعداد من الصفر:
```bash
# 1. تشغيل Evolution API
cd /root/evolution-api
docker-compose up -d

# 2. إنشاء Instance
curl -X POST http://localhost:8080/instance/create \
  -H "apikey: shami_secret_key_123" \
  -H "Content-Type: application/json" \
  -d '{"instanceName": "aqar_bot", "qrcode": true}'

# 3. استخراج QR
python3 get_qr.py

# 4. بعد مسح QR، اختبر
python3 test_evolution.py

# 5. شغّل البوت
systemctl start aqar_new.service
```

### قطع اتصال الواتساب (انتهت الجلسة):
```bash
# 1. استخرج QR جديد
python3 get_qr.py

# 2. امسح QR بالهاتف

# 3. تحقق من الحالة
python3 test_evolution.py
```

### ترقية السكريبتات:
```bash
# 1. إيقاف البوت
systemctl stop aqar_new.service

# 2. نسخ الملفات الجديدة
scp noteShami.py root@SERVER:/root/

# 3. إعادة تشغيل
systemctl start aqar_new.service

# 4. مراقبة
journalctl -u aqar_new.service -f
```

---

## 🔐 ملفات مهمة

```
/root/
├── noteShami.py                  # البوت الرئيسي
├── get_qr.py                     # استخراج QR Code
├── test_evolution.py             # اختبارات شاملة
├── setup_whatsapp.sh             # أداة إعداد تفاعلية
├── config.env                    # ملف التكوين
├── serviceAccountKey.json        # مفتاح Firebase
└── evolution-api/
    └── docker-compose.yml        # تكوين Docker

/etc/systemd/system/
└── aqar_new.service              # خدمة البوت
```

---

## 📱 معلومات الاتصال

- **API URL:** http://localhost:8080
- **API Key:** shami_secret_key_123
- **Instance Name:** aqar_bot
- **Telegram Channel:** @aqarShami
- **Domain:** https://n4yo.com

---

## 🆘 روابط مفيدة

- **Evolution API Docs:** https://doc.evolution-api.com/
- **Base64 to Image:** https://base64.guru/converter/decode/image
- **Firebase Console:** https://console.firebase.google.com/

---

## ✅ اختبار سريع (One-liner)

```bash
# اختبار كامل في أمر واحد
docker ps | grep evolution && \
python3 test_evolution.py && \
systemctl status aqar_new.service
```

إذا نجحت كل الأوامر أعلاه، نظامك يعمل بشكل صحيح! ✅
