-- RistOs 0.1: resource dashboard and rendering profiles.
-- Compatible with the MineOS GUI/System APIs; changes persist in user settings.
local GUI = require("GUI")
local system = require("System")
local screen = require("Screen")
local paths = require("Paths")
local filesystem = require("Filesystem")

local workspace, window = system.addWindow(GUI.filledWindow(1, 1, 70, 24, 0x192432))
local bg = window.backgroundPanel
local setting = system.getUserSettings()
local white, muted, accent = 0xF0F0F0, 0xB6C6D8, 0x51B7FF

window:addChild(GUI.text(3, 3, white, "RistOs 0.1 | Control Center"))
window:addChild(GUI.text(3, 5, muted, "Graphics profile / Profil grafiki"))

local details = window:addChild(GUI.object(3, 18, 60, 4))
details.draw = function(object)
  local mem = computer.totalMemory()
  local free = computer.freeMemory()
  local pct = math.floor(free * 100 / math.max(1, mem))
  screen.drawText(object.x, object.y, muted,
    "RAM free: " .. math.floor(free / 1024) .. " / " .. math.floor(mem / 1024) .. " KiB (" .. pct .. "%)")
  screen.drawText(object.x, object.y + 1, muted,
    "Wallpaper: " .. (setting.interfaceWallpaperEnabled and "on" or "off"))
  screen.drawText(object.x, object.y + 2, muted,
    "Double buffering: on | Network: " .. (setting.networkEnabled and "on" or "off"))
end

local info = window:addChild(GUI.text(3, 16, accent, "Select a profile."))
local function setProfile(name)
  setting.interfaceBlurEnabled = false
  setting.interfaceTransparencyEnabled = false
  setting.interfaceTransparencyDock = 0
  setting.interfaceTransparencyMenu = 0
  setting.interfaceTransparencyContextMenu = 0
  if name == "ECO" then
    setting.interfaceWallpaperEnabled = false
  elseif name == "BALANCED" then
    setting.interfaceWallpaperEnabled = true
    setting.interfaceWallpaperPath = paths.system.wallpapers .. "Solid color.wlp/"
  else
    setting.interfaceWallpaperEnabled = true
    setting.interfaceWallpaperPath = paths.system.wallpapers .. "Stars.wlp/"
    setting.interfaceTransparencyEnabled = true
    setting.interfaceTransparencyDock = 0.2
    setting.interfaceTransparencyMenu = 0.15
    setting.interfaceTransparencyContextMenu = 0.15
  end
  system.saveUserSettings()
  system.updateColorScheme()
  system.updateWallpaper()
  info.text = "Active profile: " .. name .. " (saved)"
  workspace:draw()
end

local function addButton(x, y, name, description)
  window:addChild(GUI.button(x, y, 18, 3, 0x25394D, white, 0x2563B0, white, name)).onTouch = function()
    setProfile(name)
  end
  window:addChild(GUI.text(x, y + 4, muted, description))
end

addButton(3, 8, "ECO", "No animations")
addButton(25, 8, "BALANCED", "Static desktop")
addButton(47, 8, "VISUAL", "10 FPS wallpaper")

window.onResize = function(width, height)
  bg.width, bg.height = width, height
end
workspace:draw()
