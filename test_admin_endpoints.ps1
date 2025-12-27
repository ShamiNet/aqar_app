# سكريبت اختبار سريع لفحص endpoints الـ Admin
# للاستخدام في PowerShell

Write-Host "🔍 اختبار سيرفر Admin..." -ForegroundColor Cyan

$baseUrl = "http://72.60.80.201:3001/api"

# 1. اختبار endpoint /admin/stats
Write-Host "`n📊 اختبار /admin/stats..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/admin/stats" -Method GET -ErrorAction Stop
    Write-Host "✅ نجح! البيانات: $($response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "❌ فشل! الخطأ: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
}

# 2. اختبار endpoint /admin/users
Write-Host "`n👥 اختبار /admin/users..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/admin/users" -Method GET -ErrorAction Stop
    Write-Host "✅ نجح! عدد المستخدمين: $($response.Count)" -ForegroundColor Green
    if ($response.Count -gt 0) {
        Write-Host "   أول مستخدم: $($response[0] | ConvertTo-Json -Compress)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "❌ فشل! الخطأ: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
}

# 3. اختبار endpoint /admin/chats
Write-Host "`n💬 اختبار /admin/chats..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/admin/chats" -Method GET -ErrorAction Stop
    Write-Host "✅ نجح! عدد المحادثات: $($response.Count)" -ForegroundColor Green
} catch {
    Write-Host "❌ فشل! الخطأ: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
}

# 4. اختبار endpoint /admin/reports
Write-Host "`n📝 اختبار /admin/reports..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/admin/reports" -Method GET -ErrorAction Stop
    Write-Host "✅ نجح! عدد البلاغات: $($response.Count)" -ForegroundColor Green
} catch {
    Write-Host "❌ فشل! الخطأ: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
}

Write-Host "`n🏁 انتهى الاختبار!" -ForegroundColor Cyan
Write-Host "If all results are 401/403, endpoints need authentication." -ForegroundColor Gray
Write-Host "If results are 404, endpoints don't exist on server." -ForegroundColor Gray
