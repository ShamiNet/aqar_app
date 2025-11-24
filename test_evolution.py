#!/usr/bin/env python3
"""
سكريبت اختبار شامل لـ Evolution API
يتحقق من الاتصال، حالة Instance، وإرسال رسالة تجريبية
"""

import requests
import json
from datetime import datetime

# ================= الإعدادات =================
API_BASE_URL = "http://localhost:8080"
API_KEY = "shami_secret_key_123"
INSTANCE_NAME = "aqar_bot"
TEST_NUMBER = "966XXXXXXXXX@s.whatsapp.net"  # رقم اختبار (اجعله رقمك للتجربة)
# =============================================

def test_api_health():
    """اختبار 1: هل السيرفر يعمل؟"""
    print("\n" + "="*60)
    print("🧪 اختبار 1: التحقق من صحة السيرفر")
    print("="*60)
    
    try:
        # بعض endpoints لا تحتاج API Key
        response = requests.get(f"{API_BASE_URL}/", timeout=5)
        
        if response.status_code in [200, 404]:
            print("✅ السيرفر يعمل ويستجيب")
            return True
        else:
            print(f"⚠️ السيرفر يستجيب لكن بكود غير متوقع: {response.status_code}")
            return True
    except requests.exceptions.ConnectionError:
        print("❌ فشل الاتصال بالسيرفر!")
        print("💡 تحقق من:")
        print("   - docker ps (تأكد أن evolution_api يعمل)")
        print("   - docker logs -f evolution_api")
        return False
    except Exception as e:
        print(f"❌ خطأ: {e}")
        return False

def test_list_instances():
    """اختبار 2: عرض قائمة Instances"""
    print("\n" + "="*60)
    print("🧪 اختبار 2: عرض قائمة Instances")
    print("="*60)
    
    headers = {"apikey": API_KEY}
    
    try:
        response = requests.get(
            f"{API_BASE_URL}/instance/fetchInstances",
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 200:
            instances = response.json()
            print(f"✅ تم الحصول على قائمة Instances:")
            print(json.dumps(instances, indent=2, ensure_ascii=False))
            
            # البحث عن instance المطلوب
            if isinstance(instances, list):
                for inst in instances:
                    if inst.get("instance", {}).get("instanceName") == INSTANCE_NAME:
                        print(f"\n✅ تم العثور على Instance: {INSTANCE_NAME}")
                        return True
            
            print(f"\n⚠️ لم يتم العثور على Instance بالاسم: {INSTANCE_NAME}")
            return False
        else:
            print(f"❌ فشل الطلب: {response.status_code}")
            print(f"   الرد: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ خطأ: {e}")
        return False

def test_instance_status():
    """اختبار 3: فحص حالة Instance المحددة"""
    print("\n" + "="*60)
    print("🧪 اختبار 3: فحص حالة Instance")
    print("="*60)
    
    headers = {"apikey": API_KEY}
    
    try:
        response = requests.get(
            f"{API_BASE_URL}/instance/connectionState/{INSTANCE_NAME}",
            headers=headers,
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ بيانات Instance:")
            print(json.dumps(data, indent=2, ensure_ascii=False))
            
            state = data.get("instance", {}).get("state", "unknown")
            print(f"\n📊 الحالة: {state}")
            
            if state == "open":
                print("✅ Instance متصل وجاهز للإرسال!")
                return True
            elif state == "close":
                print("⚠️ Instance مغلق - يحتاج لمسح QR Code")
                print("💡 استخدم: python3 get_qr.py")
                return False
            elif state == "connecting":
                print("⏳ Instance في حالة اتصال...")
                return False
            else:
                print(f"⚠️ حالة غير معروفة: {state}")
                return False
        else:
            print(f"❌ فشل الطلب: {response.status_code}")
            print(f"   الرد: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ خطأ: {e}")
        return False

def test_send_message():
    """اختبار 4: إرسال رسالة تجريبية"""
    print("\n" + "="*60)
    print("🧪 اختبار 4: إرسال رسالة تجريبية")
    print("="*60)
    
    if "XXXXXXXXX" in TEST_NUMBER:
        print("⚠️ تم تخطي الاختبار - لم يتم تعيين رقم اختبار حقيقي")
        print("💡 عدّل TEST_NUMBER في بداية الملف")
        return False
    
    headers = {
        "apikey": API_KEY,
        "Content-Type": "application/json"
    }
    
    payload = {
        "number": TEST_NUMBER,
        "text": f"🤖 رسالة اختبار من عقار بلص\n⏰ {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n✅ Evolution API يعمل بنجاح!"
    }
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/message/sendText/{INSTANCE_NAME}",
            json=payload,
            headers=headers,
            timeout=15
        )
        
        if response.status_code in [200, 201]:
            print("✅ تم إرسال الرسالة بنجاح!")
            print(f"   الرد: {response.text[:300]}")
            return True
        else:
            print(f"❌ فشل الإرسال: {response.status_code}")
            print(f"   الرد: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ خطأ: {e}")
        return False

def test_send_image():
    """اختبار 5: إرسال صورة تجريبية"""
    print("\n" + "="*60)
    print("🧪 اختبار 5: إرسال صورة تجريبية")
    print("="*60)
    
    if "XXXXXXXXX" in TEST_NUMBER:
        print("⚠️ تم تخطي الاختبار - لم يتم تعيين رقم اختبار")
        return False
    
    headers = {
        "apikey": API_KEY,
        "Content-Type": "application/json"
    }
    
    # صورة اختبار (يمكن استبدالها بصورة حقيقية)
    test_image = "https://picsum.photos/800/600"
    
    payload = {
        "number": TEST_NUMBER,
        "mediatype": "image",
        "mimetype": "image/jpeg",
        "media": test_image,
        "caption": f"🏠 اختبار إرسال صورة عقار\n⏰ {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    }
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/message/sendMedia/{INSTANCE_NAME}",
            json=payload,
            headers=headers,
            timeout=20
        )
        
        if response.status_code in [200, 201]:
            print("✅ تم إرسال الصورة بنجاح!")
            print(f"   الرد: {response.text[:300]}")
            return True
        else:
            print(f"❌ فشل إرسال الصورة: {response.status_code}")
            print(f"   الرد: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ خطأ: {e}")
        return False

def main():
    """تشغيل جميع الاختبارات"""
    print("\n" + "="*60)
    print("🤖 Evolution API - مجموعة اختبارات شاملة")
    print("="*60)
    print(f"📡 السيرفر: {API_BASE_URL}")
    print(f"🔑 Instance: {INSTANCE_NAME}")
    print("="*60)
    
    results = {
        "صحة السيرفر": test_api_health(),
        "قائمة Instances": test_list_instances(),
        "حالة Instance": test_instance_status(),
    }
    
    # اختبارات الإرسال فقط إذا كان Instance متصل
    if results["حالة Instance"]:
        results["إرسال رسالة نصية"] = test_send_message()
        results["إرسال صورة"] = test_send_image()
    
    # النتيجة النهائية
    print("\n" + "="*60)
    print("📊 ملخص النتائج:")
    print("="*60)
    
    for test_name, result in results.items():
        icon = "✅" if result else "❌"
        print(f"{icon} {test_name}")
    
    print("="*60)
    
    passed = sum(results.values())
    total = len(results)
    
    print(f"\n📈 النتيجة: {passed}/{total} اختبارات نجحت")
    
    if passed == total:
        print("✅ جميع الاختبارات نجحت! Evolution API جاهز للعمل 🎉")
    elif results["حالة Instance"]:
        print("✅ Instance متصل، لكن هناك مشاكل في الإرسال")
    else:
        print("⚠️ Instance غير متصل - استخدم get_qr.py لمسح QR Code")
    
    print("="*60)

if __name__ == "__main__":
    main()
