#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
  exit 1
fi

# Mevcut pf.conf dosyasını yedekle
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/etc/pf.conf.backup.$TIMESTAMP"
cp /etc/pf.conf "$BACKUP_FILE"
echo " /etc/pf.conf dosyası yedeklendi: $BACKUP_FILE"

# Geçici dosyalar
SCRUB_LINE_FILE=$(mktemp)
RULES_FILE=$(mktemp)

# 22. satıra eklenecek satır
echo "scrub in all" > "$SCRUB_LINE_FILE"

# 28. satırdan itibaren eklenecek sabit kurallar
cat <<EOF > "$RULES_FILE"
# --- [EKLENDİ: Sadece port 10343 için kural] ---
pass out all keep state
set skip on lo0
block drop in proto udp from any to any port 5353
EOF

# Yeni pf.conf dosyasını oluştur
awk -v scrub_file="$SCRUB_LINE_FILE" \
    -v rules_file="$RULES_FILE" \
    '
    NR==22 { while ((getline line < scrub_file) > 0) print line }
    NR==27 { print; while ((getline line < rules_file) > 0) print line; next }
    { print }
    ' /etc/pf.conf > /etc/pf.conf.new

# Orijinal dosyayla değiştir
mv /etc/pf.conf.new /etc/pf.conf
rm "$SCRUB_LINE_FILE" "$RULES_FILE"

# pf.conf'u yeniden yükle
pfctl -f /etc/pf.conf
if [ $? -eq 0 ]; then
  echo " pf.conf başarıyla yüklendi."
else
  echo " Hata! Geri almak için: sudo cp $BACKUP_FILE /etc/pf.conf && sudo pfctl -f /etc/pf.conf"
  exit 2
fi

# ▶ pf servisini başlat
pfctl -e 2>/dev/null
if [ $? -eq 0 ]; then
  echo " pf servisi etkinleştirildi."
else
  echo " pf zaten aktif olabilir, sorun yok."
fi

# Mevcut kuralları göster
echo -e "\n Güncel pf kuralları:"
pfctl -sr
