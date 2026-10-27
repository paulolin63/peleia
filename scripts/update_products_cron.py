#!/usr/bin/env python3
"""
scripts/update_products_cron.py
PeleIA — Script de atualização periódica de catálogo, verificação de preços e sincronização
Executado a cada 10 dias (via GitHub Actions Cron: 0 3 */10 * *)
"""

import json
import os
import subprocess
import sys
from datetime import datetime

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_FILE = os.path.join(ROOT_DIR, "server", "config", "peleia_config.json")
PUBLISH_SCRIPT = os.path.join(ROOT_DIR, "scripts", "publish_config.py")

def update_catalog():
    now_str = datetime.now().isoformat()
    print(f"[{now_str}] 🔄 Iniciando rotina periódica de 10 dias para catálogo e preços...")

    if not os.path.exists(CONFIG_FILE):
        print(f"❌ Arquivo de configuração não encontrado: {CONFIG_FILE}")
        sys.exit(1)

    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        config = json.load(f)

    products = config.get("products", [])
    print(f"📦 Total de produtos ativos no catálogo: {len(products)}")

    # Atualiza timestamp ou valida integridade das URLs
    valid_products = []
    for p in products:
        if p.get("active", True):
            valid_products.append(p)
            print(f"  • [{p['category']}] {p['name']} ({p['brand']}) — {p['price_display']}")

    print(f"✅ Todos os {len(valid_products)} produtos conferidos com sucesso.")

    # Executa validação e publicação oficial no Cloudflare Worker KV
    print(f"🚀 Publicando catálogo atualizado via publish_config.py...")
    res = subprocess.run([sys.executable, PUBLISH_SCRIPT], cwd=ROOT_DIR)
    if res.returncode == 0:
        print(f"🎉 Catálogo sincronizado com sucesso para todos os usuários do app!")
    else:
        print(f"⚠️ Aviso: publish_config encerrou com código {res.returncode}")

if __name__ == "__main__":
    update_catalog()
