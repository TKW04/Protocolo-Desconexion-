"""Esquema de los recuerdos (data/memories.json, tools/validate_memories.py; paso 1 de
docs/propuesta-recuerdos.md §7, con las decisiones del 2026-10-19 de §10).

- Los datos reales son validos: 18 capas de jefe (6 mundos x 3) y los mensajes del Mundo 1 (1-1
  secreto A, 1-2 Spam, 1-3 Excepciones) con remitente, asunto, nivel, secreto y first_lap.
- Casos negativos sinteticos: id repetido, capa que falta o repetida, mundo fuera de rango,
  mensaje sin remitente o asunto, jefe con campos de mensaje, mensaje con capa, nivel de otro
  mundo o sin registrar, secreto que el nivel no tiene, first_lap fuera de rango o de una vuelta
  en la que el subnivel no existe, glifos que la fuente no tiene y textos que nombran las vueltas.

Uso: python3 -m unittest tests/test_memories.py
"""
import copy
import json
import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import validate_memories as vm  # noqa: E402

DATA = os.path.join(ROOT, "data", "memories.json")
LEVELS = {"1-1": (1, [1]), "1-2": (1, [1]), "1-3": (1, [1]), "2-1": (2, [1, 2])}
SECRETS = {"1-1": {"secreto_a"}, "1-2": {"secreto_spam"}}


def _boss_set():
    out = []
    for w in range(1, 7):
        for layer in (1, 2, 3):
            out.append({"id": "boss_w%d_l%d" % (w, layer), "world": w, "kind": "boss", "layer": layer,
                        "order": layer, "title": "Fragmento", "text": "(por escribir)"})
    return out


def _message(**extra):
    m = {"id": "msg_1_1", "world": 1, "kind": "secret", "order": 1, "level": "1-1", "secret": "secreto_a",
         "first_lap": 1, "sender": "Mamá", "subject": "Recado", "title": "Recado", "text": "Hola."}
    m.update(extra)
    return m


def _validate(items):
    return vm.validate({"memories": items}, levels=LEVELS, secrets_of=SECRETS.get)


class RealData(unittest.TestCase):
    def setUp(self):
        with open(DATA, encoding="utf-8") as fh:
            self.data = json.load(fh)

    def test_real_data_is_valid(self):
        self.assertEqual(vm.validate(self.data), [])

    def test_script_exits_zero(self):
        result = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "validate_memories.py")],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_eighteen_boss_layers_and_world_1_messages(self):
        items = self.data["memories"]
        bosses = [m for m in items if m["kind"] == "boss"]
        self.assertEqual(len(bosses), 18)
        messages = {m["level"]: m for m in items if m["kind"] == "secret"}
        self.assertEqual(sorted(messages), ["1-1", "1-2", "1-3"])
        self.assertEqual(messages["1-1"]["secret"], "secreto_puente_servicio")
        self.assertEqual(messages["1-2"]["secret"], "secreto_spam")
        for m in messages.values():
            self.assertEqual(m["first_lap"], 1, "Los mensajes de Caché aparecen desde Caché")
            self.assertEqual(m["sender"], "Mamá")

    def test_world_1_sketch_is_written(self):
        w1 = [m for m in self.data["memories"] if m["kind"] == "boss" and m["world"] == 1]
        for m in w1:
            self.assertNotIn("por escribir", m["text"], "Esbozo del Mundo 1 (§5)")
        others = [m for m in self.data["memories"] if m["kind"] == "boss" and m["world"] != 1]
        for m in others:
            self.assertEqual(m["text"], "(por escribir)", "Sin inventar historia")


class Synthetic(unittest.TestCase):
    def test_baseline_is_valid(self):
        self.assertEqual(_validate(_boss_set() + [_message()]), [])

    def _assert_error(self, items, fragment):
        errors = _validate(items)
        self.assertTrue(any(fragment in e for e in errors), "%r no esta en %r" % (fragment, errors))

    def test_duplicate_id(self):
        self._assert_error(_boss_set() + [_message(), _message(order=2)], "id repetido")

    def test_missing_and_repeated_layer(self):
        bosses = _boss_set()
        bosses = [b for b in bosses if b["id"] != "boss_w3_l2"]
        self._assert_error(bosses, "mundo 3")
        bosses = _boss_set()
        bosses[1]["layer"] = 1
        bosses[1]["order"] = 9
        self._assert_error(bosses, "mundo 1")

    def test_bad_world_and_layer(self):
        bosses = _boss_set()
        bosses[0]["world"] = 7
        self._assert_error(bosses, "world debe ser")
        bosses = _boss_set()
        bosses[0]["layer"] = 4
        self._assert_error(bosses, "layer debe ser")

    def test_message_needs_sender_and_subject(self):
        self._assert_error(_boss_set() + [_message(sender="")], "necesita sender")
        m = _message()
        del m["subject"]
        self._assert_error(_boss_set() + [m], "necesita subject")

    def test_boss_has_no_message_fields_and_message_no_layer(self):
        bosses = _boss_set()
        bosses[0]["first_lap"] = 1
        self._assert_error(bosses, "no lleva first_lap")
        self._assert_error(_boss_set() + [_message(layer=1)], "no lleva layer")

    def test_message_place(self):
        self._assert_error(_boss_set() + [_message(level="2-1")], "no es del mundo")
        self._assert_error(_boss_set() + [_message(level="1-9")], "no esta en worlds")
        self._assert_error(_boss_set() + [_message(secret="secreto_x")], "no tiene el secreto")
        self._assert_error(_boss_set() + [_message(secret="")], "falta el secreto")
        # Nivel sin JSON todavia (1-3): basta con nombrar el secreto.
        self.assertEqual(_validate(_boss_set() + [_message(level="1-3", secret="secreto_excepciones")]), [])

    def test_first_lap(self):
        self._assert_error(_boss_set() + [_message(first_lap=4)], "first_lap debe ser")
        self._assert_error(_boss_set() + [_message(first_lap=2)], "no existe en el acceso 2")
        m = _message(id="msg_2_1", world=2, level="2-1", secret="s", first_lap=2)
        self.assertEqual(_validate(_boss_set() + [m]), [], "2-1 existe en Kernel")

    def test_texts(self):
        self._assert_error(_boss_set() + [_message(text="Hola €")], "glifos")
        self._assert_error(_boss_set() + [_message(text="En la vuelta Normal")], "nombra las vueltas")

    def test_real_data_copy_with_unknown_secret_fails(self):
        with open(DATA, encoding="utf-8") as fh:
            data = json.load(fh)
        broken = copy.deepcopy(data)
        for m in broken["memories"]:
            if m.get("level") == "1-2":
                m["secret"] = "secreto_que_no_existe"
        self.assertTrue(any("no tiene el secreto" in e for e in vm.validate(broken)))



class LevelLinks(unittest.TestCase):
    """Coherencia mensaje <-> secreto del nivel (paso 4, 2026-10-19): el secreto de cada mensaje lo
    ofrece con la recompensa memory y el nivel tiene su memory_pickup; y al reves."""

    def test_real_levels_offer_their_messages(self):
        links = vm.level_links()
        self.assertEqual(links["1-1"]["secrets"]["secreto_puente_servicio"], "msg_1_1")
        self.assertEqual(links["1-2"]["secrets"]["secreto_spam"], "msg_1_2")
        self.assertEqual(links["1-1"]["pickups"], {"msg_1_1"})
        self.assertEqual(links["1-2"]["pickups"], {"msg_1_2"})
        self.assertNotIn("1-3", links, "El 1-3 aun no existe")
        with open(DATA, encoding="utf-8") as fh:
            self.assertEqual(vm.validate(json.load(fh)), [])

    def _links(self, secret_mid="msg_1_1", pickups=("msg_1_1",)):
        return {"1-1": {"secrets": {"secreto_a": secret_mid}, "pickups": set(pickups)}}

    def _validate(self, links, items=None):
        items = items if items is not None else _boss_set() + [_message()]
        return vm.validate({"memories": items}, levels=LEVELS, secrets_of=SECRETS.get, links=links)

    def test_coherent_links_are_valid(self):
        self.assertEqual(self._validate(self._links()), [])

    def test_secret_that_does_not_offer_its_message(self):
        errors = self._validate(self._links(secret_mid=None))
        self.assertTrue(any("el secreto secreto_a del nivel 1-1 no lo ofrece" in e for e in errors), errors)

    def test_level_without_the_pickup(self):
        errors = self._validate(self._links(pickups=()))
        self.assertTrue(any("no tiene ningun memory_pickup con memory_id msg_1_1" in e for e in errors), errors)

    def test_reward_or_pickup_pointing_elsewhere(self):
        links = self._links()
        links["1-2"] = {"secrets": {"secreto_spam": "msg_1_1"}, "pickups": {"msg_1_1", "msg_x"}}
        errors = self._validate(links)
        self.assertTrue(any("nivel 1-2, secreto secreto_spam: el mensaje msg_1_1 es del nivel 1-1" in e
                            for e in errors), errors)
        self.assertTrue(any("nivel 1-2: memory_pickup del mensaje msg_1_1, que es del nivel 1-1" in e
                            for e in errors), errors)
        self.assertTrue(any("memory_pickup con memory_id msg_x, que no es un mensaje" in e for e in errors), errors)

    def test_test_room_standing_for_the_level(self):
        """Una sala de prueba con stands_for (2026-10-20, paso 7 de docs/propuesta-1-3.md) ofrece
        el mensaje de ese subnivel; sin stands_for, no."""
        links = self._links()
        links["excepciones_test"] = {"secrets": {"secreto_a": "msg_1_1"}, "pickups": {"msg_1_1"},
                                     "stands_for": "1-1"}
        self.assertEqual(self._validate(links), [])
        links["excepciones_test"]["stands_for"] = None
        errors = self._validate(links)
        self.assertTrue(any("nivel excepciones_test, secreto secreto_a: el mensaje msg_1_1 es del nivel 1-1" in e
                            for e in errors), errors)

    def test_real_excepciones_room_offers_msg_1_3(self):
        links = vm.level_links()
        self.assertEqual(links["excepciones_test"]["secrets"]["secreto_excepciones"], "msg_1_3")
        self.assertEqual(links["excepciones_test"]["stands_for"], "1-3")


if __name__ == "__main__":
    unittest.main()
