import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore
import time
import requests
from datetime import datetime

# ================= إعدادات تلغرام =================
TELEGRAM_BOT_TOKEN = "8047447151:AAGFT88l2BskNm0Z4T-ehHNVBxox9g34L40"
TELEGRAM_CHANNEL = "@aqarShami"
# =================================================

# ================= إعدادات واتساب (Evolution API) =================
EVOLUTION_API_URL = "http://localhost:8080"
EVOLUTION_API_KEY = "shami_secret_key_123"
EVOLUTION_INSTANCE = "aqar_bot"
WHATSAPP_NUMBER = "966XXXXXXXXX@s.whatsapp.net"  # <--- ⚠️ استبدل برقم المستلم (مع رمز الدولة)
# =================================================================

# الاتصال بـ Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("🚀 تم تشغيل نظام النشر التسويقي المطور...")

def send_to_telegram(property_data, property_id):
    try:
        # --- استخراج كافة البيانات ---
        title = property_data.get('title', 'عقار لقطة')
        price = property_data.get('price', 0)
        currency = property_data.get('currency', 'ر.س')
        description = property_data.get('description', '')
        images = property_data.get('imageUrls', [])
        
        # بيانات إضافية
        category = property_data.get('category', 'غير محدد')       # بيع/إيجار
        prop_type = property_data.get('propertyType', 'عقار')      # شقة/فيلا
        area = property_data.get('area', 0)
        rooms = property_data.get('rooms', 0)
        address = property_data.get('address', 'موقع مميز')
        
        # رابط العقار (الدومين الحقيقي)
        deep_link = f"https://n4yo.com/property/{property_id}"
        
        # --- صياغة الرسالة الاحترافية ---
        caption = f"""
🌟 <b>فرصة عقارية جديدة في عقار بلص!</b> 🌟

🏠 <b>{title}</b>

📊 <b>التفاصيل الرئيسية:</b>
💰 <b>السعر:</b> {price} {currency}
📍 <b>العنوان:</b> {address}
🏷 <b>النوع:</b> {prop_type} - {category}
📐 <b>المساحة:</b> {area} م²
🛏 <b>الغرف:</b> {rooms}

📝 <b>الوصف الكامل:</b>
{description}

➖➖➖➖➖➖➖
🔥 <b>هل تبحث عن التفاصيل الأهم؟</b>
التطبيق يحتوي على ما لا يمكن عرضه هنا!
✅ <b>شاهد جولة الفيديو للعقار 🎥</b>
✅ <b>اعرف الموقع الدقيق على الخريطة 🗺️</b>
✅ <b>تواصل مباشرة مع المالك (اتصال/دردشة) 📞</b>

👇 <b>اضغط هنا للانتقال للتطبيق فوراً:</b>
<a href="{deep_link}">🚀 <b>عرض العقار كاملاً والتواصل مع المالك</b></a>
        """

        # التأكد من طول الرسالة (تلغرام يقبل 1024 حرف مع الصورة)
        if len(caption) > 1024:
            caption = caption[:1000] + "...\n\n<a href='{deep_link}'>تكملة التفاصيل في التطبيق 📲</a>"

        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendPhoto"
        
        payload = {
            "chat_id": TELEGRAM_CHANNEL,
            "caption": caption,
            "parse_mode": "HTML"
        }

        if images and len(images) > 0:
            payload["photo"] = images[0] 
            requests.post(url, data=payload)
        else:
            url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
            payload = {
                "chat_id": TELEGRAM_CHANNEL,
                "text": caption, 
                "parse_mode": "HTML",
                "disable_web_page_preview": False
            }
            requests.post(url, data=payload)
            
        print(f"✅ تم النشر بنجاح: {title}")

    except Exception as e:
        print(f"❌ فشل النشر على تلغرام: {e}")

def send_to_whatsapp(property_data, property_id):
    """إرسال العقار إلى واتساب عبر Evolution API"""
    try:
        # --- استخراج البيانات ---
        title = property_data.get('title', 'عقار لقطة')
        price = property_data.get('price', 0)
        currency = property_data.get('currency', 'ر.س')
        description = property_data.get('description', '')
        images = property_data.get('imageUrls', [])
        
        # بيانات إضافية
        category = property_data.get('category', 'غير محدد')
        prop_type = property_data.get('propertyType', 'عقار')
        area = property_data.get('area', 0)
        rooms = property_data.get('rooms', 0)
        address = property_data.get('address', 'موقع مميز')
        
        # رابط العقار
        deep_link = f"https://n4yo.com/property/{property_id}"
        
        # --- صياغة الرسالة ---
        message = f"""
🌟 *فرصة عقارية جديدة في عقار بلص!* 🌟

🏠 *{title}*

📊 *التفاصيل الرئيسية:*
💰 *السعر:* {price} {currency}
📍 *العنوان:* {address}
🏷 *النوع:* {prop_type} - {category}
📐 *المساحة:* {area} م²
🛏 *الغرف:* {rooms}

📝 *الوصف:*
{description}

━━━━━━━━━━━━━━━━━
🔥 *هل تبحث عن التفاصيل الأهم؟*
✅ شاهد جولة الفيديو للعقار 🎥
✅ اعرف الموقع الدقيق على الخريطة 🗺️
✅ تواصل مباشرة مع المالك 📞

👇 *اضغط هنا للانتقال للتطبيق فوراً:*
{deep_link}
        """.strip()
        
        headers = {
            "apikey": EVOLUTION_API_KEY,
            "Content-Type": "application/json"
        }
        
        # إرسال الصورة مع النص (إذا كانت موجودة)
        if images and len(images) > 0:
            url = f"{EVOLUTION_API_URL}/message/sendMedia/{EVOLUTION_INSTANCE}"
            payload = {
                "number": WHATSAPP_NUMBER,
                "mediatype": "image",
                "mimetype": "image/jpeg",
                "media": images[0],
                "caption": message
            }
        else:
            # إرسال نص فقط
            url = f"{EVOLUTION_API_URL}/message/sendText/{EVOLUTION_INSTANCE}"
            payload = {
                "number": WHATSAPP_NUMBER,
                "text": message
            }
        
        response = requests.post(url, json=payload, headers=headers, timeout=15)
        
        if response.status_code == 201 or response.status_code == 200:
            print(f"✅ تم النشر على واتساب بنجاح: {title}")
            return True
        else:
            print(f"⚠️ فشل النشر على واتساب: {response.status_code} - {response.text[:200]}")
            return False
            
    except Exception as e:
        print(f"❌ خطأ في إرسال واتساب: {e}")
        return False

def on_snapshot(col_snapshot, changes, read_time):
    for change in changes:
        if change.type.name == 'ADDED':
            doc = change.document
            data = doc.to_dict()
            
            created_at = data.get('createdAt')
            if created_at:
                prop_time = created_at.timestamp()
                # تجاهل العقارات القديمة (أكثر من دقيقتين) لتجنب التكرار عند التشغيل
                if (time.time() - prop_time) > 120:
                    continue
            
            print(f"🆕 رصد عقار جديد: {doc.id}")
            print("-" * 60)
            
            # إرسال إلى تلغرام
            send_to_telegram(data, doc.id)
            
            # إرسال إلى واتساب
            send_to_whatsapp(data, doc.id)
            
            print("-" * 60)

col_query = db.collection('properties')
query_watch = col_query.on_snapshot(on_snapshot)

while True:
    time.sleep(1)