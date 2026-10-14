local utils = require 'mp.utils'

-- track selection keywords (case insensitive)
local SUB_KEYWORDS = { "english", "eng", "en" }
local AUD_KEYWORDS = { "japanese", "jpn", "jp", "ja" }
local SUB_REFINE_KEYWORDS = { "honorifics" }

local DISCOVERY_DEPTH = 3
local SUB_EXTENSIONS = {
  "utf",
  "utf8",
  "utf-8",
  "idx",
  "sub",
  "srt",
  "rt",
  "ssa",
  "ass",
  "mks",
  "vtt",
  "sup",
  "scc",
  "smi",
  "lrc",
  "pgs",
}
local AUD_EXTENSIONS = {
  "aac",
  "ac3",
  "aif",
  "aiff",
  "alac",
  "ape",
  "dts",
  "dff",
  "dsf",
  "eac3",
  "ec3",
  "flac",
  "m4a",
  "m4b",
  "mka",
  "mogg",
  "mp2",
  "mp3",
  "mpc",
  "m4p",
  "oga",
  "ogg",
  "opus",
  "ra",
  "rm",
  "spx",
  "tak",
  "tta",
  "truehd",
  "thd",
  "wav",
  "w64",
  "wma",
  "wv",
}

local function recursive_path_discovery(root, depth, max_depth, paths)
  if depth >= max_depth then
    return
  end

  local sub_dirs = utils.readdir(root, "dirs")
  local root_files = utils.readdir(root, "files")
  local has_sub_res = false
  local has_aud_res = false

  for _, dir in ipairs(sub_dirs) do
    dir = utils.join_path(root, dir)
    recursive_path_discovery(dir, depth + 1, max_depth, paths)
  end

  if depth == 0 then
    return
  end

  for _, dir in ipairs(root_files) do
    dir = utils.join_path(root, dir)
    for _, kw in ipairs(SUB_EXTENSIONS) do
      if dir:lower():find("." .. kw .. "$") then
        has_sub_res = true
      end
    end
    for _, kw in ipairs(AUD_EXTENSIONS) do
      if dir:lower():find("." .. kw .. "$") then
        has_aud_res = true
      end
    end
  end

  if has_sub_res then
    table.insert(paths.subs, root)
  end
  if has_aud_res then
    table.insert(paths.audios, root)
  end
end

local function add_paths_to_src(key, paths)
  if #paths > 0 then
    local current_paths = mp.get_property_native(key) or {}
    for _, p in ipairs(paths) do
      table.insert(current_paths, p)
    end
    mp.set_property_native(key, current_paths)
  end
end

local function auto_src_discovery(max_depth)
  if max_depth < 1 then
    max_depth = 0
  end

  local path = mp.get_property("path")
  -- skip URLs/streams
  if not path or path:find("^%a+://") then return end

  -- splits path and filename
  local cwd, _ = utils.split_path(path)
  if not cwd or cwd == "" then return end

  local paths = { subs = {}, audios = {} }
  recursive_path_discovery(cwd, 0, max_depth, paths)

  add_paths_to_src("sub-file-paths", paths.subs)
  add_paths_to_src("audio-file-paths", paths.audios)
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

local function discover_resources()
  auto_src_discovery(DISCOVERY_DEPTH)
end

local function select_audio_n_subs()
  select_track({ type = "sub", res = "sid" }, SUB_KEYWORDS, SUB_REFINE_KEYWORDS)
  select_track({ type = "audio", res = "aid" }, AUD_KEYWORDS, {})
end

mp.add_hook("on_load", 50, discover_resources)
mp.register_event("file-loaded", select_audio_n_subs)
