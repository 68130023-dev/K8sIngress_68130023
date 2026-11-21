#!/usr/bin/env python3
# app-api : นำข้อความจาก URL มาแสดงตัวใหญ่กลางจอ
# เรียกใช้: http://www.id-023.com/api/<ข้อความ>
# นายยุทธนา เอมยงค์  รหัสนักศึกษา 68130023

import os
import html
import urllib.parse

from flask import Flask

app = Flask(__name__)

STUDENT_ID = "68130023"


def render(message, hint=False):
    safe = html.escape(message)
    sub = ("ลองพิมพ์ต่อท้าย URL เช่น /api/สวัสดี"
           if hint else
           f"Served by <strong>app-api</strong> &middot; Student ID: {STUDENT_ID}")
    return f"""<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>app-api - {STUDENT_ID}</title>
<style>
  *{{box-sizing:border-box}}
  body{{margin:0;min-height:100vh;display:flex;flex-direction:column;
        justify-content:center;align-items:center;gap:28px;padding:40px 24px;
        background:radial-gradient(circle at 50% 0%,#1e293b,#020617);
        color:#38bdf8;text-align:center;
        font-family:'Noto Sans Thai',Tahoma,'Segoe UI',sans-serif}}
  .msg-box{{font-size:clamp(2.2rem,11vw,7rem);font-weight:700;line-height:1.25;
            padding:0.4em 0.7em;border:3px solid #38bdf8;border-radius:20px;
            background:rgba(56,189,248,.06);max-width:92vw;
            word-break:break-word;overflow-wrap:anywhere;
            box-shadow:0 18px 50px rgba(0,0,0,.55)}}
  .sub{{color:#94a3b8;font-size:1rem}}
  .sub strong{{color:#cbd5e1}}
  .pod{{color:#475569;font-size:.8rem}}
</style>
</head>
<body>
  <div class="msg-box">{safe}</div>
  <div class="sub">{sub}</div>
  <div class="pod">pod: {os.environ.get('HOSTNAME','-')}</div>
</body>
</html>"""


@app.route("/healthz")
def healthz():
    return "ok", 200


@app.route("/api")
@app.route("/api/")
def api_hint():
    return render("ใส่ข้อความต่อท้าย /api/", hint=True)


@app.route("/api/<path:msg>")
def show_message(msg):
    return render(urllib.parse.unquote(msg))


# เผื่อถูกเรียกตรงผ่าน Service โดยไม่ผ่าน Ingress
@app.route("/")
def root():
    return render("app-api พร้อมทำงาน", hint=True)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
