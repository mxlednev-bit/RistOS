-- RistOS 0.2 / Control Center. MineOS-compatible GUI.
local GUI, system, screen = require("GUI"), require("System"), require("Screen")
local paths = require("Paths")
local workspace, window = system.addWindow(GUI.filledWindow(1, 1, 76, 27, 0x171B24))
local white, soft, blue, green = 0xE8EDF4, 0xAAB8CD, 0x65B6FF, 0x73DCA2
local settings = system.getUserSettings()
window:addChild(GUI.text(3, 3, white, "RistOS 0.2  /  CONTROL CENTER"))
window:addChild(GUI.text(3, 5, soft, "Graphics profiles  -  optimized for 2048 KiB RAM"))
local status = window:addChild(GUI.text(3, 17, blue, "Choose a profile"))
local metrics = window:addChild(GUI.object(3, 19, 68, 5))
metrics.draw = function(o)
  local total, free = computer.totalMemory(), computer.freeMemory()
  screen.drawText(o.x, o.y, soft, string.format("RAM: %d / %d KiB free", math.floor(free/1024), math.floor(total/1024)))
  screen.drawText(o.x, o.y + 1, soft, "Effects: " .. (settings.interfaceTransparencyEnabled and "on" or "off") ..
    "   Wallpaper: " .. (settings.interfaceWallpaperEnabled and "on" or "off"))
  screen.drawText(o.x, o.y + 2, soft, "No BIOS / EEPROM changes are made from Control Center")
end
local function apply(name)
  settings.interfaceBlurEnabled = false
  settings.interfaceTransparencyEnabled = false
  settings.interfaceTransparencyDock = 0
  settings.interfaceTransparencyMenu = 0
  settings.interfaceTransparencyContextMenu = 0
  if name == "ECO" then
    settings.interfaceWallpaperEnabled = false
  else
    settings.interfaceWallpaperEnabled = true
    settings.interfaceWallpaperPath = paths.system.wallpapers .. (name == "VISUAL" and "Stars.wlp/" or "Solid color.wlp/")
  end
  system.saveUserSettings()
  system.updateColorScheme()
  system.updateWallpaper()
  status.text = "Profile: " .. name .. " (saved)"
  workspace:draw()
end
for i, profile in ipairs({"ECO", "BALANCED", "VISUAL"}) do
  local x = 3 + (i-1) * 24
  window:addChild(GUI.button(x, 8, 21, 3, 0x293E53, white, 0x32649E, white, profile)).onTouch = function()
    apply(profile)
  end
end
local function openApp(path)
  if require("Filesystem").exists(path) then
    system.execute(path)
  else
    GUI.alert("Application is not installed: " .. path)
  end
end
window:addChild(GUI.button(3, 13, 32, 3, 0x244E48, white, 0x347765, white, "Rist Article AI")).onTouch = function()
  openApp("/Applications/Rist Article AI.app/Main.lua")
end
window:addChild(GUI.button(39, 13, 32, 3, 0x293E53, white, 0x32649E, white, "Rist Update")).onTouch = function()
  openApp("/Applications/Rist Update.app/Main.lua")
end
window:addChild(GUI.button(3, 24, 21, 2, 0x293E53, white, 0x32649E, white, "Refresh RAM")).onTouch = function()
  workspace:draw()
end
window.onResize = function(w, h)
  window.backgroundPanel.width, window.backgroundPanel.height = w, h
end
workspace:draw()
