#!/usr/bin/env python3
# app-research : แสดงสรุปงานวิจัย (/research) และแก้ไขสรุปงานวิจัย (/edit)
# นายยุทธนา เอมยงค์  รหัสนักศึกษา 68130023

import os
import html
from datetime import datetime, timezone, timedelta

from flask import Flask, request, redirect

app = Flask(__name__)

STUDENT_ID = "68130023"
STUDENT_NAME = "นายยุทธนา เอมยงค์"

# /data คือ PersistentVolumeClaim -> ข้อมูลไม่หายเมื่อ pod restart
DATA_FILE = os.environ.get("DATA_FILE", "/data/research.txt")
# ข้อความตั้งต้น ถูก mount มาจาก ConfigMap คู่กับไฟล์นี้
DEFAULT_FILE = os.environ.get("DEFAULT_FILE", "/app/default.txt")

TH = timezone(timedelta(hours=7))


def read_default():
    try:
        with open(DEFAULT_FILE, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return "ยังไม่มีข้อมูลสรุปงานวิจัย"


def get_content():
    """อ่านจาก PVC ก่อน ถ้ายังไม่เคยบันทึกจึงใช้ค่าตั้งต้นจาก ConfigMap"""
    try:
        with open(DATA_FILE, encoding="utf-8") as f:
            text = f.read()
        if text.strip():
            return text, "PVC"
    except OSError:
        pass
    return read_default(), "ConfigMap"


def save_content(text):
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    tmp = DATA_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, DATA_FILE)  # เขียนแบบ atomic กันไฟล์พังกลางคัน


def char_count(text):
    """นับจำนวนตัวอักษร ไม่นับช่องว่างและการขึ้นบรรทัดใหม่

    ไม่ใช้การนับคำด้วย text.split() เพราะภาษาไทยไม่เว้นวรรคระหว่างคำ
    การแยกด้วยช่องว่างจะนับทั้งวรรคเป็นคำเดียว ทำให้ได้ตัวเลขต่ำกว่าความจริงมาก
    การนับคำภาษาไทยที่ถูกต้องต้องใช้พจนานุกรมตัดคำ เช่น pythainlp หรือ MS Word
    """
    return len([c for c in text if not c.isspace()])


def now_th():
    return datetime.now(TH).strftime("%d/%m/%Y %H:%M:%S")


CSS_BASE = """
  *{box-sizing:border-box}
  body{font-family:'Noto Sans Thai',Tahoma,'Segoe UI',sans-serif;margin:0;
       padding:40px 20px;background:#f1f5f9;color:#1e293b;line-height:1.85}
  .container{max-width:900px;margin:0 auto;background:#fff;padding:36px;
             border-radius:12px;box-shadow:0 2px 14px rgba(15,23,42,.08)}
  .nav{max-width:900px;margin:0 auto 18px;font-size:14px}
  .nav a{color:#2563eb;text-decoration:none;margin-right:16px}
  .nav a:hover{text-decoration:underline}
  .badge{display:inline-block;font-size:12px;padding:3px 10px;border-radius:999px;
         background:#e0e7ff;color:#3730a3;margin-left:8px}
"""


@app.route("/healthz")
def healthz():
    return "ok", 200


@app.route("/")
def root():
    # admin.id-023.com  ->  เด้งไปหน้าแก้ไข
    if request.host.startswith("admin."):
        return redirect("/edit", code=302)
    return redirect("/research", code=302)


@app.route("/research")
def research():
    content, source = get_content()
    return f"""<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>สรุปงานวิจัย - {STUDENT_ID}</title>
<style>{CSS_BASE}
  h1{{color:#0f172a;border-bottom:3px solid #2563eb;padding-bottom:12px;
      font-size:22px;margin:0 0 18px}}
  .meta{{background:#f8fafc;border-left:4px solid #2563eb;padding:12px 16px;
         font-size:14px;color:#475569;margin-bottom:24px;border-radius:0 6px 6px 0}}
  .content{{white-space:pre-wrap;font-size:16px;text-align:justify;color:#1e293b}}
  footer{{margin-top:28px;padding-top:16px;border-top:1px solid #e2e8f0;
          font-size:12px;color:#94a3b8}}
</style>
</head>
<body>
<div class="nav">
  <a href="http://www.id-{STUDENT_ID[-3:]}.com/">หน้าแรก</a>
  <a href="http://www.id-{STUDENT_ID[-3:]}.com/about">เกี่ยวกับผู้จัดทำ</a>
  <a href="http://admin.id-{STUDENT_ID[-3:]}.com/edit">แก้ไขสรุปงานวิจัย</a>
</div>
<div class="container">
  <h1>สรุปงานวิจัยที่นำเสนอในวิชาสัมมนา
      <span class="badge">app-research</span></h1>
  <div class="meta">
    <strong>ผู้วิจัย:</strong> {STUDENT_NAME} (รหัสนักศึกษา {STUDENT_ID})<br>
    <strong>แหล่งข้อมูล:</strong> {source} &nbsp;|&nbsp;
    <strong>ความยาว:</strong> {char_count(content):,} ตัวอักษร &nbsp;|&nbsp;
    <strong>ดูเมื่อ:</strong> {now_th()} น.
  </div>
  <div class="content">{html.escape(content)}</div>
  <footer>Served by <strong>app-research</strong> &middot;
          pod: {os.environ.get('HOSTNAME','-')}</footer>
</div>
</body>
</html>"""


@app.route("/edit", methods=["GET", "POST"])
def edit():
    msg = ""
    if request.method == "POST":
        new_content = request.form.get("content", "")
        try:
            save_content(new_content)
            msg = ('<div class="ok">บันทึกสรุปงานวิจัยเรียบร้อยแล้ว '
                   f'เมื่อ {now_th()} &mdash; '
                   f'<a href="http://www.id-{STUDENT_ID[-3:]}.com/research" '
                   'target="_blank">ตรวจสอบที่หน้า /research</a></div>')
        except OSError as e:
            msg = f'<div class="err">บันทึกไม่สำเร็จ: {html.escape(str(e))}</div>'

    content, source = get_content()
    return f"""<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>แก้ไขสรุปงานวิจัย - {STUDENT_ID}</title>
<style>{CSS_BASE}
  body{{background:#fffbeb}}
  .container{{border-top:5px solid #d97706}}
  h1{{color:#b45309;font-size:22px;margin:0 0 6px}}
  .sub{{color:#78716c;font-size:14px;margin-bottom:20px}}
  textarea{{width:100%;height:380px;font-size:15px;padding:14px;border-radius:8px;
            border:1px solid #d6d3d1;font-family:'Noto Sans Thai',Tahoma,sans-serif;
            line-height:1.8;resize:vertical}}
  textarea:focus{{outline:2px solid #d97706;border-color:#d97706}}
  button{{margin-top:16px;padding:12px 30px;font-size:16px;background:#d97706;
          color:#fff;border:0;border-radius:8px;cursor:pointer;font-weight:600}}
  button:hover{{background:#b45309}}
  .ok{{background:#dcfce7;color:#166534;padding:12px 16px;border-radius:8px;
       margin-bottom:16px;font-size:15px}}
  .ok a{{color:#166534}}
  .err{{background:#fee2e2;color:#991b1b;padding:12px 16px;border-radius:8px;
        margin-bottom:16px;font-size:15px}}
  footer{{margin-top:24px;font-size:12px;color:#a8a29e}}
</style>
</head>
<body>
<div class="nav">
  <a href="http://www.id-{STUDENT_ID[-3:]}.com/">หน้าแรก</a>
  <a href="http://www.id-{STUDENT_ID[-3:]}.com/research">ดูหน้าสรุปงานวิจัย</a>
</div>
<div class="container">
  <h1>ระบบแก้ไขสรุปงานวิจัย <span class="badge">admin</span></h1>
  <div class="sub">admin.id-{STUDENT_ID[-3:]}.com/edit &mdash;
      บันทึกลง PersistentVolume ({html.escape(DATA_FILE)})
      &middot; ข้อมูลปัจจุบันอ่านจาก {source}</div>
  {msg}
  <form method="POST" action="/edit">
    <textarea name="content" spellcheck="false">{html.escape(content)}</textarea>
    <button type="submit">บันทึกการแก้ไข</button>
  </form>
  <footer>Served by <strong>app-research</strong> &middot;
          pod: {os.environ.get('HOSTNAME','-')}</footer>
</div>
</body>
</html>"""


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
