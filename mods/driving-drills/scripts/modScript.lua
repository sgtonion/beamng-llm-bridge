-- Run automatically by the mod manager when this mod is mounted
-- (core_modmanager.initDB scans /scripts/ for modScript.lua).
--
-- Loads the drill extension so it is available from the console (or the
-- bridge) in any freeroam session without a manual extensions.load(). The
-- mod manager wraps extensions.load here to set unload mode "manual", so
-- the extension survives level loads.

extensions.load("drivingDrills_turnsCourse")

log("I", "drivingDrills", "modScript loaded: turnsCourse drill available")
