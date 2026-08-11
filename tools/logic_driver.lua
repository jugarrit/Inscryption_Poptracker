-- Stubs the PopTracker API so `has`, `count`, `opt` and `flag` read from the case being
-- evaluated, loads the real scripts/logic.lua, and prints one row of 0/1 per case.
--
--   lua tools/logic_driver.lua <pack dir> <cases file>
--
-- Cases file returns {rules = {{fn, arg}, ...}, cases = {{opts, items}, ...}}; a sibling
-- "<cases file>.types" returns a code -> "toggle"/"consumable" table.

local pack = arg[1]
local cases_file = arg[2]

STATE = {opts = {}, items = {}}
ITEM_TYPES = dofile(cases_file .. ".types")

-- Options the pack models as toggles rather than progressive stages.
OPTION_TOGGLES = {act1on = true, act2on = true, act3on = true, randnodes = true,
                  act3overhaul = true, releaseonact = true}

local obj_cache = {}

local function object_for(code)
  local o = obj_cache[code]
  if not o then
    o = {}
    obj_cache[code] = o
  end
  if OPTION_TOGGLES[code] then
    o.Type = "toggle"
    o.Active = (STATE.opts[code] or 0) ~= 0
    return o
  end
  if STATE.opts[code] ~= nil then
    o.Type = "progressive"
    o.CurrentStage = STATE.opts[code]
    return o
  end
  local kind = ITEM_TYPES[code]
  if kind == nil then
    return nil
  end
  local n = STATE.items[code] or 0
  if kind == "consumable" then
    o.Type = "consumable"
    o.AcquiredCount = n
  else
    o.Type = "toggle"
    o.Active = n > 0
  end
  return o
end

Tracker = {
  FindObjectForCode = function(_, code) return object_for(code) end,
  AddItems = function() end,
  AddLocations = function() end,
  AddLayouts = function() end,
  AddMaps = function() end,
}
ScriptHost = {LoadScript = function() end, AddWatchForCode = function() end,
              AddOnLocationSectionChangedHandler = function() end}

dofile(pack .. "/scripts/logic.lua")

local cases = dofile(cases_file)

local out = {}
for _, case in ipairs(cases.cases) do
  STATE.opts = case.opts
  STATE.items = case.items
  local row = {}
  for _, rule in ipairs(cases.rules) do
    local fn = _G[rule.fn]
    if fn == nil then
      error("no such lua function: " .. rule.fn)
    end
    row[#row + 1] = fn(rule.arg) and "1" or "0"
  end
  out[#out + 1] = table.concat(row)
end
print(table.concat(out, "\n"))
