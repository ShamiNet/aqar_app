const { default: makeWASocket, DisconnectReason, useMultiFileAuthState } = require('@whiskeysockets/baileys');
const qrcode = require('qrcode-terminal');
const { Boom } = require('@hapi/boom');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// ================= الإعدادات =================
const TELEGRAM_BOT_TOKEN = "8047447151:AAGFT88l2BskNm0Z4T-ehHNVBxox9g34L40";
const TELEGRAM_CHANNEL = "@aqarShami";
const WHATSAPP_NUMBER = "966XXXXXXXXX@s.whatsapp.net"; // غيّر هذا لرقمك
const FIREBASE_CREDENTIALS = './serviceAccountKey.json';
const APP_DOMAIN = "https://s313.store";
// =============================================

// تهيئة Firebase
const serviceAccount = require(FIREBASE_CREDENTIALS);
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

// متغير للاتصال بالواتساب
let sock;
let isConnected = false;
let reconnectAttempts = 0;
const MAX_RECONNECT_DELAY_MS = 60000; // 1 minute cap

// دالة إرسال إلى تلغرام
async function sendToTelegram(propertyData, propertyId) {
    try {
        const { title = 'عقار لقطة', price = 0, currency = 'ر.س', description = '', 
                imageUrls = [], category = 'غير محدد', propertyType = 'عقار',
                area = 0, rooms = 0, address = 'موقع مميز' } = propertyData;
        
        const deepLink = `${APP_DOMAIN}/property/${propertyId}`;
        
        const caption = `
🌟 *فرصة عقارية جديدة في عقار بلس!* 🌟

🏠 *${title}*

📊 *التفاصيل الرئيسية:*
💰 *السعر:* ${price} ${currency}
📍 *العنوان:* ${address}
🏷 *النوع:* ${propertyType} - ${category}
📐 *المساحة:* ${area} م²
🛏 *الغرف:* ${rooms}

📝 *الوصف:*
${description}

━━━━━━━━━━━━━━━━━
🔥 *هل تبحث عن التفاصيل الأهم؟*
✅ شاهد جولة الفيديو للعقار 🎥
✅ اعرف الموقع الدقيق على الخريطة 🗺️
✅ تواصل مباشرة مع المالك 📞

👇 *اضغط هنا للانتقال للتطبيق:*
${deepLink}
        `.trim();

        const axios = require('axios');
        const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto`;
        
        if (imageUrls && imageUrls.length > 0) {
            await axios.post(url, {
                chat_id: TELEGRAM_CHANNEL,
                photo: imageUrls[0],
                caption: caption,
                parse_mode: 'Markdown'
            });
        } else {
            await axios.post(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
                chat_id: TELEGRAM_CHANNEL,
                text: caption,
                parse_mode: 'Markdown'
            });
        }
        
        console.log(`✅ تم النشر على تلغرام: ${title}`);
    } catch (error) {
        console.error(`❌ فشل النشر على تلغرام:`, error.message);
    }
}

// دالة إرسال إلى واتساب
async function sendToWhatsApp(propertyData, propertyId) {
    if (!isConnected) {
        console.log('⚠️ الواتساب غير متصل بعد');
        return;
    }

    try {
        const { title = 'عقار لقطة', price = 0, currency = 'ر.س', description = '', 
                imageUrls = [], category = 'غير محدد', propertyType = 'عقار',
                area = 0, rooms = 0, address = 'موقع مميز' } = propertyData;
        
        const deepLink = `${APP_DOMAIN}/property/${propertyId}`;
        
        const message = `
🌟 *فرصة عقارية جديدة في عقار بلس!* 🌟

🏠 *${title}*

📊 *التفاصيل الرئيسية:*
💰 *السعر:* ${price} ${currency}
📍 *العنوان:* ${address}
🏷 *النوع:* ${propertyType} - ${category}
📐 *المساحة:* ${area} م²
🛏 *الغرف:* ${rooms}

📝 *الوصف:*
${description}

━━━━━━━━━━━━━━━━━
🔥 *هل تبحث عن التفاصيل الأهم؟*
✅ شاهد جولة الفيديو للعقار 🎥
✅ اعرف الموقع الدقيق على الخريطة 🗺️
✅ تواصل مباشرة مع المالك 📞

👇 *اضغط هنا للانتقال للتطبيق:*
${deepLink}
        `.trim();

        // إرسال الصورة والنص
        if (imageUrls && imageUrls.length > 0) {
            await sock.sendMessage(WHATSAPP_NUMBER, {
                image: { url: imageUrls[0] },
                caption: message
            });
        } else {
            await sock.sendMessage(WHATSAPP_NUMBER, { text: message });
        }
        
        console.log(`✅ تم النشر على واتساب: ${title}`);
    } catch (error) {
        console.error(`❌ فشل النشر على واتساب:`, error.message);
    }
}

// دالة الاتصال بالواتساب
async function connectToWhatsApp() {
    const { state, saveCreds } = await useMultiFileAuthState('auth_info_baileys');

    sock = makeWASocket({
        auth: state,
        browser: ['Aqar Plus Bot', 'Chrome', '1.0.0'],
        syncFullHistory: false
    });

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr) {
            console.log('\n📱 امسح هذا الـ QR خلال 60 ثانية من واتساب -> الأجهزة المرتبطة:');
            try {
                qrcode.generate(qr, { small: true });
            } catch (e) {
                console.log('QR:', qr);
            }
            console.log('\nإذا انتهت صلاحية الكود سيظهر واحد جديد تلقائياً.\n');
        }

        if (connection === 'open') {
            reconnectAttempts = 0;
            isConnected = true;
            console.log('✅ تم الاتصال بالواتساب بنجاح! جاهز للإرسال.');
        } else if (connection === 'close') {
            isConnected = false;
            const error = lastDisconnect?.error;
            const statusCode = (error instanceof Boom) ? error.output.statusCode : undefined;
            let reason = 'غير معروف';
            if (statusCode === DisconnectReason.loggedOut) reason = 'تم تسجيل الخروج - حذف بيانات الاعتماد مطلوب';
            else if (statusCode === DisconnectReason.connectionLost) reason = 'انقطاع الاتصال';
            else if (statusCode === DisconnectReason.restartRequired) reason = 'مطلوب إعادة تشغيل';
            else if (statusCode === DisconnectReason.timedOut) reason = 'انتهت مهلة الاتصال';

            console.log(`❌ اتصال الواتساب مغلق (${reason}).`);

            const shouldReconnect = statusCode !== DisconnectReason.loggedOut;
            if (!shouldReconnect) {
                console.log('🛑 لن يُعاد الاتصال تلقائياً. احذف مجلد auth_info_baileys ثم شغّل من جديد لمسح QR جديد.');
                return;
            }

            reconnectAttempts++;
            const delay = Math.min(3000 * Math.pow(1.5, reconnectAttempts - 1), MAX_RECONNECT_DELAY_MS);
            console.log(`🔁 محاولة إعادة اتصال #${reconnectAttempts} خلال ${(delay/1000).toFixed(1)} ثانية...`);
            setTimeout(connectToWhatsApp, delay);
        }
    });

    sock.ev.on('messages.upsert', (m) => {
        // احتياطي لإظهار أي رسائل واردة (مفيدة أثناء الاختبار)
        if (m.type === 'notify') {
            m.messages.forEach(msg => {
                if (msg.message?.conversation) {
                    console.log(`💬 رسالة واردة من ${msg.key.remoteJid}: ${msg.message.conversation}`);
                }
            });
        }
    });
}

// دالة مراقبة Firestore
function startFirestoreListener() {
    console.log('🔄 بدء مراقبة قاعدة البيانات...');
    
    const propertiesRef = db.collection('properties');
    
    propertiesRef.onSnapshot((snapshot) => {
        snapshot.docChanges().forEach(async (change) => {
            if (change.type === 'added') {
                const data = change.doc.data();
                const docId = change.doc.id;
                
                // تجاهل العقارات القديمة (أكثر من دقيقتين)
                if (data.createdAt) {
                    const propTime = data.createdAt.toMillis();
                    const now = Date.now();
                    if ((now - propTime) > 120000) {
                        return;
                    }
                }
                
                console.log(`\n🆕 رصد عقار جديد: ${docId}`);
                console.log('─'.repeat(60));
                
                // إرسال إلى تلغرام
                await sendToTelegram(data, docId);
                
                // إرسال إلى واتساب
                await sendToWhatsApp(data, docId);
                
                console.log('─'.repeat(60));
            }
        });
    }, (error) => {
        console.error('❌ خطأ في مراقبة Firestore:', error);
    });
}

// بدء التطبيق
async function main() {
    console.log('═'.repeat(60));
    console.log('🚀 بوت عقار بلس - نظام النشر التلقائي');
    console.log('═'.repeat(60));
    
    // الاتصال بالواتساب
    await connectToWhatsApp();
    
    // بدء مراقبة Firebase
    startFirestoreListener();
    
    console.log('\n✅ البوت يعمل الآن! اضغط Ctrl+C للإيقاف\n');
}

// معالجة الإيقاف النظيف
process.on('SIGINT', () => {
    console.log('\n\n🛑 إيقاف البوت...');
    process.exit(0);
});

// بدء التطبيق
main().catch(console.error);
