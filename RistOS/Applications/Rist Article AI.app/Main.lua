-- RistOS 0.2 / Article AI. API key only held in memory for this session.
local GUI, system, fs = require("GUI"), require("System"), require("Filesystem")
local json = require("JSON")
local workspace, window = system.addWindow(GUI.filledWindow(1, 1, 91, 30, 0x16202B))
local C, T, SUB, ACC = 0xEAF2FC, 0x112033, 0xA6BCD0, 0x69C3EA
window:addChild(GUI.text(3, 3, C, "RIST ARTICLE AI  /  automatic articles"))
window:addChild(GUI.text(3, 5, SUB, "Title"))
local title = window:addChild(GUI.input(3, 6, 82, 3, T, C, SUB, 0x193852, C, "", "Enter article title"))
window:addChild(GUI.text(3, 10, SUB, "Gemini model"))
local model = window:addChild(GUI.input(3, 11, 38, 3, T, C, SUB, 0x193852, C, "gemini-2.5-flash", "Model identifier"))
window:addChild(GUI.text(44, 10, SUB, "Google AI Studio API key (not saved)"))
local key = window:addChild(GUI.input(44, 11, 41, 3, T, C, SUB, 0x193852, C, "", "API key", false, "*"))
local info = window:addChild(GUI.text(3, 20, ACC, "Ready  |  Goal: 10,000-12,000 characters"))
window:addChild(GUI.text(3, 22, SUB, "Output: /Users/Rist/Articles/article_NNN.txt"))
window:addChild(GUI.text(3, 24, SUB, "No API key is stored. No auto-publication. Requires Internet Card."))
local busy = false
local function status(message)
  info.text = tostring(message):sub(1, 85)
  workspace:draw()
end
local function length(s)
  return unicode.len(s or "") or #(s or "")
end
local function request(prompt, maxTokens)
  local address = component.list("internet")()
  assert(address, "Internet Card not found")
  local card = component.proxy(address)
  local data = json.encode({
    contents = {{parts = {{text = prompt}}}},
    generationConfig = {temperature = 0.85, maxOutputTokens = maxTokens or 8192}
  })
  local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model.text .. ":generateContent"
  local handle, why = card.request(url, data, {
    ["Content-Type"] = "application/json",
    ["x-goog-api-key"] = key.text
  }, "POST")
  assert(handle, "HTTP request failed: " .. tostring(why))
  local parts, size = {}, 0
  while true do
    local chunk, reason = handle.read(8192)
    if not chunk then
      handle.close()
      assert(not reason, tostring(reason))
      break
    end
    size = size + #chunk
    assert(size < 400000, "Response too large")
    parts[#parts+1] = chunk
  end
  local result = json.decode(table.concat(parts))
  if result.error then error((result.error.message or "API error"):sub(1, 160)) end
  local candidate = result.candidates and result.candidates[1]
  assert(candidate and candidate.content and candidate.content.parts, "Gemini returned no article")
  local items = {}
  for _, part in ipairs(candidate.content.parts) do
    if type(part.text) == "string" then items[#items+1] = part.text end
  end
  assert(#items > 0, "No text in model response")
  return table.concat(items)
end
local function saveArticle(article, complete)
  local folder = "/Users/Rist/Articles/"
  fs.makeDirectory(folder)
  for i = 1, 999 do
    local path = folder .. string.format("article_%03d.txt", i)
    if not fs.exists(path) then
      local text = title.text .. "\n\n" .. article
      local ok, reason = fs.write(path, text)
      assert(ok, tostring(reason))
      return path
    end
  end
  error("Articles folder is full")
end
local function runGenerate()
  if busy then return end
  if title.text == "" or model.text == "" or key.text == "" then
    GUI.alert("Enter a title, model, and API key")
    return
  end
  busy = true
  local success, result = pcall(function()
    status("Generating original article...")
    local article = request(table.concat({
      "Write an original, realistic Russian social/family story for readers aged 55+.",
      "Title: " .. title.text,
      "Write a COMPLETE standalone story, aiming for 10,000 to 12,000 Unicode characters, including headings.",
      "Use descriptive scenes, natural dialogue on separate lines with em dashes, paragraphs of 2-5 sentences.",
      "Use a few meaningful Markdown headings (###). No outline, no comments about writing.",
      "Maintain a consistent plot and end the story with a satisfying resolution. Output only the finished article."
    }, "\n"), 8192)
    if length(article) < 10000 then
      status("Article short; asking Gemini to expand...")
      local expanded = request("Expand the following original story to 10,000-12,000 Unicode characters in Russian. Keep the SAME plot, characters and ending. Keep headings and dialogues. Return the entire improved story only.\n\n" .. article, 8192)
      if length(expanded) > length(article) then article = expanded end
    end
    local path = saveArticle(article, length(article) >= 10000 and length(article) <= 12000)
    return {path = path, count = length(article)}
  end)
  busy = false
  if success then
    status("Saved: " .. result.path .. "  | " .. result.count .. " chars")
    GUI.alert("Saved: " .. result.path .. "\nCharacters: " .. result.count .. (result.count >= 10000 and result.count <= 12000 and " (in range)" or " (outside target range)"))
  else
    status("Generation failed; no article saved")
    GUI.alert("Gemini error: " .. tostring(result):sub(1, 190))
  end
end
window:addChild(GUI.button(3, 16, 36, 3, 0x235E57, C, 0x2B8976, C, "Generate and save article")).onTouch = runGenerate
window:addChild(GUI.button(44, 16, 41, 3, 0x2A455B, C, 0x39779D, C, "Test API")).onTouch = function()
  if busy then return end
  if key.text == "" or model.text == "" then GUI.alert("Enter API key and model"); return end
  busy = true
  status("Testing API connection...")
  local ok, reason = pcall(function() return request("Reply with one word: OK", 16) end)
  busy = false
  status(ok and "API connection OK" or "API request failed")
  GUI.alert(ok and "Gemini API connected" or ("Gemini error: " .. tostring(reason):sub(1, 190)))
end
window.onResize = function(w, h)
  window.backgroundPanel.width, window.backgroundPanel.height = w, h
end
workspace:draw()
