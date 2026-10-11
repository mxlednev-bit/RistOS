-- Restore original MineOS core files after RistOs upgrade.
-- Does not touch profiles or EEPROM, and does not delete Rist Control.app.
local component = require("component")
local disks = {}
for addr in component.list("filesystem") do
  local fs = component.proxy(addr)
  if not fs.isReadOnly() and fs.exists("/.ristos-backup/OS.lua") and fs.exists("/.ristos-backup/Libraries/System.lua") then
    disks[#disks+1] = fs
  end
end
assert(#disks > 0, "No RistOs backup HDD found")
for i, fs in ipairs(disks) do
  print(i .. ") " .. (fs.getLabel() or "unnamed") .. " / " .. fs.address)
end
io.write("Choose disk for rollback: ")
local drive = disks[tonumber(io.read() or "")]
assert(drive, "Invalid disk")
io.write("Type RESTORE to put original OS.lua and System.lua back: ")
assert(io.read() == "RESTORE", "Cancelled")
for _, path in ipairs({"OS.lua", "Libraries/System.lua"}) do
  local source = "/.ristos-backup/" .. path
  local dest = "/" .. path
  local rd, why = drive.open(source, "rb")
  assert(rd, "Cannot read backup: " .. tostring(why))
  local wr, err = drive.open(dest, "wb")
  assert(wr, "Cannot write original: " .. tostring(err))
  while true do
    local chunk = drive.read(rd, 8192)
    if not chunk then break end
    assert(drive.write(wr, chunk))
  end
  drive.close(rd)
  drive.close(wr)
  print("Restored " .. path)
end
print("Rollback complete. Reboot the computer; EEPROM unchanged.")
