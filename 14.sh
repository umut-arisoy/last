#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  echo "Bu script root olarak çalıştırılmalıdır."
  exit 1
fi

# Mevcut pf.conf dosyasını yedekle
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/etc/pf.conf.backup.$TIMESTAMP"
cp /etc/pf.conf "$BACKUP_FILE"
echo "Yedek alındı: $BACKUP_FILE"

# Geçici dosya
MODIFIED_FILE=$(mktemp)

# Anahtar ifadeler
SCRUB_ANCHOR_LINE='scrub-anchor "com.apple/*"'
ANCHOR_LOAD_LINE='load anchor "com.apple" from "/etc/pf.anchors/com.apple"'

# Satırları işle
awk -v scrub_line='scrub in all' \
    -v line1='pass out all keep state' \
    -v line2='set skip on lo0' \
    -v line3='block drop in proto udp from any to any port 5353' \
    -v scrub_anchor="$SCRUB_ANCHOR_LINE" \
    -v anchor_load="$ANCHOR_LOAD_LINE" '
{
    # "scrub-anchor" satırından önce "scrub in all" ekle
    if ($0 == scrub_anchor) {
        print scrub_line
    }

    print $0

    # "load anchor ..." satırından sonra diğer kuralları ekle
    if ($0 == anchor_load) {
        print line1
        print line2
        print line3
    }
}
' /etc/pf.conf > "$MODIFIED_FILE"

# Değişiklikleri uygula
mv "$MODIFIED_FILE" /etc/pf.conf

# pf.conf'u yeniden yükle
pfctl -f /etc/pf.conf
if [ $? -eq 0 ]; then
  echo "pf.conf başarıyla yüklendi."
else
  echo "Hata oluştu! Geri almak için: sudo cp $BACKUP_FILE /etc/pf.conf && sudo pfctl -f /etc/pf.conf"
  exit 2
fi

# pf servisini etkinleştir
pfctl -e 2>/dev/null
if [ $? -eq 0 ]; then
  echo "pf servisi etkinleştirildi."
else
  echo "pf servisi zaten aktif olabilir."
fi

# Mevcut kuralları göster
echo -e "\n Güncel pf kuralları:"
pfctl -sr
