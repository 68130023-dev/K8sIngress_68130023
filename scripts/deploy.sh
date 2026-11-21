#!/usr/bin/env bash
# ติดตั้งระบบทั้งหมดลง Kubernetes
# ใช้งาน:  ./scripts/deploy.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS=id-023

echo "=============================================="
echo " Deploy ระบบ www.id-023.com ลง Kubernetes"
echo " นายยุทธนา เอมยงค์  รหัส 68130023"
echo "=============================================="
echo

command -v kubectl >/dev/null || { echo "ไม่พบคำสั่ง kubectl"; exit 1; }

echo "[1/4] ตรวจสอบการเชื่อมต่อ cluster"
kubectl cluster-info >/dev/null || { echo "เชื่อมต่อ cluster ไม่ได้"; exit 1; }
kubectl get nodes
echo

echo "[2/4] apply manifest ทั้งหมดใน k8s/"
kubectl apply -f "$ROOT/k8s/"
echo

echo "[3/4] รอให้ Deployment พร้อมใช้งาน (pip install flask ใช้เวลาสักครู่)"
for d in app-about app-api app-research; do
  printf '  %-14s ... ' "$d"
  if kubectl -n "$NS" rollout status "deployment/$d" --timeout=300s >/dev/null 2>&1; then
    echo "พร้อม"
  else
    echo "ยังไม่พร้อม  ->  kubectl -n $NS describe deploy/$d"
  fi
done
echo

echo "[4/4] สรุปสถานะ"
kubectl -n "$NS" get deploy,svc,ingress,pvc,pod -o wide
echo
echo "----------------------------------------------"
echo " Ingress IP : $(kubectl -n "$NS" get ingress main-ingress-023 \
                      -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)"
echo " ขั้นต่อไป   : แก้ /etc/hosts แล้วรัน ./scripts/test.sh"
echo "----------------------------------------------"
