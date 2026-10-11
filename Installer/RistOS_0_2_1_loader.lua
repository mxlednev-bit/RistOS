-- RistOS 0.2.1 loader. Run from MineCode IDE in an already installed RistOS.
local url = "https://cdn.jsdelivr.net/gh/mxlednev-bit/RistOS@main/Installer/Upgrade_0_2_1.lua"
local card = assert(component.list("internet")(), "Internet Card missing")
local h, reason = component.proxy(card).request(url)
assert(h, tostring(reason))
local parts, size = {}, 0
while true do
  local chunk, err = h.read(8192)
  if not chunk then
    h.close()
    assert(not err, tostring(err))
    break
  end
  size = size + #chunk
  assert(size < 20000, "Loader received unexpected size")
  parts[#parts + 1] = chunk
end
local code = table.concat(parts)
assert(code:sub(1, 31):find("RistOS 0.2.1 upgrade engine", 1, true), "Unexpected CDN response")
local fn, err = load(code, "=RistOS 0.2.1 updater", "t")
assert(fn, tostring(err))
fn()
