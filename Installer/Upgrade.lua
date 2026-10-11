-- RistOS upgrade for an existing MineOS hard disk.
-- Stages and verifies files, keeps original versions in /.ristos-backup/.
-- DOES NOT format disk, alter users, or flash EEPROM.
local component = require("component")
local base = ...
if not base or not base:match("^https://") or not base:match("/RistOS/$") then
  print("Usage: upgrade.lua https://cdn.jsdelivr.net/gh/USER/REPO@main/RistOS/")
  return
end
local internet = component.internet
assert(internet, "Internet Card required")
local function encode(path)
  return (path:gsub("([^%w%-%_%.%~/])", function(c)
    return string.format("%%%02X", c:byte())
  end))
end
local function readRequest(url, sink)
  local handle, why = internet.request(url)
  if not handle then return nil, tostring(why) end
  local total = 0
  while true do
    local part, reason = handle.read(16384)
    if not part then
      handle.close()
      if reason then return nil, tostring(reason) end
      return total
    end
    total = total + #part
    local ok, err = sink(part)
    if not ok then handle.close(); return nil, tostring(err) end
  end
end
local pieces = {}
local ok, why = readRequest(base:gsub("RistOS/$", "Installer/UpgradeFiles.lua"), function(chunk)
  pieces[#pieces + 1] = chunk
  return #pieces <= 64 or nil, "Oversized manifest"
end)
assert(ok and ok < 65536, tostring(why or "Manifest too large"))
local chunk, err = load(table.concat(pieces), "=RistOS upgrade manifest", "t", {})
assert(chunk, err)
local entries = chunk()
assert(type(entries) == "table" and #entries >= 4 and #entries <= 30, "Invalid file manifest")

local disks = {}
for address in component.list("filesystem") do
  local fs = component.proxy(address)
  if not fs.isReadOnly() and fs.exists("/OS.lua") and fs.exists("/Libraries/System.lua") then
    disks[#disks+1] = fs
  end
end
assert(#disks > 0, "No writable MineOS disk found")
for i, d in ipairs(disks) do print(i .. ") " .. (d.getLabel() or "unnamed") .. " / " .. d.address) end
io.write("Choose MineOS disk number: ")
local drive = disks[tonumber(io.read() or "")]
assert(drive, "Invalid disk")

local function mkdir(path)
  local cur = ""
  for part in path:gmatch("[^/]+") do
    cur = cur .. "/" .. part
    if not drive.exists(cur) then
      local yes, reason = drive.makeDirectory(cur)
      assert(yes, tostring(reason))
    end
  end
end
local function copy(source, dest)
  mkdir(dest:match("^(.+)/[^/]+$") or "/")
  local a, reason = drive.open(source, "rb")
  assert(a, "Cannot read " .. source .. ": " .. tostring(reason))
  local b, reason = drive.open(dest, "wb")
  assert(b, "Cannot write " .. dest .. ": " .. tostring(reason))
  while true do
    local data = drive.read(a, 8192)
    if not data then break end
    local yes, why = drive.write(b, data)
    assert(yes, tostring(why))
  end
  drive.close(a)
  drive.close(b)
end

-- Download and verify ALL changed files before touching the live OS.
local stage = "/.ristos-stage/"
local backup = "/.ristos-backup/"
local total = 0
for i, entry in ipairs(entries) do
  local path, size = entry[1], entry[2]
  assert(type(path) == "string" and not path:find("%.%.") and path:sub(1,1) ~= "/", "Unsafe path")
  assert(type(size) == "number" and size > 0, "Invalid file size")
  total = total + size
end
assert(total < drive.spaceTotal() - drive.spaceUsed(), "Not enough free HDD space for staging")
print("RistOS upgrade: staging " .. #entries .. " files (" .. math.ceil(total/1024) .. " KiB)")
for i, entry in ipairs(entries) do
  local path, size = entry[1], entry[2]
  local destination = stage .. path
  mkdir(destination:match("^(.+)/[^/]+$") or stage)
  local fd, why = drive.open(destination, "wb")
  assert(fd, "Cannot open staging file: " .. tostring(why))
  local count, err = readRequest(base .. encode(path), function(part)
    return drive.write(fd, part)
  end)
  drive.close(fd)
  if not count or count ~= size then
    drive.remove(destination)
    error("Download failed for " .. path .. ": " .. tostring(err or ("size " .. tostring(count) .. "/" .. size)))
  end
  print("Staged " .. i .. "/" .. #entries .. ": " .. path)
end
io.write("All verified. Type UPGRADE to replace system files (users are preserved): ")
assert(io.read() == "UPGRADE", "Cancelled. Existing OS unchanged")
for _, entry in ipairs(entries) do
  local path = entry[1]
  local destination = "/" .. path
  local old = backup .. path
  if drive.exists(destination) and not drive.exists(old) then
    copy(destination, old)
  end
  copy(stage .. path, destination)
  print("Updated: " .. destination)
end
print("RistOS 0.1 upgrade complete. Reboot the computer.")
print("Original system files backed up in /.ristos-backup/ ; firmware unchanged.")
