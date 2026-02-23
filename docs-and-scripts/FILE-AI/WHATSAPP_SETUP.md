# 📱 دليل إعداد وربط الواتساب - تطبيق عقار بلس

## 📋 المحتويات
1. [نظرة عامة](#نظرة-عامة)
2. [متطلبات النظام](#متطلبات-النظام)
3. [خطوات الإعداد](#خطوات-الإعداد)
4. [ربط الواتساب (QR Code)](#ربط-الواتساب-qr-code)
5. [التحقق من عمل البوت](#التحقق-من-عمل-البوت)
6. [حل المشاكل الشائعة](#حل-المشاكل-الشائعة)

---

## 🎯 نظرة عامة

هذا الدليل يشرح كيفية إعداد نظام النشر التلقائي للعقارات على واتساب باستخدام Evolution API v2.

**البنية التحتية:**
- **السيرفر:** Debian VPS
- **البوت:** Python script (`noteShami.py`)
- **بوابة الواتساب:** Evolution API v2 (Docker)
- **قاعدة البيانات:** Firebase Firestore

---

## 💻 متطلبات النظام

### على السيرفر (VPS):
```bash
✅ Docker و Docker Compose
✅ Python 3.8+
✅ البيئة الافتراضية (aqar_env)
✅ المكتبات: firebase-admin، requests
✅ Evolution API يعمل على http://localhost:8080
```

### الملفات المطلوبة:
```
/root/
├── noteShami.py              # البوت الرئيسي
├── get_qr.py                 # سكريبت استخراج QR Code
├── test_evolution.py         # سكريبت الاختبار
├── serviceAccountKey.json    # مفتاح Firebase
└── evolution-api/
    └── docker-compose.yml    # تكوين Evolution API
```

---

## 🚀 خطوات الإعداد

### 1️⃣ التحقق من عمل Evolution API

```bash
# على السيرفر (VPS)
ssh root@your-server-ip

# التحقق من أن الـ containers تعمل
docker ps

# يجب أن ترى:
# - evolution_api (Up)
# - postgres (Up)
# - redis (Up)

# مراقبة Logs
docker logs -f evolution_api
```

### 2️⃣ إنشاء Instance جديدة (إذا لم تكن موجودة)

```bash
curl -X POST http://localhost:8080/instance/create \
  -H "apikey: shami_secret_key_123" \
  -H "Content-Type: application/json" \
  -d '{
    "instanceName": "aqar_bot",
    "qrcode": true,
    "integration": "WHATSAPP-BAILEYS"
  }'
```

**الناتج المتوقع:**
```json
{
  "instance": {
    "instanceName": "aqar_bot",
    "status": "created"
  }
}
```

---

## 📱 ربط الواتساب (QR Code)

### الطريقة الموصى بها: استخدام `get_qr.py`

#### الخطوة 1: نقل السكريبت للسيرفر

```bash
# من جهازك المحلي (Windows)
scp get_qr.py root@your-server-ip:/root/
```

#### الخطوة 2: تشغيل السكريبت

```bash
# على السيرفر
cd /root
source aqar_env/bin/activate
python3 get_qr.py
```

**السكريبت سيقوم بـ:**
1. ✅ فحص حالة Instance
2. 🔄 محاولة استخراج QR Code (30 محاولة، كل 5 ثواني)
3. 💾 حفظ Base64 في ملف `qr_code_YYYYMMDD_HHMMSS.txt`

#### الخطوة 3: تحويل Base64 إلى صورة

**الطريقة الأولى - عبر الموقع:**
1. افتح الملف: `cat qr_code_*.txt`
2. انسخ النص الطويل (Base64)
3. افتح: https://base64.guru/converter/decode/image
4. الصق النص واضغط "Decode"
5. سيظهر QR Code

**الطريقة الثانية - باستخدام أمر Linux:**
```bash
# تحويل Base64 إلى صورة PNG
base64 -d qr_code_*.txt > qr.png

# نقل الصورة لجهازك المحلي
scp root@your-server-ip:/root/qr.png ./
```

#### الخطوة 4: مسح QR Code

1. افتح واتساب على هاتفك
2. اذهب إلى: **الإعدادات > الأجهزة المرتبطة**
3. اضغط **ربط جهاز**
4. امسح الـ QR Code
5. ✅ تم الربط!

#### الخطوة 5: التحقق من نجاح الربط

```bash
python3 test_evolution.py
```

يجب أن ترى:
```
✅ Instance متصل وجاهز للإرسال!
```

---

## 🧪 التحقق من عمل البوت

### اختبار 1: التحقق من Evolution API

```bash
python3 test_evolution.py
```

**الاختبارات المشمولة:**
- ✅ صحة السيرفر
- ✅ قائمة Instances
- ✅ حالة Instance
- ✅ إرسال رسالة نصية
- ✅ إرسال صورة

### اختبار 2: تشغيل البوت

```bash
# تشغيل يدوي (للاختبار)
python3 noteShami.py

# يجب أن ترى:
🚀 تم تشغيل نظام النشر التسويقي المطور...
```

### اختبار 3: إضافة عقار تجريبي

من تطبيق Flutter، أضف عقار جديد. يجب أن يصل تلقائياً إلى:
- ✅ قناة تلغرام (@aqarShami)
- ✅ رقم الواتساب المحدد

---

## 🔧 حل المشاكل الشائعة

### ❌ المشكلة: "فشل الحصول على QR Code بعد 30 محاولة"

**الأسباب المحتملة:**
1. **RAM ممتلئ:**
   ```bash
   free -h
   # إذا كان Available أقل من 500MB، أعد تشغيل Docker
   docker restart evolution_api
   ```

2. **البورت مشغول:**
   ```bash
   netstat -tuln | grep 8080
   # إذا لم يظهر شيء، Evolution API لا يعمل
   ```

3. **Instance محذوف:**
   ```bash
   # احذف Instance القديم
   curl -X DELETE http://localhost:8080/instance/delete/aqar_bot \
     -H "apikey: shami_secret_key_123"
   
   # أعد إنشاءه
   curl -X POST http://localhost:8080/instance/create \
     -H "apikey: shami_secret_key_123" \
     -H "Content-Type: application/json" \
     -d '{"instanceName": "aqar_bot", "qrcode": true}'
   ```

---

### ❌ المشكلة: "Instance state: close"

**الحل:**
```bash
# أعد طلب QR Code
python3 get_qr.py
```

الجلسة قد انتهت أو تم فصل الجهاز من واتساب. امسح QR جديد.

---

### ❌ المشكلة: "فشل النشر على واتساب: 401"

**السبب:** API Key خاطئ

**الحل:**
تحقق من أن `EVOLUTION_API_KEY` في `noteShami.py` يطابق `docker-compose.yml`:
```yaml
# في docker-compose.yml
AUTHENTICATION_API_KEY: "shami_secret_key_123"
```

---

### ❌ المشكلة: "فشل النشر على واتساب: 404"

**السبب:** رقم الواتساب خاطئ

**الحل:**
تأكد من الصيغة الصحيحة:
```python
# ✅ صحيح
WHATSAPP_NUMBER = "966501234567@s.whatsapp.net"

# ❌ خطأ
WHATSAPP_NUMBER = "966501234567"  # ناقص @s.whatsapp.net
WHATSAPP_NUMBER = "+966501234567@s.whatsapp.net"  # لا تضع +
```

---

### ❌ المشكلة: البوت لا يرسل تلقائياً

**التحقق:**
```bash
# هل الخدمة تعمل؟
systemctl status aqar_new.service

# إعادة تشغيل الخدمة
systemctl restart aqar_new.service

# مراقبة Logs
journalctl -u aqar_new.service -f
```

---

## 🎉 الإعداد النهائي

بعد نجاح جميع الاختبارات:

### 1. تحديث رقم الواتساب

عدّل في `noteShami.py`:
```python
WHATSAPP_NUMBER = "966XXXXXXXXX@s.whatsapp.net"  # ضع رقمك الحقيقي
```

### 2. إعادة تشغيل البوت

```bash
systemctl restart aqar_new.service
systemctl status aqar_new.service
```

### 3. مراقبة العمل

```bash
# مراقبة logs البوت
journalctl -u aqar_new.service -f

# مراقبة Evolution API
docker logs -f evolution_api
```

---

## 📊 معلومات مهمة

### بيانات الاتصال:
- **API URL:** http://localhost:8080
- **API Key:** shami_secret_key_123
- **Instance Name:** aqar_bot

### الملفات الرئيسية:
- **البوت:** `/root/noteShami.py`
- **الخدمة:** `/etc/systemd/system/aqar_new.service`
- **Docker Compose:** `/root/evolution-api/docker-compose.yml`

### أوامر مفيدة:

```bash
# حالة Docker Containers
docker ps

# إعادة تشغيل Evolution API
docker restart evolution_api

# مراقبة logs
docker logs -f evolution_api
journalctl -u aqar_new.service -f

# حالة البوت
systemctl status aqar_new.service

# إعادة تشغيل البوت
systemctl restart aqar_new.service
```

---

## 🆘 الدعم

إذا واجهت مشاكل:

1. ✅ تحقق من Logs: `docker logs evolution_api`
2. ✅ جرّب `test_evolution.py`
3. ✅ تحقق من RAM: `free -h`
4. ✅ أعد تشغيل Docker: `docker restart evolution_api`
5. ✅ احذف وأعد إنشاء Instance

---

## ✅ Checklist النهائي

- [ ] Docker يعمل: `docker ps`
- [ ] Evolution API يستجيب: `curl localhost:8080`
- [ ] Instance موجود: `test_evolution.py`
- [ ] QR Code تم مسحه: `state = open`
- [ ] اختبار إرسال نجح: `test_evolution.py`
- [ ] رقم الواتساب محدث في `noteShami.py`
- [ ] البوت يعمل: `systemctl status aqar_new.service`
- [ ] إضافة عقار تجريبي وصل للواتساب: ✅

---

**🎉 تهانينا! نظام النشر التلقائي جاهز للعمل!**
