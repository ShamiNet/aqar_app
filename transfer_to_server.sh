#!/bin/bash

# ============================================================
# سكريبت نقل الملفات من Windows إلى السيرفر (Linux)
# استخدم هذا السكريبت على Git Bash أو WSL
# ============================================================

# 🔧 عدّل هذه المعلومات:
SERVER_IP="YOUR_SERVER_IP"          # مثال: 192.168.1.100
SERVER_USER="root"                  # عادة root
SERVER_PATH="/root"                 # المسار على السيرفر

# الألوان
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================================${NC}"
echo -e "${BLUE}نقل ملفات البوت إلى السيرفر${NC}"
echo -e "${BLUE}============================================================${NC}"

# التحقق من أن المعلومات تم تحديثها
if [ "$SERVER_IP" == "YOUR_SERVER_IP" ]; then
    echo "❌ يجب تحديث SERVER_IP في السكريبت أولاً!"
    exit 1
fi

echo ""
echo "📡 السيرفر: $SERVER_USER@$SERVER_IP"
echo "📁 المسار: $SERVER_PATH"
echo ""

# الملفات المطلوب نقلها
FILES=(
    "noteShami.py"
    "get_qr.py"
    "test_evolution.py"
    "setup_whatsapp.sh"
    "config.env"
)

# نقل كل ملف
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "📤 نقل: $file"
        scp "$file" "$SERVER_USER@$SERVER_IP:$SERVER_PATH/"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ تم نقل $file${NC}"
        else
            echo "❌ فشل نقل $file"
        fi
    else
        echo "⚠️  الملف غير موجود: $file"
    fi
    echo ""
done

# جعل الملفات قابلة للتنفيذ
echo "🔧 جعل السكريبتات قابلة للتنفيذ..."
ssh "$SERVER_USER@$SERVER_IP" "chmod +x $SERVER_PATH/setup_whatsapp.sh"

echo ""
echo -e "${GREEN}✅ تم نقل جميع الملفات!${NC}"
echo ""
echo "📋 الخطوات التالية:"
echo "  1. اتصل بالسيرفر: ssh $SERVER_USER@$SERVER_IP"
echo "  2. فعّل البيئة: source aqar_env/bin/activate"
echo "  3. شغّل الأداة: ./setup_whatsapp.sh"
echo ""
echo "أو:"
echo "  python3 get_qr.py"
echo ""
