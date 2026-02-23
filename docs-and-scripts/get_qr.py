#!/usr/bin/env python3
"""
سكريبت لاستخراج QR Code من Evolution API
يعمل بنظام Retry ويحفظ الصورة محلياً أو يعرض Base64
"""

import requests
import time
import base64
from datetime import datetime
import sys

# ================= الإعدادات =================
API_BASE_URL = "http://localhost:8080"
API_KEY = "shami_secret_key_123"
INSTANCE_NAME = "aqar_bot"
MAX_RETRIES = 30  # محاولات (كل محاولة 5 ثواني = 2.5 دقيقة)
RETRY_DELAY = 5   # ثواني بين كل محاولة
# =============================================

def get_qr_code():
    """استخراج QR Code من Evolution API"""
    
    headers = {
        "apikey": API_KEY,
        "Content-Type": "application/json"
    }
    
    # URL لاستخراج الـ QR
    qr_url = f"{API_BASE_URL}/instance/connect/{INSTANCE_NAME}"
    
    print(f"🔄 جاري محاولة الاتصال بـ Evolution API...")
    print(f"📡 URL: {qr_url}")
    print(f"🔑 Instance: {INSTANCE_NAME}")
    print("-" * 60)
    
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            print(f"\n⏳ المحاولة {attempt}/{MAX_RETRIES}...", end=" ")
            
            # طلب QR Code
            response = requests.get(qr_url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                
                # التحقق من وجود QR Code
                if data.get("count", 0) > 0 and "qrcode" in data:
                    qr_data = data["qrcode"]
                    
                    # حفظ الصورة
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    filename = f"qr_code_{timestamp}.txt"
                    
                    with open(filename, "w", encoding="utf-8") as f:
                        f.write(qr_data["base64"])
                    
                    print(f"\n\n✅ تم الحصول على QR Code بنجاح!")
                    print(f"📄 تم حفظ Base64 في الملف: {filename}")
                    print("-" * 60)
                    print("📱 الآن قم بما يلي:")
                    print("   1. افتح الملف المحفوظ")
                    print("   2. انسخ النص الطويل (Base64)")
                    print("   3. افتح الرابط التالي في متصفح:")
                    print("      https://base64.guru/converter/decode/image")
                    print("   4. الصق النص وحوّله لصورة")
                    print("   5. امسح الـ QR بهاتفك (واتساب > الأجهزة المرتبطة)")
                    print("-" * 60)
                    
                    # طباعة أول 100 حرف من الـ Base64
                    print(f"\n🔍 بداية Base64:")
                    print(qr_data["base64"][:100] + "...")
                    
                    return True
                    
                elif data.get("count", 0) == 0:
                    print("⚠️ لا يوجد QR بعد، السيرفر يعالج الطلب...")
                else:
                    print(f"⚠️ استجابة غير متوقعة: {data}")
                    
            elif response.status_code == 404:
                print(f"❌ Instance غير موجود!")
                print("💡 تأكد من إنشاء Instance أولاً بالأمر:")
                print(f"   curl -X POST {API_BASE_URL}/instance/create \\")
                print(f'        -H "apikey: {API_KEY}" \\')
                print(f'        -d \'{{"instanceName": "{INSTANCE_NAME}"}}\'')
                return False
                
            elif response.status_code == 401:
                print(f"❌ API Key خاطئ!")
                return False
                
            else:
                print(f"⚠️ رمز استجابة غير متوقع: {response.status_code}")
                print(f"   الرد: {response.text[:200]}")
        
        except requests.exceptions.Timeout:
            print("⏰ انتهى وقت الطلب")
        except requests.exceptions.ConnectionError:
            print("🔌 فشل الاتصال بالسيرفر")
            print("💡 تأكد من أن Evolution API يعمل: docker ps")
        except Exception as e:
            print(f"❌ خطأ: {str(e)}")
        
        # انتظار قبل المحاولة التالية
        if attempt < MAX_RETRIES:
            print(f"   ⏳ انتظار {RETRY_DELAY} ثواني...", end="")
            time.sleep(RETRY_DELAY)
            print(" ✓")
    
    print(f"\n\n❌ فشل الحصول على QR Code بعد {MAX_RETRIES} محاولة")
    print("💡 نصائح للحل:")
    print("   1. تحقق من logs: docker logs -f evolution_api")
    print("   2. أعد تشغيل Container: docker restart evolution_api")
    print("   3. تحقق من RAM: free -h")
    print("   4. حاول حذف وإعادة إنشاء Instance")
    return False

def check_instance_status():
    """التحقق من حالة Instance"""
    
    headers = {
        "apikey": API_KEY
    }
    
    status_url = f"{API_BASE_URL}/instance/connectionState/{INSTANCE_NAME}"
    
    try:
        print(f"🔍 جاري فحص حالة Instance...")
        response = requests.get(status_url, headers=headers, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            state = data.get("instance", {}).get("state", "unknown")
            print(f"📊 الحالة الحالية: {state}")
            
            if state == "open":
                print("✅ Instance متصل بالفعل!")
                return True
            elif state == "connecting":
                print("⏳ Instance في حالة اتصال...")
            elif state == "close":
                print("⚠️ Instance مغلق، يحتاج لإعادة مسح QR")
            else:
                print(f"⚠️ حالة غير متوقعة: {state}")
        else:
            print(f"⚠️ لم نستطع فحص الحالة: {response.status_code}")
    except Exception as e:
        print(f"⚠️ خطأ في فحص الحالة: {e}")
    
    return False

if __name__ == "__main__":
    print("=" * 60)
    print("🤖 Evolution API - QR Code Extractor")
    print("=" * 60)
    
    # فحص الحالة أولاً
    if check_instance_status():
        print("\n✅ الواتساب متصل بالفعل! لا حاجة لـ QR جديد")
        sys.exit(0)
    
    print()
    
    # استخراج QR Code
    success = get_qr_code()
    
    if success:
        print("\n✅ العملية نجحت! امسح الـ QR الآن")
        sys.exit(0)
    else:
        print("\n❌ فشلت العملية")
        sys.exit(1)
