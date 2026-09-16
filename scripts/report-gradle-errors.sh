#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  Vizitor — انتشار خلاصهٔ خطاهای Gradle به‌صورت Annotation گیت‌هاب
#  Developed by Milano Technical Team, Milad Yaghoobi
#  ─────────────────────────────────────────────────────────────────────────
#  استفاده:  scripts/report-gradle-errors.sh <gradle-log-file> <variant>
#  چرا؟ لاگ کامل روی Azure Blob ذخیره می‌شود؛ خطاهای کلیدی به‌صورت Annotation
#  منتشر می‌شوند تا از طریق API گیت‌هاب (بدون دانلود فایل) قابل خواندن باشند.
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail

LOG="${1:-build.log}"
VARIANT="${2:-build}"

if [ ! -f "$LOG" ]; then
  echo "::error title=${VARIANT}: log missing::فایل لاگ ${LOG} پیدا نشد."
  exit 0
fi

# خطاهای Kotlin (^e:)، خطاهای Java/Gradle، تسک‌های شکست‌خورده و علت ریشه
PATTERN='^e: |^error: |error:|> Task .* FAILED|Execution failed for task|What went wrong|Caused by:|Unresolved reference|FAILURE: Build failed|Could not (resolve|find|download|determine)|A problem occurred|> Could not|minSdk|Deprecated Gradle features'

# حداکثر ۱۰ خط اول معنادار (annotation محدودیت طول دارد)
EXCERPT=$(grep -aE "$PATTERN" "$LOG" | head -10 | cut -c1-220 || true)

if [ -z "$EXCERPT" ]; then
  # اگر الگوها نگرفتند، آخرین ۱۵ خط لاگ را بفرست
  EXCERPT=$(tail -15 "$LOG" | cut -c1-220 || true)
fi

# کدگذاری برای workflow command: درصد و خط جدید و CR
ENC=$(printf '%s' "$EXCERPT" | sed -e 's/%/%25/g' | awk '{printf "%s%%0A", $0}')

echo "::error title=Gradle ${VARIANT} — خطاهای کلیدی::${ENC}"

# خلاصهٔ کوتاه برای خوانایی در UI
echo "### خطاهای بیلد ${VARIANT}"
echo '```'
printf '%s\n' "$EXCERPT"
echo '```'
