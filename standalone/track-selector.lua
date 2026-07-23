local utils = require 'mp.utils'

-- track selection keywords (case insensitive)
local SUB_KEYWORDS = { "english", "eng", "en" }
local AUD_KEYWORDS = { "japanese", "jpn", "jp" }
local SUB_REFINE_KEYWORDS = { "honorifics" }

-- sub-directory discovery keywords (case sensitive except for Windows)
local SIBLING_FOLDERS = { "ENG", "EN", "english", "English", "ESP", "ES", "spanish" }

local function set_dir_discovery()
  local path = mp.get_property("path")
  if not path or path:find("^%a+://") then return end -- Skip URLs/Streams

  -- get the directory containing the video file
  local video_dir, _ = utils.split_path(path)
  if not video_dir or video_dir == "" then return end

  local paths_to_add = {}

  -- scan for folders inside the video's directory
  for _, sibling_name in ipairs(SIBLING_FOLDERS) do
    -- target path is directly inside video_dir (e.g., /path/to/video/eng/)
    local target_path = utils.join_path(video_dir, sibling_name)

    -- verify it actually exists and is readable
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

local function select_track(resource, keywords_1st, keywords_2nd)
  local track_list = mp.get_property_native("track-list")
  if not track_list then return end

  local primary_matches = {}

  -- multi-selection of resources based on primary keys
  for _, track in ipairs(track_list) do
    if track.type == resource.type then
      local lang = (track.lang or ""):lower()
      local title = (track.title or ""):lower()
      mp.msg.info("[" .. resource.type .. "] lang: " .. lang)

      local is_primary_match = false
      for _, kw in ipairs(keywords_1st) do
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

  -- greedy refinement of resource based on secondary keys
  for _, track in ipairs(primary_matches) do
    local title = (track.title or ""):lower()

    if track.type == resource.type then
      for _, sec_kw in ipairs(keywords_2nd) do
        if title:find("%f[%w]" .. sec_kw .. "%f[%W]") then
          mp.set_property_number(resource.res, track.id)
          mp.msg.info("Refined selection: " .. (track.title or "Untitled"))
          return
        end
      end
    end
  end

  mp.set_property_number(resource.res, primary_matches[1].id)
  mp.msg.info("Primary selection: " .. (primary_matches[1].title or "Untitled"))
end

local function select_audio_n_subs()
  select_track({ type = "sub", res = "sid" }, SUB_KEYWORDS, SUB_REFINE_KEYWORDS)
  select_track({ type = "audio", res = "aid" }, AUD_KEYWORDS, {})
end

-- Hook into mpv events
-- File loaded event triggers right before track layout selection
mp.add_hook("on_load", 50, set_dir_discovery)
-- Observe track changes to select the best track once loaded
mp.register_event("file-loaded", select_audio_n_subs)
