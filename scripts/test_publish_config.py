#!/usr/bin/env python3
"""Testes do validador da config remota: python3 scripts/test_publish_config.py"""

import copy
import json
import os
import unittest

import publish_config as pc

with open(pc.CONFIG_FILE, "r", encoding="utf-8") as f:
    BASE = json.load(f)


def mutate(fn):
    config = copy.deepcopy(BASE)
    fn(config)
    return pc.validate(config)


class ValidateTest(unittest.TestCase):
    def test_config_do_repositorio_e_valida(self):
        self.assertEqual(pc.validate(BASE), [])

    def test_id_de_produto_repetido(self):
        errors = mutate(lambda c: c["products"].append(copy.deepcopy(c["products"][0])))
        self.assertTrue(any("ids repetidos" in e for e in errors))

    def test_ingrediente_desconhecido(self):
        errors = mutate(lambda c: c["products"][0].update(ingredients=["mercurio"]))
        self.assertTrue(any("mercurio" in e for e in errors))

    def test_link_sem_https(self):
        errors = mutate(lambda c: c["products"][0].update(affiliate_url="http://shopee.com.br/x"))
        self.assertTrue(any("https" in e for e in errors))

    def test_categoria_obrigatoria_sem_produto_ativo(self):
        def disable_sunscreens(c):
            for p in c["products"]:
                if p["category"] == "protetor":
                    p["active"] = False
        errors = mutate(disable_sunscreens)
        self.assertTrue(any("protetor" in e for e in errors))

    def test_cota_fora_do_intervalo(self):
        errors = mutate(lambda c: c["quota"].update(pro_daily=0))
        self.assertTrue(any("pro_daily" in e for e in errors))

    def test_prompt_ausente(self):
        errors = mutate(lambda c: c["server"].pop("report_prompt"))
        self.assertTrue(any("report_prompt" in e for e in errors))

    def test_config_invalida_nao_publica(self):
        broken = copy.deepcopy(BASE)
        broken["schema_version"] = 99
        path = os.path.join(os.path.dirname(__file__), "_broken_config.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(broken, f)
        published = []
        original = pc.publish_to_kv
        pc.publish_to_kv = lambda cfg: published.append(cfg)
        try:
            self.assertEqual(pc.main(["--file", path]), 1)
        finally:
            pc.publish_to_kv = original
            os.unlink(path)
        self.assertEqual(published, [])


class TransformTest(unittest.TestCase):
    def test_publico_sem_server(self):
        self.assertNotIn("server", pc.public_config(BASE))

    def test_injeta_tag_amazon_sem_duplicar(self):
        result = pc.inject_affiliate_tags(BASE, {"AMAZON_AFFILIATE_TAG": "peleia-20"})
        result = pc.inject_affiliate_tags(result, {"AMAZON_AFFILIATE_TAG": "peleia-20"})
        amazon = [p for p in result["products"] if p["store"] == "amazon"]
        self.assertTrue(amazon)
        for p in amazon:
            self.assertEqual(p["affiliate_url"].count("tag=peleia-20"), 1)
        shopee = [p for p in result["products"] if p["store"] == "shopee"]
        self.assertTrue(all("tag=" not in p["affiliate_url"] for p in shopee))


if __name__ == "__main__":
    unittest.main()
