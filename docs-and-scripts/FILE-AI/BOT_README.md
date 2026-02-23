# 🏠 عقار بلس - نظام النشر التلقائي (Automated Marketing Bot)

<div dir="rtl">

## 📋 نظرة عامة

نظام متكامل للنشر التلقائي للعقارات على منصات التواصل الاجتماعي (تلغرام وواتساب) فور إضافتها إلى تطبيق Flutter.

### 🎯 الميزات الرئيسية:
- ✅ مراقبة قاعدة بيانات Firebase Firestore في الوقت الفعلي
- ✅ نشر تلقائي على قناة تلغرام
- ✅ نشر تلقائي على واتساب (رقم/مجموعة)
- ✅ تنسيق رسائل احترافي مع الصور
- ✅ Deep Links للتطبيق
- ✅ يعمل كخدمة خلفية (Systemd)

---

## 🏗️ البنية التحتية

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (عقار بلس)                   │
│                    (iOS / Android / Web)                    │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
            ┌────────────────────┐
            │  Firebase Firestore │
            │   (Properties DB)   │
            └─────────┬────────────┘
                     │
                     ↓
            ┌────────────────────┐
            │   Python Bot       │
            │  (noteShami.py)    │
            └─────┬──────┬────────┘
                  │      │
         ┌────────┘      └────────┐
         ↓                        ↓
  ┌─────────────┐        ┌──────────────────┐
  │  Telegram   │        │  Evolution API   │
  │   Channel   │        │   (WhatsApp)     │
  └─────────────┘        └──────────────────┘
```

---

## 📦 الملفات الرئيسية

| الملف | الوظيفة |
|------|---------|
| `noteShami.py` | البوت الرئيسي الذي يراقب Firebase ويرسل للتلغرام والواتساب |
| `get_qr.py` | سكريبت استخراج QR Code لربط الواتساب |
| `test_evolution.py` | سكريبت اختبار شامل لـ Evolution API |
| `setup_whatsapp.sh` | أداة إعداد تفاعلية (Bash) |
| `config.env` | ملف التكوين المركزي |
| `WHATSAPP_SETUP.md` | دليل الإعداد الكامل |
| `CHEATSHEET.md` | ورقة غش سريعة للأوامر |

---

## ⚙️ المتطلبات

### على السيرفر (VPS):
- ✅ نظام Debian/Ubuntu
- ✅ Docker & Docker Compose
- ✅ Python 3.8+
- ✅ RAM: 2GB على الأقل
- ✅ مساحة: 5GB

### المكتبات Python:
```bash
pip install firebase-admin requests
```

### Docker Services:
- Evolution API v2
- PostgreSQL
- Redis

---

## 🚀 التثبيت السريع

### 1️⃣ على السيرفر:

```bash
# الاتصال بالسيرفر
ssh root@your-server-ip

# إنشاء البيئة الافتراضية
python3 -m venv aqar_env
source aqar_env/bin/activate

# تثبيت المكتبات
pip install firebase-admin requests

# تشغيل Evolution API
cd /root/evolution-api
docker-compose up -d
```

### 2️⃣ نقل الملفات:

```bash
# من جهازك المحلي
scp noteShami.py get_qr.py test_evolution.py setup_whatsapp.sh \
    serviceAccountKey.json root@your-server:/root/
```

### 3️⃣ الإعداد:

```bash
# على السيرفر
chmod +x setup_whatsapp.sh
./setup_whatsapp.sh
```

اتبع القائمة التفاعلية لإكمال الإعداد.

---

## 📱 ربط الواتساب

### الطريقة الموصى بها:

```bash
# 1. تشغيل سكريبت استخراج QR
python3 get_qr.py

# 2. سيتم حفظ QR Code في ملف نصي (Base64)

# 3. حوّل Base64 إلى صورة:
# افتح: https://base64.guru/converter/decode/image
# الصق المحتوى وحوّله

# 4. امسح QR بهاتفك:
# واتساب > الإعدادات > الأجهزة المرتبطة > ربط جهاز

# 5. تحقق من النجاح:
python3 test_evolution.py
```

**راجع [WHATSAPP_SETUP.md](WHATSAPP_SETUP.md) للدليل الكامل**

---

## 🧪 الاختبار

### اختبار Evolution API:
```bash
python3 test_evolution.py
```

يقوم بـ:
- ✅ فحص اتصال السيرفر
- ✅ عرض قائمة Instances
- ✅ فحص حالة الاتصال
- ✅ إرسال رسالة تجريبية
- ✅ إرسال صورة تجريبية

### اختبار البوت كاملاً:
```bash
# تشغيل يدوي
python3 noteShami.py

# من تطبيق Flutter، أضف عقار جديد
# يجب أن يصل إلى التلغرام والواتساب
```

---

## 🔧 التكوين

### تعديل الإعدادات في `noteShami.py`:

```python
# التلغرام
TELEGRAM_BOT_TOKEN = "YOUR_BOT_TOKEN"
TELEGRAM_CHANNEL = "@YourChannel"

# الواتساب
EVOLUTION_API_URL = "http://localhost:8080"
EVOLUTION_API_KEY = "shami_secret_key_123"
EVOLUTION_INSTANCE = "aqar_bot"
WHATSAPP_NUMBER = "966XXXXXXXXX@s.whatsapp.net"
```

### للإرسال لمجموعة واتساب:
```python
WHATSAPP_NUMBER = "120363XXXXX@g.us"  # Group ID
```

**للحصول على Group ID:**
1. أرسل رسالة للمجموعة
2. راقب: `docker logs -f evolution_api`
3. ابحث عن: `"remoteJid": "120363XXX@g.us"`

---

## 🔄 تشغيل كخدمة

### إنشاء Systemd Service:

```bash
sudo nano /etc/systemd/system/aqar_new.service
```

```ini
[Unit]
Description=Aqar Bot - Auto Marketing System
After=network.target docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/root/aqar_env/bin/python3 /root/noteShami.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### تفعيل الخدمة:

```bash
sudo systemctl daemon-reload
sudo systemctl enable aqar_new.service
sudo systemctl start aqar_new.service
sudo systemctl status aqar_new.service
```

---

## 📊 المراقبة

### مراقبة البوت:
```bash
journalctl -u aqar_new.service -f
```

### مراقبة Evolution API:
```bash
docker logs -f evolution_api
```

### فحص صحة النظام:
```bash
# Docker
docker ps

# البوت
systemctl status aqar_new.service

# RAM
free -h
```

---

## 🛠️ استكشاف الأخطاء

### ❌ QR Code لا يظهر:
```bash
# أعد تشغيل Evolution API
docker restart evolution_api

# حاول مرة أخرى
python3 get_qr.py
```

### ❌ فشل الإرسال للواتساب:
```bash
# تحقق من الحالة
python3 test_evolution.py

# إذا كانت الحالة "close"، أعد مسح QR
python3 get_qr.py
```

### ❌ البوت لا يرسل تلقائياً:
```bash
# راجع Logs
journalctl -u aqar_new.service -f

# أعد تشغيل الخدمة
systemctl restart aqar_new.service
```

**راجع [WHATSAPP_SETUP.md](WHATSAPP_SETUP.md) لحلول مفصلة**

---

## 📚 الموارد

- 📖 [دليل الإعداد الكامل](WHATSAPP_SETUP.md)
- 📝 [ورقة الغش السريعة](CHEATSHEET.md)
- 🌐 [Evolution API Docs](https://doc.evolution-api.com/)
- 🔥 [Firebase Console](https://console.firebase.google.com/)

---

## 🎯 الخطة القادمة

- [ ] إضافة دعم لمنصات أخرى (Facebook, Twitter)
- [ ] لوحة تحكم (Dashboard) لمراقبة الإحصائيات
- [ ] جدولة النشر (Scheduling)
- [ ] قوالب رسائل قابلة للتخصيص
- [ ] دعم متعدد اللغات

---

## 🤝 المساهمة

هذا المشروع خاص بتطبيق عقار بلس. للاستفسارات:
- 📧 البريد: support@n4yo.com
- 🌐 الموقع: https://n4yo.com

---

## 📄 الترخيص

© 2025 عقار بلس - جميع الحقوق محفوظة

---

## ✅ Checklist التثبيت

- [ ] Docker يعمل
- [ ] Evolution API يعمل
- [ ] Instance تم إنشاؤه
- [ ] QR Code تم مسحه
- [ ] Instance متصل (state: open)
- [ ] اختبار الإرسال نجح
- [ ] رقم الواتساب محدّث في الكود
- [ ] البوت يعمل كخدمة
- [ ] تم اختبار إضافة عقار حقيقي

**عند إتمام جميع النقاط أعلاه، نظامك جاهز للعمل! 🎉**

</div>
