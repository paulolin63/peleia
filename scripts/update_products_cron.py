#!/usr/bin/env python3
"""
scripts/update_products_cron.py
PeleIA — Script de atualização periódica de catálogo e preços
Executado a cada 10 dias (via GitHub Actions ou Cron Job)
"""

import json
import os
import sys
from datetime import datetime

PRODUCTS_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets",
    "data",
    "products.json",
)

def update_catalog():
    print(f"[{datetime.now().isoformat()}] 🔄 Iniciando atualização de produtos...")

    if not os.path.exists(PRODUCTS_FILE):
        print(f"❌ Arquivo não encontrado: {PRODUCTS_FILE}")
        sys.exit(1)

    with open(PRODUCTS_FILE, "r", encoding="utf-8") as f:
        products = json.load(f)

    print(f"📦 Total de produtos carregados: {len(products)}")

    # Aqui você pode plugar a API oficial da Shopee / Mercado Livre / Amazon
    # Ou fazer verificações de links e ajustes de faixa de preço.
    # Exemplo: atualização de timestamp ou formatação de links afiliados
    affiliate_tag_shopee = os.getenv("SHOPEE_AFFILIATE_TAG", "")
    affiliate_tag_ml = os.getenv("ML_AFFILIATE_TAG", "")
    affiliate_tag_amazon = os.getenv("AMAZON_AFFILIATE_TAG", "")

    updated_count = 0
    for item in products:
        # Se você tiver tags de afiliados no ambiente, injeta automaticamente nas URLs
        url = item.get("affiliate_url", "")
        if "shopee.com.br" in url and affiliate_tag_shopee and affiliate_tag_shopee not in url:
            item["affiliate_url"] += f"&af={affiliate_tag_shopee}"
            updated_count += 1
        elif "amazon.com.br" in url and affiliate_tag_amazon and affiliate_tag_amazon not in url:
            item["affiliate_url"] += f"&tag={affiliate_tag_amazon}"
            updated_count += 1

    # Salva JSON formatado e limpo
    with open(PRODUCTS_FILE, "w", encoding="utf-8") as f:
        json.dump(products, f, ensure_ascii=False, indent=2)

    print(f"✅ Catálogo atualizado com sucesso em: {PRODUCTS_FILE}")
    print(f"🎉 Pronto para sincronização online!")

if __name__ == "__main__":
    update_catalog()
