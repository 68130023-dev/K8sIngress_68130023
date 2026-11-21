#!/usr/bin/env bash
# ทดสอบการทำงานของทุก service และเก็บหลักฐานลงโฟลเดอร์ docs/evidence/
# ใช้งาน:  ./scripts/test.sh
#
# สคริปต์นี้จะคืนค่าสรุปงานวิจัยกลับเป็นข้อความจริงเมื่อทดสอบเสร็จเสมอ
set -uo pipefail

export TZ=Asia/Bangkok

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS=id-023
OUT="$ROOT/docs/evidence"
mkdir -p "$OUT"

IP="$(kubectl -n "$NS" get ingress main-ingress-023 \
       -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)"
IP="${IP:-$(hostname -I | awk '{print $1}')}"

STAMP="$(date '+%d/%m/%Y %H:%M:%S')"

hit() {  # hit <host> <path> <คำอธิบาย>
  local host="$1" path="$2" desc="$3" code
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $host" \
          --max-time 10 "http://$IP$path")"
  printf '  HTTP %-4s  %-34s  %s\n' "$code" "http://$host$path" "$desc"
}

# รอจนหน้าเว็บมีข้อความที่ต้องการ สูงสุด 30 วินาที
# จำเป็นเพราะหลัง pod restart ตัว Ingress controller ต้องใช้เวลา
# อัปเดตตาราง endpoint ให้ชี้ไปยัง pod IP ตัวใหม่
wait_for_text() {   # wait_for_text <host> <path> <ข้อความ>
  local host="$1" path="$2" needle="$3" i
  for i in $(seq 1 15); do
    if curl -s --max-time 5 -H "Host: $host" "http://$IP$path" \
         | grep -qF "$needle"; then
      echo "  (พบหลังรอ $(( (i-1) * 2 )) วินาที)"
      return 0
    fi
    sleep 2
  done
  return 1
}

{
echo "=============================================================="
echo " รายงานการทดสอบระบบ www.id-023.com"
echo " นายยุทธนา เอมยงค์  รหัสนักศึกษา 68130023"
echo " เวลาทดสอบ : $STAMP น. (เวลาประเทศไทย)"
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
kubectl -n "$NS" get endpoints 2>/dev/null
echo
echo "########## 7. ทดสอบ HTTP ทุก path ##########"
hit www.id-023.com   /                "หน้าแรก (app-about)"
hit www.id-023.com   /about           "รูป ชื่อ รหัส (app-about)"
hit www.id-023.com   /research        "สรุปงานวิจัย (app-research)"
hit www.id-023.com   /api/สวัสดี      "ข้อความตัวใหญ่ (app-api)"
hit www.id-023.com   /api/Kubernetes  "ข้อความตัวใหญ่ (app-api)"
hit admin.id-023.com /                "ต้องได้ 302 redirect ไป /edit"
hit admin.id-023.com /edit            "หน้าแก้ไข (app-research)"
echo
echo "########## 8. ทดสอบการบันทึกข้อมูลลง PVC ##########"
MARK="[ข้อความทดสอบระบบ] บันทึกเมื่อ $STAMP น."
echo "  ส่ง POST ไปที่ admin.id-023.com/edit"
curl -s -o /dev/null -w '  POST /edit -> HTTP %{http_code}\n' \
     -H "Host: admin.id-023.com" \
     --data-urlencode "content=$MARK" \
     "http://$IP/edit"
echo "  อ่านกลับจาก www.id-023.com/research"
if wait_for_text www.id-023.com /research "$MARK"; then
  echo "  ผลลัพธ์: พบข้อความที่เพิ่งบันทึก -> บันทึกลง PVC สำเร็จ"
else
  echo "  ผลลัพธ์: ไม่พบข้อความ -> ตรวจสอบ PVC"
fi
echo
echo "########## 9. ทดสอบว่าข้อมูลไม่หายหลัง pod restart ##########"
OLD_POD="$(kubectl -n "$NS" get pod -l app=app-research \
            -o jsonpath='{.items[0].metadata.name}')"
echo "  pod เดิม : $OLD_POD"
kubectl -n "$NS" rollout restart deployment/app-research >/dev/null
kubectl -n "$NS" rollout status deployment/app-research --timeout=300s
NEW_POD="$(kubectl -n "$NS" get pod -l app=app-research \
            -o jsonpath='{.items[0].metadata.name}')"
echo "  pod ใหม่ : $NEW_POD"
echo "  อ่านข้อมูลซ้ำผ่าน Ingress"
if wait_for_text www.id-023.com /research "$MARK"; then
  echo "  ผลลัพธ์: ข้อมูลยังอยู่หลัง pod ถูกสร้างใหม่ -> PVC ทำงานถูกต้อง"
else
  echo "  ผลลัพธ์: อ่านผ่าน Ingress ไม่พบ ตรวจไฟล์บน volume โดยตรง"
  kubectl -n "$NS" exec deploy/app-research -- cat /data/research.txt
fi
echo
echo "########## 10. ไฟล์ที่เก็บจริงบน PersistentVolume ##########"
kubectl -n "$NS" exec deploy/app-research -- ls -la /data
echo
echo "########## 11. คืนค่าสรุปงานวิจัยกลับเป็นข้อความจริง ##########"
# ลบไฟล์บน PVC ออก แอปจะกลับไปใช้ default.txt จาก ConfigMap อัตโนมัติ
kubectl -n "$NS" exec deploy/app-research -- rm -f /data/research.txt
if wait_for_text www.id-023.com /research "Agentic AI"; then
  echo "  ผลลัพธ์: หน้า /research กลับมาแสดงสรุปงานวิจัยจริงแล้ว"
else
  echo "  ผลลัพธ์: ยังไม่กลับ ตรวจด้วย curl http://www.id-023.com/research"
fi
echo
echo "=============================================================="
echo " จบรายงานการทดสอบ"
echo "=============================================================="
} 2>&1 | tee "$OUT/test-report.txt"

echo
echo "บันทึกรายงานไว้ที่ $OUT/test-report.txt"
