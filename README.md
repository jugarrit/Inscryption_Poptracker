# Inscryption Poptracker pack with Archipelago autotracking

This is a tracker pack for Poptracker. [Get Poptracker here](https://github.com/black-sliver/PopTracker/releases).

To install this pack, download the source code zip in [releases](https://github.com/DrBibop/Inscryption_Poptracker/releases) and move the zip package into Poptracker's `packs` folder.

## Version 2.0 — Inscryption Beta

This pack targets the **`Inscryption Beta`** apworld (the `inscryption_beta` world used by the
[empathy-mp3 fork](https://github.com/empathy-mp3/Archipelago_Inscryption) of the mod), not the
original `Inscryption` world. Location and item ids differ between the two, so use pack version
1.0 for the original apworld.

What the beta adds, and what this pack now tracks:

* **Act 1 map checks** — the 9 area battles, 6 consumable checks, the 3 pelt trades, the New Game
  button, and the 3 free cabin checks, grouped by map area on the Act 1 map.
* **Act 1 items** — the 7 map nodes, the Kaycee's Mod challenge items, and Progressive
  Candle / Squirrel / Grizzlies.
* **Act 2** — the `Act 2 Bridge Repair` item and the "left side start" bridge option.
* **Act 3** — the 3 Botopia shortcuts, 3 Vessel Upgrades, the Conduit Upgrade, the Wizard Tower
  satellite dish, plus the `Act 3 Bridge Repair` and `Resplendent Bastion Gate` items used by
  the Act 3 Overhaul option.
* **Act unlocks** — `Act 1` / `Act 2` / `Act 3` items for the "Items" act-unlock mode, and the
  new goal option (beat one act / two acts / all acts).
* **Hammer** — tracked for the Randomize Hammer option.

Options are read from slot data on connect, so the settings panel fills itself in. Checks a given
seed does not generate — for example the Act 3 shortcut checks when Randomize Shortcuts is
`vanilla` — are hidden rather than shown as unreachable.

The Act 1 node and challenge item icons are extracted from the game's own assets — node art
(`animated_buildtotemnode`, `animated_mushrooms`, …) composited onto the map's `paper_darker`
parchment because it is black ink and would be invisible on a dark background, and the Kaycee's Mod
`ascensionicon_*` icons used as-is since they are white on transparent. The mapping from AP item to
game asset is taken from the mod's `ReplaceLockedNodeIcon` and `SetChallengesOnStartup` patches.
The act unlock icons come from the mod's own `Assets Sources`. The Act 2 bridge repair is cropped
from `broken_bridge_bg`, whose left end is already broken, and the three Act 3 shortcuts reuse the
game's own fast travel icon (`holomap_fasttravelhint_1`) tinted to each destination's region colour,
sampled from `images/maps/Act3.png`. The two Act 3 gate icons are screenshots of the NPCs who block
the bridge and the Resplendent Bastion.

Still generated placeholders: the vessel and conduit upgrades, the hammer, and every option icon.

### Keeping the logic in sync with the apworld

`scripts/logic.lua` is a hand-maintained Lua copy of `worlds/inscryption_beta/Rules.py`.
**There is no way to avoid this.** A PopTracker pack always computes reachability itself from its
own Lua rules; neither the Archipelago interface nor UAT can receive "in logic" state from an
external tool, so Universal Tracker's logic cannot be fed into a pack. UT is a good companion —
it runs the apworld directly and so is authoritative — but it does not replace these rules.

That makes drift the thing to watch for. When `Rules.py` changes:

* Rule changes must be mirrored by hand in `logic.lua`. Nothing detects a mismatch.
* Location or item list changes shift every id after the insertion point, so
  `scripts/autotracking/*_mapping.lua` must be regenerated. This *is* checkable — ids are assigned
  by list order in `Locations.py` / `Items.py`, so compare the mapping tables against those lists.
* New options that rules read must be added to `options/options.json` and `option_mapping.lua`.

`tools/check_logic_sync.py` automates as much of that as can be automated:

```
python tools/check_logic_sync.py ../Archipelago/worlds/inscryption_beta
```

It maps every location id to its apworld rule and to the pack's access rules, then checks the two
partition the locations the same way — locations sharing a rule in `Rules.py` must share one in the
pack, and vice versa. It cannot verify what a Lua function *does*, but it does catch a rule attached
to the wrong check, a location whose rule moved, and ids drifting out of alignment.

`logic.lua` also holds two things that are not access logic:

* `vis_*` functions mirroring `create_regions` — which checks a seed generates at all, so checks
  that do not exist are hidden rather than shown as permanently unreachable.
* `update_options` — clamps the Epitaph and Vessel Upgrade counters to the maximum the chosen
  options allow. Wired up by `init_options()` via `ScriptHost:AddWatchForCode`, and also called at
  the end of `onClear`.
