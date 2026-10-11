-- RistOS 0.2 upgrade engine (runs inside RistOS, not OpenOS).
-- Downloads only versioned changed files; never writes EEPROM/OS.lua/users.
local GUI = require("GUI")
local fs = require("Filesystem")
local BASE = "https://cdn.jsdelivr.net/gh/mxlednev-bit/RistOS@main/"
local ROOT = BASE .. "RistOS/"
local STAGE, BACKUP = "/.ristos-020-stage/", "/.ristos-020-backup/"
local address = component.list("internet")()
assert(address, "Internet Card missing")
local internet = component.proxy(address)
local drive = fs.getProxy()
assert(drive and not drive.isReadOnly(), "Boot disk is read-only")
assert(drive.exists("/RistOS.txt") and drive.exists("/OS.lua"), "No RistOS boot disk")
local function pathOK(path)
  return type(path) == "string" and path:match("^[%w_%-%. /]+$") and
    not path:find("%.%.", 1, false) and path:sub(1, 1) ~= "/" and
    (path:match("^Applications/Rist .+%.app/") or path == "RistOS.txt")
end
local function encode(path)
  return (path:gsub("([^%w%-%_%.%~/])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end
local function request(url, sink)
  local h, why = internet.request(url)
  assert(h, "CDN request failed: " .. tostring(why))
  local count = 0
  while true do
    local chunk, reason = h.read(8192)
    if not chunk then
      h.close()
      assert(not reason, "CDN read error: " .. tostring(reason))
      break
    end
    count = count + #chunk
    assert(count < 100000, "Downloaded file too large")
    local ok, err = sink(chunk)
    assert(ok, tostring(err))
  end
  return count
end
local function mkdir(path)
  local current = ""
  for part in path:gmatch("[^/]+") do
    current = current .. "/" .. part
    if not drive.exists(current) then
      local yes, why = drive.makeDirectory(current)
      assert(yes, tostring(why))
    end
  end
end
local function download(url, path, expected)
  mkdir(path:match("^(.+)/[^/]+$") or "/")
  local stream, why = drive.open(path, "wb")
  assert(stream, tostring(why))
  local success, count = pcall(request, url, function(chunk)
    return drive.write(stream, chunk)
  end)
  drive.close(stream)
  if not success or count ~= expected then
    drive.remove(path)
    error("Download failed: " .. path .. " / " .. tostring(count) .. " (expected " .. expected .. ")")
  end
end
local function copy(src, dst)
  mkdir(dst:match("^(.+)/[^/]+$") or "/")
  local input, why = drive.open(src, "rb")
  assert(input, "Cannot read " .. src .. ": " .. tostring(why))
  local output, reason = drive.open(dst, "wb")
  if not output then drive.close(input); error(tostring(reason)) end
  while true do
    local part = drive.read(input, 8192)
    if not part then break end
    local ok, err = drive.write(output, part)
    if not ok then drive.close(input); drive.close(output); error(tostring(err)) end
  end
  drive.close(input)
  drive.close(output)
end
-- Manifest is explicitly versioned; Lua parser runs in an empty sandbox.
local chunks = {}
request(BASE .. "Installer/Upgrade_0_2_files.lua", function(part)
  chunks[#chunks + 1] = part
  return true
end)
local manifest = table.concat(chunks)
assert(#manifest < 6000, "Manifest is too large")
local run, err = load(manifest, "=RistOS 0.2 manifest", "t", {})
assert(run, "Bad manifest: " .. tostring(err))
local entries = run()
assert(type(entries) == "table" and #entries >= 5 and #entries <= 12, "Bad RistOS manifest")
local needed, backupSize = 0, 0
for _, file in ipairs(entries) do
  assert(type(file) == "table" and pathOK(file[1]) and
    type(file[2]) == "number" and file[2] > 0 and file[2] < 80000, "Unsafe update file")
  local target = "/" .. file[1]
  if not drive.exists(target) or drive.size(target) ~= file[2] then
    needed = needed + file[2]
    if drive.exists(target) and not drive.exists(BACKUP .. file[1]) then
      backupSize = backupSize + drive.size(target)
    end
  end
end
local free = drive.spaceTotal() - drive.spaceUsed()
assert(free > needed + backupSize + 32768, "Not enough HDD space to safely upgrade")
-- Stage and verify all file sizes before any live file is changed.
for i, file in ipairs(entries) do
  local stage, target = STAGE .. file[1], "/" .. file[1]
  if (not drive.exists(target) or drive.size(target) ~= file[2]) and
    (not drive.exists(stage) or drive.size(stage) ~= file[2]) then
    download(ROOT .. encode(file[1]), stage, file[2])
  end
end
-- Keep backups of old files. Re-running is safe if interrupted.
for _, file in ipairs(entries) do
  local path, size = file[1], file[2]
  local target = "/" .. path
  if not drive.exists(target) or drive.size(target) ~= size then
    local backup = BACKUP .. path
    if drive.exists(target) and not drive.exists(backup) then copy(target, backup) end
    copy(STAGE .. path, target)
    assert(drive.size(target) == size, "Write verification failed: " .. target)
  end
end
-- Shortcuts are created locally, never fetched over CDN (9-byte 404 bug).
local shortcuts = {
  ["/Users/Rist/Desktop/Rist Article AI.lnk"] = "/Applications/Rist Article AI.app/",
  ["/Users/Rist/Desktop/Rist Update.lnk"] = "/Applications/Rist Update.app/",
}
for path, contents in pairs(shortcuts) do
  if not drive.exists(path) then
    mkdir(path:match("^(.+)/[^/]+$") or "/")
    local f = assert(drive.open(path, "wb"))
    assert(drive.write(f, contents))
    drive.close(f)
  end
end
GUI.alert("RistOS 0.2 installed. Restart computer to load changes.\nRistEFI was NOT modified.")
