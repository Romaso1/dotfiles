#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

BAD="$(
grep -RIlE \
'ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+|glpat-[A-Za-z0-9_-]+|BEGIN OPENSSH PRIVATE KEY|BEGIN RSA PRIVATE KEY|BEGIN PRIVATE KEY|api[_-]?key[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9._-]{16,}|access[_-]?token[[:space:]]*[:=][[:space:]]*["'\'']?[A-Za-z0-9._-]{16,}|password[[:space:]]*[:=][[:space:]]*["'\'']?.{4,}|passwd[[:space:]]*[:=][[:space:]]*["'\'']?.{4,}' \
. \
--exclude-dir=.git \
--exclude=.gitignore \
--exclude=check-secrets.sh \
--exclude=push.sh \
--exclude=README.md || true
)"

if [ -n "$BAD" ]; then
    echo "❌ Найдены возможные реальные секреты:"
    echo "$BAD"
    echo
    echo "Проверь эти файлы вручную. Push остановлен."
    exit 1
fi

echo "✅ Реальных секретов не найдено"
