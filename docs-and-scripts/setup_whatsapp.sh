#!/bin/bash

# =============================================================
# سكريبت إعداد وتشغيل Evolution API للواتساب
# تطبيق عقار بلس - نظام النشر التلقائي
# =============================================================

# الألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # بدون لون

# المتغيرات
INSTANCE_NAME="aqar_bot"
API_KEY="shami_secret_key_123"
API_URL="http://localhost:8080"

# =============================================================
# دوال مساعدة
# =============================================================

print_header() {
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# =============================================================
# الوظائف الرئيسية
# =============================================================

check_docker() {
    print_header "التحقق من Docker"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker غير مثبت!"
        echo "قم بتثبيت Docker أولاً: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    print_success "Docker مثبت"
    
    if ! docker ps &> /dev/null; then
        print_error "Docker لا يعمل أو ليس لديك صلاحيات!"
        echo "جرّب: sudo systemctl start docker"
        exit 1
    fi
    
    print_success "Docker يعمل بشكل صحيح"
}

check_evolution_api() {
    print_header "التحقق من Evolution API"
    
    if docker ps | grep -q "evolution_api"; then
        print_success "Evolution API يعمل"
        docker ps | grep evolution
    else
        print_error "Evolution API لا يعمل!"
        print_info "تحقق من docker-compose.yml وشغّل: docker-compose up -d"
        exit 1
    fi
}

check_api_response() {
    print_header "اختبار الاتصال بالـ API"
    
    if curl -s --connect-timeout 5 "$API_URL" &> /dev/null; then
        print_success "السيرفر يستجيب على $API_URL"
    else
        print_error "لا يمكن الاتصال بالسيرفر!"
        print_info "تأكد من أن Evolution API يعمل"
        exit 1
    fi
}

create_instance() {
    print_header "إنشاء Instance جديد: $INSTANCE_NAME"
    
    response=$(curl -s -X POST "$API_URL/instance/create" \
        -H "apikey: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"instanceName\": \"$INSTANCE_NAME\", \"qrcode\": true, \"integration\": \"WHATSAPP-BAILEYS\"}")
    
    if echo "$response" | grep -q "instanceName"; then
        print_success "تم إنشاء Instance بنجاح"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        print_warning "Instance قد يكون موجود مسبقاً أو حدث خطأ"
        echo "$response"
    fi
}

delete_instance() {
    print_header "حذف Instance: $INSTANCE_NAME"
    
    read -p "هل أنت متأكد من حذف Instance؟ (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "تم الإلغاء"
        return
    fi
    
    response=$(curl -s -X DELETE "$API_URL/instance/delete/$INSTANCE_NAME" \
        -H "apikey: $API_KEY")
    
    print_success "تم إرسال طلب الحذف"
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
}

check_instance_status() {
    print_header "فحص حالة Instance: $INSTANCE_NAME"
    
    response=$(curl -s -X GET "$API_URL/instance/connectionState/$INSTANCE_NAME" \
        -H "apikey: $API_KEY")
    
    state=$(echo "$response" | jq -r '.instance.state' 2>/dev/null)
    
    if [ "$state" == "open" ]; then
        print_success "Instance متصل وجاهز! ✅"
    elif [ "$state" == "close" ]; then
        print_warning "Instance مغلق - يحتاج لمسح QR Code"
    elif [ "$state" == "connecting" ]; then
        print_info "Instance في حالة اتصال..."
    else
        print_error "حالة غير معروفة: $state"
    fi
    
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
}

get_qr_code() {
    print_header "استخراج QR Code"
    
    print_info "جاري طلب QR Code... (قد يستغرق بضع ثوان)"
    
    for i in {1..30}; do
        echo -ne "${YELLOW}محاولة $i/30...\r${NC}"
        
        response=$(curl -s -X GET "$API_URL/instance/connect/$INSTANCE_NAME" \
            -H "apikey: $API_KEY")
        
        count=$(echo "$response" | jq -r '.count' 2>/dev/null)
        
        if [ "$count" == "1" ] || [ "$count" -gt 0 ]; then
            echo ""
            print_success "تم الحصول على QR Code!"
            
            # حفظ Base64
            qr_base64=$(echo "$response" | jq -r '.qrcode.base64' 2>/dev/null)
            
            if [ ! -z "$qr_base64" ] && [ "$qr_base64" != "null" ]; then
                timestamp=$(date +"%Y%m%d_%H%M%S")
                filename="qr_code_$timestamp.txt"
                echo "$qr_base64" > "$filename"
                print_success "تم حفظ Base64 في: $filename"
                
                echo ""
                print_info "الخطوات التالية:"
                echo "  1. افتح: https://base64.guru/converter/decode/image"
                echo "  2. الصق محتوى الملف: $filename"
                echo "  3. حوّل إلى صورة"
                echo "  4. امسح QR Code بواتساب (الأجهزة المرتبطة)"
                
                # محاولة طباعة الـ QR في Terminal (إذا كان qrencode متوفر)
                if command -v qrencode &> /dev/null; then
                    echo ""
                    print_info "يمكنك أيضاً مسح QR مباشرة من Terminal:"
                    echo "$qr_base64" | base64 -d 2>/dev/null | qrencode -t ANSIUTF8
                fi
            fi
            
            return 0
        fi
        
        sleep 5
    done
    
    echo ""
    print_error "فشل الحصول على QR Code بعد 30 محاولة"
    print_info "نصائح:"
    echo "  - تحقق من RAM: free -h"
    echo "  - أعد تشغيل: docker restart evolution_api"
    echo "  - راجع Logs: docker logs -f evolution_api"
}

restart_evolution() {
    print_header "إعادة تشغيل Evolution API"
    
    print_info "جاري إيقاف Container..."
    docker stop evolution_api
    
    print_info "جاري تشغيل Container..."
    docker start evolution_api
    
    sleep 5
    
    if docker ps | grep -q "evolution_api"; then
        print_success "تم إعادة التشغيل بنجاح"
    else
        print_error "فشلت إعادة التشغيل!"
    fi
}

show_logs() {
    print_header "عرض Logs (اضغط Ctrl+C للخروج)"
    docker logs -f evolution_api
}

test_send_message() {
    print_header "إرسال رسالة تجريبية"
    
    read -p "أدخل رقم الواتساب (مثال: 966501234567): " phone
    
    if [ -z "$phone" ]; then
        print_error "لم يتم إدخال رقم!"
        return
    fi
    
    number="${phone}@s.whatsapp.net"
    
    print_info "جاري إرسال رسالة إلى: $number"
    
    message="🤖 رسالة اختبار من عقار بلس\n⏰ $(date '+%Y-%m-%d %H:%M:%S')\n✅ Evolution API يعمل بنجاح!"
    
    response=$(curl -s -X POST "$API_URL/message/sendText/$INSTANCE_NAME" \
        -H "apikey: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"number\": \"$number\", \"text\": \"$message\"}")
    
    if echo "$response" | grep -q "key"; then
        print_success "تم إرسال الرسالة بنجاح!"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        print_error "فشل إرسال الرسالة"
        echo "$response"
    fi
}

show_menu() {
    echo ""
    print_header "قائمة الإعدادات - Evolution API"
    echo ""
    echo "1) التحقق من حالة النظام"
    echo "2) إنشاء Instance جديد"
    echo "3) فحص حالة Instance"
    echo "4) استخراج QR Code"
    echo "5) إرسال رسالة تجريبية"
    echo "6) حذف Instance"
    echo "7) إعادة تشغيل Evolution API"
    echo "8) عرض Logs"
    echo "9) تشغيل Python Scripts (get_qr.py / test_evolution.py)"
    echo "0) خروج"
    echo ""
    read -p "اختر رقم: " choice
    
    case $choice in
        1)
            check_docker
            check_evolution_api
            check_api_response
            ;;
        2)
            create_instance
            ;;
        3)
            check_instance_status
            ;;
        4)
            get_qr_code
            ;;
        5)
            test_send_message
            ;;
        6)
            delete_instance
            ;;
        7)
            restart_evolution
            ;;
        8)
            show_logs
            ;;
        9)
            echo ""
            echo "أ) تشغيل get_qr.py"
            echo "ب) تشغيل test_evolution.py"
            read -p "اختر: " sub
            if [ "$sub" == "أ" ] || [ "$sub" == "a" ]; then
                python3 get_qr.py
            elif [ "$sub" == "ب" ] || [ "$sub" == "b" ]; then
                python3 test_evolution.py
            fi
            ;;
        0)
            print_success "إلى اللقاء!"
            exit 0
            ;;
        *)
            print_error "خيار غير صحيح!"
            ;;
    esac
    
    read -p "اضغط Enter للمتابعة..."
    show_menu
}

# =============================================================
# البداية
# =============================================================

clear
print_header "🤖 Evolution API - أداة الإعداد السريع"
echo ""
echo "تطبيق عقار بلس - نظام النشر التلقائي"
echo "Instance: $INSTANCE_NAME"
echo "API URL: $API_URL"
echo ""

# فحص سريع
check_docker
check_evolution_api
check_api_response

# عرض القائمة
show_menu
