"""Check the pack's logic.lua produces the same answers as the apworld's Rules.py.

check_logic_sync.py verifies that locations are *assigned* matching rules; this verifies the
rules themselves agree, by evaluating both implementations over the same option grid and the
same inventories and reporting any rule that disagrees. Needs a `lua` binary on PATH, and a
Python that can import the apworld (the Archipelago venv):

    Archipelago/.venv/bin/python tools/check_logic_parity.py ../Archipelago/worlds/inscryption_beta

Two things this learned the hard way:

* Inventories are bucketed by their Act 1 points total rather than sampled freely. The Act 1
  rules are thresholds on that total, so a random inventory almost never lands on a boundary
  and a one-point difference between the two files stays invisible.
* All three acts are enabled. With an act off the pack returns false, since its access rules
  drive visibility, while the apworld returns True because the region does not exist. That is
  a difference in purpose, not a drift, so comparing it would only produce noise.
"""
import importlib
import itertools
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace

PACK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# apworld rule -> pack function. "name:n" takes an argument; "painting:n" is folded by the
# pack into one function per painting, so the apworld side rebuilds set_all_rules' branches.
PAIRS = [
    ("has_later_woodlands_requirements", "a1_woodlands_later", None),
    ("has_prospector_requirements", "a1_prospector", None),
    ("has_wetlands_requirements", "a1_wetlands", None),
    ("has_angler_requirements", "a1_angler", None),
    ("has_snow_line_requirements", "a1_snow_line", None),
    ("has_trapper_requirements", "a1_trapper", None),
    ("has_leshy_requirements", "a1_leshy", None),
    ("has_woodlands_consumable_requirements", "a1_woodlands_consumable", None),
    ("has_wetlands_consumable_requirements", "a1_wetlands_consumable", None),
    ("has_snow_line_consumable_requirements", "a1_snow_line_consumable", None),
    ("has_wolf_pelt_requirements", "a1_wolf_pelt", None),
    ("has_golden_pelt_requirements", "a1_golden_pelt", None),
    ("has_useful_act1_items", "a1_useful_items", None),
    ("has_all_epitaph_pieces", "has_all_epitaphs", None),
    ("has_act2_right_side_requirements", "a2_right_side", None),
    ("has_act2_bridge_requirements", "a2_bridge", None),
    ("has_forest_requirements", "a2_forest", None),
    ("has_grimora_requirements", "a2_grimora", None),
    ("has_bone_lord_stairs_requirements", "a2_bone_lord_stairs", None),
    ("has_tower_requirements", "a2_tower", None),
    ("has_tower_and_right_requirements", "a2_tower_and_right", None),
    ("has_inspectometer_battery", "a3_battery", None),
    ("has_act3_missable_check_requirements", "a3_missable", None),
    ("has_act3_bridge_requirements", "a3_bridge", None),
    ("has_filthy_corpse_world_requirements", "a3_filthy_corpse_world", None),
    ("has_gems_and_battery", "a3_gems_and_battery", None),
    ("has_gaudy_gem_land_requirements", "a3_gaudy_gem_land", None),
    ("has_resplendent_bastion_requirements", "a3_bastion", None),
    ("has_archivist_requirements", "a3_archivist", None),
    ("has_transcendence_requirements", "a3_transcendence", None),
    ("has_mycologists_boss_requirements", "a3_mycologists", None),
    ("has_bone_lord_room_requirements", "a3_bone_lord_room", None),
    ("has_goobert_painting_requirements", "a3_goobert_painting", None),
    ("has_act3_shop_requirements", "a3_shop", None),
    ("has_ourobot_requirements", "a3_ourobot", None),
    ("has_act1_requirements", "act1_access", None),
    ("beat_act1_requirements", "beat_act1", None),
    ("has_act2_requirements", "act2_access", None),
    ("beat_act2_requirements", "beat_act2", None),
    ("has_act3_requirements", "act3_access", None),
    ("beat_act3_requirements", "beat_act3", None),
]
PAIRS += [(f"has_pelts:{n}", "a3_pelts", n) for n in range(1, 6)]
PAIRS += [(f"has_vessel_upgrade_requirements:{n}", "a3_vessel_upgrade", n) for n in range(1, 5)]
PAIRS += [(f"painting:{n}", f"a1_painting_{n}", None) for n in (1, 2, 3)]

STACKS = {"Tipped Scales Challenge": 3, "More Difficult Challenge": 2, "Progressive Candle": 2,
          "Progressive Squirrel": 2, "Progressive Grizzlies": 3, "Holo Pelt": 5}
EPITAPHS = {0: ("Epitaph Piece", 9), 1: ("Epitaph Pieces", 3), 2: ("Epitaph Pieces", 1)}
DEFAULT_OPTS = {"randnodes": 0, "randchallenges": 0, "act2bridge": 0, "act3overhaul": 0,
                "actunlocks": 0, "epitaphtype": 0, "paintingbalance": 0}


def load_json(path):
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", open(path, encoding="utf-8").read()))


def import_rules(world):
    """Import the apworld's Rules module, with the Archipelago root on the path."""
    world = os.path.abspath(world)
    package, worlds_dir = os.path.basename(world), os.path.dirname(world)
    sys.path.insert(0, os.path.dirname(worlds_dir))
    return importlib.import_module(f"{os.path.basename(worlds_dir)}.{package}.Rules")


class FakeState:
    """Stands in for a CollectionState holding a fixed inventory."""

    def __init__(self, items):
        self.items = items

    def has(self, item, player, count=1):
        return self.items.get(item, 0) >= count

    def count(self, item, player):
        return self.items.get(item, 0)

    def has_all(self, items, player):
        return all(self.items.get(i, 0) >= 1 for i in items)


def make_world(opts):
    name, count = EPITAPHS[opts["epitaphtype"]]
    return SimpleNamespace(
        player=1, multiworld=None,
        required_epitaph_pieces_name=name, required_epitaph_pieces_count=count,
        options=SimpleNamespace(
            randomize_nodes=opts["randnodes"], randomize_challenges=opts["randchallenges"],
            act2_randomize_bridge=opts["act2bridge"], act3_overhaul=opts["act3overhaul"],
            act_unlocks=opts["actunlocks"], painting_checks_balancing=opts["paintingbalance"],
            enable_act_1=1, enable_act_2=1, enable_act_3=1, goal=2))


def python_rule(rules, name, arg, state):
    if name.startswith("has_pelts:"):
        return rules.has_pelts(arg)(state)
    if name.startswith("has_vessel_upgrade_requirements:"):
        return rules.has_vessel_upgrade_requirements(arg)(state)
    if name.startswith("painting:"):
        which = name.split(":")[1]
        if rules.act1_randomized:
            return {"1": rules.has_prospector_requirements,
                    "2": rules.has_painting_2_requirements,
                    "3": rules.has_painting_3_requirements}[which](state)
        if which != "1" and rules.world.options.painting_checks_balancing == 1:
            return rules.has_useful_act1_items(state)
        return True
    return getattr(rules, name)(state)


def random_items(rng, singles):
    density = rng.uniform(0.02, 0.75)
    items = {n: 1 for n in singles if rng.random() < density}
    for name, cap in STACKS.items():
        n = sum(1 for _ in range(cap) if rng.random() < density)
        if n:
            items[name] = n
    n = sum(1 for _ in range(9) if rng.random() < density)
    if n:
        items["Epitaph Piece"] = items["Epitaph Pieces"] = n
    return items


def build_inventories(rng, rules_module, singles, per_bucket=2):
    """Inventories bucketed by Act 1 points, so every threshold boundary is represented."""
    probe = rules_module.InscryptionRules(
        make_world(dict(DEFAULT_OPTS, randnodes=1, randchallenges=2)))
    buckets = {}
    for _ in range(40000):
        inv = random_items(rng, singles)
        state = FakeState(inv)
        # Points are context-free now, so bucket on the total and on what each context withholds
        # -- that is what still moves a threshold boundary.
        key = (probe.act1_battle_points(state),
               probe.act1_points_withheld(state, rules_module.LATER_BOSS),
               probe.act1_points_withheld(state, rules_module.WOODLANDS_BATTLE),
               min(inv.get("Progressive Grizzlies", 0), 3))
        bucket = buckets.setdefault(key, [])
        if len(bucket) < per_bucket:
            bucket.append(inv)
    out = [inv for bucket in buckets.values() for inv in bucket]
    rng.shuffle(out)
    return out


def lua_literal(d):
    body = ",".join(f'["{k}"]="{v}"' if isinstance(v, str) else f'["{k}"]={v}'
                    for k, v in d.items())
    return "{" + body + "}"


def run_pass(label, grid, inventories, rules_module, code, kind, tmp):
    names, values = list(grid), list(grid.values())
    cases, meta = [], []
    for combo in itertools.product(*values):
        opts = {**DEFAULT_OPTS, **dict(zip(names, combo))}
        lua_opts = dict(opts, act1on=1, act2on=1, act3on=1, releaseonact=0, goal=2)
        for inv in inventories:
            cases.append((lua_opts, {code[item]: n for item, n in inv.items()}))
            meta.append((opts, inv))

    rules_lua = ",".join(f'{{fn="{fn}"}}' if arg is None else f'{{fn="{fn}",arg={arg}}}'
                         for _, fn, arg in PAIRS)
    cases_path = os.path.join(tmp, f"{label}.lua")
    with open(cases_path, "w", encoding="utf-8") as f:
        f.write("return {rules={" + rules_lua + "},cases={")
        f.write(",".join(f"{{opts={lua_literal(o)},items={lua_literal(i)}}}" for o, i in cases))
        f.write("}}\n")
    with open(cases_path + ".types", "w", encoding="utf-8") as f:
        f.write("return " + lua_literal(kind) + "\n")

    print(f"{label}: {len(cases)} cases x {len(PAIRS)} rules = "
          f"{len(cases) * len(PAIRS)} evaluations")
    driver = os.path.join(PACK, "tools", "logic_driver.lua")
    proc = subprocess.run(["lua", driver, PACK, cases_path], capture_output=True, text=True)
    if proc.returncode != 0:
        print("  lua failed:\n" + proc.stderr[:2000])
        return 1
    rows = proc.stdout.strip().split("\n")
    if len(rows) != len(cases):
        print(f"  driver returned {len(rows)} rows for {len(cases)} cases")
        return 1

    mismatches = {}
    for row, (opts, inv) in zip(rows, meta):
        rules = rules_module.InscryptionRules(make_world(opts))
        state = FakeState(inv)
        for (ap_name, pack_name, arg), got in zip(PAIRS, row):
            if bool(python_rule(rules, ap_name, arg, state)) != (got == "1"):
                mismatches.setdefault(f"{ap_name} / {pack_name}", []).append((opts, inv))

    if not mismatches:
        print(f"  all {len(PAIRS)} rules agree")
        return 0
    print(f"  FAILED: {len(mismatches)} rules disagree")
    for key, examples in mismatches.items():
        opts, inv = examples[0]
        print(f"    {key}: {len(examples)} cases, e.g. opts={opts}")
        print(f"        items={inv}")
    return 1


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    if not shutil.which("lua"):
        print("no `lua` on PATH (brew install lua)")
        return 2

    rules_module = import_rules(sys.argv[1])
    items = load_json(os.path.join(PACK, "items", "items.json"))
    code = {e["name"]: e["codes"] for e in items if e.get("codes")}
    kind = {e["codes"]: e.get("type", "toggle") for e in items if e.get("codes")}
    code["Epitaph Piece"] = code["Epitaph Pieces"] = "epitaph"
    singles = [n for n in code if n not in STACKS and n not in ("Epitaph Piece", "Epitaph Pieces")]

    rng = random.Random(20260809)
    inventories = build_inventories(rng, rules_module, singles)
    print(f"{len(inventories)} inventories covering the Act 1 points range")

    tmp = tempfile.mkdtemp(prefix="logic_parity_")
    try:
        # The first pass sweeps every option combination, the second sweeps the thresholds,
        # where the Act 1 options are the only ones that matter.
        failures = run_pass("options",
                            {"randnodes": (0, 1), "randchallenges": (0, 1, 2),
                             "act2bridge": (0, 1, 2), "act3overhaul": (0, 1),
                             "actunlocks": (0, 1, 2), "epitaphtype": (0, 1, 2),
                             "paintingbalance": (0, 1, 2)},
                            inventories[:40], rules_module, code, kind, tmp)
        failures += run_pass("thresholds",
                             {"randnodes": (0, 1), "randchallenges": (0, 1, 2),
                              "paintingbalance": (0, 1, 2)},
                             inventories, rules_module, code, kind, tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("FAILED" if failures else "consistent")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
