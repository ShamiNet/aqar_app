# PM2 Commands Reference

## عرض حالة جميع التطبيقات
```bash
pm2 list
```

## عرض logs drone-backend
```bash
pm2 logs drone-backend
```

## عرض logs aqar-server
```bash
pm2 logs aqar-server
```

## عرض logs aqar-app
```bash
pm2 logs aqar-app
```

## إيقاف drone-backend
```bash
pm2 stop drone-backend
```

## إعادة تشغيل drone-backend
```bash
pm2 restart drone-backend
```

## حذف drone-backend من pm2
```bash
pm2 delete drone-backend
```

## حفظ قائمة العمليات
```bash
pm2 save
```

## إعادة تحميل جميع التطبيقات
```bash
pm2 reload all
```

## إيقاف جميع التطبيقات
```bash
pm2 stop all
```

## حذف جميع التطبيقات
```bash
pm2 delete all
```

## بدء تطبيق جديد
```bash
cd ~/drone-backend
pm2 start server.js --name drone-backend
pm2 save
```

## عرض معلومات تفصيلية عن تطبيق معين
```bash
pm2 show drone-backend
```

## عرض الموارد المستخدمة (CPU, Memory)
```bash
pm2 monit
```

## حفظ الحالة الحالية (Auto-restart)
```bash
pm2 startup
pm2 save
```

## مسح logs
```bash
pm2 flush
```
