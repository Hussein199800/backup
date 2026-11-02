# 📦 نسخ احتياطي تلقائي لـ GitHub ← Google Drive + تيلجرام

كل 6 ساعات بيتم التالي:
- نسخ **كل مستودعاتك** (العامة والخاصة) مع كامل التاريخ، وبيتجاوز المستودعات اللي ما تغيّرت
- تنزيل ملفات **APK/AAB** من الـ Releases ومن GitHub Actions
- رفع كل شي على Drive، وتيلجرام بيبعتلك ملخص

## شكل الملفات على Drive
```
GitHub-Backup/
├── repos/<اسم>.bundle         ← الكود كامل
├── apks/<اسم>/releases/<tag>/
├── apks/<اسم>/actions/<id>/
├── secure/                    ← مفاتيحك (مشفّرة)
└── state.json
```

## التركيب (مرة وحدة، حوالي 10 دقايق)

**1. المستودع:** اعمل مستودع **خاص (Private)** اسمه `backup`، وانقل عليه محتوى هالمجلد كله، ومعه مجلد `.github`.

**2. توكن GitHub:** افتح Settings ← Developer settings ← Tokens (classic) ← Generate، واختار صلاحية `repo`.

**3. ربط Drive (من جهازك):**
```bash
rclone config
# n → الاسم: drive  → النوع: drive → كمّل بالافتراضي وسجّل دخول
# n → الاسم: secure → النوع: crypt → remote: drive:GitHub-Backup/secure → حط كلمة سر
rclone config file   # بيعطيك مكان الملف، انسخ محتواه
```
> ⚠️ **اكتب كلمة سر `secure` بمكان آمن.** إذا ضاعت ما في أي طريقة ترجع فيها المفاتيح.

**4. بوت تيلجرام:** افتح @BotFather واكتب `/newbot` وخود الـ token. بعدين ابعت أي رسالة للبوت، وافتح
`https://api.telegram.org/bot<TOKEN>/getUpdates` وانسخ الرقم اللي بعد `"chat":{"id":`.

**5. أضف الأسرار:** بمستودع `backup` روح على Settings ← Secrets ← Actions:

| الاسم | القيمة |
|---|---|
| `GH_PAT` | توكن الخطوة 2 |
| `RCLONE_CONF` | محتوى ملف rclone.conf |
| `TG_BOT_TOKEN` | توكن البوت |
| `TG_CHAT_ID` | رقم المحادثة |

**6. التجربة:** Actions ← GitHub Backup ← **Run workflow**.

## المفاتيح السرية والـ APK اللي على جهازك
حط الـ keystore وملفات `.env` و`google-services.json` والـ APK المحلية بمجلد واحد، وبعدين شغّل:
```bash
./local-backup.sh ~/MyVault
```
الملفات بتترفع **مشفّرة** على `secure/`. ولما بدك ترجعها: `rclone copy secure: ~/Restore`

## استرجاع مستودع
```bash
git clone myrepo.bundle myrepo
```
