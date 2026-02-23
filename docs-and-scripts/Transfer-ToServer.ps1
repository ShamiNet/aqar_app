# ============================================================
# سكريبت PowerShell لنقل الملفات إلى السيرفر
# استخدم هذا على Windows PowerShell
# ============================================================

# 🔧 عدّل هذه المعلومات:
$SERVER_IP = "qaaz.live"            # عنوان السيرفر
$SERVER_USER = "root"                # عادة root
$SERVER_PATH = "/root"               # المسار على السيرفر

Write-Host "============================================================" -ForegroundColor Blue
Write-Host "نقل ملفات البوت إلى السيرفر" -ForegroundColor Blue
Write-Host "============================================================" -ForegroundColor Blue

Write-Host ""
Write-Host "📡 السيرفر: $SERVER_USER@$SERVER_IP"
Write-Host "📁 المسار: $SERVER_PATH"
Write-Host ""

# الملفات المطلوب نقلها
$files = @(
    "noteShami.py",
    "get_qr.py",
    "test_evolution.py",
    "setup_whatsapp.sh",
    "config.env"
)

# التحقق من وجود SCP
$scpPath = Get-Command scp -ErrorAction SilentlyContinue

if (-not $scpPath) {
    Write-Host "❌ SCP غير موجود!" -ForegroundColor Red
    Write-Host ""
    Write-Host "الحلول المتاحة:" -ForegroundColor Yellow
    Write-Host "1. استخدم WinSCP (https://winscp.net/)" -ForegroundColor Yellow
    Write-Host "2. ثبّت Git for Windows (يحتوي على SCP)" -ForegroundColor Yellow
    Write-Host "3. استخدم WSL" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "أو انسخ الملفات يدوياً باستخدام WinSCP:"
    foreach ($file in $files) {
        Write-Host "  - $file"
    }
    exit
}

# نقل كل ملف
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "📤 نقل: $file" -ForegroundColor Cyan
        
        & scp $file "${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ تم نقل $file" -ForegroundColor Green
        } else {
            Write-Host "❌ فشل نقل $file" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠️  الملف غير موجود: $file" -ForegroundColor Yellow
    }
    Write-Host ""
}

# جعل الملفات قابلة للتنفيذ
Write-Host "🔧 جعل السكريبتات قابلة للتنفيذ..." -ForegroundColor Cyan
& ssh "${SERVER_USER}@${SERVER_IP}" "chmod +x ${SERVER_PATH}/setup_whatsapp.sh"

Write-Host ""
Write-Host "✅ تم نقل جميع الملفات!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 الخطوات التالية:" -ForegroundColor Yellow
Write-Host "  1. اتصل بالسيرفر: ssh $SERVER_USER@$SERVER_IP"
Write-Host "  2. فعّل البيئة: source aqar_env/bin/activate"
Write-Host "  3. شغّل الأداة: ./setup_whatsapp.sh"
Write-Host ""
Write-Host "أو مباشرة:" -ForegroundColor Yellow
Write-Host "  python3 get_qr.py"
Write-Host ""
