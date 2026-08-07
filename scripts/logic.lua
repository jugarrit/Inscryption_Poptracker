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

-- ---------------------------------------------------------------- Act 1 ----

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

function bypass_grizzly_requirements(boss_number)
  if opt("randchallenges") == CHALLENGES_RANDOMIZE and
      not has("proggrizzlies", boss_number) and not nodes_randomized() then
    if boss_number - count("proggrizzlies") == 1 then
      return (has("dagger") and has("hook")) or has("backpacknode")
    end
    return has("backpacknode")
  end
  return true
end

function a1_woodlands_later()
  local extra = count("progcandle") * 3 + count("backpacknode") * 2
  if nodes_randomized() and challenges_randomized() then
    return act1_battle_requirements(3 + extra, true, false)
  end
  return true
end

function a1_prospector()
  local extra = 0
  if has("alltotembattles") then extra = 3 end
  if opt("randchallenges") == CHALLENGES_RANDOMIZE and not has("proggrizzlies") then
    extra = 10
  end
  if nodes_randomized() and challenges_randomized() then
    return act1_battle_requirements(6 + extra, true, false) and a1_woodlands_later()
      and bypass_grizzly_requirements(1)
  elseif nodes_randomized() or challenges_randomized() then
    return act1_battle_requirements(4 + extra, true, false) and a1_woodlands_later()
  end
  return true
end

function a1_wetlands()
  if nodes_randomized() and challenges_randomized() then
    return act1_battle_requirements(13, true, true) and a1_prospector()
  elseif challenges_randomized() then
    return act1_battle_requirements(8, true, true) and a1_prospector()
  elseif nodes_randomized() then
    return act1_battle_requirements(5, true, false) and a1_prospector()
  end
  return true
end

function a1_angler()
  local extra = 0
  if has("alltotembattles") then extra = 3 end
  if opt("randchallenges") == CHALLENGES_RANDOMIZE and not has("proggrizzlies", 2) then
    extra = 10
  end
  if nodes_randomized() and challenges_randomized() then
    return act1_battle_requirements(18 + extra, true, true) and bypass_grizzly_requirements(2)
  elseif challenges_randomized() then
    return act1_battle_requirements(13 + extra, true, true) and bypass_grizzly_requirements(2)
  elseif nodes_randomized() then
    return act1_battle_requirements(8, true, true)
  end
  return true
end

function a1_snow_line()
  if nodes_randomized() and challenges_randomized() then
    return act1_battle_requirements(23, true, true) and a1_angler()
  elseif challenges_randomized() then
    return act1_battle_requirements(17, true, true) and a1_angler()
  elseif nodes_randomized() then
    return act1_battle_requirements(8, true, true) and a1_angler()
  end
  return true
end

function a1_trapper()
  local extra = 0
  if has("alltotembattles") then extra = extra + 3 end
  if opt("randchallenges") == CHALLENGES_RANDOMIZE and not has("proggrizzlies", 3) then
    extra = extra + 10
  end
  if nodes_randomized() and challenges_randomized() then
    return act1_battle_requirements(27 + extra, true, true) and bypass_grizzly_requirements(3)
  elseif challenges_randomized() then
    return act1_battle_requirements(22 + extra, true, true) and bypass_grizzly_requirements(3)
  elseif nodes_randomized() then
    return act1_battle_requirements(12, true, true)
  end
  return true
end

function a1_leshy()
  local extra = 0
  if has("alltotembattles") then extra = 3 end
  if nodes_randomized() and challenges_randomized() then
    return act1_battle_requirements(33 + extra, true, true) and a1_trapper()
  elseif challenges_randomized() then
    return act1_battle_requirements(27 + extra, true, true) and a1_trapper()
  elseif nodes_randomized() then
    return act1_battle_requirements(12 + extra, true, true) and a1_trapper()
  end
  return true
end

function a1_woodlands_consumable()
  return (not nodes_randomized() or has("backpacknode")) and a1_woodlands_later()
end

function a1_wetlands_consumable()
  return (not nodes_randomized() or has("backpacknode")) and a1_wetlands()
end

function a1_snow_line_consumable()
  return (not nodes_randomized() or has("backpacknode")) and a1_snow_line()
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
  if nodes_randomized() or challenges_randomized() then
    return a1_prospector()
  end
  return true
end

function a1_painting_2()
  if nodes_randomized() or challenges_randomized() then
    return has("paintingclover") and a1_angler()
  elseif opt("paintingbalance") == PAINTING_BALANCED then
    return a1_useful_items()
  end
  return true
end

function a1_painting_3()
  if nodes_randomized() or challenges_randomized() then
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
  if opt("act2bridge") == A2_BRIDGE_LEFT_START then
    return has("act2bridgerepair")
  end
  return true
end

function a2_bridge()
  local stage = opt("act2bridge")
  if stage == A2_BRIDGE_ENABLE then
    return has("act2bridgerepair")
  elseif stage == A2_BRIDGE_LEFT_START then
    return true
  end
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
  if flag("act3overhaul") then
    return true
  end
  return has("inspectobattery")
end

function a3_bridge()
  if flag("act3overhaul") then
    return has("act3bridgerepair")
  end
  return has("inspectobattery")
end

function a3_filthy_corpse_world()
  if flag("act3overhaul") then
    return true
  end
  return has("inspectobattery")
end

function a3_gems_and_battery()
  return has("gemsmodule") and a3_bridge()
end

function a3_gaudy_gem_land()
  if flag("act3overhaul") then
    return a3_bridge() and has("gemsmodule")
  end
  return a3_gems_and_battery()
end

function a3_bastion()
  if flag("act3overhaul") then
    return a3_bridge() and has("bastiongate")
  end
  return a3_gems_and_battery()
end

function a3_archivist()
  return a3_filthy_corpse_world() and has("quill")
end

function a3_battery_and_quill()
  return has("quill") and a3_battery()
end

function a3_bridge_and_quill()
  return has("quill") and a3_bridge()
end

function a3_gem_land_and_quill()
  return has("quill") and a3_gaudy_gem_land()
end

function a3_pelts(amount)
  return has("holopelt", amount) and a3_bastion()
end

function a3_area_count()
  local areas = 0
  if a3_bastion() then areas = areas + 1 end
  if a3_battery() then areas = areas + 1 end
  if a3_archivist() then areas = areas + 1 end
  if a3_gaudy_gem_land() then areas = areas + 1 end
  return areas
end

function a3_vessel_upgrade(amount)
  return a3_area_count() >= (tonumber(amount) or 1)
end

function a3_transcendence()
  return a3_bastion() and a3_battery() and a3_archivist() and a3_gaudy_gem_land()
end

function a3_mycologists()
  return has("mycokey") and a3_transcendence()
end

function a3_bone_lord_room()
  return has("bonelordkey") and a3_filthy_corpse_world()
end

function a3_goobert_painting()
  if flag("act1on") then
    return a1_trapper() and a3_bastion() and a3_battery()
  end
  return a3_bastion() and a3_battery()
end

function a3_shop()
  local areas = 0
  if a3_bastion() then areas = areas + 1 end
  if a3_battery() then areas = areas + 1 end
  if a3_filthy_corpse_world() then areas = areas + 1 end
  if a3_gaudy_gem_land() then areas = areas + 1 end
  return areas >= 3
end

function a3_ourobot()
  return a3_gaudy_gem_land() and a3_shop()
end

-- --------------------------------------------------------------- Regions ---

function act1_access()
  if not flag("act1on") then
    return false
  end
  if opt("actunlocks") == UNLOCKS_ITEMS then
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
  local unlocks = opt("actunlocks")
  if unlocks == UNLOCKS_ITEMS then
    return has("act2unlock")
  elseif unlocks == UNLOCKS_SEQUENTIAL then
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
  local unlocks = opt("actunlocks")
  if unlocks == UNLOCKS_ITEMS then
    return has("act3unlock")
  elseif unlocks == UNLOCKS_SEQUENTIAL then
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
  return nodes_randomized() or challenges_randomized()
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
  return flag("act3overhaul")
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
