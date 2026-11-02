#!/usr/bin/env bash
# رفع الأشياء اللي على جهازك (APK محلية + مفاتيح سرية) إلى Drive مشفّرة
# الاستخدام:  ./local-backup.sh ~/MyVault
set -euo pipefail
SRC="${1:?حدد المجلد: ./local-backup.sh ~/MyVault}"
rclone copy "$SRC" "secure:" --progress
echo "✅ تم الرفع المشفّر إلى Drive"
