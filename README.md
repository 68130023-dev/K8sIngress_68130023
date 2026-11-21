# ระบบให้บริการเว็บบน Kubernetes — www.id-023.com

งานวิชา Kubernetes — สร้างระบบให้บริการเว็บหลาย service บน Kubernetes cluster
โดยเข้าถึงผ่านชื่อโดเมนและแยกการทำงานตาม path ด้วย Ingress

| | |
|---|---|
| **ผู้จัดทำ** | นายยุทธนา เอมยงค์ |
| **รหัสนักศึกษา** | 68130023 |
| **หลักสูตร** | วิศวกรรมศาสตรมหาบัณฑิต สาขาวิชาวิศวกรรมคอมพิวเตอร์ |
| **สถาบัน** | วิทยาลัยวิศวกรรมศาสตร์และเทคโนโลยี มหาวิทยาลัยธุรกิจบัณฑิตย์ |

---

## 1. บริการที่ให้

| URL | หน้าที่ | ทำงานด้วย |
|---|---|---|
| `http://www.id-023.com/` | หน้าแรก รวมลิงก์ทุกบริการ | `app-about` |
| `http://www.id-023.com/about` | แสดงรูป ชื่อ และรหัสนักศึกษา | `app-about` |
| `http://www.id-023.com/research` | สรุปงานวิจัยที่นำเสนอในวิชาสัมมนา | `app-research` |
| `http://www.id-023.com/api/<ข้อความ>` | นำข้อความมาแสดงตัวใหญ่กลางจอ | `app-api` |
| `http://admin.id-023.com/` | เด้งไปหน้าแก้ไขอัตโนมัติ (302) | `app-research` |
| `http://admin.id-023.com/edit` | แก้ไขและบันทึกสรุปงานวิจัยกลับ | `app-research` |

---

## 2. สถาปัตยกรรม

```
            Chrome (Windows host)                 curl (Ubuntu VM)
                    |                                    |
         C:\...\drivers\etc\hosts                  /etc/hosts
                    |                                    |
                    +----------------+-------------------+
                                     |
                         192.168.176.137 : 80
                                     |
                       svclb-traefik (DaemonSet)
                                     |
                          Traefik Ingress Controller
                                     |
            +------------------------+------------------------+
            |                                                 |
   Ingress: main-ingress-023                      Ingress: admin-ingress-023
   host = www.id-023.com                          host = admin.id-023.com
            |                                                 |
  +---------+---------+-------------+                         |
  |         |         |             |                         |
 /  +  /about     /research       /api                        /
  |         |         |             |                         |
  v         v         v             v                         v
Service   Service   Service      Service                   Service
app-about app-about app-research app-api                 app-research
  |                   |                                       |
Deployment         Deployment  <-------- PVC (local-path) ----+
nginx:alpine       python:3.10-slim      research-data-pvc 1Gi
                                         เก็บ /data/research.txt
```

**จุดสำคัญของการออกแบบ**

1. **ไม่ต้อง build container image เอง** — ใช้ image มาตรฐาน `nginx:alpine` และ
   `python:3.10-slim` แล้ว mount ซอร์สโค้ดเข้าไปผ่าน ConfigMap ทำให้ไม่ต้องติดตั้ง
   Docker และไม่ต้องใช้ container registry ทุกอย่างเป็นไฟล์ YAML ล้วน
2. **ไม่ต้องใช้ Ingress rewrite** — แต่ละแอปรองรับ path เต็มของตัวเอง
   (`/about`, `/research`, `/api/...`) จึงย้ายไปใช้ ingress-nginx แทน Traefik ได้
   โดยไม่ต้องแก้ manifest
3. **ข้อมูลไม่หาย** — สรุปงานวิจัยที่แก้ผ่าน `/edit` ถูกเขียนลง PersistentVolumeClaim
   ไม่ใช่ `emptyDir` จึงคงอยู่แม้ pod จะถูกสร้างใหม่
4. **`strategy: Recreate` ใน app-research** — เพราะ PVC เป็น `ReadWriteOnce`
   ถ้าใช้ RollingUpdate pod ใหม่จะรอ volume จาก pod เก่าจนค้าง

---

## 3. สภาพแวดล้อมที่ใช้ทดสอบ

| รายการ | ค่า |
|---|---|
| Hypervisor | VMware Workstation (Windows host) |
| Guest OS | Ubuntu Server 24.04.5 LTS |
| Kubernetes | k3s v1.36.5+k3s1 |
| Container runtime | containerd 2.3.4-k3s1.36 |
| Ingress Controller | Traefik (IngressClass `traefik`, default ของ k3s) |
| StorageClass | `local-path` (rancher.io/local-path, default ของ k3s) |
| Node | `server1` (control-plane) IP 192.168.176.137 |

---

## 4. โครงสร้างไฟล์

```
k8s-id-023/
├── README.md
├── k8s/                              <-- Kubernetes manifest ทั้งหมด
│   ├── 00-namespace.yaml             Namespace id-023
│   ├── 01-pvc.yaml                   PVC 1Gi สำหรับเก็บสรุปงานวิจัย
│   ├── 02-configmap-about-web.yaml   index.html, about.html (+ profile.jpg)
│   ├── 03-configmap-about-nginx.yaml nginx.conf ของ app-about
│   ├── 04-configmap-api-code.yaml    โค้ด Flask ของ app-api
│   ├── 05-configmap-research-code.yaml โค้ด Flask + ข้อความตั้งต้น
│   ├── 06-deploy-app-about.yaml      Deployment app-about
│   ├── 07-deploy-app-api.yaml        Deployment app-api
│   ├── 08-deploy-app-research.yaml   Deployment app-research (+ PVC)
│   ├── 09-services.yaml              Service 3 ตัว (ClusterIP)
│   ├── 10-ingress-www.yaml           Ingress www.id-023.com
│   └── 11-ingress-admin.yaml         Ingress admin.id-023.com
├── src/                              <-- ซอร์สโค้ดที่อ่านง่าย (ต้นทางของ ConfigMap)
│   ├── app-about/{index.html,about.html,nginx.conf,profile.jpg}
│   ├── app-api/app.py
│   └── app-research/{app.py,default.txt}
├── scripts/
│   ├── gen_configmaps.py             สร้าง ConfigMap YAML จาก src/ (python)
│   ├── build-configmaps.sh           สร้าง ConfigMap YAML จาก src/ (kubectl)
│   ├── cleanup-old.sh                ลบของเก่าใน namespace default
│   ├── deploy.sh                     ติดตั้งทั้งระบบ
│   ├── setup-hosts.sh                เพิ่มโดเมนลง /etc/hosts อัตโนมัติ
│   └── test.sh                       ทดสอบทุก service + เก็บหลักฐาน
├── hosts/
│   ├── linux-etc-hosts.txt           สิ่งที่ต้องใส่ใน /etc/hosts ของ Ubuntu
│   └── windows-hosts.txt             สิ่งที่ต้องใส่ใน hosts ของ Windows
└── docs/
    └── evidence/                     ผลการทดสอบที่ test.sh บันทึกไว้
```

---

## 5. ขั้นตอนการ deploy

### 5.1 เตรียมเครื่อง

ใช้ `kubectl` ได้โดยไม่ต้อง `sudo`

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config
chmod 600 ~/.kube/config
kubectl get nodes
```

### 5.2 ลบของเก่า (ทำครั้งเดียว ถ้าเคยติดตั้งไว้ใน namespace `default`)

```bash
chmod +x scripts/*.sh
./scripts/cleanup-old.sh
```

> จำเป็นต้องลบ Ingress เก่าก่อน เพราะใช้ host `www.id-023.com` ซ้ำกัน
> ถ้าไม่ลบ Traefik จะมี rule ซ้ำสองชุด

### 5.3 ใส่รูปของตัวเอง (ถ้ามี)

วางไฟล์รูปไว้ที่ `src/app-about/profile.jpg` (ย่อให้เล็กกว่า 500 KB
เพราะ ConfigMap จำกัดไว้ที่ 1 MB) แล้วสร้าง ConfigMap ใหม่

```bash
python3 scripts/gen_configmaps.py      # หรือ ./scripts/build-configmaps.sh
```

ถ้าไม่ใส่ หน้าเว็บจะแสดงรูปแทนเป็นภาพ avatar สีน้ำเงินอัตโนมัติ

### 5.4 ติดตั้ง

```bash
./scripts/deploy.sh
```

หรือสั่งเองทีละขั้น

```bash
kubectl apply -f k8s/
kubectl -n id-023 rollout status deployment/app-about
kubectl -n id-023 rollout status deployment/app-api
kubectl -n id-023 rollout status deployment/app-research
```

### 5.5 ตั้งค่า DNS ด้วยไฟล์ hosts

บน Ubuntu

```bash
sudo ./scripts/setup-hosts.sh
```

บน Windows ให้เปิด Notepad แบบ Run as administrator แล้วแก้
`C:\Windows\System32\drivers\etc\hosts` ตามไฟล์ `hosts/windows-hosts.txt`

### 5.6 ทดสอบ

```bash
./scripts/test.sh
```

ผลการทดสอบถูกบันทึกไว้ที่ `docs/evidence/test-report.txt`

---

## 6. คำสั่งตรวจสอบการทำงาน

```bash
# ภาพรวมทั้งหมด
kubectl -n id-023 get all,ingress,pvc,configmap -o wide

# ตรวจว่า PVC ถูกผูกแล้ว (ต้องเป็น Bound)
kubectl -n id-023 get pvc
kubectl -n id-023 describe pvc research-data-pvc

# ตรวจกฎ routing ของ Ingress
kubectl -n id-023 describe ingress main-ingress-023
kubectl -n id-023 describe ingress admin-ingress-023

# ตรวจว่า Service หา pod เจอจริง (ต้องมี IP:port ไม่ใช่ <none>)
kubectl -n id-023 get endpoints

# ดู log ของแต่ละแอป
kubectl -n id-023 logs deploy/app-about
kubectl -n id-023 logs deploy/app-api
kubectl -n id-023 logs deploy/app-research

# ดูไฟล์ที่เก็บจริงบน PersistentVolume
kubectl -n id-023 exec deploy/app-research -- ls -la /data
kubectl -n id-023 exec deploy/app-research -- cat /data/research.txt

# ทดสอบจากในเครื่องโดยไม่ต้องแก้ /etc/hosts
curl -H 'Host: www.id-023.com' http://192.168.176.137/about
```

---

## 7. การแก้ไขเนื้อหา

| จะแก้อะไร | แก้ไฟล์ไหน | แล้วสั่ง |
|---|---|---|
| หน้าแรก / หน้าประวัติ | `src/app-about/*.html` | `python3 scripts/gen_configmaps.py && kubectl apply -f k8s/ && kubectl -n id-023 rollout restart deploy/app-about` |
| รูปตัวเอง | วาง `src/app-about/profile.jpg` | เหมือนด้านบน |
| หน้าแสดงข้อความ | `src/app-api/app.py` | `... rollout restart deploy/app-api` |
| สรุปงานวิจัย (ตั้งต้น) | `src/app-research/default.txt` | `... rollout restart deploy/app-research` |
| สรุปงานวิจัย (ใช้งานจริง) | แก้ผ่านหน้าเว็บ `admin.id-023.com/edit` | บันทึกลง PVC ทันที |

> ข้อความที่บันทึกผ่าน `/edit` จะถูกเก็บใน PVC และมีลำดับความสำคัญเหนือ
> `default.txt` เสมอ ถ้าต้องการกลับไปใช้ข้อความตั้งต้นให้ลบไฟล์ใน PVC
> `kubectl -n id-023 exec deploy/app-research -- rm /data/research.txt`

---

## 8. การถอนการติดตั้ง

```bash
kubectl delete namespace id-023
```

ลบทุกอย่างรวมถึง PVC และข้อมูลที่บันทึกไว้

---

## 9. ปัญหาที่พบบ่อย

| อาการ | สาเหตุ | วิธีแก้ |
|---|---|---|
| `www.id-023.com` ขึ้น 404 | Ingress ไม่มี path `/` หรือมี Ingress เก่าซ้ำ host | `kubectl get ingress -A` แล้วลบตัวที่ซ้ำ |
| PVC ค้าง `Pending` | `local-path` เป็น WaitForFirstConsumer | ปกติ จะ Bound เองเมื่อ pod ถูก schedule |
| pod ค้าง `ContainerCreating` นาน | กำลังดึง image หรือ `pip install flask` | `kubectl -n id-023 describe pod <ชื่อ>` |
| pod `CrashLoopBackOff` | node ต่ออินเทอร์เน็ตไม่ได้ ติดตั้ง flask ไม่สำเร็จ | `kubectl -n id-023 logs <ชื่อ> --previous` |
| Windows เปิดเว็บไม่ได้ แต่ VM เปิดได้ | hosts ของ Windows ยังไม่ได้แก้ หรือ IP ของ VM เปลี่ยน | เช็ค `hostname -I` แล้วแก้ hosts ใหม่ |
| แก้แล้วเว็บยังเหมือนเดิม | ConfigMap อัปเดตแล้วแต่ pod ยังไม่โหลดใหม่ | `kubectl -n id-023 rollout restart deploy/<ชื่อ>` |
| node `NotReady` | VM worker ยังไม่ได้เปิด | เปิด VM `Ubuntu 64-bit Server 2/3` หรือปล่อยไว้ก็ได้ |
