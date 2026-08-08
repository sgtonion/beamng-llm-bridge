-- Minimal GE-Lua extension template.
--
-- A GE (game-engine-side) extension is a Lua module: a local table `M` with
-- functions attached to it, returned at the end of the file. The engine
-- calls specific functions on `M` by name if present (lifecycle hooks) and
-- callers invoke any other function on `M` directly, e.g.
-- <module_name>.hello().

local M = {}

-- onExtensionLoaded fires when the extension is loaded AND on every
-- extensions.reload(...) call. Good place for setup/logging so a reload is
-- visibly confirmed in the console.
local function onExtensionLoaded()
  log('I', 'template', 'extension loaded')
end

-- Example public function. Any function you want callable from the console
-- or from another extension must be attached to M explicitly (see bottom).
local function hello(name)
  local who = name or 'world'
  log('I', 'template', 'hello, ' .. who)
  return 'hello, ' .. who
end

--[[ onPreRender: fires every frame. Uncomment to draw world-space text near
     a fixed point (e.g. the origin, or a vehicle position you look up here).

     IMPORTANT notes:
     - This is IMMEDIATE-MODE drawing: the call must be re-issued every
       frame (that's why it lives in onPreRender) or the text vanishes.
     - Use ASCII only in the text string -- fonts may not render em-dashes
       or other non-ASCII glyphs.
     - ColorF(r, g, b, a) takes 0-1 floats -- used for the text color.
     - ColorI(r, g, b, a) takes 0-255 ints -- used for the background color.

local function onPreRender(dtReal, dtSim, dtRaw)
  local worldPos = vec3(0, 0, 1)
  local textColor = ColorF(1, 1, 1, 1)
  local bgColor = ColorI(0, 0, 0, 200)
  debugDrawer:drawTextAdvanced(
    worldPos,
    String('example text'),
    textColor,
    true,
    false,
    bgColor
  )
end
--]]

M.onExtensionLoaded = onExtensionLoaded
M.hello = hello
-- M.onPreRender = onPreRender -- uncomment together with the block above

return M
