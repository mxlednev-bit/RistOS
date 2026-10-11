-- RistOS 0.2 bootstrap: use MineCode IDE -> New -> paste -> Run.
-- Verify official repository address below before executing.
local url = "https://cdn.jsdelivr.net/gh/mxlednev-bit/RistOS@main/Installer/Upgrade_0_2.lua"
local cardAddress = assert(component.list("internet")(), "Internet Card missing")
local h, why = component.proxy(cardAddress).request(url)
assert(h, tostring(why))
local parts, size = {}, 0
while true do
  local chunk, reason = h.read(8192)
  if not chunk then h.close(); assert(not reason, tostring(reason)); break end
  size = size + #chunk
  assert(size < 25000, "Installer too large")
  parts[#parts+1] = chunk
end
local code = table.concat(parts)
assert(code:find("RistOS 0.2 upgrade engine", 1, true), "Unexpected CDN response")
assert(load(code, "=RistOS 0.2 updater", "t"))()
