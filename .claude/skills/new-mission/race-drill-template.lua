-- Checkpoint-drill GE extension template (Tier D: standalone race runtime).
-- Runs a checkpoint course with NO mission system: no countdown, timer,
-- or end screen -- just gates and driving.
--
-- Install: copy to  mods/<mod>/lua/ge/extensions/<ns>/<name>.lua
--          (module name becomes <ns>_<name>)
-- Fill in RACE_FILE below, deploy the mod, then in the console or bridge:
--   extensions.load("<ns>_<name>")
--   extensions.<ns>_<name>.start()
--   extensions.<ns>_<name>.stop()
-- Optional: auto-load via scripts/modScript.lua (see new-ge-extension skill).

local M = {}

-- TODO: point at your route file (author it with the pose mark-loop +
-- poses-to-race.ps1 from the new-mission skill).
local RACE_FILE = "/gameplay/<your-route>.race.json"
-- Optional custom marker style: a module name under scenario/raceMarkers/.
-- nil uses the game's default side-column markers.
local MARKER_STYLE = nil

local race = nil
local markers = nil
local playerVehId = nil

local function loadCoursePath()
  local path = require("/lua/ge/extensions/gameplay/race/path")("Drill Course")
  path:onDeserialized(jsonReadFile(RACE_FILE))
  path:autoConfig()
  return path
end

local function buildWaypoints(path)
  local wps = {}
  for _, pn in ipairs(path.pathnodes.sorted) do
    table.insert(wps, { name = pn.id, pos = pn.pos, radius = pn.radius,
                        normal = pn.hasNormal and pn.normal or nil })
  end
  for i, wp in ipairs(wps) do
    wp.nextPos = wps[(i % #wps) + 1].pos
  end
  return wps
end

local function createRace(path, vehId)
  local r = require("/lua/ge/extensions/gameplay/race/race")()
  r:setPath(path)
  r.useHotlappingApp = false
  r.useDebugDraw = false
  r.useWaypointAudio = true
  r:setVehicleIds({ vehId })
  r:startRace()
  return r
end

-- Mirrors flowgraph/nodes/gameplay/race/raceMarkers.lua: modes only change
-- on race events, so only push them when an event fired this frame.
local function updateMarkerModes(state)
  local events = state.events
  if not events then return end
  if not (events.raceStarted or events.pathnodeReached or events.rollingStarted) then return end
  local wps = {}
  for _, e in ipairs(state.nextPathnodes) do wps[e[1].id] = e[2] end
  for _, e in ipairs(state.overNextPathnodes) do wps[e[1].id] = "next" end
  markers.setModes(wps)
end

function M.start()
  M.stop()
  playerVehId = be:getPlayerVehicleID(0)
  if not playerVehId or playerVehId == -1 then
    log("E", "raceDrill", "no player vehicle; drill not started")
    return false
  end
  local path = loadCoursePath()
  race = createRace(path, playerVehId)
  markers = require("scenario/race_marker")
  markers.init()
  markers.setupMarkers(buildWaypoints(path), MARKER_STYLE)
  log("I", "raceDrill", "drill started: " .. #path.pathnodes.sorted .. " checkpoints")
  return true
end

function M.stop()
  if race then race:stopRace() end
  race = nil
  if markers then markers.onClientEndMission() end
  markers = nil
  playerVehId = nil
end

function M.isRunning()
  return race ~= nil
end

-- Dev-time probe; the race object is otherwise unreachable from the console.
function M.debug()
  if not race then return { running = false } end
  local state = race.states[playerVehId]
  return {
    running = true,
    vehId = playerVehId,
    nextPathnodes = state and #state.nextPathnodes or -1,
    complete = state and state.complete or false,
  }
end

function M.onUpdate(dtReal, dtSim)
  if not race then return end
  race:onUpdate(dtSim)
  local state = race.states[playerVehId]
  if not state then return end
  updateMarkerModes(state)
  if state.complete then
    ui_message("Course complete!", 5, "raceDrill")
    M.stop()
  end
end

function M.onPreRender(dt, dtSim)
  if markers then markers.render(dt, dtSim) end
end

function M.onClientEndMission()
  M.stop()
end

function M.onExtensionLoaded()
  setExtensionUnloadMode(M, "manual")
  return true
end

function M.onExtensionUnloaded()
  M.stop()
end

return M
