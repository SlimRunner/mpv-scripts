local utils = require 'mp.utils'

-- track selection keywords (case insensitive)
local SUB_KEYWORDS = { "english", "eng", "en" }
local AUD_KEYWORDS = { "japanese", "jpn", "jp" }
local SUB_REFINE_KEYWORDS = { "honorifics" }

-- sub-directory discovery keywords (case insensitive)
local SUBDIR_KEYWORDS = {
  "eng",
  "en",
  "english",
  "esp",
  "es",
  "spanish",
  "jpn",
  "jp",
  "japanese"
}

local function set_dir_discovery()
  local path = mp.get_property("path")
  -- skip URLs/streams
  if not path or path:find("^%a+://") then return end

  -- splits path and filename
  local video_dir, _ = utils.split_path(path)
  if not video_dir or video_dir == "" then return end

  local paths_to_add = {}

  sub_dirs = utils.readdir(video_dir)

  -- the reason for this pattern is to allow the keywords to be case-less
  for _, dir in ipairs(sub_dirs) do
    for _, kw in ipairs(SUBDIR_KEYWORDS) do
      if kw:lower() == dir:lower() then
        table.insert(paths_to_add, dir)
        break
      end
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

  local pri_dict = {}

  -- multi-selection of resources based on primary keys
  for _, track in ipairs(track_list) do
    if track.type == resource.type then
      local lang = (track.lang or ""):lower()
      local title = (track.title or ""):lower()
      local pri = 0

      if track.default then
        pri = pri + 1
      end

      for _, kw in ipairs(keywords_1st) do
        if lang == kw or title:find("%f[%w]" .. kw .. "%f[%W]") then
          pri = pri + 2
          break
        end
      end

      if pri > 0 then
        table.insert(pri_dict, { pri = pri, track = track })
      end
    end
  end

  if #pri_dict == 0 then return end

  for _, entry in ipairs(pri_dict) do
    local curr_title = entry.track.title
    for _, sec_kw in ipairs(keywords_2nd) do
      if curr_title and curr_title:lower():find("%f[%w]" .. sec_kw .. "%f[%W]") then
        entry.pri = entry.pri + 5
      end
    end
  end

  table.sort(pri_dict, function(e1, e2) return e1.pri > e2.pri end)

  local pick = pri_dict[1]
  mp.msg.info(
    "picked " .. resource.type .. " with priority " ..
    pick.pri .. " (" .. (pick.track.title or "Untitled") .. ")"
  )
  mp.set_property_number(resource.res, pick.track.id)
end

local function select_audio_n_subs()
  select_track({ type = "sub", res = "sid" }, SUB_KEYWORDS, SUB_REFINE_KEYWORDS)
  select_track({ type = "audio", res = "aid" }, AUD_KEYWORDS, {})
end

mp.add_hook("on_load", 50, set_dir_discovery)
mp.register_event("file-loaded", select_audio_n_subs)
