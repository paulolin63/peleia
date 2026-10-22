#!/usr/bin/env python3
"""
scripts/publish_config.py
PeleIA — valida e publica a configuração remota (produtos, planos, cotas, textos, prompts).

Uso:
  python3 scripts/publish_config.py --check       # só valida
  python3 scripts/publish_config.py --no-publish  # valida e atualiza a cópia embutida no app
  python3 scripts/publish_config.py               # valida, atualiza a cópia e publica no KV do Worker

Tags de afiliado (opcionais) vêm de SHOPEE_AFFILIATE_TAG e AMAZON_AFFILIATE_TAG.
"""

import argparse
import copy
import json
import os
import subprocess
import sys
import tempfile
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_FILE = os.path.join(ROOT, "server", "config", "peleia_config.json")
APP_ASSET_FILE = os.path.join(ROOT, "assets", "config", "peleia_config.json")
WORKER_DIR = os.path.join(ROOT, "server", "cloudflare-worker")
KV_KEY = "peleia_config"

SCHEMA_VERSION = 1
CATEGORIES = {"limpeza", "serum", "protetor", "hidratante"}
STORES = {"shopee", "mercadolivre", "amazon"}
SERVER_KEYS = [
    "model",
    "vision_prompt",
    "report_prompt",
    "report_memory_first",
    "report_memory_followup",
    "report_memory_section",
    "report_restrictions",
]
AFFILIATE_PARAMS = {
    "shopee.com.br": ("SHOPEE_AFFILIATE_TAG", "af"),
    "amazon.com.br": ("AMAZON_AFFILIATE_TAG", "tag"),
}


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value):
    return (isinstance(value, (int, float))) and not isinstance(value, bool)


def _non_empty_str(value):
    return isinstance(value, str) and value.strip() != ""


def validate(config):
    """Retorna a lista de erros; lista vazia significa config válida."""
    errors = []

    def err(msg):
        errors.append(msg)

    if config.get("schema_version") != SCHEMA_VERSION:
        err(f"schema_version deve ser {SCHEMA_VERSION}")
    if not _non_empty_str(config.get("config_version")):
        err("config_version ausente")
    if not _is_int(config.get("min_app_build")) or config["min_app_build"] < 1:
        err("min_app_build deve ser inteiro >= 1")

    notice = config.get("notice")
    if notice is not None:
        if not isinstance(notice, dict) or not _non_empty_str(notice.get("message")):
            err("notice deve ser null ou ter 'message'")

    quota = config.get("quota") or {}
    for key, minimum in (("free_lifetime", 0), ("pro_daily", 1), ("sos_credits", 1)):
        if not _is_int(quota.get(key)) or quota[key] < minimum or quota[key] > 100:
            err(f"quota.{key} deve ser inteiro entre {minimum} e 100")

    options = config.get("profile_options") or {}
    ingredient_ids = []
    for i, ing in enumerate(options.get("ingredients") or []):
        if not _non_empty_str(ing.get("id")) or not _non_empty_str(ing.get("label")):
            err(f"profile_options.ingredients[{i}] precisa de id e label")
            continue
        ingredient_ids.append(ing["id"])
    if len(ingredient_ids) != len(set(ingredient_ids)):
        err("profile_options.ingredients tem ids repetidos")
    known_ingredients = set(ingredient_ids)

    condition_ids = []
    for i, cond in enumerate(options.get("conditions") or []):
        if not _non_empty_str(cond.get("id")) or not _non_empty_str(cond.get("label")):
            err(f"profile_options.conditions[{i}] precisa de id e label")
            continue
        condition_ids.append(cond["id"])
        unknown = set(cond.get("excludes") or []) - known_ingredients
        if unknown:
            err(f"condição '{cond['id']}' exclui ingredientes inexistentes: {sorted(unknown)}")
    if len(condition_ids) != len(set(condition_ids)):
        err("profile_options.conditions tem ids repetidos")

    products = config.get("products")
    if not isinstance(products, list) or not products:
        err("products deve ser uma lista não vazia")
        products = []

    product_ids = []
    active_categories = set()
    for i, p in enumerate(products):
        where = f"products[{i}] ({p.get('id', '?')})"
        for key in ("id", "name", "brand", "description", "price_display", "emoji"):
            if not _non_empty_str(p.get(key)):
                err(f"{where}: campo '{key}' obrigatório")
        product_ids.append(p.get("id"))
        if p.get("category") not in CATEGORIES:
            err(f"{where}: category deve ser uma de {sorted(CATEGORIES)}")
        if p.get("store") not in STORES:
            err(f"{where}: store deve ser uma de {sorted(STORES)}")
        if not isinstance(p.get("affiliate_url"), str) or not p["affiliate_url"].startswith("https://"):
            err(f"{where}: affiliate_url deve começar com https://")
        if not _is_number(p.get("price_estimated")) or p["price_estimated"] < 0:
            err(f"{where}: price_estimated deve ser número >= 0")
        if not _is_int(p.get("priority")):
            err(f"{where}: priority deve ser inteiro")
        if not isinstance(p.get("active"), bool):
            err(f"{where}: active deve ser true/false")
        if not isinstance(p.get("for_skin_types"), list):
            err(f"{where}: for_skin_types deve ser lista")
        ingredients = p.get("ingredients")
        if not isinstance(ingredients, list):
            err(f"{where}: ingredients deve ser lista (use [] se não houver)")
        else:
            unknown = set(ingredients) - known_ingredients
            if unknown:
                err(f"{where}: ingredientes fora de profile_options: {sorted(unknown)}")
        if p.get("active") is True:
            active_categories.add(p.get("category"))
    if len(product_ids) != len(set(product_ids)):
        err("products tem ids repetidos")

    rec = config.get("recommendation") or {}
    if not _is_int(rec.get("max_products")) or not 1 <= rec["max_products"] <= 10:
        err("recommendation.max_products deve ser inteiro entre 1 e 10")
    for cat in rec.get("required_categories") or []:
        if cat not in active_categories:
            err(f"recommendation.required_categories: nenhum produto ativo na categoria '{cat}'")

    plans = config.get("plans")
    if not isinstance(plans, list) or not plans:
        err("plans deve ser uma lista não vazia")
        plans = []
    plan_ids = []
    for i, plan in enumerate(plans):
        if not _non_empty_str(plan.get("product_id")) or not _non_empty_str(plan.get("label")):
            err(f"plans[{i}] precisa de product_id e label")
        if not isinstance(plan.get("consumable"), bool):
            err(f"plans[{i}].consumable deve ser true/false")
        plan_ids.append(plan.get("product_id"))
    if len(plan_ids) != len(set(plan_ids)):
        err("plans tem product_id repetido")

    if not isinstance(config.get("texts"), dict):
        err("texts deve ser um objeto")

    routine = config.get("routine") or {}
    for period in ("morning", "night"):
        for i, step in enumerate(routine.get(period) or []):
            if not _non_empty_str(step.get("title")):
                err(f"routine.{period}[{i}] precisa de title")
            unknown = set(step.get("ingredients") or []) - known_ingredients
            if unknown:
                err(f"routine.{period}[{i}]: ingredientes fora de profile_options: {sorted(unknown)}")

    server = config.get("server") or {}
    for key in SERVER_KEYS:
        if not _non_empty_str(server.get(key)):
            err(f"server.{key} obrigatório")

    return errors


def _add_query_param(url, key, value):
    parts = urlsplit(url)
    query = [(k, v) for k, v in parse_qsl(parts.query, keep_blank_values=True) if k != key]
    query.append((key, value))
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))


def inject_affiliate_tags(config, environ=None):
    """Adiciona as tags de afiliado configuradas no ambiente aos links dos produtos."""
    environ = os.environ if environ is None else environ
    result = copy.deepcopy(config)
    for product in result.get("products", []):
        host = urlsplit(product.get("affiliate_url", "")).netloc
        for domain, (env_name, param) in AFFILIATE_PARAMS.items():
            tag = environ.get(env_name, "")
            if tag and host.endswith(domain):
                product["affiliate_url"] = _add_query_param(product["affiliate_url"], param, tag)
    return result


def public_config(config):
    return {k: v for k, v in config.items() if k != "server"}


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def publish_to_kv(config):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as tmp:
        json.dump(config, tmp, ensure_ascii=False)
        tmp_path = tmp.name
    try:
        subprocess.run(
            ["npx", "wrangler", "kv", "key", "put", KV_KEY,
             "--path", tmp_path, "--binding", "CONFIG_KV", "--remote"],
            cwd=WORKER_DIR,
            check=True,
        )
    finally:
        os.unlink(tmp_path)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="apenas valida")
    parser.add_argument("--no-publish", action="store_true", help="não envia ao KV")
    parser.add_argument("--file", default=CONFIG_FILE, help="arquivo de config")
    args = parser.parse_args(argv)

    try:
        with open(args.file, "r", encoding="utf-8") as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"❌ Não foi possível ler {args.file}: {e}")
        return 1

    errors = validate(config)
    if errors:
        print("❌ Config inválida, nada foi publicado:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"✅ Config {config['config_version']} válida ({len(config['products'])} produtos).")

    if args.check:
        return 0

    final = inject_affiliate_tags(config)
    write_json(APP_ASSET_FILE, public_config(final))
    print(f"📦 Cópia embutida atualizada: {os.path.relpath(APP_ASSET_FILE, ROOT)}")

    if args.no_publish:
        return 0

    publish_to_kv(final)
    print("🚀 Publicado no KV do Worker. O app recebe em até ~1 hora (ou ao reabrir).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
