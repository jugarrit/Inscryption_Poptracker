-- Logic mirrors worlds/inscryption_beta/Rules.py of the Inscryption Beta apworld.
-- It is a hand-maintained copy: changes to Rules.py must be reflected here.

-- Option stage constants, matching the apworld's Choice option values.
UNLOCKS_SEQUENTIAL, UNLOCKS_OPEN, UNLOCKS_ITEMS = 0, 1, 2
CHALLENGES_DISABLE, CHALLENGES_NO_GRIZZLIES, CHALLENGES_RANDOMIZE = 0, 1, 2
A2_BRIDGE_DISABLE, A2_BRIDGE_ENABLE, A2_BRIDGE_LEFT_START = 0, 1, 2
PAINTING_NONE, PAINTING_BALANCED, PAINTING_FORCE_FILLER = 0, 1, 2
SHORTCUTS_VANILLA, SHORTCUTS_RANDOMIZE, SHORTCUTS_OPEN = 0, 1, 2
VESSELS_VANILLA, VESSELS_RANDOMIZE, VESSELS_REMOVE_ONE = 0, 1, 2

function count(code)
  local obj = Tracker:FindObjectForCode(code)
  if not obj then
    return 0
  end
  if obj.Type == "toggle" then
    return obj.Active and 1 or 0
  elseif obj.Type == "consumable" then
    return obj.AcquiredCount
  elseif obj.Type == "progressive" then
    return obj.CurrentStage
  end
  return 0
end

function has(item, amount)
  return count(item) >= (tonumber(amount) or 1)
end

-- Current stage of a progressive option.
function opt(code)
  local obj = Tracker:FindObjectForCode(code)
  if not obj then
    return 0
  end
  return obj.CurrentStage
end

-- State of a toggle option.
function flag(code)
  local obj = Tracker:FindObjectForCode(code)
  return obj ~= nil and obj.Active
end

function nodes_randomized()
  return flag("randnodes")
end

function challenges_randomized()
  return opt("randchallenges") ~= CHALLENGES_DISABLE
end

-- Grizzlies are only in the pool on the full "randomize" setting, not on "no grizzlies".
function grizzlies_randomized()
  return opt("randchallenges") == CHALLENGES_RANDOMIZE
end

function act1_randomized()
  return nodes_randomized() or challenges_randomized()
end

function act2_bridge_randomized()
  return opt("act2bridge") == A2_BRIDGE_ENABLE
end

function act2_starts_on_left_side()
  return opt("act2bridge") == A2_BRIDGE_LEFT_START
end

function act3_overhauled()
  return flag("act3overhaul")
end

function acts_unlocked_by_items()
  return opt("actunlocks") == UNLOCKS_ITEMS
end

function acts_unlocked_sequentially()
  return opt("actunlocks") == UNLOCKS_SEQUENTIAL
end

-- ---------------------------------------------------------------- Act 1 ----

-- Each Act 1 boss keeps its grizzly phase until this many Progressive Grizzlies are collected.
PROSPECTOR, ANGLER, TRAPPER = 1, 2, 3

-- How far a boss's points threshold rises while it keeps its grizzly phase.
GRIZZLY_PENALTY = 10

-- Worth points in general, but not this early, so the later woodlands hands their points back.
WOODLANDS_CANCELLED = {"progcandle", "backpacknode"}

-- The four kinds of Act 1 fight. Which one a rule gates decides what its points may come from:
-- a boss ignores the regular-only items and vice versa, and the woodlands ignores the later nodes.
WOODLANDS_BATTLE = {is_boss = false, is_beyond_area1 = false}
WOODLANDS_BOSS = {is_boss = true, is_beyond_area1 = false}
LATER_BATTLE = {is_boss = false, is_beyond_area1 = true}
LATER_BOSS = {is_boss = true, is_beyond_area1 = true}

ACT1_ITEM_VALUES = {
  {"hook", 1}, {"paintingclover", 1}, {"dagger", 1},
  {"woodcarvernode", 2}, {"backpacknode", 2},
  {"sacstonesnode", 3}, {"campfirenode", 3},
  {"beefigurine", 3}, {"extracandle", 3}
}

ACT1_BOSS_ITEM_VALUES = {
  {"greatersmoke", 1}, {"bosstotems", 3}
}

-- Only ever counted for a regular battle. All Totem Battles turns regular map nodes into
-- totem battles; Boss Totems, above, is the challenge that puts a totem on a boss.
ACT1_REGULAR_ITEM_VALUES = {
  {"alltotembattles", 3}
}

ACT1_PROGRESSIVE_VALUES = {
  {"moredifficult", {5, 4}},
  {"progcandle", {3, 3}},
  {"progsquirrel", {2, 3}},
  {"tippedscales", {5, 4, 3}}
}

ACT1_BEYOND_AREA1_VALUES = {
  {"myconode", 1}, {"bonealtarnode", 1}
}

-- Pairs that pay only when both halves are held. The second table is worth nothing before the
-- wetlands, where the base game has not started spawning those nodes.
ACT1_PAIR_VALUES = {
  {{"squirreltotem", "woodcarvernode"}, 3},
  {{"smallerbackpack", "backpacknode"}, 1}
}

ACT1_BEYOND_AREA1_PAIR_VALUES = {
  {{"sacstonesnode", "goobertnode"}, 1}
}

-- What everything the player holds is worth, before any fight decides what applies to it.
function act1_battle_points()
  local points = 0

  for _, tbl in ipairs({ACT1_ITEM_VALUES, ACT1_BOSS_ITEM_VALUES,
                        ACT1_REGULAR_ITEM_VALUES, ACT1_BEYOND_AREA1_VALUES}) do
    for _, entry in ipairs(tbl) do
      if has(entry[1]) then points = points + entry[2] end
    end
  end

  for _, entry in ipairs(ACT1_PROGRESSIVE_VALUES) do
    local owned = count(entry[1])
    for copy, value in ipairs(entry[2]) do
      if owned >= copy then points = points + value end
    end
  end

  for _, tbl in ipairs({ACT1_PAIR_VALUES, ACT1_BEYOND_AREA1_PAIR_VALUES}) do
    for _, entry in ipairs(tbl) do
      if has(entry[1][1]) and has(entry[1][2]) then points = points + entry[2] end
    end
  end

  return points
end

-- What this fight must not be paid with: the items belonging to the other kind of battle, and
-- everything that does not exist yet before the wetlands. Its threshold rises by that much.
function act1_points_withheld(fight)
  local withheld = 0

  for _, entry in ipairs(fight.is_boss and ACT1_REGULAR_ITEM_VALUES or ACT1_BOSS_ITEM_VALUES) do
    if has(entry[1]) then withheld = withheld + entry[2] end
  end

  if not fight.is_beyond_area1 then
    for _, entry in ipairs(ACT1_BEYOND_AREA1_VALUES) do
      if has(entry[1]) then withheld = withheld + entry[2] end
    end
    for _, entry in ipairs(ACT1_BEYOND_AREA1_PAIR_VALUES) do
      if has(entry[1][1]) and has(entry[1][2]) then withheld = withheld + entry[2] end
    end
  end

  return withheld
end

-- The bar a fight actually sets, in one expression: what it was tuned to, plus the points it must
-- not be paid with, plus a boss's grizzly penalty and anything too early to help.
function act1_threshold(base, fight, grizzly, cancels)
  local needed = base + act1_points_withheld(fight)
  if grizzly then needed = needed + act1_grizzly_penalty(grizzly) end
  if cancels then needed = needed + act1_points_from(cancels) end
  return needed
end

-- What the named items are worth, asked of the points function itself rather than restated, so a
-- change to any value, context table or pairing is picked up here for free.
function act1_points_from(items)
  local allowed = {}
  for _, item in ipairs(items) do allowed[item] = true end

  -- The points function reads the tracker through these, so narrowing them to the named items
  -- is what makes it score those alone. Restored before returning.
  local real_has, real_count = has, count
  has = function(item, amount) return allowed[item] and real_has(item, amount) end
  count = function(item) return allowed[item] and real_count(item) or 0 end

  local points = act1_battle_points()

  has, count = real_has, real_count
  return points
end

-- Thresholds are tuned per option combination. nil means neither option is on, so Act 1 runs
-- at vanilla difficulty and its battles are free.
function act1_points_needed(thresholds)
  if nodes_randomized() and challenges_randomized() then
    return thresholds.both
  elseif challenges_randomized() then
    return thresholds.challenges_only
  elseif nodes_randomized() then
    return thresholds.nodes_only
  end
  return nil
end

-- How much extra help a boss needs while it still has its grizzly phase.
function act1_grizzly_penalty(boss)
  if grizzlies_randomized() and not has("proggrizzlies", boss) then
    return GRIZZLY_PENALTY
  end
  return 0
end

-- A concrete answer to a boss that still has its grizzly phase. Only bites when nodes are
-- randomized: with them off the backpack node is always there and its consumables suffice.
function bypass_grizzly_requirements(boss)
  if not grizzlies_randomized() or not nodes_randomized() then
    return true
  end
  local grizzlies_short = boss - count("proggrizzlies")
  if grizzlies_short <= 0 then
    return true
  end
  -- One short is close enough to the tuned fight that the dagger's death card plus the hook
  -- can carry it. Any further short, only the backpack's consumables will do.
  if grizzlies_short == 1 then
    return has("backpacknode") or (has("dagger") and has("hook"))
  end
  return has("backpacknode")
end

function a1_woodlands_later()
  if not (nodes_randomized() and challenges_randomized()) then
    return true
  end
  -- Candles and backpacks do nothing for these early fights, so their points are cancelled.
  local needed = act1_threshold(3, WOODLANDS_BATTLE, nil, WOODLANDS_CANCELLED)
  return act1_battle_points() >= needed
end

function a1_prospector()
  local base = act1_points_needed({both = 6, challenges_only = 4, nodes_only = 4})
  if base == nil then
    return true
  end
  local needed = act1_threshold(base, WOODLANDS_BOSS, PROSPECTOR)
  return act1_battle_points() >= needed and a1_woodlands_later()
    and bypass_grizzly_requirements(PROSPECTOR)
end

function a1_wetlands()
  local base = act1_points_needed({both = 13, challenges_only = 8, nodes_only = 5})
  if base == nil then
    return true
  end
  local needed = act1_threshold(base, LATER_BATTLE, nil)
  return act1_battle_points() >= needed and a1_prospector()
end

function a1_angler()
  local base = act1_points_needed({both = 18, challenges_only = 13, nodes_only = 8})
  if base == nil then
    return true
  end
  local needed = act1_threshold(base, LATER_BOSS, ANGLER)
  return act1_battle_points() >= needed and bypass_grizzly_requirements(ANGLER)
end

function a1_snow_line()
  local base = act1_points_needed({both = 23, challenges_only = 17, nodes_only = 8})
  if base == nil then
    return true
  end
  local needed = act1_threshold(base, LATER_BATTLE, nil)
  return act1_battle_points() >= needed and a1_angler()
end

function a1_trapper()
  local base = act1_points_needed({both = 27, challenges_only = 22, nodes_only = 12})
  if base == nil then
    return true
  end
  local needed = act1_threshold(base, LATER_BOSS, TRAPPER)
  return act1_battle_points() >= needed and bypass_grizzly_requirements(TRAPPER)
end

function a1_leshy()
  local base = act1_points_needed({both = 33, challenges_only = 27, nodes_only = 12})
  if base == nil then
    return true
  end
  local needed = act1_threshold(base, LATER_BOSS, nil)
  return act1_battle_points() >= needed and a1_trapper()
end

-- Consumable checks are the items a run picks up off the map, which only exist while the
-- backpack node does.
function a1_backpack_consumables()
  return not nodes_randomized() or has("backpacknode")
end

function a1_woodlands_consumable()
  return a1_backpack_consumables() and a1_woodlands_later()
end

function a1_wetlands_consumable()
  return a1_backpack_consumables() and a1_wetlands()
end

function a1_snow_line_consumable()
  return a1_backpack_consumables() and a1_snow_line()
end

function a1_wolf_pelt()
  return a1_snow_line() or (a1_wetlands() and has("priceypelts"))
end

function a1_golden_pelt()
  return a1_trapper() and has("priceypelts")
end

function a1_useful_items()
  if nodes_randomized() then
    return has("paintingclover") and has("squirreltotem") and has("woodcarvernode")
  end
  return has("paintingclover") and has("squirreltotem")
end

function a1_painting_1()
  if act1_randomized() then
    return a1_prospector()
  end
  return true
end

function a1_painting_2()
  if act1_randomized() then
    return has("paintingclover") and a1_angler()
  elseif opt("paintingbalance") == PAINTING_BALANCED then
    return a1_useful_items()
  end
  return true
end

function a1_painting_3()
  if act1_randomized() then
    return has("paintingclover") and a1_trapper()
  elseif opt("paintingbalance") == PAINTING_BALANCED then
    return a1_useful_items()
  end
  return true
end

-- ---------------------------------------------------------------- Act 2 ----

function has_all_epitaphs()
  local stage = opt("epitaphtype")
  if stage == 0 then
    return has("epitaph", 9)
  elseif stage == 1 then
    return has("epitaph", 3)
  end
  return has("epitaph", 1)
end

function a2_right_side()
  if act2_starts_on_left_side() then
    return has("act2bridgerepair")
  end
  return true
end

function a2_bridge()
  if act2_bridge_randomized() then
    return has("act2bridgerepair")
  end
  if act2_starts_on_left_side() then
    return true
  end
  -- Vanilla: the bridge opens once either the forest or the crypt route is finished.
  return (has("camera") and has("meat")) or has_all_epitaphs()
end

function a2_forest()
  return has("camera") and has("meat") and a2_right_side()
end

function a2_grimora()
  return has_all_epitaphs() and a2_right_side()
end

function a2_bone_lord_stairs()
  return has("obol") and a2_right_side()
end

function a2_tower()
  return has("monocle") and a2_bridge()
end

function a2_tower_and_right()
  return a2_tower() and a2_right_side()
end

-- ---------------------------------------------------------------- Act 3 ----

function a3_battery()
  return has("inspectobattery")
end

-- Checks that are only missable (not gated) once Act 3 is overhauled.
function a3_missable()
  if act3_overhauled() then
    return true
  end
  return has("inspectobattery")
end

function a3_bridge()
  if act3_overhauled() then
    return has("act3bridgerepair")
  end
  return has("inspectobattery")
end

function a3_filthy_corpse_world()
  if act3_overhauled() then
    return true
  end
  return has("inspectobattery")
end

function a3_gems_and_battery()
  return has("gemsmodule") and a3_bridge()
end

function a3_gaudy_gem_land()
  if act3_overhauled() then
    return a3_bridge() and has("gemsmodule")
  end
  return a3_gems_and_battery()
end

function a3_bastion()
  if act3_overhauled() then
    return a3_bridge() and has("bastiongate")
  end
  return a3_gems_and_battery()
end

function a3_archivist()
  return a3_filthy_corpse_world() and has("quill")
end

function a3_pelts(amount)
  return has("holopelt", amount) and a3_bastion()
end

-- Some Act 3 checks are spread over the map or cost money to buy, so they are gated on how
-- much of Botopia is open rather than on one specific area.
function count_act3_areas_open(areas)
  local open = 0
  for _, area in ipairs(areas) do
    if area() then open = open + 1 end
  end
  return open
end

function a3_vessel_upgrade(amount)
  local open = count_act3_areas_open({a3_bastion, a3_battery, a3_archivist, a3_gaudy_gem_land})
  return open >= (tonumber(amount) or 1)
end

function a3_transcendence()
  return a3_bastion() and a3_battery() and a3_archivist() and a3_gaudy_gem_land()
end

-- Available once the hut can be opened and eastern Botopia reached, not at the end of the act.
function a3_mycologists()
  return has("mycokey") and a3_filthy_corpse_world()
end

function a3_bone_lord_room()
  return has("bonelordkey") and a3_filthy_corpse_world()
end

function a3_goobert_painting()
  if flag("act1on") and not a1_trapper() then
    return false
  end
  return a3_bastion() and a3_battery()
end

function a3_shop()
  local open = count_act3_areas_open({a3_bastion, a3_battery, a3_filthy_corpse_world,
                                      a3_gaudy_gem_land})
  return open >= 3
end

function a3_ourobot()
  return a3_gaudy_gem_land() and a3_shop()
end

-- --------------------------------------------------------------- Regions ---

function act1_access()
  if not flag("act1on") then
    return false
  end
  if acts_unlocked_by_items() then
    return has("act1unlock")
  end
  return true
end

function beat_act1()
  if not flag("act1on") then
    return true
  end
  return act1_access() and has("filmroll") and a1_leshy()
end

function act2_access()
  if not flag("act2on") then
    return false
  end
  if acts_unlocked_by_items() then
    return has("act2unlock")
  end
  if acts_unlocked_sequentially() then
    return beat_act1()
  end
  return true
end

function beat_act2()
  if not flag("act2on") then
    return true
  end
  return act2_access() and has_all_epitaphs() and has("camera") and has("meat") and has("monocle")
end

function act3_access()
  if not flag("act3on") then
    return false
  end
  if acts_unlocked_by_items() then
    return has("act3unlock")
  end
  if acts_unlocked_sequentially() then
    return beat_act2()
  end
  return true
end

function beat_act3()
  if not flag("act3on") then
    return true
  end
  return act3_access() and a3_transcendence()
end

-- ------------------------------------------------------------- Act release ---
-- Beating an act hands over its remaining checks, so they are in logic from that point.
-- Mirrors the apworld, which ors each location's own rule with its act's beat rule.

function release_act1()
  return flag("releaseonact") and flag("act1on") and beat_act1()
end

function release_act2()
  return flag("releaseonact") and flag("act2on") and beat_act2()
end

function release_act3()
  return flag("releaseonact") and flag("act3on") and beat_act3()
end

-- ------------------------------------------------------------ Visibility ---
-- Mirrors which locations create_regions() actually adds for the given options.

function vis_act1()
  return flag("act1on")
end

function vis_act2()
  return flag("act2on")
end

function vis_act3()
  return flag("act3on")
end

function vis_a1_battles()
  return act1_randomized()
end

function vis_a1_challenge_checks()
  return challenges_randomized()
end

function vis_a1_consumables()
  return challenges_randomized() and nodes_randomized()
end

function vis_a3_shortcuts()
  return opt("randshortcuts") ~= SHORTCUTS_VANILLA
end

function vis_a3_vessel_upgrades()
  return opt("randvessel") ~= VESSELS_VANILLA
end

function vis_a3_satellite_dish()
  return act3_overhauled()
end

-- --------------------------------------------------------------- Options ---

function clamp_consumable(code, max)
  local obj = Tracker:FindObjectForCode(code)
  if not obj then
    return
  end
  if obj.AcquiredCount > max then
    obj.AcquiredCount = max
  end
  obj.MaxCount = max
end

function update_options()
  local stage = opt("epitaphtype")
  if stage == 0 then
    clamp_consumable("epitaph", 9)
  elseif stage == 1 then
    clamp_consumable("epitaph", 3)
  else
    clamp_consumable("epitaph", 1)
  end
  if opt("randvessel") == VESSELS_REMOVE_ONE then
    clamp_consumable("vesselupgrade", 2)
  else
    clamp_consumable("vesselupgrade", 3)
  end
  return true
end

-- Called from init.lua once the option items exist.
function init_options()
  ScriptHost:AddWatchForCode("epitaph_max", "epitaphtype", update_options)
  ScriptHost:AddWatchForCode("vessel_max", "randvessel", update_options)
  update_options()
end
