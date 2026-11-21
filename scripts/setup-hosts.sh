#!/usr/bin/env bash
# เพิ่ม www.id-023.com และ admin.id-023.com ลงใน /etc/hosts ของ Linux
# อ่าน IP จาก node จริงอัตโนมัติ จึงไม่ต้องแก้ตัวเลขเอง
# ใช้งาน:  sudo ./scripts/setup-hosts.sh
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ต้องรันด้วย sudo"; exit 1; }

NS=id-023
IP="$(kubectl -n "$NS" get ingress main-ingress-023 \
       -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
[[ -n "$IP" ]] || IP="$(hostname -I | awk '{print $1}')"

LINE="$IP   www.id-023.com   admin.id-023.com"
MARK="# k8s-id-023"

cp /etc/hosts "/etc/hosts.bak.$(date +%Y%m%d%H%M%S)"
sed -i "/$MARK/d" /etc/hosts
sed -i '/www\.id-023\.com/d;/admin\.id-023\.com/d' /etc/hosts
echo "$LINE $MARK" >> /etc/hosts

echo "เพิ่มลง /etc/hosts แล้ว:"
echo "  $LINE"
echo
echo "ตรวจสอบ:"
getent hosts www.id-023.com   || true
getent hosts admin.id-023.com || true
echo
echo "สำหรับ Windows ให้ใส่ IP นี้ลงใน C:\\Windows\\System32\\drivers\\etc\\hosts :"
echo "  $IP   www.id-023.com"
echo "  $IP   admin.id-023.com"
