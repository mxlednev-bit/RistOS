-- RistEFI 0.1: minimal optional BIOS for RistOS / OpenComputers.
-- Firmware reads the boot HDD address from EEPROM data, then /OS.lua.
local eeprom = component.proxy(component.list("eeprom")())
local address = eeprom.getData()
local ok, drive = pcall(component.proxy, address)
if not ok then drive = nil end
if not drive or not drive.exists("/OS.lua") then
  for candidate in component.list("filesystem") do
    local p = component.proxy(candidate)
    if p.exists("/RistOS.txt") and p.exists("/OS.lua") then
      drive, address = p, candidate
      break
    end
  end
end
assert(drive and drive.exists("/OS.lua"), "RistEFI: RistOS boot disk not found")
local gpu, screen = component.list("gpu")(), component.list("screen")()
if gpu and screen then
  component.invoke(gpu, "bind", screen, true)
  pcall(component.invoke, gpu, "setDepth", 8)
end
eeprom.setData(address)
local fd = assert(drive.open("/OS.lua", "rb"))
local parts = {}
while true do
  local data = drive.read(fd, 8192)
  if not data then break end
  parts[#parts + 1] = data
end
drive.close(fd)
assert(load(table.concat(parts), "=/OS.lua"))()
