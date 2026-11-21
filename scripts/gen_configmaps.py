#!/usr/bin/env python3
"""สร้างไฟล์ ConfigMap YAML ใน k8s/ จากซอร์สใน src/ (ทางเลือกแทน build-configmaps.sh
สำหรับเครื่องที่ยังไม่มี kubectl) ผลลัพธ์เหมือน kubectl create configmap --dry-run"""
import base64
import os
import sys

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NS = "id-023"

JOBS = [
    ("about-web", "02-configmap-about-web.yaml",
     ["src/app-about/index.html", "src/app-about/about.html",
      "src/app-about/profile.jpg"]),
    ("about-nginx-conf", "03-configmap-about-nginx.yaml",
     ["src/app-about/nginx.conf"]),
    ("api-app-code", "04-configmap-api-code.yaml",
     ["src/app-api/app.py"]),
    ("research-app-code", "05-configmap-research-code.yaml",
     ["src/app-research/app.py", "src/app-research/default.txt"]),
]


class Literal(str):
    pass


def _literal(dumper, data):
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")


yaml.add_representer(Literal, _literal)


def main():
    for name, out, sources in JOBS:
        data, binary = {}, {}
        for rel in sources:
            path = os.path.join(ROOT, rel)
            if not os.path.isfile(path):
                continue
            key = os.path.basename(path)
            raw = open(path, "rb").read()
            try:
                text = raw.decode("utf-8")
            except UnicodeDecodeError:
                binary[key] = base64.b64encode(raw).decode("ascii")
                continue
            if not text.endswith("\n"):
                text += "\n"
            data[key] = Literal(text)

        doc = {"apiVersion": "v1", "kind": "ConfigMap",
               "metadata": {"name": name, "namespace": NS}}
        if data:
            doc["data"] = data
        if binary:
            doc["binaryData"] = binary

        dest = os.path.join(ROOT, "k8s", out)
        with open(dest, "w", encoding="utf-8") as f:
            f.write(f"# สร้างอัตโนมัติจาก src/ โดย scripts/gen_configmaps.py\n"
                    f"# อย่าแก้ไฟล์นี้ตรง ๆ ให้ไปแก้ที่ src/ แล้วรันสคริปต์ใหม่\n")
            yaml.dump(doc, f, allow_unicode=True, sort_keys=False,
                      default_flow_style=False, width=4096)
        print(f"  {out}  <-  {len(data) + len(binary)} ไฟล์")


if __name__ == "__main__":
    sys.exit(main())
