# 🚀 إعداد بوت Node.js + Baileys

## ✅ الميزات:
- ✅ أبسط من Evolution API
- ✅ QR Code يظهر مباشرة في Terminal
- ✅ لا يحتاج Docker
- ✅ يعمل مع Python Bot الموجود أو بديل عنه

---

## 📋 الخطوات (على السيرفر):

### 1️⃣ تثبيت Node.js (إذا لم يكن مثبتاً):

```bash
# على السيرفر
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
node -v
npm -v
```

---

### 2️⃣ نقل الملفات للسيرفر:

من جهازك (Windows PowerShell):

```powershell
cd C:\Users\Qualcomm\pro\aqar_app
scp whatsapp-bot.js package.json root@qaaz.live:/root/whatsapp-bot/
```

---

### 3️⃣ إعداد المشروع على السيرفر:

```bash
# على السيرفر
cd /root/whatsapp-bot

# نسخ serviceAccountKey.json
cp /root/serviceAccountKey.json ./

# تثبيت المكتبات
npm install

# تعديل رقم الواتساب
nano whatsapp-bot.js
# غيّر السطر:
# const WHATSAPP_NUMBER = "966XXXXXXXXX@s.whatsapp.net";
# إلى رقمك الحقيقي مثل:
# const WHATSAPP_NUMBER = "966501234567@s.whatsapp.net";
```

---

### 4️⃣ تشغيل البوت:

```bash
# تشغيل مباشر
node whatsapp-bot.js
```

**سيظهر QR Code في Terminal مباشرة!** 📱

امسحه بهاتفك:
1. افتح واتساب
2. الإعدادات > الأجهزة المرتبطة
3. ربط جهاز
4. امسح QR

---

### 5️⃣ تشغيل كخدمة (Systemd):

بعد نجاح الربط، أنشئ خدمة:

```bash
nano /etc/systemd/system/aqar-whatsapp.service
```

الصق هذا:

```ini
[Unit]
Description=Aqar Plus WhatsApp Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/whatsapp-bot
ExecStart=/usr/bin/node /root/whatsapp-bot/whatsapp-bot.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/aqar-whatsapp.log
StandardError=append:/var/log/aqar-whatsapp-error.log

[Install]
WantedBy=multi-user.target
```

احفظ وشغّل:

```bash
systemctl daemon-reload
systemctl enable aqar-whatsapp.service
systemctl start aqar-whatsapp.service
systemctl status aqar-whatsapp.service

# مراقبة Logs
journalctl -u aqar-whatsapp.service -f
```

---

## 🎯 الفرق بين الحلول:

| الميزة | Evolution API | Node.js + Baileys |
|--------|---------------|-------------------|
| سهولة الإعداد | معقد ❌ | بسيط ✅ |
| QR Code | مشاكل ❌ | يظهر مباشرة ✅ |
| Docker | مطلوب ❌ | غير مطلوب ✅ |
| استهلاك الموارد | عالي | منخفض ✅ |
| الموثوقية | متوسط | عالية ✅ |

---

## 🔄 إيقاف Evolution API (اختياري):

إذا أردت التخلي عن Evolution API تماماً:

```bash
cd /root/evolution-api
docker compose down
```

---

## ✅ الاختبار:

1. شغّل البوت: `node whatsapp-bot.js`
2. امسح QR Code
3. من تطبيق Flutter، أضف عقار جديد
4. يجب أن يصل إلى تلغرام والواتساب معاً! 🎉

---

## 🆘 حل المشاكل:

### QR Code لا يظهر؟
```bash
npm install qrcode-terminal
node whatsapp-bot.js
```

### الاتصال يفصل؟
- احذف مجلد `auth_info_baileys` وأعد المسح
```bash
rm -rf auth_info_baileys
node whatsapp-bot.js
```

### رقم الواتساب خاطئ؟
تأكد من الصيغة:
- ✅ `966501234567@s.whatsapp.net`
- ❌ `+966501234567@s.whatsapp.net`
- ❌ `966501234567`

---

**🎉 الآن لديك حل أبسط وأقوى بدون Evolution API!**
