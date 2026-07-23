local utils = require 'mp.utils'

-- CONFIGURATION
-- case insensitive
local SUB_KEYWORDS = { "english", "eng", "en" }
local AUD_KEYWORDS = { "japanese", "jpn", "jp" }
local SUB_REFINE_KEYWORDS = { "honorifics" }

-- case sensitive
local SIBLING_FOLDERS = { "ENG", "EN", "english", "English" }

-- 1. Scan Sibling Directories on File Load
local function discover_sibling_subs()
  local path = mp.get_property("path")
  if not path or path:find("^%a+://") then return end -- Skip URLs/Streams

  -- Get the directory containing the video file
  local video_dir, _ = utils.split_path(path)
  if not video_dir or video_dir == "" then return end

  local paths_to_add = {}

  -- Scan for folders inside the video's directory
  for _, sibling_name in ipairs(SIBLING_FOLDERS) do
    -- Target path is directly inside video_dir (e.g., /path/to/video/eng/)
    local target_path = utils.join_path(video_dir, sibling_name)

    -- Verify it actually exists and is readable
    local info = utils.readdir(target_path)
    if info then
      table.insert(paths_to_add, sibling_name)
    end
  end

  if #paths_to_add > 0 then
    local current_paths = mp.get_property_native("sub-file-paths") or {}
    for _, p in ipairs(paths_to_add) do
      table.insert(current_paths, p)
      mp.msg.info("Added relative path: " .. p)
    end
    mp.set_property_native("sub-file-paths", current_paths)
  end
end

-- 2. Smart Track Selection Logic
local function select_audio_n_subs()
  local track_list = mp.get_property_native("track-list")
  if not track_list then return end

  local primary_matches = {}

  -- Step A: Find all tracks matching primary language keywords
  for _, track in ipairs(track_list) do
    if track.type == "sub" then
      local lang = (track.lang or ""):lower()
      local title = (track.title or ""):lower()

      local is_primary_match = false
      for _, kw in ipairs(SUB_KEYWORDS) do
        -- matches only full words
        if lang == kw or title:find("%f[%w]" .. kw .. "%f[%W]") then
          is_primary_match = true
          break
        end
      end

      if is_primary_match then
        table.insert(primary_matches, track)
      end
    end

    if track.type == "audio" then
      local lang = (track.lang or ""):lower()
      local title = (track.title or ""):lower()

      local is_primary_match = false
      for _, kw in ipairs(AUD_KEYWORDS) do
        -- matches only full words
        if lang == kw or title:find("%f[%w]" .. kw .. "%f[%W]") then
          is_primary_match = true
          break
        end
      end

      if is_primary_match then
        table.insert(primary_matches, track)
      end
    end
  end

  if #primary_matches == 0 then return end

  -- Step B: Greedily search primary matches for secondary keywords
  for _, track in ipairs(primary_matches) do
    local title = (track.title or ""):lower()

    if track.type == "sub" then
      for _, sec_kw in ipairs(SUB_REFINE_KEYWORDS) do
        -- matches only full words
        if title:find("%f[%w]" .. sec_kw .. "%f[%W]") then
          -- Found an anime-specific track, select it immediately
          mp.set_property_number("sid", track.id)
          mp.msg.info("Selected secondary match: " .. (track.title or "Untitled"))
          return
        end
      end
    end
  end

  -- Step C: Fallback to the first primary language match if no secondary matches
  mp.set_property_number("sid", primary_matches[1].id)
  mp.msg.info("Selected primary fallback: " .. (primary_matches[1].title or "Untitled"))
end

-- Hook into mpv events
-- File loaded event triggers right before track layout selection
mp.add_hook("on_load", 50, discover_sibling_subs)
-- Observe track changes to select the best track once loaded
mp.register_event("file-loaded", select_audio_n_subs)
