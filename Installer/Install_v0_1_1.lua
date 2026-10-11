-- RistOS installer v0.1.1 for OpenOS. Reads files from the owner's HTTPS CDN.
-- Does NOT format disks or flash EEPROM.
local component = require("component")
local computer = require("computer")

local base, edition = ...
if not base or not base:match("^https://") or not base:match("/RistOS/$") then
  print("Usage: install.lua https://cdn.jsdelivr.net/gh/USER/REPO@main/RistOS/ lite|full")
  return
end
edition = edition or "lite"
if edition ~= "lite" and edition ~= "full" then error("Edition must be lite or full") end

local internet = component.internet
assert(internet, "Internet Card required")
local MAX_BYTES = 65536
local function encode(path)
  return (path:gsub("([^%w%-%_%.%~/])", function(c)
    return string.format("%%%02X", c:byte())
  end))
end
local function request(url, sink)
  local handle, why = internet.request(url)
  if not handle then return nil, tostring(why) end
  local count = 0
  while true do
    local chunk, err = handle.read(MAX_BYTES)
    if not chunk then
      handle.close()
      if err then return nil, tostring(err) end
      return count
    end
    count = count + #chunk
    local ok, reason = sink(chunk)
    if not ok then
      handle.close()
      return nil, tostring(reason)
    end
  end
end
local function fetchText(url)
  local chunks = {}
  local count, reason = request(url, function(part)
    if #chunks > 64 then return nil, "Manifest too large" end
    chunks[#chunks + 1] = part
    return true
  end)
  if not count then return nil, reason end
  if count > 256*1024 then return nil, "Manifest too large" end
  return table.concat(chunks)
end
local manifestURL = base:gsub("RistOS/$", "Installer/Files" .. (edition == "lite" and "Lite" or "Full") .. "_v0_1_1.lua")
print("RistOS v0.1.1 " .. edition .. " - loading file manifest")
local manifestText, reason = fetchText(manifestURL)
assert(manifestText, reason)
local loadManifest, err = load(manifestText, "=RistOS manifest", "t", {})
assert(loadManifest, err)
local files = loadManifest()
assert(type(files) == "table" and #files > 0 and #files < 1000, "Invalid manifest")

local drives = {}
for addr in component.list("filesystem") do
  local d = component.proxy(addr)
  local ok, ro = pcall(d.isReadOnly)
  if ok and not ro and d.spaceTotal() >= 1024*1024 then
    drives[#drives + 1] = d
  end
end
assert(#drives > 0, "Writable HDD missing")
print("Select destination HDD:")
for i, d in ipairs(drives) do
  print(i .. ") " .. (d.getLabel() or "unnamed") .. " / " .. math.floor(d.spaceTotal()/1024) .. " KiB / " .. d.address:sub(1,8))
end
io.write("Disk number: ")
local drive = drives[tonumber(io.read() or "")]
assert(drive, "Invalid disk")
assert(not drive.exists("/OS.lua") or drive.exists("/.ristos-installing") or drive.exists("/RistOS.txt"),
  "Existing non-RistOS detected. Use Upgrade.lua instead.")
local needed = 0
for _, entry in ipairs(files) do
  assert(type(entry[1]) == "string" and entry[1]:sub(1,1) ~= "/" and not entry[1]:find("%.%."), "Unsafe path")
  assert(type(entry[2]) == "number" and entry[2] > 0, "Invalid size")
  local dst = "/" .. entry[1]
  if not drive.exists(dst) or drive.size(dst) ~= entry[2] then
    needed = needed + entry[2]
  end
end
local free = drive.spaceTotal() - drive.spaceUsed()
print("Files: " .. #files .. ", remaining payload: " .. math.ceil(needed/1024) .. " KiB; free: " .. math.floor(free/1024) .. " KiB")
assert(needed + 32768 < free, "Not enough disk space")
io.write("Type INSTALL to copy/resume files (EEPROM stays unchanged): ")
assert(io.read() == "INSTALL", "Cancelled")
local marker = drive.open("/.ristos-installing", "wb")
assert(marker, "Cannot create installation marker")
drive.write(marker, "RistOS installation in progress")
drive.close(marker)

local function mkdir(path)
  local current = ""
  for part in path:gmatch("[^/]+") do
    current = current .. "/" .. part
    if not drive.exists(current) then
      local ok, why = drive.makeDirectory(current)
      assert(ok, tostring(why))
    end
  end
end
for n, entry in ipairs(files) do
  local path, expected = entry[1], entry[2]
  local dirname = path:match("^(.+)/[^/]+$")
  if dirname then mkdir(dirname) end
  local dest = "/" .. path
  if drive.exists(dest) and drive.size(dest) == expected then
    if n % 10 == 0 then print(n .. "/" .. #files .. ": already present") end
  else
  local fd, why = drive.open(dest, "wb")
  assert(fd, tostring(why))
  local wrote, r = request(base .. encode(path), function(chunk)
    return drive.write(fd, chunk)
  end)
  drive.close(fd)
  if not wrote or wrote ~= expected then
    drive.remove(dest)
    error("Failed " .. path .. ": " .. tostring(r or ("length " .. tostring(wrote) .. " != " .. expected)))
  end
  if n == 1 or n % 10 == 0 or n == #files then
    print(n .. "/" .. #files .. " files: " .. path)
  end
  end -- missing or size-mismatched entry
end
-- The manifest omits empty directories; initialize them explicitly.
for _, dir in ipairs({
  "Mounts", "Temporary", "Users/Rist/Application data",
  "Users/Rist/Applications", "Users/Rist/Libraries",
  "Users/Rist/Trash", "Users/Rist/Wallpapers"
}) do
  mkdir(dir)
end
drive.remove("/.ristos-installing")
print("RistOS files installed. HDD: " .. drive.address)
print("EEPROM NOT modified. Flash RistEFI manually after backing up current firmware.")
