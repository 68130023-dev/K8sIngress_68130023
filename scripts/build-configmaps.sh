#!/usr/bin/env bash
# สร้างไฟล์ ConfigMap YAML ใน k8s/ จากซอร์สโค้ดใน src/
# รันสคริปต์นี้ทุกครั้งที่แก้ไฟล์ใน src/ แล้วค่อย ./scripts/deploy.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS=id-023

gen() {   # gen <ชื่อ configmap> <ไฟล์ปลายทาง> <ไฟล์ซอร์ส...>
  local name="$1" out="$2"; shift 2
  local args=()
  for f in "$@"; do
    [[ -f "$f" ]] && args+=(--from-file="$(basename "$f")=$f")
  done
  kubectl create configmap "$name" \
    --namespace "$NS" \
    "${args[@]}" \
    --dry-run=client -o yaml > "$out"
  echo "  สร้าง $(basename "$out")  <-  ${#args[@]} ไฟล์"
}

echo "สร้าง ConfigMap YAML จาก src/ ..."

# app-about : หน้าเว็บ (+ รูป profile.jpg ถ้ามี) และ nginx.conf
gen about-web "$ROOT/k8s/02-configmap-about-web.yaml" \
  "$ROOT/src/app-about/index.html" \
  "$ROOT/src/app-about/about.html" \
  "$ROOT/src/app-about/profile.jpg"

gen about-nginx-conf "$ROOT/k8s/03-configmap-about-nginx.yaml" \
  "$ROOT/src/app-about/nginx.conf"

# app-api
gen api-app-code "$ROOT/k8s/04-configmap-api-code.yaml" \
  "$ROOT/src/app-api/app.py"

# app-research : โค้ด + ข้อความสรุปงานวิจัยตั้งต้น
gen research-app-code "$ROOT/k8s/05-configmap-research-code.yaml" \
  "$ROOT/src/app-research/app.py" \
  "$ROOT/src/app-research/default.txt"

echo "เสร็จแล้ว"
