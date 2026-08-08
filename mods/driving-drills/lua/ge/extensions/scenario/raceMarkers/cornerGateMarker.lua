-- Checkpoint marker drawn as four corner pieces, matching the parking markers
-- precisionParking uses (flowgraph node scene/rectMarker).
--
-- Implements the race-marker interface that scenario/race_marker.lua drives:
--   createMarkers() / clearMarkers() / setToCheckpoint(wp) / setMode(mode)
--   show() / hide() / update(dt, dtSim)
--
-- The stock timeTrial marker is two tall side columns. This instead outlines a
-- rectangle on the road with one position_marker.dae per corner, each rotated
-- 90 degrees from the last and ray-cast down onto the terrain so it sits flush
-- on sloped ground.

local C = {}

-- Other shipped shapes that work here: park_outline_marker.dae,
-- s_poi_circle.dae, checkpoint_marker.dae, checkpoint_marker_base.dae,
-- single_faded_column.dae, s_mm_gatecone.dae, s_mm_arrow_floating.dae.
-- (checkpoint_ring.dae is a curved gate section, not a closed ring.)
local cornerShape = "art/shapes/interface/position_marker.dae"

-- Gate footprint in metres. Half-extents: a car is ~1.9 wide, ~4.5 long.
local HALF_WIDTH = 1.6
local HALF_LENGTH = 2.8
local TERRAIN_PROBE_UP = 2
local TERRAIN_PROBE_DOWN = 4
local COLOR_RATE = 8

-- Corner order matches rectMarker's: top-left, top-right, bottom-right,
-- bottom-left, each turned a further 90 degrees so the L-shapes face inward.
local CORNER_ROTATIONS = {math.rad(90), math.rad(180), math.rad(270), 0}

local modeColors = {
  default = {1.0, 0.1, 0.0},
  next = {0.35, 0.35, 0.35},
  start = {0.2, 1.0, 0.2},
  lap = {0.2, 1.0, 0.2},
  final = {0.2, 0.4, 1.0},
  branch = {1.0, 0.6, 0.0},
  recovery = {1.0, 0.85, 0.0},
  hidden = {0.3, 0.3, 0.3},
}

local function modeColor(mode)
  return modeColors[mode or "default"] or modeColors.default
end

local function newSmoother()
  return newTemporalSmoothingNonLinear(COLOR_RATE, COLOR_RATE, 1)
end

-- Offsets of the four corners in the gate's own axes.
local function cornerOffsets(xVec, yVec)
  return {
    -xVec * HALF_WIDTH + yVec * HALF_LENGTH,
    xVec * HALF_WIDTH + yVec * HALF_LENGTH,
    xVec * HALF_WIDTH - yVec * HALF_LENGTH,
    -xVec * HALF_WIDTH - yVec * HALF_LENGTH,
  }
end

-- Drop the corner onto whatever surface is under it; keep the original point
-- if the ray misses (bridges, gaps) rather than sinking the marker.
local function groundedPoint(point, upVec)
  local hit = Engine.castRay(point + upVec * TERRAIN_PROBE_UP,
    point - upVec * TERRAIN_PROBE_DOWN, true, false)
  return hit and vec3(hit.pt) or point
end

function C:init(id)
  self.id = tostring(id or "cornerGateMarker")
  self.visible = false
  self.mode = "hidden"
  self.pos = vec3(0, 0, 0)
  self.rot = quat(0, 0, 0, 1)
  self.corners = {}
  self.smoothers = {newSmoother(), newSmoother(), newSmoother()}
  self.currentColor = {1, 1, 1}
end

function C:createObject(objectName)
  local obj = createObject("TSStatic")
  -- preApply/postApply bracket the shape assignment so the mesh loads; without
  -- them the object exists but never renders.
  obj:preApply()
  obj:setField("shapeName", 0, cornerShape)
  obj:postApply()
  obj:setPosition(vec3(0, 0, 0))
  obj.scale = vec3(1, 1, 1)
  obj.useInstanceRenderData = true
  obj:setField("instanceColor", 0, "1 1 1 1")
  obj:setField("collisionType", 0, "None")
  obj:setField("decalType", 0, "None")
  obj.canSave = false
  obj.hidden = true
  obj:registerObject(objectName)
  -- A fresh TSStatic can come back with rendering disabled, which looks
  -- identical to a missing object. Force it on.
  obj:setField("isRenderEnabled", 0, "1")
  local group = scenetree.ScenarioObjectsGroup
  if group then group:addObject(obj) end
  -- scenetree scans do not enumerate these objects, so the id logged here is
  -- the only handle for outside inspection (scenetree.findObjectById).
  log("D", "cornerGateMarker", "created " .. objectName .. " id=" .. obj:getID())
  return obj
end

-- setupMarkers() calls createMarkers() again after building the marker, so
-- this must be idempotent or the second call would discard the first's work.
function C:createMarkers()
  if #self.corners > 0 then return end
  for i = 1, 4 do
    -- "gate_" prefix: pathnode ids are bare digits, and the engine rejects
    -- object names that start with a digit.
    self.corners[i] = self:createObject("gate_" .. self.id .. "_corner_" .. i)
  end
end

function C:clearMarkers()
  for i, obj in ipairs(self.corners) do
    if obj then obj:delete() end
    self.corners[i] = nil
  end
end

function C:setToCheckpoint(wp)
  self.pos = vec3(wp.pos)
  -- Face the gate along the route so the rectangle spans the road rather than
  -- lying along it; fall back to world axes when a node has no normal.
  local fwd = wp.normal and vec3(wp.normal.x, wp.normal.y, 0) or vec3(0, 1, 0)
  if fwd:length() < 0.01 then fwd = vec3(0, 1, 0) end
  self.rot = quatFromDir(fwd:normalized(), vec3(0, 0, 1))
  local xVec = self.rot * vec3(1, 0, 0)
  local yVec = self.rot * vec3(0, 1, 0)
  local zVec = self.rot * vec3(0, 0, 1)
  local offsets = cornerOffsets(xVec, yVec)
  for i, obj in ipairs(self.corners) do
    local corner = groundedPoint(self.pos + offsets[i], zVec)
    obj:setPosition(corner)
    local r = (quatFromEuler(0, 0, CORNER_ROTATIONS[i]) * self.rot):toTorqueQuat()
    obj:setField("rotation", 0, r.x .. " " .. r.y .. " " .. r.z .. " " .. r.w)
  end
end

function C:setMode(mode)
  if mode ~= "hidden" then self:show() end
  self.mode = mode
  self:update(0, 0)
end

function C:setVisibility(v)
  self.visible = v
  for _, obj in ipairs(self.corners) do
    obj.hidden = not v
  end
end

function C:show() self:setVisibility(true) end
function C:hide() self:setVisibility(false) end

function C:update(dt, dtSim)
  if not self.visible then return end
  local target = modeColor(self.mode)
  for i = 1, 3 do
    self.currentColor[i] = self.smoothers[i]:get(target[i], dt)
  end
  local clr = ColorF(self.currentColor[1], self.currentColor[2], self.currentColor[3], 1):asLinear4F()
  for _, obj in ipairs(self.corners) do
    obj.instanceColor = clr
    obj:updateInstanceRenderData()
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
