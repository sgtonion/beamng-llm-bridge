-- Standalone turns-practice drill. No mission system involved.
--
-- The mission flowgraph (timeTrial) is just a wrapper around two plain
-- classes: gameplay/race/race (checkpoint detection, timing) and
-- scenario/race_marker (gate rendering). This extension drives them
-- directly, so starting the drill shows checkpoint gates and nothing
-- else -- no countdown, no timer app, no end screen.
--
-- Start:  extensions.drivingDrills_turnsCourse.start()
-- Stop:   extensions.drivingDrills_turnsCourse.stop()

local M = {}

local RACE_FILE = "/drills/turnsCourse/race.race.json"
local PROPS_FILE = "/drills/turnsCourse/props.cars.json"
local MARKER_STYLE = "cornerGateMarker"

-- Final challenge: park in the gap between these two entries of PROPS_FILE
-- (1-based indices). Bay position/orientation/width derive from their poses,
-- so rearranging the cars moves the bay too.
local PARKING_BAY = { betweenProps = { 3, 4 }, length = 5.5, height = 3, holdSeconds = 2 }

local race = nil
local markers = nil
local playerVehId = nil
local propVehIds = {}
local parking = nil
local parkingHold = 0
local parkingValid = false

local function loadCoursePath()
  local path = require("/lua/ge/extensions/gameplay/race/path")("Turns Practice")
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

-- Scene-tree parent for the prop cars, so they show up as one tidy group
-- ("parked_cars") instead of loose clone* entries.
local function getPropGroup()
  local group = scenetree.findObject("parked_cars")
  if group then return group end
  group = createObject("SimGroup")
  group:registerObject("parked_cars")
  scenetree.MissionGroup:addObject(group)
  return group
end

-- Prop cars persist across drill start/stop so arrangements survive between
-- runs; they are only removed on level exit or extension unload.
local function spawnPropCars()
  local alive = {}
  for _, id in ipairs(propVehIds) do
    if be:getObjectByID(id) then table.insert(alive, id) end
  end
  propVehIds = alive
  if #propVehIds > 0 then return end
  local props = jsonReadFile(PROPS_FILE)
  if not props then return end
  for _, p in ipairs(props) do
    local veh = core_vehicles.spawnNewVehicle(p.model, {
      pos = vec3(p.pos[1], p.pos[2], p.pos[3]),
      rot = quatFromDir(vec3(p.dir[1], p.dir[2], p.dir[3]), vec3(p.up[1], p.up[2], p.up[3])),
      autoEnterVehicle = false,
    })
    if veh then
      getPropGroup():addObject(veh)
      table.insert(propVehIds, veh:getID())
    end
  end
end

local function removePropCars()
  for _, id in ipairs(propVehIds) do
    local veh = be:getObjectByID(id)
    if veh then veh:delete() end
  end
  propVehIds = {}
  local group = scenetree.findObject("parked_cars")
  if group and group:size() == 0 then group:delete() end
end

-- Poses of the currently spawned prop cars, in props.cars.json entry shape.
-- Used to persist an arrangement after moving cars around in the editor.
function M.capturePropPoses()
  local out = {}
  for _, id in ipairs(propVehIds) do
    local v = be:getObjectByID(id)
    if v then
      local p, d, u = v:getPosition(), v:getDirectionVector(), v:getDirectionVectorUp()
      table.insert(out, { model = v:getJBeamFilename(),
                          pos = { p.x, p.y, p.z }, dir = { d.x, d.y, d.z }, up = { u.x, u.y, u.z } })
    end
  end
  return out
end

function M.getPropVehIds()
  return propVehIds
end

local function readBayEndpoints()
  local props = jsonReadFile(PROPS_FILE)
  local a = props and props[PARKING_BAY.betweenProps[1]]
  local b = props and props[PARKING_BAY.betweenProps[2]]
  if not (a and b) then return nil end
  return { pos = vec3(a.pos[1], a.pos[2], a.pos[3]), dir = vec3(a.dir[1], a.dir[2], a.dir[3]) },
         { pos = vec3(b.pos[1], b.pos[2], b.pos[3]), dir = vec3(b.dir[1], b.dir[2], b.dir[3]) }
end

-- The bay is the game's own sites parkingSpot (oriented box + checkParking
-- containment/alignment/speed test); only the hold-for-N-seconds is ours.
local function createParkingSpot()
  local a, b = readBayEndpoints()
  if not a then return nil end
  local dir = (a.dir + b.dir):normalized()
  local across = math.abs((b.pos - a.pos):dot(dir:cross(vec3(0, 0, 1))))
  local spot = require("/lua/ge/extensions/gameplay/sites/parkingSpot")(nil, "Park here", 1)
  spot:set((a.pos + b.pos) * 0.5, quatFromDir(dir, vec3(0, 0, 1)),
           vec3(math.max(2.2, across - 2.0), PARKING_BAY.length, PARKING_BAY.height))
  return spot
end

local function startParkingPhase()
  if race then race:stopRace() end
  race = nil
  if markers then markers.onClientEndMission() end
  markers = nil
  parking = createParkingSpot()
  parkingHold = 0
  if parking then
    ui_message("Gates done! Now park between the two cars.", 6, "turnsCourse")
  else
    ui_message("Course complete!", 5, "turnsCourse")
    playerVehId = nil
  end
end

local function updateParking(dtSim)
  parkingValid = parking:checkParking(playerVehId)
  parkingHold = parkingValid and (parkingHold + dtSim) or 0
  if parkingHold >= PARKING_BAY.holdSeconds then
    ui_message("Parking complete!", 5, "turnsCourse")
    M.stop()
  end
end

function M.start()
  M.stop()
  playerVehId = be:getPlayerVehicleID(0)
  if not playerVehId or playerVehId == -1 then
    log("E", "turnsCourse", "no player vehicle; drill not started")
    return false
  end
  local path = loadCoursePath()
  race = createRace(path, playerVehId)
  markers = require("scenario/race_marker")
  markers.init()
  markers.setupMarkers(buildWaypoints(path), MARKER_STYLE)
  spawnPropCars()
  log("I", "turnsCourse", "drill started: " .. #path.pathnodes.sorted .. " checkpoints")
  return true
end

function M.stop()
  if race then race:stopRace() end
  race = nil
  if markers then markers.onClientEndMission() end
  markers = nil
  playerVehId = nil
  parking = nil
  parkingHold = 0
  parkingValid = false
end

function M.isRunning()
  return race ~= nil or parking ~= nil
end

-- Dev-time shortcut: jump straight to the parking phase without driving
-- the gates first.
function M.skipToParking()
  M.stop()
  playerVehId = be:getPlayerVehicleID(0)
  spawnPropCars()
  startParkingPhase()
  return parking ~= nil
end

-- The drill and any mission share markers and race state; stop the drill
-- whenever a mission launches so they never overlap.
function M.onAnyMissionChanged(state)
  if state == "started" then M.stop() end
end

-- Dev-time probe; the race object is otherwise unreachable from the console.
function M.debug()
  if not M.isRunning() then return { running = false } end
  local state = race and race.states[playerVehId]
  return {
    running = true,
    phase = race and "gates" or "parking",
    vehId = playerVehId,
    nextPathnodes = state and #state.nextPathnodes or -1,
    complete = state and state.complete or false,
    parkingValid = parkingValid,
    parkingHold = parkingHold,
  }
end

function M.onUpdate(dtReal, dtSim)
  if race then
    race:onUpdate(dtSim)
    local state = race.states[playerVehId]
    if not state then return end
    updateMarkerModes(state)
    if state.complete then startParkingPhase() end
  elseif parking then
    updateParking(dtSim)
  end
end

function M.onPreRender(dt, dtSim)
  if markers then markers.render(dt, dtSim) end
  if parking then
    parking:drawDebug("normal", parkingValid and { 0, 1, 0 } or { 0.2, 0.6, 1 })
  end
end

function M.onClientEndMission()
  M.stop()
  propVehIds = {}
end

function M.onExtensionLoaded()
  setExtensionUnloadMode(M, "manual")
  return true
end

function M.onExtensionUnloaded()
  M.stop()
  removePropCars()
end

return M
