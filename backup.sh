#!/usr/bin/env bash
# نسخ احتياطي لكل مستودعات GitHub إلى Google Drive + إشعار تيلجرام
# المتغيرات المطلوبة: GH_TOKEN, OWNER, TG_BOT_TOKEN, TG_CHAT_ID
# واختياري: REMOTE (الافتراضي drive:GitHub-Backup)
set -uo pipefail

REMOTE="${REMOTE:-drive:GitHub-Backup}"
WORK="$(mktemp -d)"
STATE="$WORK/state.json"
done_list=(); fail_list=(); apk_count=0

tg() {
  [ -n "${TG_BOT_TOKEN:-}" ] || return 0
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d chat_id="$TG_CHAT_ID" --data-urlencode text="$1" >/dev/null
}

# حالة آخر نسخ (لتجاوز اللي ما تغيّر)
rclone copyto "$REMOTE/state.json" "$STATE" 2>/dev/null || echo '{}' > "$STATE"

repos=$(gh repo list "$OWNER" --limit 1000 --json name,pushedAt -q '.[] | "\(.name) \(.pushedAt)"')

while read -r name pushed; do
  [ -n "$name" ] || continue
  full="$OWNER/$name"
  prev=$(jq -r --arg r "$name" '.[$r] // {}' "$STATE")
  changed=0

  # 1) الكود كامل مع كل التاريخ (ملف bundle واحد)
  if [ "$(jq -r '.pushed // ""' <<<"$prev")" != "$pushed" ]; then
    dir="$WORK/$name.git"
    if git clone -q --mirror "https://x-access-token:${GH_TOKEN}@github.com/${full}.git" "$dir" \
       && { git -C "$dir" bundle create "$WORK/$name.bundle" --all 2>/dev/null || true; } \
       && { [ ! -f "$WORK/$name.bundle" ] || rclone copyto "$WORK/$name.bundle" "$REMOTE/repos/$name.bundle"; }; then
      prev=$(jq --arg p "$pushed" '.pushed=$p' <<<"$prev"); changed=1
    else
      fail_list+=("$name"); continue
    fi
    rm -rf "$dir" "$WORK/$name.bundle"
  fi

  # 2) APK من آخر 5 إصدارات (Releases)
  for tag in $(gh release list -R "$full" --limit 5 --json tagName -q '.[].tagName' 2>/dev/null); do
    jq -e --arg t "$tag" '(.releases // []) | index($t)' <<<"$prev" >/dev/null && continue
    out="$WORK/rel/$name/$tag"; mkdir -p "$out"
    gh release download "$tag" -R "$full" -D "$out" -p '*.apk' -p '*.aab' 2>/dev/null || true
    n=$(find "$out" -type f | wc -l)
    [ "$n" -gt 0 ] && rclone copy "$out" "$REMOTE/apks/$name/releases/$tag" && apk_count=$((apk_count+n)) && changed=1
    prev=$(jq --arg t "$tag" '.releases=((.releases // []) + [$t])' <<<"$prev")
  done

  # 3) APK من GitHub Actions (آخر 3 artifacts)
  for id in $(gh api "repos/$full/actions/artifacts?per_page=3" -q '.artifacts[] | select(.expired|not) | .id' 2>/dev/null); do
    jq -e --argjson i "$id" '(.artifacts // []) | index($i)' <<<"$prev" >/dev/null && continue
    out="$WORK/art/$name/$id"; mkdir -p "$out"
    if gh api "repos/$full/actions/artifacts/$id/zip" > "$out.zip" 2>/dev/null; then
      unzip -qo "$out.zip" -d "$out" '*.apk' '*.aab' 2>/dev/null || true
      n=$(find "$out" -type f | wc -l)
      [ "$n" -gt 0 ] && rclone copy "$out" "$REMOTE/apks/$name/actions/$id" && apk_count=$((apk_count+n)) && changed=1
    fi
    prev=$(jq --argjson i "$id" '.artifacts=((.artifacts // []) + [$i])' <<<"$prev")
  done

  jq --arg r "$name" --argjson v "$prev" '.[$r]=$v' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  [ "$changed" = 1 ] && done_list+=("$name")
  rm -rf "$WORK/rel" "$WORK/art"
done <<<"$repos"

rclone copyto "$STATE" "$REMOTE/state.json"

# إشعار تيلجرام (فقط إذا صار شي)
if [ ${#done_list[@]} -gt 0 ] || [ ${#fail_list[@]} -gt 0 ]; then
  msg="📦 نسخ احتياطي GitHub"$'\n'"✅ تم: ${#done_list[@]} مستودع | APK: $apk_count"
  [ ${#done_list[@]} -gt 0 ] && msg+=$'\n'"• ${done_list[*]}"
  [ ${#fail_list[@]} -gt 0 ] && msg+=$'\n'"❌ فشل: ${fail_list[*]}"
  tg "$msg"
fi
[ ${#fail_list[@]} -eq 0 ]
