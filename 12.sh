#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  exit 1
fi

# Mevcut pf.conf dosyasını yedekle
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/etc/pf.conf.backup.$TIMESTAMP"
cp /etc/pf.conf "$BACKUP_FILE"

# Geçici dosyalar
MODIFIED_FILE=$(mktemp)

# Anahtar ifadeler
SCRUB_ANCHOR_LINE='scrub-anchor "com.apple/*"'
ANCHOR_LOAD_LINE='load anchor "com.apple" from "/etc/pf.anchors/com.apple"'

# Satırları işle
awk -v scrub_line='scrub in all' \
    -v passout_line='pass out all keep state' \
    -v passout_line='set skip on lo0' \
    -v passout_line='block drop in proto udp from any to any port 5353' \
    -v scrub_anchor="$SCRUB_ANCHOR_LINE" \
    -v anchor_load="$ANCHOR_LOAD_LINE" '
{
    # "scrub-anchor" satırından önce "scrub in all" ekle
    if ($0 == scrub_anchor) {
        print scrub_line
    }

    print $0

    # "load anchor ..." satırından sonra "pass out all keep state" ekle
    if ($0 == anchor_load) {
        print passout_line
    }
}
' /etc/pf.conf > "$MODIFIED_FILE"

# Değişiklikleri uygula
mv "$MODIFIED_FILE" /etc/pf.conf

# pf.conf'u yeniden yükle
pfctl -f /etc/pf.conf
if [ $? -eq 0 ]; then
else
  exit 2
fi

# pf servisini etkinleştir
pfctl -e 2>/dev/null
if [ $? -eq 0 ]; then
else
fi

# Mevcut kuralları göster
echo -e "\n Güncel pf kuralları:"
pfctl -sr
