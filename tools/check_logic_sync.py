"""Check the pack's access rules are assigned consistently with the apworld's Rules.py.

This cannot verify what a Lua rule *does* -- only that locations sharing an apworld rule
also share a pack rule, and vice versa. That catches mis-assigned rules and, after an
apworld change, locations whose rule moved. Run with the path to the apworld directory:

    python tools/check_logic_sync.py ../Archipelago/worlds/inscryption_beta
"""
import json, os, re, sys
from collections import defaultdict

PACK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_json(path):
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", open(path, encoding="utf-8").read()))


def apworld_rules(world):
    """AP location name -> rule named in location_rules, plus those set in set_all_rules.

    set_all_rules assigns option-dependent rules, so those locations are only checked for
    having some rule at all; the pack folds the branches into one wrapper function.
    """
    src = open(os.path.join(world, "Rules.py"), encoding="utf-8").read()
    body = re.search(r"self\.location_rules\s*=\s*\{(.*?)\n        \}", src, re.S).group(1)
    rules = dict(re.findall(r'"([^"]+)":\s*self\.(\w+)', body))
    conditional = set(re.findall(r'get_location\("([^"]+)"\)\.access_rule', src))
    return rules, conditional


def apworld_locations(world):
    src = open(os.path.join(world, "Locations.py"), encoding="utf-8").read()
    names = []
    for lst in ("act1_locations", "act2_locations", "act3_locations"):
        chunk = re.search(rf"^{lst}[^=]*=\s*\[(.*?)^\]", src, re.M | re.S).group(1)
        names += re.findall(r'"([^"]+)"', chunk)
    return names


def pack_rules():
    """Pack location path -> frozenset of access rules in effect (group + section)."""
    out = {}
    for act in ("Act1", "Act2", "Act3"):
        for root in load_json(os.path.join(PACK, "locations", f"{act}.json")):
            for group in root.get("children", []):
                gpath = f"@{root['name']}/{group['name']}"
                grules = tuple(group.get("access_rules", []))
                for sec in group.get("sections", []):
                    srules = tuple(sec.get("access_rules", []))
                    out[f"{gpath}/{sec['name']}"] = frozenset(grules + srules)
    return out


def id_to_path():
    text = open(os.path.join(PACK, "scripts/autotracking/location_mapping.lua"),
                encoding="utf-8").read()
    return {int(i): p for i, p in re.findall(r'\[(\d+)\]\s*=\s*\{"([^"]+)"\}', text)}


def main():
    world = sys.argv[1] if len(sys.argv) > 1 else r"../Archipelago/worlds/inscryption_beta"
    (ap_rules, conditional), names = apworld_rules(world), apworld_locations(world)
    packr, mapping = pack_rules(), id_to_path()

    ap_to_pack = defaultdict(set)
    pack_to_ap = defaultdict(set)
    problems = []

    for i, ap_name in enumerate(names):
        path = mapping.get(147000 + i)
        if path is None:
            problems.append(f"no pack mapping for {ap_name}")
            continue
        if path not in packr:
            problems.append(f"mapping points at a missing section: {path}")
            continue
        # Rule factories take a count ("$a3_pelts|3") -- compare the function, not the count.
        # An item argument ("$has|dagger") is part of the rule's identity, so keep it.
        rules = frozenset(r.split("|")[0] if r.split("|")[-1].isdigit() else r
                          for r in packr[path])
        if ap_name in conditional:
            if not rules:
                problems.append(f"{ap_name} has an option-dependent rule in Rules.py "
                                f"but no rule in the pack")
            continue
        ap_rule = ap_rules.get(ap_name, "<none>")
        ap_to_pack[ap_rule].add((rules, ap_name))
        pack_to_ap[rules].add((ap_rule, ap_name))

    for ap_rule, entries in sorted(ap_to_pack.items()):
        variants = {rules for rules, _ in entries}
        if len(variants) > 1:
            problems.append(f"apworld rule {ap_rule} maps to {len(variants)} different pack rules:")
            for rules, ap_name in sorted(entries, key=lambda e: sorted(e[0])):
                problems.append(f"    {sorted(rules) or ['<none>']}  <- {ap_name}")

    for rules, entries in sorted(pack_to_ap.items(), key=lambda kv: sorted(kv[0])):
        variants = {rule for rule, _ in entries}
        if len(variants) > 1:
            problems.append(f"pack rule {sorted(rules) or ['<none>']} covers "
                            f"{len(variants)} different apworld rules:")
            for rule, ap_name in sorted(entries):
                problems.append(f"    {rule}  <- {ap_name}")

    print(f"{len(names)} locations, {len(ap_to_pack)} distinct apworld rules, "
          f"{len(pack_to_ap)} distinct pack rules")
    for p in problems:
        print(p)
    print("FAILED" if problems else "consistent")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
