--[[############################################

  Daze Before Christmas (SNES) Level Data Reader

--############################################]]

-- #####################################################################################################
-- INITIAL STATEMENTS:

-- Basic definitions
local fmt = string.format
local floor = math.floor
local ceil = math.ceil

-- Rname memory read/write functions
local u8 =  mainmemory.read_u8
local s8 =  mainmemory.read_s8
local w8 =  mainmemory.write_u8
local u16 = mainmemory.read_u16_le
local s16 = mainmemory.read_s16_le
local w16 = mainmemory.write_u16_le
local u24 = mainmemory.read_u24_le
local s24 = mainmemory.read_s24_le
local w24 = mainmemory.write_u24_le

-- Memory addresses used
local WRAM = {
  level_width = 0x0418, -- 2 bytes
  level_height = 0x041A, -- 2 bytes
  camera_x = 0x0422, -- 2 bytes
  camera_y = 0x0424, -- 2 bytes
  level_id = 0x1E6E, -- 2 bytes
  metatile_data = 0x15000,
}

-- #####################################################################################################
-- MAIN:

-- Read main level variables
local Level_id, Level_width, Level_height
local Level_width_tiles, Level_height_tiles, Tiles_total
local Level_width_metatiles, Level_height_metatiles, Metatiles_total
local function get_level()
  -- Read main values
  Level_id = u16(WRAM.level_id)
  Level_width = u16(WRAM.level_width)
  Level_height = u16(WRAM.level_height)
  
  -- Hardcoded fix for level $15, because its height is "wrong"
  if Level_id == 0x15 then Level_height = 0x04C0 end
  
  -- Calculate derived dimensions
  Level_width_tiles = Level_width/0x10
  Level_height_tiles = Level_height/0x10
  Tiles_total = Level_width_tiles*Level_height_tiles
  Level_width_metatiles = Level_width_tiles/4
  Level_height_metatiles = Level_height_tiles/4
  Metatiles_total = Level_width_metatiles*Level_height_metatiles
end


-- Tool to force the camera inside a region that is better for screenshoting the Graphics Debugger
local Camera_lock_on = false
local Camera_manipulate_on = false
local Camera_x_manip, Camera_y_manip = u16(WRAM.camera_x), u16(WRAM.camera_y)
local function force_camera()
  if not Camera_lock_on then return end
  
  local camera_x = u16(WRAM.camera_x)
  local camera_y = u16(WRAM.camera_y) 
  
  if Camera_manipulate_on then
    w16(WRAM.camera_x, Camera_x_manip)
    w16(WRAM.camera_y, Camera_y_manip)
  else
    if camera_x > 0x00F7 then w16(WRAM.camera_x, 0x00F7) end --; w16(0x04AD, 0x00FF) ; w16(0x044A, 0x00FF) ; w16(0x04B1, 0x00FF) end
    if camera_y > 0x0115 then w16(WRAM.camera_y, 0x0115) end --; w16(0x04AF, 0x011F) ; w16(0x044C, 0x011F) end
  end
end


-- Reading thru the whole BG1 metatile data to fill the metatable with tile IDs as keys and the count of occurrence as values
local Metatiles_used = {} -- to store occurrences of each metatile, to later organize in unique ones table
local Level_layout = {} -- to get the level map per se
local Metatiles_unique = {} -- to get unique metatiles
local Metatile_pages = 0 -- to keep track how many metatiles pages the current level has (conserindo each page to be 64 metatiles)
local Level_scanned
local function read_level_data()
  print(fmt("\n%s\nScanning level $%02X BG1 metatile data...", string.rep("#", 50), Level_id))
  
  -- Loop the entire level to register metatiles used in it
  local metatile_id
  Metatiles_used = {}
  Level_layout = {}
  local level_layout_str = "layout = {"
  for i = 0, Metatiles_total - 1 do
    
    metatile_id = u16(WRAM.metatile_data + 2*i)
    
    if Metatiles_used[metatile_id] == nil then -- to start a occurrence
      Metatiles_used[metatile_id] = 1
    else -- to increment a occurrence
      Metatiles_used[metatile_id] = Metatiles_used[metatile_id] + 1
    end
    
    Level_layout[i] = metatile_id
    level_layout_str = level_layout_str .. fmt("0x%04X, ", metatile_id)
  end
  level_layout_str = level_layout_str .. "},"

  print(fmt("Last metatile address in WRAM: $%06X.", WRAM.metatile_data + 2*(Metatiles_total-1)))
  
  -- Loop to create the table with unique metatile IDs accordingly
  Metatiles_unique = {}
  for k, v in pairs(Metatiles_used) do
    table.insert(Metatiles_unique, k)
  end
  table.sort(Metatiles_unique)

  -- Calculate metatile pages
  Metatile_pages = ceil(#Metatiles_unique/64)
  
  print(fmt("Total unique metatiles: %d (%d pages).", #Metatiles_unique, Metatile_pages))
  
  -- Loop to format metatiles_unique_str
  local metatiles_unique_str = "metatiles = {"
  for i = 1, #Metatiles_unique do
    metatiles_unique_str = metatiles_unique_str .. fmt("0x%04X, ", Metatiles_unique[i])
  end
  metatiles_unique_str = metatiles_unique_str .. "},"
  
  -- Format level dimension string
  local dimension_str = fmt("width = 0x%04X, height = 0x%04X,", Level_width, Level_height)
  
  -- Dump info
  print(fmt("\n[0x%02X] = {%s\n  %s\n  %s},", Level_id, dimension_str, level_layout_str, metatiles_unique_str))
  
  -- Store which level was scanned, to later prevent writing metatile data from one level into another
  Level_scanned = Level_id
end


-- Write unique metatiles in the level in a order that helps screenshoting the Graphics Debugger (512x512 pixels, or 8x8 metatiles)
local function write_metatiles(page)
  
  -- Loop to wipe out the level
  local empty_table = {}
  for i = 0, Metatiles_total - 1 do
    w16(WRAM.metatile_data + 2*i, 0x0000) -- 0x0000 is only good for level $00, there should be a better empty id
  end
  
  -- Edit level dimensions to force it having 576x512 (512x512 + extra column the levels have)
  
  -- TODO
  
  -- Loop to write the unique metatiles into the map in a order that helps screenshoting the Graphics Debugger (max of 8 columns of matatiles)
  local index_in_level
  for i = 1, 64 do
    --               which column   account for level width                                         account for height limit, so will use more 8 columns (TODO: this last parcel is not needed anymore i guess)
    index_in_level = (i-1)%8      + Level_width_metatiles*(floor((i-1)/8)%Level_height_metatiles) + 8*floor((i-1)/(8*Level_height_metatiles)) -- add values to i to shift the writing area, necessary for the autoscrolling levels (most of them +80 do the job)
    
    if Metatiles_unique[i + page*64] then -- to avoid nil indexing when a page is not completely full
      w16(WRAM.metatile_data + 2*index_in_level, Metatiles_unique[i + page*64])
    end
  end
  
  print(fmt("\nDone writing page %d.", page))
  
  -- Print name of the image file to use
  print(fmt("\nLevel $%02X %02d", Level_id, page))
  
  -- Print warning if level original height is smaller than 8 metatiles
  if Level_height_metatiles < 8 then
    print(fmt("WARNING! LEVEL HEIGHT IS JUST %d METATILES!", Level_height_metatiles))
  end

end


-- Forms for the commands
local Commands_form = {}
function Commands_form.create_window()

  -- Create form
  local form_width, form_height = 300, 150
  Commands_form.form = forms.newform(form_width, form_height, "Level Data Reader")
  
  local xform, yform, delta_x, delta_y = 4, 10, 120, 20
  
  -- Button to scan the level data
  Commands_form.scan_level = forms.button(Commands_form.form, "Scan level", function()
    -- Call to the read level data function
    read_level_data()
    -- Update the metatile page option
    local page_table = {}
    for i = 1, Metatile_pages do
      page_table[i] = tostring(i-1)
    end
    forms.setdropdownitems(Commands_form.page_value, page_table)
  end, xform, yform, 80, 24)
  
  -- Metatile page option
  xform = xform + forms.getproperty(Commands_form.scan_level, "Width") + 10
  Commands_form.page_label = forms.label(Commands_form.form, "Page", xform, yform + 4)
  forms.setproperty(Commands_form.page_label, "AutoSize", true)
  xform = xform + forms.getproperty(Commands_form.page_label, "Width") + 4
  Commands_form.page_value = forms.dropdown(Commands_form.form, {"0"}, xform, yform + 1, 40, 20)
  --forms.dropdown(int formhandle, nluatable items, [int? x = null], [int? y = null], [int? width = null], [int? height = null])
  
  -- Button to write metatiles in WRAM
  xform = xform + forms.getproperty(Commands_form.page_value, "Width") + 10
  Commands_form.write_tiles = forms.button(Commands_form.form, "Write metatiles", function()
    
    -- Failsafes
    if #Metatiles_unique == 0 then -- empty, data was not scanned yet
      print("\nPress \"Scan level\" first!")
      return
    end
    if Level_scanned ~= Level_id then -- last level scanned is different from current, to prevent writing metatile data from one level into another
      print("\nPress \"Scan level\" for this level!")
      return
    end
    
    -- Call write metatiles
    local page = tonumber(forms.gettext(Commands_form.page_value))
    write_metatiles(page)
  end, xform - 1, yform, 80, 24)
  forms.setproperty(Commands_form.write_tiles, "AutoSize", true)
  
  -- Camera lock option
  xform, yform = 5, yform + 1.5*delta_y
  Commands_form.camera_lock = forms.checkbox(Commands_form.form, "Camera lock", xform, yform)
  forms.setproperty(Commands_form.camera_lock, "Checked", Camera_lock_on)
  
  -- Camera manipulate option
  yform = yform + delta_y
  Commands_form.camera_manipulate = forms.checkbox(Commands_form.form, "Camera manip", xform, yform)
  forms.setproperty(Commands_form.camera_manipulate, "Checked", Camera_manipulate_on)
  
  -- Manual camera manipulation
    -- Camera x
  xform, yform = xform + delta_x, yform - delta_y
  forms.label(Commands_form.form, "Camera x", xform, yform, 70, 20)
  yform = yform + delta_y
  
      -- decrease
  forms.button(Commands_form.form, "-", function()
    --if u16(WRAM.camera_x) < 0x08 then w16(WRAM.camera_x, 0) else w16(WRAM.camera_x, u16(WRAM.camera_x) - 0x08) end
    if Camera_x_manip < 0x08 then Camera_x_manip = 0 else Camera_x_manip = Camera_x_manip - 0x08 end
  end, xform, yform, 24, 24)
  xform = xform + 24
  
      -- increase
  forms.button(Commands_form.form, "+", function()
    --if u16(WRAM.camera_x) >= 0xFFF8 then w16(WRAM.camera_x, 0xFFFF) else w16(WRAM.camera_x, u16(WRAM.camera_x) + 0x08) end
    if Camera_x_manip >= 0xFFF8 then Camera_x_manip = 0xFFFF else Camera_x_manip = Camera_x_manip + 0x08 end
  end, xform, yform, 24, 24)
  
    -- Camera y
  xform, yform = xform + 50, yform - delta_y
  forms.label(Commands_form.form, "Camera y", xform, yform, 70, 20)
  yform = yform + delta_y
  
      --decrease
  forms.button(Commands_form.form, "-", function()
    --if u16(WRAM.camera_y) < 0x08 then w16(WRAM.camera_y, 0) else w16(WRAM.camera_y, u16(WRAM.camera_y) - 0x08) end
    if Camera_y_manip < 0x08 then Camera_y_manip = 0 else Camera_y_manip = Camera_y_manip - 0x08 end
  end, xform, yform, 24, 24)
  
      -- increase
  xform = xform + 24
  forms.button(Commands_form.form, "+", function()
    --if u16(WRAM.camera_y) >= 0xFFF8 then w16(WRAM.camera_y, 0xFFFF) else w16(WRAM.camera_y, u16(WRAM.camera_y) + 0x08) end
    if Camera_y_manip >= 0xFFF8 then Camera_y_manip = 0xFFFF else Camera_y_manip = Camera_y_manip + 0x08 end
  end, xform, yform, 24, 24)
end
Commands_form.create_window()


-- Update options based on the form
function Commands_form.evaluate_form()
  Camera_lock_on = forms.ischecked(Commands_form.camera_lock) or false
  Camera_manipulate_on = forms.ischecked(Commands_form.camera_manipulate) or false
end


-- Forces all forms to close when script is stopped or reset
event.onexit(function()
  forms.destroy(Commands_form.form)
end)


-- Main loop
while true do
  get_level()
  
  Commands_form.is_form_closed = forms.gettext(Commands_form.form) == "" -- way to sure the form is not closed
  if not Commands_form.is_form_closed then Commands_form.evaluate_form() end
  
  force_camera()
  
  emu.frameadvance()
end






