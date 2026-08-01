"""Check the pack's access rules are assigned consistently with the apworld's Rules.py.

This cannot verify what a Lua rule *does* -- only that locations sharing an apworld rule
also share a pack rule, and vice versa. That catches mis-assigned rules and, after an
apworld change, locations whose rule moved. Both levels of rule are checked: the apworld's
location_rules against the pack's group/section rules, and its region_rules against the
rules on the pack's act roots. Run with the path to the apworld directory:

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


def apworld_region_rules(world):
    """AP region name -> rule named in region_rules. Applied to the region's entrances."""
    src = open(os.path.join(world, "Rules.py"), encoding="utf-8").read()
    body = re.search(r"self\.region_rules\s*=\s*\{(.*?)\n        \}", src, re.S).group(1)
    return dict(re.findall(r'"([^"]+)":\s*self\.(\w+)', body))


def apworld_locations(world):
    """AP location names in id order, and the region each one belongs to.

    Ids come from all_locations, so the list order here has to match __init__.py's concat.
    """
    src = open(os.path.join(world, "Locations.py"), encoding="utf-8").read()
    r2l = re.search(r"regions_to_locations[^=]*=\s*\{(.*?)^\}", src, re.M | re.S).group(1)
    region_of_list = {lst: region for region, lst in re.findall(r'"([^"]+)":\s*(\w+)', r2l)}
    names, regions = [], {}
    for lst in ("act1_locations", "act2_locations", "act3_locations"):
        chunk = re.search(rf"^{lst}[^=]*=\s*\[(.*?)^\]", src, re.M | re.S).group(1)
        for name in re.findall(r'"([^"]+)"', chunk):
            names.append(name)
            regions[name] = region_of_list.get(lst, f"<{lst} in no region>")
    return names, regions


def pack_rules():
    """Pack location path -> (rules on the act root, rules in effect on the check itself)."""
    out = {}
    for act in ("Act1", "Act2", "Act3"):
        for root in load_json(os.path.join(PACK, "locations", f"{act}.json")):
            rootr = frozenset(root.get("access_rules", []))
            for group in root.get("children", []):
                gpath = f"@{root['name']}/{group['name']}"
                grules = tuple(group.get("access_rules", []))
                for sec in group.get("sections", []):
                    srules = tuple(sec.get("access_rules", []))
                    out[f"{gpath}/{sec['name']}"] = (rootr, frozenset(grules + srules))
    return out


def id_to_path():
    text = open(os.path.join(PACK, "scripts/autotracking/location_mapping.lua"),
                encoding="utf-8").read()
    return {int(i): p for i, p in re.findall(r'\[(\d+)\]\s*=\s*\{"([^"]+)"\}', text)}


EXAMPLES = 3  # a whole act can share one rule, so list the split, not every location


def report_split(header, groups, problems):
    """Report one rule covering several counterparts, as a count and a few examples each."""
    problems.append(f"{header} {len(groups)} different rules:")
    for key, locs in sorted(groups.items(), key=lambda kv: (-len(kv[1]), sorted(kv[1]))):
        shown = sorted(locs)[:EXAMPLES]
        more = f", +{len(locs) - EXAMPLES} more" if len(locs) > EXAMPLES else ""
        problems.append(f"    {key}  <- {len(locs)}x: {', '.join(shown)}{more}")


def check_partition(pairs, label, problems):
    """Verify (apworld rule, pack rules) pairs partition their locations identically."""
    ap_to_pack, pack_to_ap = defaultdict(lambda: defaultdict(set)), \
        defaultdict(lambda: defaultdict(set))
    for ap_rule, rules, ap_name in pairs:
        ap_to_pack[ap_rule][rules].add(ap_name)
        pack_to_ap[rules][ap_rule].add(ap_name)

    for ap_rule, groups in sorted(ap_to_pack.items()):
        if len(groups) > 1:
            report_split(f"apworld {label} rule {ap_rule} maps to",
                         {str(sorted(r) or ["<none>"]): v for r, v in groups.items()}, problems)

    for rules, groups in sorted(pack_to_ap.items(), key=lambda kv: sorted(kv[0])):
        if len(groups) > 1:
            report_split(f"pack {label} rule {sorted(rules) or ['<none>']} covers",
                         groups, problems)

    return len(ap_to_pack), len(pack_to_ap)


def normalize(rules):
    """Rule factories take a count ("$a3_pelts|3") -- compare the function, not the count.
    An item argument ("$has|dagger") is part of the rule's identity, so keep it."""
    return frozenset(r.split("|")[0] if r.split("|")[-1].isdigit() else r for r in rules)


def main():
    world = sys.argv[1] if len(sys.argv) > 1 else r"../Archipelago/worlds/inscryption_beta"
    ap_rules, conditional = apworld_rules(world)
    ap_region_rules = apworld_region_rules(world)
    names, ap_regions = apworld_locations(world)
    packr, mapping = pack_rules(), id_to_path()

    loc_pairs, region_pairs, problems = [], [], []
    missing_root_rule = set()

    for i, ap_name in enumerate(names):
        path = mapping.get(147000 + i)
        if path is None:
            problems.append(f"no pack mapping for {ap_name}")
            continue
        if path not in packr:
            problems.append(f"mapping points at a missing section: {path}")
            continue
        root_rules, own_rules = packr[path]
        region = ap_regions[ap_name]
        ap_region_rule = ap_region_rules.get(region, "<none>")
        # A uniform drop stays a valid partition, so also require the rule to exist at all.
        if ap_region_rule != "<none>" and not root_rules:
            missing_root_rule.add(f"{region} has {ap_region_rule} in Rules.py but the pack "
                                  f"root for {path.split('/')[0]} has no access rule")
        region_pairs.append((ap_region_rule, normalize(root_rules), ap_name))
        rules = normalize(own_rules)
        if ap_name in conditional:
            if not rules:
                problems.append(f"{ap_name} has an option-dependent rule in Rules.py "
                                f"but no rule in the pack")
            continue
        loc_pairs.append((ap_rules.get(ap_name, "<none>"), rules, ap_name))

    problems += sorted(missing_root_rule)
    n_ap, n_pack = check_partition(loc_pairs, "location", problems)
    r_ap, r_pack = check_partition(region_pairs, "region", problems)

    empty = sorted(set(ap_region_rules) - set(ap_regions.values()))
    print(f"{len(names)} locations, {n_ap} distinct apworld rules, {n_pack} distinct pack rules")
    print(f"{r_ap} apworld region rules, {r_pack} distinct pack root rules"
          + (f" ({', '.join(empty)}: no locations, not checked)" if empty else ""))
    for p in problems:
        print(p)
    print("FAILED" if problems else "consistent")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
