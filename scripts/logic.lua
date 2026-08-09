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

-- How far a boss's points threshold rises while it keeps its grizzly phase, and once the
-- All Totem Battles challenge has been turned off.
GRIZZLY_PENALTY = 10
TOTEM_PENALTY = 3

ACT1_ITEM_VALUES = {
  {"hook", 1}, {"paintingclover", 1}, {"dagger", 1},
  {"woodcarvernode", 2}, {"backpacknode", 2},
  {"sacstonesnode", 3}, {"campfirenode", 3},
  {"alltotembattles", 3}, {"beefigurine", 3}, {"extracandle", 3}
}

ACT1_BOSS_ITEM_VALUES = {
  {"greatersmoke", 1}, {"bosstotems", 3}
}

ACT1_PROGRESSIVE_VALUES = {
  {"moredifficult", {5, 4}},
  {"progcandle", {3, 3}},
  {"progsquirrel", {2, 3}},
  {"tippedscales", {5, 4, 3}}
}

ACT1_AREA2_VALUES = {
  {"myconode", 1}, {"bonealtarnode", 1}
}

function act1_battle_points(is_boss, area2)
  local points = 0
  for _, entry in ipairs(ACT1_ITEM_VALUES) do
    if has(entry[1]) then points = points + entry[2] end
  end
  for _, entry in ipairs(ACT1_PROGRESSIVE_VALUES) do
    local owned = count(entry[1])
    for copy, value in ipairs(entry[2]) do
      if owned >= copy then points = points + value end
    end
  end
  if is_boss then
    for _, entry in ipairs(ACT1_BOSS_ITEM_VALUES) do
      if has(entry[1]) then points = points + entry[2] end
    end
  end
  if area2 then
    -- The base game only spawns these nodes from the wetlands on, so they can only have
    -- helped a battle in the wetlands or later.
    if has("sacstonesnode") and has("goobertnode") then points = points + 1 end
    for _, entry in ipairs(ACT1_AREA2_VALUES) do
      if has(entry[1]) then points = points + entry[2] end
    end
  end
  if has("squirreltotem") and has("woodcarvernode") then points = points + 3 end
  if has("smallerbackpack") and has("backpacknode") then points = points + 1 end
  return points
end

function act1_battle_requirements(amount, is_boss, area2)
  return act1_battle_points(is_boss, area2) >= amount
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

-- All Totem Battles only changes regular battles, so on a boss the threshold rises by exactly
-- the points the item is worth, cancelling it back out.
function act1_totem_penalty()
  if has("alltotembattles") then
    return TOTEM_PENALTY
  end
  return 0
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
  -- Candles and backpacks do nothing for these early fights, so the threshold rises by exactly
  -- the points they contribute, cancelling them back out.
  local cancelled = count("progcandle") * 3 + count("backpacknode") * 2
  return act1_battle_requirements(3 + cancelled, true, false)
end

function a1_prospector()
  local needed = act1_points_needed({both = 6, challenges_only = 4, nodes_only = 4})
  if needed == nil then
    return true
  end
  needed = needed + act1_totem_penalty() + act1_grizzly_penalty(PROSPECTOR)
  return act1_battle_requirements(needed, true, false) and a1_woodlands_later()
    and bypass_grizzly_requirements(PROSPECTOR)
end

function a1_wetlands()
  local needed = act1_points_needed({both = 13, challenges_only = 8, nodes_only = 5})
  if needed == nil then
    return true
  end
  return act1_battle_requirements(needed, true, true) and a1_prospector()
end

function a1_angler()
  local needed = act1_points_needed({both = 18, challenges_only = 13, nodes_only = 8})
  if needed == nil then
    return true
  end
  needed = needed + act1_totem_penalty() + act1_grizzly_penalty(ANGLER)
  return act1_battle_requirements(needed, true, true) and bypass_grizzly_requirements(ANGLER)
end

function a1_snow_line()
  local needed = act1_points_needed({both = 23, challenges_only = 17, nodes_only = 8})
  if needed == nil then
    return true
  end
  return act1_battle_requirements(needed, true, true) and a1_angler()
end

function a1_trapper()
  local needed = act1_points_needed({both = 27, challenges_only = 22, nodes_only = 12})
  if needed == nil then
    return true
  end
  needed = needed + act1_totem_penalty() + act1_grizzly_penalty(TRAPPER)
  return act1_battle_requirements(needed, true, true) and bypass_grizzly_requirements(TRAPPER)
end

function a1_leshy()
  local needed = act1_points_needed({both = 33, challenges_only = 27, nodes_only = 12})
  if needed == nil then
    return true
  end
  needed = needed + act1_totem_penalty()
  return act1_battle_requirements(needed, true, true) and a1_trapper()
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
-- With release on act completion the mod hands over an act's remaining checks the moment
-- that act is beaten, so every check in it is also in logic from that point. Mirrors the
-- apworld, which ors each location's own rule with its act's beat rule.

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
