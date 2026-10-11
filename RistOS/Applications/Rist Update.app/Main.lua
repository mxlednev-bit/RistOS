-- RistOS 0.2 update manager. Changes only Rist applications, never firmware.
local GUI, system = require("GUI"), require("System")
local workspace, window = system.addWindow(GUI.filledWindow(1, 1, 73, 22, 0x171B24))
local white, gray = 0xEAF2FC, 0xAAB8CD
window:addChild(GUI.text(3, 3, white, "Rist Update 0.2.1"))
window:addChild(GUI.text(3, 5, gray, "Repository: mxlednev-bit / RistOS"))
window:addChild(GUI.text(3, 7, gray, "Updates only Rist apps, keeps backups on HDD."))
window:addChild(GUI.text(3, 8, gray, "Does NOT rewrite EEPROM or /OS.lua."))
window:addChild(GUI.text(3, 12, gray, "Restart the computer after a successful update."))
window:addChild(GUI.button(3, 15, 37, 3, 0x264B6E, white, 0x30709A, white, "Repair / Update RistOS 0.2.1")).onTouch = function()
  system.execute("/Applications/Rist Update.app/Engine.lua")
end
window.onResize = function(w, h)
  window.backgroundPanel.width, window.backgroundPanel.height = w, h
end
workspace:draw()
