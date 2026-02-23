# ========================================
# 🚀 PowerShell: رفع assetlinks.json للسيرفر
# ========================================

Write-Host "📁 إنشاء المجلد على السيرفر..." -ForegroundColor Cyan
ssh root@s313.store "mkdir -p /var/www/html/.well-known"

Write-Host "`n📤 رفع ملف assetlinks.json..." -ForegroundColor Cyan
scp assetlinks.json root@s313.store:/var/www/html/.well-known/assetlinks.json

Write-Host "`n🔧 ضبط الصلاحيات..." -ForegroundColor Cyan
ssh root@s313.store "chmod 644 /var/www/html/.well-known/assetlinks.json"

Write-Host "`n✅ التحقق من رفع الملف..." -ForegroundColor Cyan
ssh root@s313.store "cat /var/www/html/.well-known/assetlinks.json"

Write-Host "`n🎉 تم رفع الملف بنجاح!" -ForegroundColor Green
Write-Host "تحقق من الرابط: https://s313.store/.well-known/assetlinks.json" -ForegroundColor Yellow
