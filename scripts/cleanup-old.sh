#!/usr/bin/env bash
# ลบของเก่าที่อยู่ใน namespace default ออก ก่อนติดตั้งชุดใหม่ใน namespace id-023
#
# จำเป็นต้องลบ Ingress เก่า เพราะใช้ host www.id-023.com / admin.id-023.com ซ้ำกัน
# ถ้าไม่ลบ Traefik จะมี rule ซ้ำสองชุดและ route ไปผิดที่
#
# ใช้งาน:  ./scripts/cleanup-old.sh
set -uo pipefail

echo "=============================================="
echo " ลบทรัพยากรชุดเก่าใน namespace default"
echo "=============================================="
echo

echo "[1/4] ลบ Ingress เก่า (สำคัญที่สุด ป้องกัน host ชนกัน)"
kubectl -n default delete ingress main-ingress-023 admin-ingress-023 \
  --ignore-not-found
echo

echo "[2/4] ลบ Deployment และ Service เก่าของทั้ง 3 แอป"
kubectl -n default delete deployment app-about app-api app-research \
  --ignore-not-found
kubectl -n default delete service app-about app-api app-research \
  --ignore-not-found
echo

echo "[3/4] ลบ ConfigMap เก่า"
kubectl -n default delete configmap about-html api-app-code research-app-code \
  --ignore-not-found
echo

echo "[4/4] บังคับลบ pod ที่ค้างสถานะ Terminating"
#  pod พวกนี้ค้างเพราะ node ที่มันอยู่ (server2/server3) หลุดจาก cluster
kubectl get pods -A --no-headers 2>/dev/null \
  | awk '$4=="Terminating"{print $1" "$2}' \
  | while read -r ns name; do
      echo "  ลบ $ns/$name"
      kubectl -n "$ns" delete pod "$name" --force --grace-period=0 2>/dev/null
    done
echo

echo "----------------------------------------------"
echo " เสร็จแล้ว ตรวจสอบด้วย: kubectl get all -n default"
echo
echo " หมายเหตุ: สคริปต์นี้ไม่ลบ nginx-deploy / nginx-clusterip / nginx-nodeport"
echo "           ซึ่งเป็นของแล็บเก่า ถ้าต้องการคืนหน่วยความจำให้สั่งเพิ่ม:"
echo "             kubectl -n default delete deploy nginx-deploy"
echo "             kubectl -n default delete svc nginx-clusterip nginx-nodeport"
echo "----------------------------------------------"
