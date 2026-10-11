-- Optional flash utility, requires OpenOS on floppy + writable EEPROM.
-- Run ONLY after a successful RistOS disk install and after saving your EEPROM.
local component = require("component")
local path = ...
assert(path, "Usage: flash.lua /tmp/RistEFI.lua")
local e = component.eeprom
assert(e, "EEPROM unavailable")
local f, err = io.open(path, "rb")
assert(f, err)
local firmware = f:read("*a")
f:close()
assert(#firmware <= e.getSize(), "Firmware exceeds EEPROM capacity")
assert(firmware:find("RistEFI", 1, true), "Not RistEFI firmware")
local disks = {}
for address in component.list("filesystem") do
  local d = component.proxy(address)
  if d.exists("/OS.lua") and d.exists("/RistOS.txt") then
    disks[#disks+1] = d
  end
end
assert(#disks > 0, "RistOS HDD not found")
for i, d in ipairs(disks) do
  print(i .. ") " .. (d.getLabel() or "unnamed") .. " / " .. d.address)
end
io.write("RistOS boot disk number: ")
local drive = disks[tonumber(io.read() or "")]
assert(drive, "Invalid disk")
local old = e.get()
local backup = "/RistEFI-original-backup.lua"
local fd, reason = drive.open(backup, "wb")
assert(fd, "Could not back up existing EFI: " .. tostring(reason))
assert(drive.write(fd, old))
drive.close(fd)
print("Saved EEPROM code to " .. backup)
io.write("Type FLASH to replace EEPROM with RistEFI (irreversible without recovery): ")
assert(io.read() == "FLASH", "Cancelled")
assert(e.set(firmware), "Flashing failed")
assert(e.setData(drive.address), "Failed to set boot address")
pcall(e.setLabel, "RistOS EFI")
print("EEPROM flashed. Remove OpenOS floppy and reboot.")
