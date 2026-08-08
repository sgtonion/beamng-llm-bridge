-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- Modification contributor: sgtonion
--
-- llmBridge: an authenticated localhost HTTP endpoint that runs GE-Lua sent
-- by an external process (the LLM) and returns the value, captured print/log
-- output, and any error. Built on BeamNG's simpleHttpServer (GET-only,
-- localhost-bound).
--
-- This is a DEV/AUTHORING tool: it runs arbitrary Lua with full engine access.
-- It binds 127.0.0.1 only so nothing on the LAN can reach it. Do not ship it
-- enabled in a public release.
--
-- Endpoints:
--   GET /session         -> initialize the session from a Bearer capability
--   GET /ping            -> {ok=true, pong=true, ...}
--   GET /exec?lua=<enc>  -> {ok, result, output, phase?, error?}
-- Lua arrives URL-encoded in the query (the server has no POST body); send one
-- statement / short script per call. All endpoints require an exact loopback
-- Host and reject browser Origin headers. /session, /ping, and /exec require:
--   Authorization: Bearer <64 lowercase hex characters>

local M = {}

local ws
local HOST = '127.0.0.1'
local PORT = 23512
local EXPECTED_HOST = HOST .. ':' .. tostring(PORT)
local AUTH_PROTOCOL = 'session-bearer-v1'
local running = false
local sessionToken = nil

local socketUrl = require("socket.url")

local function authError(message, sessionRequired)
  local result = { ok = false, phase = 'auth', error = message, auth = AUTH_PROTOCOL }
  if sessionRequired then result.sessionRequired = true end
  return result
end

-- The shipped simpleHttpServer exposes request headers with lowercase keys.
-- Host validation blocks DNS rebinding; rejecting Origin adds defense in depth
-- against browser requests. The Bearer header itself cannot be attached by a
-- cross-origin page without a preflight, which this GET-only server rejects.
local function validateRequestContext(req)
  local headers = req and req.headers or {}
  if string.lower(tostring(headers.host or '')) ~= EXPECTED_HOST then
    return nil, authError('invalid Host header')
  end
  if headers.origin then
    return nil, authError('browser Origin requests are not allowed')
  end
  return headers
end

local function bearerToken(headers)
  local scheme, token = string.match(tostring(headers.authorization or ''), '^(%S+)%s+(%S+)$')
  if not scheme or string.lower(scheme) ~= 'bearer' then return nil end
  if #token ~= 64 or not string.match(token, '^[0-9a-fA-F]+$') then return nil end
  return string.lower(token)
end

local function authenticate(req)
  local headers, contextErr = validateRequestContext(req)
  if not headers then return nil, contextErr end
  if not sessionToken then
    return nil, authError('session is not initialized', true)
  end
  local token = bearerToken(headers)
  if not token or token ~= sessionToken then
    return nil, authError('invalid or missing Bearer capability')
  end
  return true
end

-- Compile a Lua source string. Returns fn or (nil, errString).
local function compileLua(luaSource)
  return loadstring(luaSource, "llmBridge")
end

-- Build a sandbox env whose print/log append to `buffer`, falling back to the
-- real globals for everything else. Keeps capture scoped to this one call so
-- the engine's global print/log are never touched.
local function buildCaptureEnv(buffer)
  local function capture(...)
    local parts = {}
    for i = 1, select('#', ...) do parts[i] = tostring(select(i, ...)) end
    buffer[#buffer + 1] = table.concat(parts, "\t")
  end
  local env = {
    print = capture,
    log = function(level, tag, msg) capture("[" .. tostring(level) .. "] " .. tostring(msg)) end,
  }
  return setmetatable(env, { __index = _G })
end

-- Run a compiled fn with output capture. Returns the {ok,...} result table.
local function runCaptured(fn)
  local buffer = {}
  setfenv(fn, buildCaptureEnv(buffer))
  local ok, resultOrErr = pcall(fn)
  local output = table.concat(buffer, "\n")
  if not ok then
    return { ok = false, phase = 'runtime', error = tostring(resultOrErr), output = output }
  end
  return { ok = true, result = dumps(resultOrErr), output = output }
end

-- Decode + execute the `lua` query param.
local function execLuaFromQuery(query)
  if not query then
    return { ok = false, error = "no query; use /exec?lua=<urlencoded>" }
  end
  local encoded = string.match(query, "lua=([^&]+)")
  if not encoded then
    return { ok = false, error = "missing `lua` param" }
  end
  local luaSource = socketUrl.unescape(encoded)
  local fn, compileErr = compileLua(luaSource)
  if not fn then
    return { ok = false, phase = 'compile', error = tostring(compileErr) }
  end
  return runCaptured(fn)
end

local function handleExec(req)
  local authenticated, authErr = authenticate(req)
  if not authenticated then return authErr end
  return execLuaFromQuery(req.uri and req.uri.query)
end

local function handleSession(req)
  local headers, contextErr = validateRequestContext(req)
  if not headers then return contextErr end
  local token = bearerToken(headers)
  if not token then return authError('Bearer capability must be 64 hexadecimal characters') end
  if sessionToken and token ~= sessionToken then
    return authError('session is already initialized with another capability')
  end
  local initialized = sessionToken == nil
  if initialized then
    sessionToken = token
    log('I', 'llmBridge', 'authenticated client session initialized')
  end
  return { ok = true, initialized = initialized, auth = AUTH_PROTOCOL }
end

local function handlePing(req)
  local authenticated, authErr = authenticate(req)
  if not authenticated then return authErr end
  return {
    ok = true,
    pong = true,
    host = HOST,
    port = PORT,
    version = beamng_version,
    auth = AUTH_PROTOCOL,
  }
end

local function handleNotFound(req)
  local _, contextErr = validateRequestContext(req)
  if contextErr then return contextErr end
  return { ok = false, error = 'unknown bridge endpoint' }
end

-- Start the server. simpleHttpServer.start() logs its own bind error and does
-- NOT return a status, so we can't assert success here — /ping is the proof.
-- If you see "address already in use" above this line, a previous server still
-- holds the port: call llmBridge_server.stop() on the holder, or — if the
-- holding extension is already gone — require('utils/simpleHttpServer').stop()
-- from the console (the module is a cached singleton, so a fresh require
-- reaches the same live socket). No restart needed.
local function startServer()
  sessionToken = nil
  ws = require('utils/simpleHttpServer')
  local handlers = {
    { '^/session$', handleSession },
    { '^/ping$', handlePing },
    { '^/exec$', handleExec },
    { '^/.*$', handleNotFound },
  }
  ws.start(HOST, PORT, '/lua/ge/extensions/llmBridge/', handlers)
  running = true
  log('I', 'llmBridge', 'server.startServer() attempted on http://' .. HOST .. ':' .. PORT .. ' - confirm with GET /ping')
end

-- Release the port. Safe to call from the console to recover a stuck socket.
local function stopServer()
  if ws then ws.stop() end
  running = false
  sessionToken = nil
  log('I', 'llmBridge', 'server stopped; port ' .. PORT .. ' released')
end

local function onUpdate()
  if running and ws then ws.update() end
end

M.onExtensionLoaded = startServer
M.onExtensionUnloaded = stopServer
M.onUpdate = onUpdate
M.start = startServer  -- console: llmBridge_server.start()
M.stop = stopServer    -- console: llmBridge_server.stop()

return M
