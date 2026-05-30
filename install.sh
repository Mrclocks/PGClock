```bash
#!/usr/bin/env bash
set -euo pipefail

DEST_DIR="/var/lib/pasarguard/templates/subscription"
DEST_FILE="${DEST_DIR}/index.html"
ENV_FILE="/opt/pasarguard/.env"

echo "Installing PGClock..."

mkdir -p "${DEST_DIR}"

if command -v wget >/dev/null 2>&1; then
    wget -q -O "${DEST_FILE}" \
    "https://raw.githubusercontent.com/Mrclocks/PGClock/main/index.html"
elif command -v curl >/dev/null 2>&1; then
    curl -fsSL \
    "https://raw.githubusercontent.com/Mrclocks/PGClock/main/index.html" \
    -o "${DEST_FILE}"
else
    echo "Error: neither wget nor curl is installed."
    exit 1
fi

touch "${ENV_FILE}"

if grep -q '^CUSTOM_TEMPLATES_DIRECTORY=' "${ENV_FILE}"; then
    sed -i 's|^CUSTOM_TEMPLATES_DIRECTORY=.*|CUSTOM_TEMPLATES_DIRECTORY="/var/lib/pasarguard/templates/"|' "${ENV_FILE}"
else
    echo 'CUSTOM_TEMPLATES_DIRECTORY="/var/lib/pasarguard/templates/"' >> "${ENV_FILE}"
fi

if grep -q '^SUBSCRIPTION_PAGE_TEMPLATE=' "${ENV_FILE}"; then
    sed -i 's|^SUBSCRIPTION_PAGE_TEMPLATE=.*|SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"|' "${ENV_FILE}"
else
    echo 'SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"' >> "${ENV_FILE}"
fi

pasarguard restart

echo ""
echo "✅ PGClock installed successfully."
echo "✅ PasarGuard restarted."
```
