-- llmBridge/main.lua — minimal entry-point extension.
--
-- Module name once loaded: "llmBridge_main" (path slashes -> underscores).
-- Load:   extensions.load("llmBridge_main")
-- Reload: extensions.reload("llmBridge_main")
--
-- onExtensionLoaded fires on every load AND every reload, so editing the
-- HELLO string below and reloading is the hot-reload acceptance check.

local M = {}

local HELLO = "hello from llm-bridge mod"

local function onExtensionLoaded()
  log("I", "llmBridge", HELLO)
end

M.onExtensionLoaded = onExtensionLoaded

return M
