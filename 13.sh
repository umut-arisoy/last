#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  exit 1
fi

# Mevcut pf.conf dosyasını yedekle
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/etc/pf.conf.backup.$TIMESTAMP"
cp /etc/pf.conf "$BACKUP_FILE"

# Anahtar ifadeler
SCRUB_ANCHOR='scrub-anchor "com.apple/*"'
ANCHOR_LOAD='load anchor "com.apple" from "/etc/pf.anchors/com.apple"'

# Geçici dosya
MODIFIED_FILE=$(mktemp)

# Yeni pf.conf dosyasını oluştur
awk -v scrub_anchor="$SCRUB_ANCHOR" \
    -v anchor_load="$ANCHOR_LOAD" '
BEGIN {
    # Tanımlanacak satırlar
    scrub_line = "scrub in all"
    post_anchor_lines[0] = "pass out all keep state"
    post_anchor_lines[1] = "set skip on lo0"
    post_anchor_lines[2] = "block drop in proto udp from any to any port 5353"
}
{
    # scrub-anchor'dan önce scrub in all ekle
    if ($0 == scrub_anchor) {
        print scrub_line
    }

    print $0

    # load anchor'dan sonra 3 satırı ekle
    if ($0 == anchor_load) {
        for (i = 0; i < 3; i++) {
            print post_anchor_lines[i]
        }
    }
}
' /etc/pf.conf > "$MODIFIED_FILE"

# Orijinal dosyayla değiştir
mv "$MODIFIED_FILE" /etc/pf.conf

# pf.conf'u yeniden yükle
pfctl -f /etc/pf.conf
if [ $? -eq 0 ]; then
  exit 2
fi

# pf servisini etkinleştir
pfctl -e 2>/dev/null
if [ $? -eq 0 ]; then
fi

# Mevcut kuralları göster
echo -e "\n Güncel pf kuralları:"
pfctl -sr
