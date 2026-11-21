#!/usr/bin/env bash
# ทดสอบการทำงานของทุก service และเก็บหลักฐานลงโฟลเดอร์ docs/evidence/
# ใช้งาน:  ./scripts/test.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS=id-023
OUT="$ROOT/docs/evidence"
mkdir -p "$OUT"

IP="$(kubectl -n "$NS" get ingress main-ingress-023 \
       -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)"
IP="${IP:-$(hostname -I | awk '{print $1}')}"

STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

hit() {  # hit <host> <path> <คำอธิบาย>
  local host="$1" path="$2" desc="$3"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $host" \
          --max-time 10 "http://$IP$path")"
  printf '  %-34s %-38s HTTP %s\n' "http://$host$path" "$desc" "$code"
}

{
echo "=============================================================="
echo " รายงานการทดสอบระบบ www.id-023.com"
echo " นายยุทธนา เอมยงค์  รหัสนักศึกษา 68130023"
echo " เวลาทดสอบ : $STAMP"
echo " Ingress IP : $IP"
echo "=============================================================="
echo
echo "########## 1. สถานะ Node ##########"
kubectl get nodes -o wide
echo
echo "########## 2. ทรัพยากรทั้งหมดใน namespace $NS ##########"
kubectl -n "$NS" get deploy,svc,ingress,pvc,configmap,pod -o wide
echo
echo "########## 3. รายละเอียด PersistentVolumeClaim ##########"
kubectl -n "$NS" describe pvc research-data-pvc
echo
echo "########## 4. รายละเอียด Ingress (www) ##########"
kubectl -n "$NS" describe ingress main-ingress-023
echo
echo "########## 5. รายละเอียด Ingress (admin) ##########"
kubectl -n "$NS" describe ingress admin-ingress-023
echo
echo "########## 6. Endpoints ของแต่ละ Service ##########"
kubectl -n "$NS" get endpoints
echo
echo "########## 7. ทดสอบ HTTP ทุก path ##########"
hit www.id-023.com   /                "หน้าแรก (app-about)"
hit www.id-023.com   /about           "รูป ชื่อ รหัส (app-about)"
hit www.id-023.com   /research        "สรุปงานวิจัย (app-research)"
hit www.id-023.com   /api/สวัสดี      "ข้อความตัวใหญ่ (app-api)"
hit www.id-023.com   /api/Kubernetes  "ข้อความตัวใหญ่ (app-api)"
hit admin.id-023.com /                "redirect ไป /edit"
hit admin.id-023.com /edit            "หน้าแก้ไข (app-research)"
echo
echo "########## 8. ทดสอบการบันทึกข้อมูลลง PVC ##########"
MARK="ทดสอบบันทึกเมื่อ $STAMP"
echo "  ส่ง POST ไป admin.id-023.com/edit ..."
curl -s -o /dev/null -w '  POST /edit -> HTTP %{http_code}\n' \
     -H "Host: admin.id-023.com" \
     --data-urlencode "content=$MARK" \
     "http://$IP/edit"
echo "  อ่านกลับจาก www.id-023.com/research ..."
if curl -s -H "Host: www.id-023.com" "http://$IP/research" | grep -qF "$MARK"; then
  echo "  ผลลัพธ์: พบข้อความที่เพิ่งบันทึก -> บันทึกลง PVC สำเร็จ"
else
  echo "  ผลลัพธ์: ไม่พบข้อความ -> ตรวจสอบ PVC"
fi
echo
echo "########## 9. ทดสอบว่าข้อมูลไม่หายหลัง pod restart ##########"
echo "  สั่ง restart deployment/app-research ..."
kubectl -n "$NS" rollout restart deployment/app-research >/dev/null
kubectl -n "$NS" rollout status deployment/app-research --timeout=300s
if curl -s -H "Host: www.id-023.com" "http://$IP/research" | grep -qF "$MARK"; then
  echo "  ผลลัพธ์: ข้อมูลยังอยู่หลัง restart -> PVC ทำงานถูกต้อง"
else
  echo "  ผลลัพธ์: ข้อมูลหาย -> PVC ยังไม่ถูกผูกกับ /data"
fi
echo
echo "########## 10. ไฟล์ที่เก็บจริงบน PersistentVolume ##########"
kubectl -n "$NS" exec deploy/app-research -- ls -la /data
echo
echo "=============================================================="
echo " จบรายงานการทดสอบ"
echo "=============================================================="
} 2>&1 | tee "$OUT/test-report.txt"

echo
echo "บันทึกรายงานไว้ที่ $OUT/test-report.txt"
