-- RistOS 0.2.1 upgrade engine. Stages and validates all files before replacing apps.
-- No EEPROM or OS.lua modifications. Designed for OpenComputers / MineOS libraries.
local GUI = require("GUI")
local fs = require("Filesystem")
local BASE = "https://cdn.jsdelivr.net/gh/mxlednev-bit/RistOS@main/RistOS/"
local STAGE = "/.ristos-021-stage/"
local BACKUP = "/.ristos-021-backup/"
local cardAddress = assert(component.list("internet")(), "Internet Card missing")
local internet = component.proxy(cardAddress)
local drive = assert(fs.getProxy(), "Boot disk missing")
assert(not drive.isReadOnly(), "Boot disk is read only")
assert(drive.exists("/OS.lua") and drive.exists("/RistOS.txt"), "RistOS boot disk not found")

-- Text files can change length after a Git commit. Verify Lua syntax and
-- RistOS headers instead of comparing against obsolete byte counts.
-- Icons remain byte-exact. No code from downloaded files executes here.
local files = {
  {"Applications/Rist Article AI.app/Icon.pic", "binary", 212},
  {"Applications/Rist Article AI.app/Main.lua", "lua"},
  {"Applications/Rist Control.app/Icon.pic", "binary", 322},
  {"Applications/Rist Control.app/Main.lua", "lua"},
  {"Applications/Rist Update.app/Engine.lua", "lua"},
  {"Applications/Rist Update.app/Icon.pic", "binary", 322},
  {"Applications/Rist Update.app/Main.lua", "lua"},
  {"RistOS.txt", "text"},
}

local function encode(path)
  return (path:gsub("([^%w%-%_%.%~/])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

local function mkdir(path)
  if not path then return end
  local current = ""
  for part in path:gmatch("[^/]+") do
    current = current .. "/" .. part
    if not drive.exists(current) then
      local ok, err = drive.makeDirectory(current)
      assert(ok, "mkdir " .. current .. ": " .. tostring(err))
    end
  end
end

local function readFile(path)
  local h, reason = drive.open(path, "rb")
  if not h then return nil, reason end
  local parts = {}
  while true do
    local part = drive.read(h, 4096)
    if not part then break end
    parts[#parts + 1] = part
  end
  drive.close(h)
  return table.concat(parts)
end

local function writeFile(path, data)
  mkdir(path:match("^(.+)/[^/]+$"))
  local h, reason = drive.open(path, "wb")
  assert(h, "open " .. path .. ": " .. tostring(reason))
  local ok, err = drive.write(h, data)
  drive.close(h)
  assert(ok, "write " .. path .. ": " .. tostring(err))
  local saved = readFile(path)
  assert(saved == data, "Write verification failed: " .. path)
end

local function download(path)
  local url = BASE .. encode(path)
  local h, reason = internet.request(url)
  assert(h, "CDN request failed for " .. path .. ": " .. tostring(reason))
  local chunks, size = {}, 0
  while true do
    local part, err = h.read(8192)
    if not part then
      h.close()
      assert(not err, "CDN read failed: " .. path .. ": " .. tostring(err))
      break
    end
    size = size + #part
    assert(size < 25000, "CDN response too large: " .. path)
    chunks[#chunks + 1] = part
  end
  return table.concat(chunks)
end

local function validate(entry, data)
  local path, kind, expected = entry[1], entry[2], entry[3]
  if kind == "binary" then
    assert(#data == expected, "Icon size mismatch: " .. path .. " / " .. #data .. " != " .. expected)
  elseif kind == "lua" then
    assert(#data >= 250 and #data < 20000, "Lua response size invalid: " .. path)
    assert(data:sub(1, 13) == "-- RistOS 0.2", "Unexpected Lua response: " .. path)
    local chunk, err = load(data, "=" .. path, "t", {})
    assert(chunk, "Downloaded Lua syntax error: " .. path .. ": " .. tostring(err))
    if path == "Applications/Rist Update.app/Engine.lua" then
      assert(data:sub(1, 45):find("RistOS 0.2.1 upgrade engine", 1, true),
        "CDN delivered outdated updater engine")
    elseif path == "Applications/Rist Update.app/Main.lua" then
      assert(data:find("Rist Update 0.2.1", 1, true),
        "CDN delivered outdated updater app")
    end
  else
    assert(#data >= 50 and #data <= 1024 and data:sub(1, 10) == "RistOS 0.2", "Unexpected RistOS.txt")
  end
end

-- Download and validate first, before changing any installed application.
local downloaded, stageBytes, backupBytes = {}, 0, 0
for i, entry in ipairs(files) do
  local path = entry[1]
  local data = download(path)
  validate(entry, data)
  downloaded[i] = data
  local stage = STAGE .. path
  if not drive.exists(stage) then stageBytes = stageBytes + #data end
  local live = "/" .. path
  if drive.exists(live) and not drive.exists(BACKUP .. path) then
    backupBytes = backupBytes + drive.size(live)
  end
end
local free = drive.spaceTotal() - drive.spaceUsed()
assert(free > stageBytes + backupBytes + 32768, "Not enough free HDD space for staging and backups")

for i, entry in ipairs(files) do
  local stage, data = STAGE .. entry[1], downloaded[i]
  if readFile(stage) ~= data then writeFile(stage, data) end
end

-- Apply only after all downloads have passed the checks and staging succeeded.
local changed = 0
for i, entry in ipairs(files) do
  local path, data = entry[1], downloaded[i]
  local live, backup = "/" .. path, BACKUP .. path
  local old = readFile(live)
  if old ~= data then
    if old and not drive.exists(backup) then writeFile(backup, old) end
    writeFile(live, data)
    changed = changed + 1
  end
end

local shortcuts = {
  ["/Users/Rist/Desktop/Rist Article AI.lnk"] = "/Applications/Rist Article AI.app/",
  ["/Users/Rist/Desktop/Rist Update.lnk"] = "/Applications/Rist Update.app/",
}
for path, target in pairs(shortcuts) do
  if not drive.exists(path) then writeFile(path, target) end
end

GUI.alert("RistOS 0.2.1 update completed. Changed files: " .. changed ..
  ".\nRestart the computer. RistEFI/EEPROM was not modified.")
