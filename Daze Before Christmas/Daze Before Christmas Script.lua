--####################################################################
--##                                                                ## 
--##   Daze Before Christmas Utility Script for BizHawk             ## 
--##   http://tasvideos.org/Bizhawk.html                            ## 
--##                                                                ## 
--##   Author: Bruno Valadão Cunha  (BrunoValads)                   ##
--##                                                                ## 
--##   Git repository: https://github.com/brunovalads/tas-scripts   ## 
--##                                                                ## 
--####################################################################


-- ##################################################################################################################################################################################################################
-- CONFIG

-- Main script options
local OPTIONS = {
  -- Display flags
  display_general_info = true,
  display_movie_info = true,
  display_level_info = true,
  display_player_info = true,
  display_player_hitbox = true,
  display_interaction_points = true,
  display_sprite_info = true,
  display_sprite_table = true,
  display_sprite_info_near = true,
  display_sprite_on_map = true,
  display_level_map = true,
  display_mouse_coordinates = false,
  display_tilemap_info = false,
  
  -- Emu borders (min. size = 16)
  left_gap = 155, -- SHOULD NEVER BE ZERO BECAUSE OF SCREEN SIZES CALCULATIONS
  right_gap = 270,
  top_gap = 30, -- SHOULD NEVER BE ZERO BECAUSE OF SCREEN SIZES CALCULATIONS
  bottom_gap = 150,
  
  -- Other positions and variables
  map_x_offset = 2, -- OPTIONS.map_x is set according to Santa's x position, inside the main loop
  map_y_offset = 16, -- OPTIONS.map_y needs to be set after Border_bottom_start is calculated (it's done in the main loop)
  map_scale = 16, -- used as 1/scale
  
  -- External file paths
  map_images = ".\\Level maps\\Maps\\",
}

-- Colours used by the script
local COLOUR = {
  -- General text
  default_text_opacity = 1.0,
  default_bg_opacity = 0.7,
  text = 0xffffffff, -- white
  background = 0xff000000, -- black
  halo = 0xff000040,
  positive = 0xff00FF00, -- green
  warning = 0xffFF0000, -- red
  warning_bg = 0xff000000,
  warning2 = 0xffFF00FF, -- purple
  warning_soft = 0xffFFA500, -- orange
  warning_transparent = 0x80FF0000, -- red (transparent)
  weak = 0xa0A9A9A9, -- gray (transparent)
  weak2 = 0xff555555, -- gray
  very_weak = 0x60A9A9A9, -- gray (transparent)
  very_weak2 = 0x20A9A9A9, -- gray (transparent)
  disabled = 0xff808080, -- gray
  memory = 0xff00FFFF, -- cyan
  joystick_input = 0xffFFFF00,
  joystick_input_bg = 0x30FFFFFF,
  button_text = 0xff300030,
  mainmenu_outline = 0xc0FFFFFF,
  mainmenu_bg = 0xc0000000,

  -- Counters
  counter_transform = 0xffA5A5A5,
  counter_invincibility = 0xffF8D870,

  -- Hitbox and related text
  santa = 0xffFF0000,
  santa_bg = 0x80FF0000,
  interaction = 0xffFFFFFF,
  interaction_bg = 0x20000000,
  interaction_nohitbox = 0xa0000000,
  interaction_nohitbox_bg = 0x70000000,
  detection_bg = 0x30400020,

  -- Sprites
  sprites = { -- Colorcet C2 palette (colourblind friendly)
    0xffEF55F1,
    0xffFBC981,
    0xffB8DF14,
    0xff31AC28,
    0xff2E5DB8,
    0xff722BF7,
  },
  sprites_bg = 0x8000b050,
  star = 0xffFFB56B,
  
  -- Misc
  block = 0x7000008B,
  blank_tile = 0x70FFFFFF,
}

-- Font settings
local BIZHAWK_FONT_WIDTH = 10  -- correction to the scale is done in bizhawk_screen_info()
local BIZHAWK_FONT_HEIGHT = 18



-- ##################################################################################################################################################################################################################
-- INITIAL STATEMENTS:

console.clear()

-- Check if is running in BizHawk
if tastudio == nil then
  error("\n\nThis script only works with BizHawk!")
end

-- Check if it's the correct game
local function get_game_name()
  local game_name_data = memory.readbyterange(0x7FC0, 21, "CARTROM")
  local game_name_str, game_name_hex_str = "", ""
  for i = 0, 21-1 do
    game_name_str = game_name_str .. string.char(game_name_data[i])
    game_name_hex_str = game_name_hex_str .. string.format("%02X", game_name_data[i])
  end
  return game_name_str, game_name_hex_str
end

if get_game_name() ~= "DAZE BEFORE CHRISTMAS" then
  error("\n\nThis script is for Daze Before Christmas only!")
end

print("Starting Daze Before Christmas script\n")

-- Basic functions renaming
local fmt = string.format
local floor = math.floor
local ceil = math.ceil
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local pi = math.pi
math.round = function(number, dec_places)
  local mult = 10^(dec_places or 0)
  return math.floor(number * mult + 0.5) / mult
end

-- Rename gui functions
local draw_line = gui.drawLine
local draw_box = gui.drawBox
local draw_rectangle = gui.drawRectangle
local draw_image = gui.drawImage
local draw_image_region = gui.drawImageRegion --gui.drawImageRegion(path, source_x, source_y, source_width, source_height, dest_x, dest_y, [? dest_width], [? dest_height])
local draw_cross = gui.drawAxis
local draw_pixel = gui.drawPixel
local draw_pixel_text = gui.pixelText

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

-- Drawing constants
local Text_opacity = 1
local Bg_opacity = 1

-- ##################################################################################################################################################################################################################
-- GAME AND SNES SPECIFIC PARAMETERS:

local WRAM = {  -- 7E0000~7FFFFF
  -- I/O
  ctrl_1_1 = 0x04CA, -- TODO: check player 2, because there's more addresses for these
  ctrl_1_2 = 0x04C9,
  ctrl_1_1_first = 0x04CC,
  ctrl_1_2_first = 0x04CB,

  -- General
  game_mode = 0x0035, -- 1 byte (defintely not game mode, but serves the purpose of this script)
  --rng = 0x, -- 2 bytes -- TODO: figure out
  can_jump_flag = 0x0199,
  level_width = 0x0418, -- 2 bytes
  level_height = 0x041A, -- 2 bytes
  camera_x = 0x0422, -- 2 bytes
  camera_y = 0x0424, -- 2 bytes
  frame_counter = 0x0484, -- 2 bytes
  magic_flag = 0x1C15,
  fire_magic_flag = 0x1C17,
  evil_santa_flag = 0x1C19,
  evil_santa_timer = 0x1D44, -- 2 bytes
  blue_gift_boxes = 0x1E60, -- 2 bytes
  red_gift_boxes = 0x1E62, -- 2 bytes
  golden_gift_boxes = 0x1E64, -- 2 bytes
  lives = 0x1E68, -- 2 bytes
  score = 0x1E6A, -- 4 bytes
  level_id = 0x1E6E, -- 2 bytes
  sublevel_id = 0x1E70, -- 2 bytes
  get_ready_timer = 0x1EBC, -- 2 bytes
  score_screen_done = 0x1F2E, -- 2 bytes
  metatile_data = 0x15000, -- size varies per level
  
  -- Player
  player_flags = 0x06D8, -- 1 bytes
  player_status_pointer = 0x06D1, -- 3 bytes
  x_subspeed = 0x06E1, -- 2 bytes
  x_speed = 0x06E3, -- 2 bytes
  y_subspeed = 0x06E5, -- 2 bytes
  y_speed = 0x06E7, -- 2 bytes
  x_subpos = 0x06E9, -- 2 bytes
  x_pos = 0x06EB, -- 2 bytes
  y_subpos = 0x06ED, -- 2 bytes
  y_pos = 0x06EF, -- 2 bytes
  hats = 0x06F9, -- 1 byte
  invincibility_timer = 0x06FA, -- 1 byte
  player_status_id = 0x0701, -- 1 byte

  
  -- Sprites (each slot takes 0x3E(62) bytes)
  sprite_start = 0x0707,
  sprite_type = 0x070F, -- 3 bytes
  sprite_flags1 = 0x0715, -- 1 byte
  sprite_flags2 = 0x0716, -- 1 byte
  sprite_anim_frame = 0x071D, -- 2 bytes
  sprite_x_subspeed = 0x071F, -- 2 bytes
  sprite_x_speed = 0x0721, -- 2 bytes
  sprite_y_subspeed = 0x0723, -- 2 bytes
  sprite_y_speed = 0x0725, -- 2 bytes
  sprite_x_subpos = 0x0727, -- 2 bytes
  sprite_x_pos = 0x0729, -- 2 bytes
  sprite_y_subpos = 0x072B, -- 2 bytes
  sprite_y_pos = 0x072D, -- 2 bytes
  sprite_invincibility_timer = 0x0735, -- 2 bytes
  sprite_hp = 0x0737, -- 1 byte
  sprite_damage_flashing_timer = 0x0738, -- 1 byte
  
}

-- Game specific constants
local DAZE = {
  game_mode_level = 0x04,
  sprite_max = 64,
  
}

-- Sprite info
DAZE.sprites = {
  [0x000000] = {name = "SPECIAL COMMANDS"},
  [0x848034] = {name =  "???"}, -- appears in Santa's House, in the upper part
  [0x8480C2] = {name =  "Rolling barrel"},
  [0x84854D] = {name =  "Mouse (walking)"},
  [0x848AD4] = {name =  "Mouse (attacking)"},
  [0x848E0B] = {name =  "Toothy beast"},
  [0x849637] = {name =  "Car toy"},
  [0x849A80] = {name =  "Cloud platform"},
  [0x849DF7] = {name =  "Elf"},
  [0x84A326] = {name =  "Electric mouse"},
  [0x84AA55] = {name =  "Steel elevator"},
  [0x84AB39] = {name =  "Fireplace"},
  [0x84B504] = {name =  "Ghost mouse"},
  [0x84B6EC] = {name =  "Punching hatstand"},
  [0x84BF90] = {name =  "Floating heart platform"},
  [0x84C13E] = {name =  "Jumping box"},
  [0x84CC5B] = {name =  "Jack-in-a-Box"},
  [0x84D578] = {name =  "Jumping rock"},
  [0x84DE23] = {name =  "Owl"},
  [0x84E0D1] = {name =  "Penguin (walking)"},
  [0x84E5E0] = {name =  "Penguin (attacking)"},
  [0x84E88B] = {name =  "Airplane toy"},
  [0x84EDC2] = {name =  "Red gift (with Extra Santa hat?)"},
  [0x84F391] = {name =  "Blue gift"},
  [0x84F960] = {name =  "Clock pendulum"},
  [0x84F9DC] = {name =  "Floating woodden platform"},
  [0x858000] = {name =  "Retracting woodden platform"},
  [0x8581FF] = {name =  "Ice platform"},
  [0x858445] = {name =  "Swimming mouse (looking to the sides)"},
  [0x85867D] = {name =  "Swimming mouse (walking)"},
  [0x858B36] = {name =  "Swimming mouse (looking to the sides slow)"},
  [0x858E21] = {name =  "Gift box thrown"},
  [0x85916C] = {name =  "Reindeer"},
  [0x8594FC] = {name =  "Checkpoint bell"},
  [0x859794] = {name =  "Mechanic mouse (running)"},
  [0x859C93] = {name =  "Mechanic mouse (standing)"},
  [0x859D4F] = {name =  "Jumping fish"},
  [0x85A4C6] = {name =  "Chimney smoke"},
  [0x85A7AD] = {name =  "Snowman"},
  [0x85AD11] = {name =  "Snowman's head"},
  [0x85AD8B] = {name =  "Spider"},
  [0x85B494] = {name =  "Evil Snowman's snowball"},
  [0x85B712] = {name =  "Penguin's snowball"},
  [0x85B74E] = {name =  "Tank toy (standing)"},
  [0x85BC13] = {name =  "Tank toy (standing)"},
  [0x85C15C] = {name =  "Tank toy (moving)"},
  [0x85C6CD] = {name =  "Tank toy (shooting)"},
  [0x85CC36] = {name =  "Tank toy's bullet"},
  [0x85D2AC] = {name =  "Star"},
  [0x85D6E7] = {name =  "Ice stalactite"},
  [0x85D743] = {name =  "Kicking foot"},
  [0x85DAE5] = {name =  "Armchair"},
  [0x85E91F] = {name =  "Cup of coffee"},
  [0x868000] = {name =  "Reindeer pulling Santa's sleigh"},
  [0x8683AF] = {name =  "Santa in sleigh (normal)"},
  [0x8684D0] = {name =  "Santa in sleigh (throwing gift)"},
  [0x868794] = {name =  "Kite"},
  [0x868CD7] = {name =  "Football"},
  [0x86A53E] = {name =  "British hot air balloon"},
  [0x86A813] = {name =  "Mouse in rocket"},
  [0x86B045] = {name =  "Mouse with backpack helicopter"},
  [0x86B34B] = {name =  "Satellite"},
  [0x86BAA4] = {name =  "The Timekeeper's gear"},
  [0x86BB9C] = {name =  "Floating basket"},
  [0x86BCB0] = {name =  "Chain hook"},
  [0x86BDE4] = {name =  "Puff of smoke"},
  [0x86BFEE] = {name =  "Machine eyes"},
  [0x86C01C] = {name =  "Knitting ball"},
  [0x86CD73] = {name =  "Rollerblade"},
  [0x86CF18] = {name =  "Worm"},
  [0x86DE42] = {name =  "Transformation smoke"},
  [0x86E555] = {name =  "Fire magic"},
  [0x86E981] = {name =  "Magic"},
  [0x888000] = {name =  "Mr. Weather (normal)", show_hp = true}, -- #4 boss
  [0x8881D1] = {name =  "Mr. Weather (getting damage)", show_hp = true},
  [0x888386] = {name =  "Mr. Weather (dying)", show_hp = true},
  [0x888784] = {name =  "Mr. Weather's lightning bolt"},
  [0x888889] = {name =  "Mr. Weather's flash"},
  [0x8888FE] = {name =  "Cloud barrier flash"},
  [0x88896B] = {name =  "Lightning bolt final flash"},
  [0x888E8E] = {name =  "Cloud barrier"},
  [0x888FF3] = {name =  "The Timekeeper (normal)", show_hp = true}, -- #2 boss
  [0x8896D6] = {name =  "The Timekeeper (exploding)", show_hp = true},
  [0x889A21] = {name =  "Evil Snowman (standing)", show_hp = true}, -- #1 boss
  [0x889A3A] = {name =  "Evil Snowman (attacking)", show_hp = true},
  [0x889A5D] = {name =  "Evil Snowman (attacking)", show_hp = true},
  [0x88A0E0] = {name =  "Evil Snowman (damaged)", show_hp = true},
  [0x88A0FD] = {name =  "Evil Snowman (dead)", show_hp = true},
  [0x88A346] = {name =  "Louse The Mouse (attacking)", show_hp = true},
  [0x88B305] = {name =  "Louse The Mouse (squashed)", show_hp = true},
  [0x88BEC4] = {name =  "Louse The Mouse (standing)", show_hp = true}, -- #3 boss
  [0x88CBB3] = {name =  "Louse The Mouse (walking)", show_hp = true},
  [0x88DABA] = {name =  "Lever"},
  [0x88DB6B] = {name =  "Crane"},
  [0x88DC46] = {name =  "10ton weight ball"},
  [0x898000] = {name =  "Bomb"},
  [0x898874] = {name =  "Fire magic box"},
  [0x898961] = {name =  "Ice wall"},
  [0x898B26] = {name =  "Magic carpet"},
  [0x899063] = {name =  "Extra Santa hat"},
  [0x899224] = {name =  "Extra life"},
  [0x8993E6] = {name =  "Golden gift"},
  [0x899C45] = {name =  "Polar bear's sleeping 'Z's"},
  [0x899CE8] = {name =  "Punch contraption"},
  [0x89A102] = {name =  "Helicopter toy"},
  [0x89A501] = {name =  "Trapdoor"},
  [0x89A6DC] = {name =  "Fireplace door"},
}

local NTSC_FRAMERATE = 60.0988138974405
local PAL_FRAMERATE = 50.0069789081886

-- ##################################################################################################################################################################################################################
-- SCRIPT UTILITIES

-- Variables used in various functions
local Options_form = {}
local Cheat = {}  -- family of cheat functions and variables
local Previous = {}
local Is_lagged = nil
local Key_input = input.get()
local Joypad = joypad.get(1) -- currently only caring about player 1


-- Get screen dimensions of the game and emulator
local Screen_width, Screen_height, Buffer_width, Buffer_height, Buffer_middle_x, Buffer_middle_y, Border_right_start, Border_bottom_start, Scale_x, Scale_y
local function bizhawk_screen_info()
  if client.borderwidth() == 0 then -- to avoid division by zero bug when borders are not yet ready when loading the script
    Scale_x = 2
    Scale_y = 2
  elseif OPTIONS.left_gap > 0 and OPTIONS.top_gap > 0 then -- to make sure this method won't get div/0
    Scale_x = math.min(client.borderwidth()/OPTIONS.left_gap, client.borderheight()/OPTIONS.top_gap) -- Pixel scale
    Scale_y = Scale_x -- assumming square pixels only
  else
    Scale_x = client.getwindowsize()
    Scale_y = Scale_x -- assumming square pixels only
  end
  
  Screen_width = client.screenwidth()/Scale_x  -- Emu screen width CONVERTED to game pixels
  Screen_height = client.screenheight()/Scale_y  -- Emu screen height CONVERTED to game pixels
  Buffer_width = client.bufferwidth()  -- Game area width, in game pixels
  Buffer_height = client.bufferheight()  -- Game area height, in game pixels
  Buffer_middle_x = OPTIONS.left_gap + Buffer_width/2  -- Game area middle x relative to emu window, in game pixels
  Buffer_middle_y = OPTIONS.top_gap + Buffer_height/2  -- Game area middle y relative to emu window, in game pixels
  Border_right_start = OPTIONS.left_gap + Buffer_width
  Border_bottom_start = OPTIONS.top_gap + Buffer_height
  
  BIZHAWK_FONT_WIDTH = 10/Scale_x -- to make compatible to the scale
  BIZHAWK_FONT_HEIGHT = 18/Scale_y
  
  -- DEBUG
  --print(fmt("Scale: %f, %f", Scale_x, Scale_y))
  --print(fmt("client.getwindowsize(): %d", client.getwindowsize()))
  --print(fmt("Buffer width: %d, height: %d", Buffer_width, Buffer_height))
  --print(fmt("Screen (real) width: %d, height: %d", client.screenwidth(), client.screenheight()))
  
end


-- Get and store input from keyboard and console
local function input_update()
  -- Handle every previous update the script might use
  --Previous.z_pressed = Key_input.Z -- for the free movement cheat
  
  -- Update input from keyboard
  Key_input = input.get()
  
  -- Update console input
  Joypad = joypad.get(1)
end


-- Verify if a point is inside a rectangle with corners (x1, y1) and (x2, y2)
local function is_inside_rectangle(xpoint, ypoint, x1, y1, x2, y2)
  -- From top-left to bottom-right
  if x2 < x1 then
    x1, x2 = x2, x1
  end
  if y2 < y1 then
    y1, y2 = y2, y1
  end

  if xpoint >= x1 and xpoint <= x2 and ypoint >= y1 and ypoint <= y2 then
    return true
  else
    return false
  end
end


-- Get BizHawk status
local Movie_active, Readonly, Framecount, Lagcount, Rerecords
local Lastframe_emulated, Nextframe
local function bizhawk_status()
  Movie_active = movie.isloaded()  -- BizHawk
  Readonly = movie.getreadonly()  -- BizHawk
  if Movie_active then
    Framecount = movie.length()  -- BizHawk
    Rerecords = movie.getrerecordcount()  -- BizHawk
  end
  Lagcount = emu.lagcount()  -- BizHawk
  Is_lagged = emu.islagged()  -- BizHawk

  -- Last frame info
  Lastframe_emulated = emu.framecount()

  -- Next frame info (only relevant in readonly mode)
  Nextframe = Lastframe_emulated + 1
end


-- Changes transparency of a colour: result is opaque original * transparency level (0.0 to 1.0)
local function change_transparency(colour, transparency)
  -- Sane transparency
  if transparency >= 1 then return colour end  -- no transparency
  if transparency <= 0 then return 0 end   -- total transparency

  -- Sane colour
  if colour == 0 then return 0 end
  if type(colour) ~= "number" then
    print(colour)
    error"Wrong colour"
  end

  local a = floor(colour/0x1000000)
  local rgb = colour - a*0x1000000
  local new_a = floor(a*transparency)
  return new_a*0x1000000 + rgb
end


-- returns the (x, y) position to start the text and its length:
-- number, number, number text_position(x, y, text, font_width, font_height[[[[, always_on_client], always_on_game], ref_x], ref_y])
-- x, y: the coordinates that the refereed point of the text must have
-- text: a string, don't make it bigger than the buffer area width and don't include escape characters
-- font_width, font_height: the sizes of the font
-- always_on_client, always_on_game: boolean
-- ref_x and ref_y: refer to the relative point of the text that must occupy the origin (x,y), from 0% to 100%
--                  for instance, if you want to display the middle of the text in (x, y), then use 0.5, 0.5
local function text_position(x, y, text, font_width, font_height, always_on_client, always_on_game, ref_x, ref_y)
  -- Reads external variables
  local buffer_left     = OPTIONS.left_gap
  local buffer_right    = Border_right_start
  local buffer_top      = OPTIONS.top_gap
  local buffer_bottom   = Border_bottom_start
  local screen_left     = 0
  local screen_right    = Screen_width
  local screen_top      = 0
  local screen_bottom   = Screen_height
  
  -- text processing
  local text_length = text and string.len(text)*font_width or font_width  -- considering another objects, like bitmaps
  
  -- actual position, relative to game area origin
  x = (not ref_x and x) or (ref_x == 0 and x) or x - floor(text_length*ref_x)
  y = (not ref_y and y) or (ref_y == 0 and y) or y - floor(font_height*ref_y)
  
  -- adjustment needed if text is supposed to be on screen area
  local x_end = x + text_length
  local y_end = y + font_height
  
  if always_on_game then
    if x < buffer_left then x = buffer_left end
    if y < buffer_top then y = buffer_top end
    
    if x_end > buffer_right  then x = buffer_right  - text_length end
    if y_end > buffer_bottom then y = buffer_bottom - font_height end
    
  elseif always_on_client then
    if x < screen_left + 1 then x = screen_left + 1 end -- +1 to avoid printing touching the screen border
    if y < screen_top + 1 then y = screen_top + 1 end
    
    if x_end > screen_right - 1  then x = screen_right  - text_length - 1 end -- -1 to avoid printing touching the screen border
    if y_end > screen_bottom - 1 then y = screen_bottom - font_height - 1 end
  end
  
  return x, y, text_length
end


-- Complex function for drawing, that uses text_position
local function draw_text(x, y, text, ...)
  -- Reads external variables
  local font_width  = BIZHAWK_FONT_WIDTH
  local font_height = BIZHAWK_FONT_HEIGHT
  local bg_default_colour = COLOUR.background
  local text_colour, bg_colour, always_on_client, always_on_game, ref_x, ref_y
  local arg1, arg2, arg3, arg4, arg5, arg6 = ...
  
  if not arg1 or arg1 == true then
    
    text_colour = COLOUR.text
    bg_colour = bg_default_colour
    always_on_client, always_on_game, ref_x, ref_y = arg1, arg2, arg3, arg4
    
  elseif not arg2 or arg2 == true then
    
    text_colour = arg1
    bg_colour = bg_default_colour
    always_on_client, always_on_game, ref_x, ref_y = arg2, arg3, arg4, arg5
    
  else
    
    text_colour, bg_colour = arg1, arg2
    always_on_client, always_on_game, ref_x, ref_y = arg3, arg4, arg5, arg6
    
  end
  
  local x_pos, y_pos, length = text_position(x, y, text, font_width, font_height, always_on_client, always_on_game, ref_x, ref_y)

  text_colour = change_transparency(text_colour, Text_opacity)
  
  gui.text(Scale_x*x_pos, Scale_y*y_pos, text, text_colour)
  
  return x_pos + length, y_pos + font_height, length
end


-- Draw an alert text
local function alert_text(x, y, text, text_colour, bg_colour, always_on_game, ref_x, ref_y)
  -- Reads external variables
  local font_width  = BIZHAWK_FONT_WIDTH
  local font_height = BIZHAWK_FONT_HEIGHT
  
  local x_pos, y_pos, text_length = text_position(x, y, text, font_width, font_height, true, always_on_game, ref_x, ref_y)
  
  text_colour = change_transparency(text_colour, Text_opacity)
  
  draw_rectangle(x_pos, y_pos, text_length - 1, font_height - 1, bg_colour, bg_colour)
  
  gui.text(Scale_x*x_pos, Scale_y*y_pos, text, text_colour)
end


-- Returns frames-time conversion
local function frame_time(frame)
  if not PAL_FRAMERATE then error("PAL_FRAMERATE undefined."); return end
  
  local total_seconds = frame/PAL_FRAMERATE
  local hours = floor(total_seconds/3600)
  local tmp = total_seconds - 3600*hours
  local minutes = floor(tmp/60)
  tmp = tmp - 60*minutes
  local seconds = floor(tmp)
  
  local miliseconds = 1000* (total_seconds%1)
  if hours == 0 then hours = "" else hours = string.format("%d:", hours) end
  local str = string.format("%s%.2d:%.2d.%03.0f", hours, minutes, seconds, miliseconds)
  return str
end


-- Quick check if file exists
function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then io.close(f) return true else return false end
end

-- ##################################################################################################################################################################################################################
-- GAME SPECIFIC FUNCTIONS

-- Read main game variables
local Frame_counter, Game_mode, RNG, Level_id
local Camera_x, Camera_y, Santa_x, Santa_y, Santa_x_sub, Santa_y_sub
Previous.Camera_x, Previous.Camera_y = s16(WRAM.camera_x), s16(WRAM.camera_y)
Previous.Santa_x, Previous.Santa_y = s16(WRAM.x_pos), s16(WRAM.y_pos)
Previous.Santa_x_sub, Previous.Santa_y_sub = u16(WRAM.x_subpos), u16(WRAM.y_subpos)
local function scan_game()
  -- Game general
  Frame_counter = u16(WRAM.frame_counter)
  Game_mode = u8(WRAM.game_mode)
  --RNG = u16(WRAM.rng) -- TODO: figure out
  
  -- Handle prev values (should always be set before the current values update), with the conditional to avoid writing nil to prev
  if Camera_x then Previous.Camera_x = Camera_x or 0 end
  if Camera_y then Previous.Camera_y = Camera_y or 0 end
  if Santa_x then Previous.Santa_x = Santa_x or 0 end
  if Santa_y then Previous.Santa_y = Santa_y or 0 end
  if Santa_x_sub then Previous.Santa_x_sub = Santa_x_sub or 0 end
  if Santa_y_sub then Previous.Santa_y_sub = Santa_y_sub or 0 end
  
  -- In level frequently used info
  Level_id = u16(WRAM.level_id)
  Sublevel_id = u16(WRAM.sublevel_id)
	Santa_x = s16(WRAM.x_pos)
	Santa_y = s16(WRAM.y_pos)
	Santa_x_sub = u16(WRAM.x_subpos)
	Santa_y_sub = u16(WRAM.y_subpos)
  Camera_x = s16(WRAM.camera_x)
  Camera_y = s16(WRAM.camera_y)
end


-- Converts the in-game (x, y) to BizHawk screen coordinates
local function screen_coordinates(x, y, camera_x, camera_y)
  -- Sane values
  camera_x = camera_x or Camera_x or s16(WRAM.camera_x)
  camera_y = camera_y or Camera_y or s16(WRAM.camera_y)
  
  -- Math
  local x_screen = (x - camera_x) + OPTIONS.left_gap
  local y_screen = (y - camera_y) + OPTIONS.top_gap
  
  return x_screen, y_screen
end


-- Converts BizHawk/emu-screen coordinates to in-game (x, y)
local function game_coordinates(x_emu, y_emu, camera_x, camera_y)
  -- Sane values
  camera_x = camera_x or Camera_x
  camera_y = camera_y or Camera_y

  -- Math
  local x_game = x_emu + camera_x - OPTIONS.left_gap
  local y_game = y_emu + camera_y - OPTIONS.top_gap

  return x_game, y_game
end


-- Display frame counter and all the other movie related info
local function show_movie_info()
  if not OPTIONS.display_movie_info then return end
  
  -- Font
  Text_opacity = 1.0
  Bg_opacity = 1.0
  local width = BIZHAWK_FONT_WIDTH
  local x_text, y_text = 11*width, 0
  
  local rec_colour = (Readonly or not Movie_active) and COLOUR.text or COLOUR.warning
  local recording_bg = (Readonly or not Movie_active) and COLOUR.background or COLOUR.warning_bg
  
  -- Read-only or read-write?
  local movie_type = (not Movie_active and "No movie ") or (Readonly and "Movie " or "REC ")
  draw_text(x_text, y_text, movie_type, rec_colour, recording_bg)
  x_text = x_text + width*(string.len(movie_type) + 1)

  -- Frame count
  local movie_info
  if Readonly and Movie_active then
    movie_info = fmt("%d/%d", Lastframe_emulated, Framecount)
  else
    movie_info = fmt("%d", Lastframe_emulated)
  end
  draw_text(x_text, y_text, movie_info)  -- Shows the latest frame emulated, not the frame being run now
  x_text = x_text + width*string.len(movie_info)

  if Movie_active then
    -- Rerecord count
    local rr_info = fmt(" %d ", Rerecords)
    draw_text(x_text, y_text, rr_info, 0x80FFFFFF)
    x_text = x_text + width*string.len(rr_info)

    -- Lag count
    draw_text(x_text, y_text, Lagcount, "red")
    x_text = x_text + width*string.len(Lagcount)
  end

  -- Time
  local time_str = frame_time(Lastframe_emulated)   -- Shows the latest frame emulated, not the frame being run now
  draw_text(x_text, y_text, fmt(" (%s)", time_str))
end


-- Display general info
local function show_general_info()
  if not OPTIONS.display_general_info then return end
	
	-- Main display
	draw_text(Buffer_middle_x, BIZHAWK_FONT_HEIGHT, fmt("Frame:$%04X  Game mode:$%02X", Frame_counter, Game_mode), COLOUR.text, false, false, 0.5)
  draw_text(Buffer_middle_x, OPTIONS.top_gap, fmt("Camera (%04X, %04X)", Camera_x, Camera_y), true, false, 0.5, 1.0)
	
  -- Score screen flag
  if Game_mode ~= DAZE.game_mode_level and memory.hash_region(0x18000, 0x200, "WRAM") == "1A8E5296A0FEAB3E948728788EE1EF80CC68C7C6BAFD5F6A117D97814D64C2BC" then -- if this hash is indeed in score screen
    local score_screen_done = u16(WRAM.score_screen_done)
    local x_tmp = draw_text(2, Buffer_middle_y, "Score screen done: ")
    draw_text(x_tmp, Buffer_middle_y, score_screen_done == 0 and "no" or "yes", score_screen_done == 0 and COLOUR.warning or COLOUR.positive)
  end
end


-- Display tilemap related info
local function tilemap()
  if not OPTIONS.display_tilemap_info then return end
  
  -- Reads basic RAM
  local level_width = u16(WRAM.level_width)   --\ in pixels
  local level_height = u16(WRAM.level_height) --/
  if Level_id == 0x15 then level_height = 0x04C0 end -- hardcoded fix for level $15, because its height is "wrong"
  local level_width_blocks = level_width/0x10
  local level_height_blocks = level_height/0x10
  local tiles_total = (level_width_blocks)*(level_height_blocks)
  
  -- Draw a grid of 16x16 tiles, highlighting 64x64 metatiles
  local x_pos, y_pos
  local x_screen, y_screen
  local tile_id, metatile_id -- TODO: figure out way to calculate the tile ID based on the metatile
  local colour
  local tiles_onscreen = 0
  for i = 0, tiles_total - 1 do
    x_pos = 16*(i%level_width_blocks)
    y_pos = 16*(math.floor(i/level_width_blocks))
    x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
    
    if is_inside_rectangle(x_screen, y_screen, -16, -16, Screen_width + 16, Screen_height + 16) then -- to prevent drawing for the whole level
      -- Draw the tile
      if ((x_pos/16)+(y_pos/16)%2)%2 == 1 then colour = COLOUR.blank_tile else colour = COLOUR.blank_tile - 0x38000000 end
      draw_rectangle(x_screen, y_screen, 15, 15, colour, 0)
      --draw_pixel_text(x_screen + 1, y_screen + 1, fmt("x:%02X\ny:%02X", x_pos, y_pos))
      
      -- Draw the metatile
      if x_pos%64 == 48 and y_pos%64 == 48 then -- metatile last tile
        if (((x_pos-48)/64)+((y_pos-48)/64)%2)%2 == 1 then colour = COLOUR.block + 0x38000000 else colour = COLOUR.warning_soft - 0x80000000 end
        draw_rectangle(x_screen-48, y_screen-48, 63, 63, colour)
        --metatile_id = u16(WRAM.metatile_data + 2*i/16) -- TODO: find a way to calculate here
        --draw_pixel_text(x_screen + 1, y_screen + 1, fmt("Meta: %02X", i/16))
      end
      --if x_pos%64 == 0 and y_pos%64 == 0 then -- metatile start
        --draw_rectangle(x_screen, y_screen, 63, 63, COLOUR.block, COLOUR.block)
        --draw_pixel_text(x_screen + 1, y_screen + 1, fmt("Meta: %02X", i/16))
      --end
      
      tiles_onscreen = tiles_onscreen + 1
    end
  end
  --draw_text(Screen_width, Screen_height, fmt("Total tiles on emu screen: %d", tiles_onscreen), COLOUR.text, true, false) -- DEBUG
  
  --[[ Draw 512x512 rectangle for the limits of the Graphics Debugger (DEBUG/RESEARCH)
  --x_screen, y_screen = screen_coordinates(0, 0, Camera_x, Camera_y)
  --draw_rectangle(x_screen, y_screen, 511, 511, COLOUR.warning)]]
  
  --[[ Draw simplified level metatile map (DEBUG/RESEARCH)
  local level_width_metatiles = level_width_blocks/4
  local level_height_metatiles = level_height_blocks/4
  local metatiles_total = level_width_metatiles*level_height_metatiles
  local colour
  for i = 0, metatiles_total - 1 do
    x_pos = 4*(i%level_width_metatiles)
    y_pos = 4*(floor(i/level_width_metatiles))
    metatile_id = u16(WRAM.metatile_data + 2*i)
    if metatile_id == 0x0000 then colour = COLOUR.weak else colour = COLOUR.sprites[metatile_id%(#COLOUR.sprites) + 1] end -- SURE FOR LEVEL 00, other levels have different empty metatiles
    draw_rectangle(OPTIONS.map_x + x_pos, OPTIONS.map_y + y_pos, 3, 3, colour, colour)
  end]]
end


-- Display main level related info
local function level_info()
  
  -- Reads RAM
  local level_width = u16(WRAM.level_width)
  local level_height = u16(WRAM.level_height)
  
  -- Hardcoded fix for level $15, because its height is "wrong"
  if Level_id == 0x15 then level_height = 0x04C0 end
  
  -- Calculate other info
  local level_width_blocks = level_width/0x10
  local level_height_blocks = level_height/0x10
  local level_width_metatiles = level_width_blocks/4
  local level_height_metatiles = level_height_blocks/4
  
  -- Display info
  if OPTIONS.display_level_info then
    local level_str = fmt("Level: $%02X (%d) %s\n(%04Xx%04X pixels, %Xx%X tiles, %Xx%X metatiles)",
      Level_id, Level_id+1, Level_id == 0x10 and fmt("sublevel: %d", Sublevel_id) or "", level_width, level_height, level_width_blocks, level_height_blocks, level_width_metatiles, level_height_metatiles)
    draw_text(OPTIONS.left_gap, Border_bottom_start, level_str, COLOUR.text)
  end
  
  -- Draw map image
  if OPTIONS.display_level_map then
    local scale = OPTIONS.map_scale
    local map_file = OPTIONS.map_images .. fmt("Level $%02X%s.png", Level_id, Level_id == 0x10 and fmt(" sublevel %d", Sublevel_id) or "") -- exception if for The Attic
    if scale == 1 then -- atlas display map
      if file_exists(map_file) then
        -- Left area
        draw_image_region(map_file, Previous.Camera_x - OPTIONS.left_gap, Previous.Camera_y - OPTIONS.top_gap, OPTIONS.left_gap, Screen_height, 0, 0)
        -- Right area
        draw_image_region(map_file, Previous.Camera_x + Buffer_width, Previous.Camera_y - OPTIONS.top_gap, OPTIONS.right_gap, Screen_height, Border_right_start, 0)
        -- Top area
        draw_image_region(map_file, Previous.Camera_x, Previous.Camera_y - OPTIONS.top_gap, Buffer_width, OPTIONS.top_gap, OPTIONS.left_gap, 0)
        -- Bottom area
        draw_image_region(map_file, Previous.Camera_x, Previous.Camera_y + Buffer_height, Buffer_width, OPTIONS.bottom_gap, OPTIONS.left_gap, Border_bottom_start)
      end
    else -- minimap
      -- Draw background for the map
      draw_rectangle(OPTIONS.map_x, OPTIONS.map_y, level_width/scale-1, level_height/scale-1, COLOUR.very_weak2, COLOUR.very_weak2)
      -- Draw level map if file exists
      if file_exists(map_file) then
        draw_image(map_file, OPTIONS.map_x, OPTIONS.map_y, level_width/scale, level_height/scale)
      end
      -- Display Santa's position in this map
      draw_cross(OPTIONS.map_x + floor(Santa_x/scale), OPTIONS.map_y + floor(Santa_y/scale), 2, COLOUR.santa)
      draw_rectangle(OPTIONS.map_x + floor((Santa_x-13)/scale), OPTIONS.map_y + floor((Santa_y-48)/scale), floor(26/scale), floor(48/scale), COLOUR.santa_bg, COLOUR.santa_bg)
    end
  end
  
end


-- Display basic player info
local function player()
  if not OPTIONS.display_player_info then return end
  
	-- Font
  Text_opacity = 1.0
  Bg_opacity = 1.0
  
  --- Read RAM
  local x_pos = Santa_x
  local y_pos = Santa_y
  local x_sub = Santa_x_sub
  local y_sub = Santa_y_sub
  local x_speed = s16(WRAM.x_speed)
  local x_subspeed = u16(WRAM.x_subspeed)
  local y_speed = s16(WRAM.y_speed)
  local y_subspeed = u16(WRAM.y_subspeed)
  local x_pos_prev = Previous.Santa_x
  local y_pos_prev = Previous.Santa_y
  local x_sub_prev = Previous.Santa_x_sub
  local y_sub_prev = Previous.Santa_y_sub
  local can_jump_flag = u8(WRAM.can_jump_flag) == 0
  local direction = bit.check(u8(WRAM.player_flags), 7)
  local invincibility_timer = u8(WRAM.invincibility_timer)
  local get_ready_timer = u16(WRAM.get_ready_timer)
  local magic_flag = u8(WRAM.magic_flag) ~= 0
  local fire_magic_flag = u8(WRAM.fire_magic_flag) ~= 0
  local evil_santa_flag = u8(WRAM.evil_santa_flag) ~= 0
  local evil_santa_timer = u16(WRAM.evil_santa_timer)
  local status_id = u8(WRAM.player_status_id)
  local status_pointer = u24(WRAM.player_status_pointer)
  local blue_gift_boxes = u16(WRAM.blue_gift_boxes)
  local red_gift_boxes = u16(WRAM.red_gift_boxes)
  local golden_gift_boxes = u16(WRAM.golden_gift_boxes)
	
  --- Transformations and calculations
	local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
	local x_display = x_pos < 0 and fmt("-%04X", 0xFFFFFFFF - x_pos + 1) or fmt("%04X", x_pos) -- position in HEXADECIMAL
	local y_display = y_pos < 0 and fmt("-%04X", 0xFFFFFFFF - y_pos + 1) or fmt("%04X", y_pos) -- position in HEXADECIMAL
	local x_spd_str, y_spd_str
	if x_speed < 0 then -- corretions for negative horizontal speed
		x_speed = x_speed + 1
		x_subspeed = 0x10000 - x_subspeed
		if x_subspeed == 0x10000 then x_subspeed = 0 ; x_speed = x_speed - 1 end
		if x_speed == 0 then x_spd_str = fmt("-%d.%04x", x_speed, x_subspeed) -- force negative signal due to previous math -- TODO: speed is in decimal, should be hex
		else x_spd_str = fmt("%d.%04x", x_speed, x_subspeed) end
	else
		x_spd_str = fmt("%+d.%04x", x_speed, x_subspeed)
	end
	if y_speed < 0 then -- corretions for negative vertical speed
		y_speed = y_speed + 1
		y_subspeed = 0x10000 - y_subspeed
		if y_subspeed == 0x10000 then y_subspeed = 0 ; y_speed = y_speed - 1 end
		if y_speed == 0 then y_spd_str = fmt("-%d.%04x", y_speed, y_subspeed) -- force negative signal due to previous math
		else y_spd_str = fmt("%d.%04x", y_speed, y_subspeed) end
	else
		y_spd_str = fmt("%+d.%04x", y_speed, y_subspeed)
	end
  local dx_pos = (x_pos*0x10000 + x_sub) - (x_pos_prev*0x10000 + x_sub_prev) -- 0x10000 to merge pos and subpos in a single number to properly subtract -- TODO: figure out a way to fix this all
  local dy_pos = (y_pos*0x10000 + y_sub) - (y_pos_prev*0x10000 + y_sub_prev) -- 0x10000 to merge pos and subpos in a single number to properly subtract
  local dx_sub = bit.band(dx_pos, 0xFFFF)
  if (bit.band(dx_pos, 0xFFFF0000))/0x10000 >= 0x8000 then dx_pos = dx_pos - 0x10000 else dx_pos = (bit.band(dx_pos, 0xFFFF0000))/0x10000 end
  local dx_pos_str = fmt("%+d.%04x", dx_pos, dx_sub) -- TODO: delta is in decimal, should be hex
  local dy_pos_str = fmt("%+d.%04x", (bit.band(dy_pos, 0xFFFF0000))/0x10000, bit.band(dy_pos, 0xFFFF)) -- TODO: delta is in decimal, should be hex  
  
  --- Table
  local i = 0
  local delta_x = BIZHAWK_FONT_WIDTH
  local delta_y = BIZHAWK_FONT_HEIGHT
  local table_x = 2
  local table_y = OPTIONS.top_gap
  local x_tmp, y_tmp, colour
  
  --- Display info
  -- Position
  draw_text(table_x, table_y + i*delta_y, fmt("Pos (%s.%04x, %s.%04x) %s", x_display, x_sub, y_display, y_sub, direction and "<-" or "->")) -- position in HEXADECIMAL
  draw_cross(x_screen, y_screen, 2, COLOUR.santa)
  i = i + 1
  
  -- Speed
	draw_text(table_x, table_y + i*delta_y, "Speed (" .. string.rep(" ", string.len(x_spd_str)) .. ", " .. y_spd_str .. ")")
  draw_text(table_x, table_y + i*delta_y, "       " .. x_spd_str, math.abs(x_speed) >= 4 and COLOUR.positive or COLOUR.warning_soft)
  i = i + 1
  
  -- Position delta
  draw_text(table_x, table_y + i*delta_y, fmt("Delta (%s, %s)", string.rep(" ", string.len(dx_pos_str)), dy_pos_str))  -- TODO: figure out a way to fix this all
  if ((x_pos*0x10000 + x_sub) - (x_pos_prev*0x10000 + x_sub_prev)) > ((u16(WRAM.x_speed))*0x10000 + x_subspeed) then
    colour = COLOUR.positive
  elseif ((x_pos*0x10000 + x_sub) - (x_pos_prev*0x10000 + x_sub_prev)) < ((u16(WRAM.x_speed))*0x10000 + x_subspeed) then
    colour = COLOUR.warning
  else
    colour = COLOUR.text
  end
  draw_text(table_x, table_y + i*delta_y, fmt("       %s", dx_pos_str), colour)  -- TODO: figure out a way to fix this all
  i = i + 1
  
  -- Can jump
  x_tmp = draw_text(table_x, table_y + i*delta_y, "Can jump: ")
  draw_text(x_tmp, table_y + i*delta_y, fmt("%s", can_jump_flag and "yes" or "no"), can_jump_flag and COLOUR.positive or COLOUR.warning)
  i = i + 1
  
  -- Can shoot magic
  x_tmp = draw_text(table_x, table_y + i*delta_y, "Can shoot magic: ")
  x_tmp = draw_text(x_tmp, table_y + i*delta_y, fmt("%s", magic_flag and "no " or "yes"), magic_flag and COLOUR.weak or COLOUR.memory)
  draw_text(x_tmp, table_y + i*delta_y, fmt(" %s", fire_magic_flag and "(fire!)" or ""), COLOUR.warning)
  i = i + 1
  
  -- Status/action
  x_tmp = draw_text(table_x, table_y + i*delta_y, fmt("Status: $%02X ($%06X)", status_id, status_pointer))
  i = i + 1
  --[[ REMOVE/DEBUG
  local print_str = ""
  for j = 0, 0xff, 3 do-- REMOVE/DEBUG
    local status_pointer_rom = memory.read_u24_le(0x0112D1 + j, "CARTROM") -- REMOVE/DEBUG
    draw_text(Border_right_start, j/3*0.8*delta_y, fmt("$%02X ($%06X)", j , status_pointer_rom))   -- REMOVE/DEBUG
    if j < 0x66 then print_str = print_str .. fmt("\n#$%02X ($%06X) = ", j, status_pointer_rom) end -- REMOVE/DEBUG
  end-- REMOVE/DEBUG
  print(print_str) -- REMOVE/DEBUG]]
  
  -- Timers
  i = i + 1
  if invincibility_timer > 0 then
    draw_text(table_x, table_y + i*delta_y, fmt("Invincibility: %d", invincibility_timer), COLOUR.warning_soft) 
  end
  i = i + 1
  if evil_santa_timer > 0 then
    draw_text(table_x, table_y + i*delta_y, fmt("Evil Santa: %d", evil_santa_timer), COLOUR.warning2) 
  end
  i = i + 1
  if get_ready_timer > 0 then
    draw_text(table_x, table_y + i*delta_y, fmt("Get ready: %d", get_ready_timer), COLOUR.warning_soft)
  end
  
  -- Gift boxes
  draw_text(table_x, Border_bottom_start - 4*delta_y, "Gifts:")
  x_tmp = draw_text(table_x, Border_bottom_start - 3*delta_y, "Blue:")
  draw_text(table_x + x_tmp, Border_bottom_start - 3*delta_y, fmt("%d", blue_gift_boxes), blue_gift_boxes > 0 and COLOUR.warning or COLOUR.positive)
  x_tmp = draw_text(table_x, Border_bottom_start - 2*delta_y, "Red:")
  draw_text(table_x + x_tmp, Border_bottom_start - 2*delta_y, fmt("%d", red_gift_boxes), red_gift_boxes > 0 and COLOUR.warning or COLOUR.positive)
  x_tmp = draw_text(table_x, Border_bottom_start - 1*delta_y, "Golden:")
  draw_text(table_x + x_tmp, Border_bottom_start - 1*delta_y, fmt("%d", golden_gift_boxes), golden_gift_boxes > 0 and COLOUR.warning or COLOUR.positive)
end


-- Displays player's hitboxes
local function player_hitbox()

  -- Transformations
	local x_screen, y_screen = screen_coordinates(Santa_x, Santa_y, Camera_x, Camera_y)
  
  -- Hitbox (collision with sprites)
  if OPTIONS.display_player_hitbox then
    -- TODO: figure out hitbox
  end
  
  -- Interaction points (collision with blocks)
  if OPTIONS.display_interaction_points then
    -- Tile interaction points (from tests)
    local interaction_pts = { -- {dx, dy} relative to Santa's position -- TODO: maybe move this inside DAZE
      bottom_left = {dx=-13, dy=0}, bottom_right = {dx=13, dy=0},
      mid_left = {dx=-13, dy=-34}, mid_right = {dx=13, dy=-34},
      top_left = {dx=-8, dy=-48}, top_right = {dx=8, dy=-48},
      --ground = {dx=0, dy=-11} -- TODO: bad, it's different between different types of floors
    } 
    
    -- Rectangle to add contrast
    draw_box(x_screen + interaction_pts.bottom_left.dx-2, y_screen + interaction_pts.top_left.dy-2, x_screen + interaction_pts.bottom_right.dx+2, y_screen + interaction_pts.bottom_right.dy+2, COLOUR.interaction_nohitbox_bg, COLOUR.interaction_nohitbox_bg) --COLOUR.interaction_nohitbox_bg
    
    local dx, dy
    -- Bottom left
    dx, dy = interaction_pts.bottom_left.dx, interaction_pts.bottom_left.dy
    gui.drawPolygon({{dx, dy-3}, {dx, dy}, {dx+3, dy}, {dx, dy}}, x_screen, y_screen)
    -- Bottom right
    dx, dy = interaction_pts.bottom_right.dx, interaction_pts.bottom_right.dy
    gui.drawPolygon({{dx, dy-3}, {dx, dy}, {dx-3, dy}, {dx, dy}}, x_screen, y_screen)
    -- Middle left
    dx, dy = interaction_pts.mid_left.dx, interaction_pts.mid_left.dy
    gui.drawPolygon({{dx, dy+3}, {dx, dy}, {dx+3, dy}, {dx, dy}}, x_screen, y_screen)
    -- Middle right
    dx, dy = interaction_pts.mid_right.dx, interaction_pts.mid_right.dy
    gui.drawPolygon({{dx, dy+3}, {dx, dy}, {dx-3, dy}, {dx, dy}}, x_screen, y_screen)
    -- Top left
    dx, dy = interaction_pts.top_left.dx, interaction_pts.top_left.dy
    gui.drawPolygon({{dx, dy+3}, {dx, dy}, {dx+3, dy}, {dx, dy}}, x_screen, y_screen)
    -- Top right
    dx, dy = interaction_pts.top_right.dx, interaction_pts.top_right.dy
    gui.drawPolygon({{dx, dy+3}, {dx, dy}, {dx-3, dy}, {dx, dy}}, x_screen, y_screen)
    -- Ground (guid for usual floor detection) -- TODO: bad, it's different between different types of floors
    --dx, dy = interaction_pts.ground.dx, interaction_pts.ground.dy
    --gui.drawPolygon({{dx-3, dy-3}, {dx, dy}, {dx+3, dy-3}, {dx, dy}}, x_screen, y_screen)
  end
  
end


local function sprite_contact_test() -- TODO: maybe remove
  --print("WRITE")
	local x_screen, y_screen = screen_coordinates(Santa_x, Santa_y, Camera_x, Camera_y)
  local x_test, y_test = s16(0x1C11), s16(0x1C13)
  --print(fmt("x_test:%04X, y_test:%04X", x_test, y_test))
  draw_line(x_screen, y_screen, x_screen + x_test, y_screen + y_test, COLOUR.memory)
end
--event.onmemoryexecute(sprite_contact_test, 0x81bdf1, "sprite_contact_test") -- $81bdf1 is right after setting the value for $7E1C13, to make sure the read gets the correct values


-- Display all sprite info
local function sprites()
  if not OPTIONS.display_sprite_info then return end
  
	-- Font
  Text_opacity = 1.0
  Bg_opacity = 1.0
  
  local sprite_counter = 0
  local table_y = BIZHAWK_FONT_HEIGHT --OPTIONS.top_gap + BIZHAWK_FONT_HEIGHT
  local delta_y = 6
  
  --if Frame_counter%30 == 0 then console.clear() ; print(string.rep("-", 20)) end -- each 30 frames to avoid lag -- DEBUG/RESEARCH
  
  for slot = 0, DAZE.sprite_max do
  
    -- Slot offset to read memory correctly
    local slot_off = 0x3E*slot
    
    -- Check if slot is active
    --local sprite_status = u8(WRAM.sprite_status + slot_off) -- TODO: figure out
    local x_pos = u16(WRAM.sprite_x_pos + slot_off)
    --if sprite_status ~= 0 then  -- returns if the slot is empty -- TODO: make an option if the player wants all visible slots or only active
    if x_pos ~= 0xDDDD then  -- 0xDDDD means the slot was never initialized by the game up to this point
      
      sprite_counter = sprite_counter + 1
      
      -- Read RAM
      local sprite_type = u24(WRAM.sprite_type + slot_off)
      local is_onscreen = bit.check(u8(WRAM.sprite_flags2 + slot_off), 1)
      local x_pos = s16(WRAM.sprite_x_pos + slot_off)
      local x_sub = u16(WRAM.sprite_x_subpos + slot_off)
      local y_pos = s16(WRAM.sprite_y_pos + slot_off)
      local y_sub = u16(WRAM.sprite_y_subpos + slot_off)
      local x_speed = s16(WRAM.sprite_x_speed + slot_off)
      local x_subspeed = u16(WRAM.sprite_x_subspeed + slot_off)
      local y_speed = s16(WRAM.sprite_y_speed + slot_off)
      local y_subspeed = u16(WRAM.sprite_y_subspeed + slot_off)
      local invincibility_timer = u16(WRAM.sprite_invincibility_timer + slot_off)
      local hp = u8(WRAM.sprite_hp + slot_off)
      local damage_flashing_timer = u8(WRAM.sprite_damage_flashing_timer + slot_off)
    
      -- Transformations
      local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
      local x_display = x_pos < 0 and fmt("-%04X", 0xFFFFFFFF - x_pos + 1) or fmt("%04X", x_pos) -- position in HEXADECIMAL
      local y_display = y_pos < 0 and fmt("-%04X", 0xFFFFFFFF - y_pos + 1) or fmt("%04X", y_pos) -- position in HEXADECIMAL
      local x_spd_str, y_spd_str
      if x_speed < 0 then -- corretions for negative horizontal speed
        x_speed = x_speed + 1
        x_subspeed = 0x10000 - x_subspeed
        if x_subspeed == 0x10000 then x_subspeed = 0 ; x_speed = x_speed - 1 end
        if x_speed == 0 then x_spd_str = fmt("-%d.%04x", x_speed, x_subspeed) -- force negative signal due to previous math
        else x_spd_str = fmt("%d.%04x", x_speed, x_subspeed) end
      else
        x_spd_str = fmt("%+d.%04x", x_speed, x_subspeed)
      end
      if y_speed < 0 then -- corretions for negative vertical speed
        y_speed = y_speed + 1
        y_subspeed = 0x10000 - y_subspeed
        if y_subspeed == 0x10000 then y_subspeed = 0 ; y_speed = y_speed - 1 end
        if y_speed == 0 then y_spd_str = fmt("-%d.%04x", y_speed, y_subspeed) -- force negative signal due to previous math
        else y_spd_str = fmt("%d.%04x", y_speed, y_subspeed) end
      else
        y_spd_str = fmt("%+d.%04x", y_speed, y_subspeed)
      end
      
      -- Calculates the correct colour to use, according to slot
      local info_colour = COLOUR.sprites[slot%(#COLOUR.sprites) + 1]
      local colour_background = change_transparency(info_colour, 0.5)--info_colour - 0x7f000000 -- same colour, but with 50% transparency
      
      --[[ Handles onscreen/offscreen
      local is_offscreen = true
      if x_screen >= OPTIONS.left_gap and x_screen <= Border_right_start and
      y_screen >= OPTIONS.top_gap and y_screen <= Border_bottom_start then is_offscreen = false end]]
      
      -- Text opacity due being offscreen
      if is_onscreen then
        info_colour = change_transparency(info_colour, 0.8)
      else
        info_colour = COLOUR.weak
        colour_background = change_transparency(info_colour, 0.25)
      end
      
      -- Debug info
      local debug_str = ""
      --[[
      local debug_offset, ammount = 0x0, 22 -- CHANGE THESE (caution: each sprite only has 0x3E/62 bytes)
      for addr = 0, ammount-1 do
        debug_str = debug_str .. fmt(" %02X", u8(WRAM.sprite_start + slot_off + addr + debug_offset))
        if slot == 0 then -- labels
          draw_text(Screen_width - (ammount-addr)*3*BIZHAWK_FONT_WIDTH, 0, fmt("+%02X", debug_offset + addr))
        end
      end
      --]]
      -- Display info in table
      if OPTIONS.display_sprite_table then
        local sprite_str = fmt("<%02d> %06X {%s.%04x(%s), %s.%04x(%s)}%s", slot, sprite_type, x_display, x_sub, x_spd_str, y_display, y_sub, y_spd_str, debug_str)
        --draw_text(Screen_width, table_y + slot*delta_y, sprite_str, info_colour, true) -- TODO: change "slot" by "sprite_counter" if ever change to that method of displaying only active slots
        draw_text(Screen_width, table_y + slot*delta_y, sprite_str, info_colour, true) -- TODO: change "slot" by "sprite_counter" if ever change to that method of displaying only active slots
        --draw_pixel_text(Border_right_start, table_y + slot*delta_y, sprite_str, info_colour) -- TODO: change "slot" by "sprite_counter" if ever change to that method of displaying only active slots
        
        -- Display warning for sprite not documented (DEBUG/RESEARCH)
        local new_sprite = true
        --[[for i = 1, #DAZE.sprites do
          if sprite_type == DAZE.sprites[i].ptr then
            new_sprite = false
            break
          end
        end]]
        if DAZE.sprites[sprite_type] ~= nil then new_sprite = false end
        if new_sprite then
          draw_text(Screen_width, table_y + slot*delta_y, fmt("%06X%s", sprite_type, string.rep(" ", 41)), COLOUR.warning, true) -- DEBUG/RESEARCH
          if OPTIONS.display_sprite_on_map then
            draw_cross(OPTIONS.map_x + floor(x_pos/16), OPTIONS.map_y + floor(y_pos/16), 2, info_colour)
            draw_pixel_text(OPTIONS.map_x + floor(x_pos/16) - 4, OPTIONS.map_y + floor(y_pos/16) + 2, fmt("%02d", slot), info_colour)
          end
          print(fmt("<%02d> 0x%06X", slot, sprite_type)) -- add "if Frame_counter%10 == 0 then print() end" if want to avoid emu lag (DEBUG/RESEARCH)
        end
        
        --[[ Increase emu gaps if too many slots
        if table_y + slot*delta_y > Screen_height - delta_y then
          client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, table_y + (slot+1)*delta_y - OPTIONS.top_gap - Buffer_height + delta_y)
        end]]
      end
      
      -- Display info near sprite on screen
      if OPTIONS.display_sprite_info_near then
        draw_text(x_screen, y_screen + 2, fmt("<%02d>", slot), info_colour, false, false, 0.5)
        draw_cross(x_screen, y_screen, 2, info_colour)
        if invincibility_timer > 0 then draw_text(x_screen, y_screen - 1, fmt("(%d)", invincibility_timer), info_colour, false, false, 0.5, 1.0) end
        if damage_flashing_timer > 0 then draw_text(x_screen, y_screen - BIZHAWK_FONT_HEIGHT, fmt("(%d)", damage_flashing_timer), info_colour, false, false, 0.5, 1.0) end
        -- HP above sprite
        if not new_sprite and DAZE.sprites[sprite_type].show_hp then
          draw_text(x_screen, y_screen - 64, fmt("HP:%d", hp), info_colour, false, false, 0.5, 1.0)
          draw_text(2, Buffer_middle_y, fmt("%s HP:%d", DAZE.sprites[sprite_type].name, hp), info_colour) -- redundant boss HP display, to avoid motion sickness since its HP above position will be constantly moving
        end
      end
      
      -- Display sprite slots in the map
      if OPTIONS.display_sprite_on_map and OPTIONS.display_level_map and OPTIONS.map_scale > 1 then
        local scale = OPTIONS.map_scale
        draw_cross(OPTIONS.map_x + floor(x_pos/scale), OPTIONS.map_y + floor(y_pos/scale), 2, info_colour)
        draw_pixel_text(OPTIONS.map_x + floor(x_pos/scale) - 4, OPTIONS.map_y + floor(y_pos/scale) + 2, fmt("%02d", slot), info_colour)
      end
      
      -- Special sprite-specific info
      if sprite_type == 0x85D2AC then -- Star
        -- Display Star position in the map
        if OPTIONS.display_sprite_on_map and OPTIONS.display_level_map and OPTIONS.map_scale > 1 then
          local scale = OPTIONS.map_scale
          draw_line(OPTIONS.map_x + floor((x_pos-1)/scale) - 3, OPTIONS.map_y + floor((y_pos-28)/scale), OPTIONS.map_x + floor((x_pos-1)/scale) + 3, OPTIONS.map_y + floor((y_pos-28)/scale), COLOUR.star)
          draw_line(OPTIONS.map_x + floor((x_pos-1)/scale), OPTIONS.map_y + floor((y_pos-28)/scale), OPTIONS.map_x + floor((x_pos-1)/scale) - 2, OPTIONS.map_y + floor((y_pos-28)/scale) + 3, COLOUR.star)
          draw_line(OPTIONS.map_x + floor((x_pos-1)/scale), OPTIONS.map_y + floor((y_pos-28)/scale), OPTIONS.map_x + floor((x_pos-1)/scale) + 2, OPTIONS.map_y + floor((y_pos-28)/scale) + 3, COLOUR.star)
          draw_line(OPTIONS.map_x + floor((x_pos-1)/scale), OPTIONS.map_y + floor((y_pos-28)/scale) + 1, OPTIONS.map_x + floor((x_pos-1)/scale), OPTIONS.map_y + floor((y_pos-28)/scale) - 3, COLOUR.star)
        end
      elseif sprite_type == 0x88DABA and Level_id == 0x10 then -- Lever (in The Attic)
        local lever_activated = u8(WRAM.sprite_anim_frame + slot_off) == 2
        draw_text(2, Buffer_middle_y + BIZHAWK_FONT_HEIGHT, fmt("Lever activated: %s", lever_activated and "yes!" or "no"), info_colour)
      end
    end
  end
  
  -- Display amount of sprites
  draw_text(Screen_width, table_y - BIZHAWK_FONT_HEIGHT, fmt("Sprites:%.2d", sprite_counter), COLOUR.weak, true)
end


-- Main function to run inside a level
local function level_mode()
  if Game_mode ~= DAZE.game_mode_level then return end
  
  --draw_sprite_spawning_areas()
  
  level_info()
  
  tilemap()
  
  sprites()
  
  player_hitbox()
  
  player()
end


-- Display mouse coordinates right above it
local function show_mouse_info()
	if not OPTIONS.display_mouse_coordinates then return end
	
	-- Font
  Text_opacity = 0.5
  Bg_opacity = 0.5
	local line_colour = COLOUR.weak
  local bg_colour = change_transparency(COLOUR.background, Bg_opacity)
  
  -- Get mouse info
  local mouse_input = input.getmouse()
	local x, y = mouse_input.X + OPTIONS.left_gap, mouse_input.Y + OPTIONS.top_gap
  --draw_text(OPTIONS.left_gap, Border_bottom_start, fmt("Mouse real: (%d, %d)\nMouse transf: (%d, %d)", mouse_input.X, mouse_input.Y, x, y)) -- DEBUG
  
  -- Tranformations
	local x_game, y_game = game_coordinates(x, y, Camera_x, Camera_y)
	if x_game < 0 then x_game = 0x10000 + x_game end
	if y_game < 0 then y_game = 0x10000 + y_game end
	
  local mouse_in_window = is_inside_rectangle(x, y, 0, 0, Screen_width, Screen_height)
  
	if mouse_in_window then
		-- Lines
    draw_line(0, y, Screen_width, y, line_colour)
    draw_line(x, 0, x, Screen_height, line_colour)
    draw_cross(x, y, 3, "cyan")
    -- Coordinates
    draw_text(x, y - 9, fmt("emu ($%X, $%X)", x, y), COLOUR.text, true, false, 0.5)
		draw_text(x, y + 9, fmt("game ($%04X, $%04X)", x_game, y_game), COLOUR.text, true, false, 0.5)
	end
end

--#############################################################################
-- CHEATS


-- Forbid cheats on script start
Cheat.allow_cheats = false
Cheat.is_cheating = false
Cheat.under_free_move = false
Cheat.under_invincibility = false


-- Cheat: free movement, for research and tests
function Cheat.free_movement()

	-- Font
  Text_opacity = 1.0
  Bg_opacity = 1.0
  
  -- All actions if cheat is active
  if Cheat.under_free_move then
    -- Warning display
    draw_text(Buffer_middle_x, Border_bottom_start, fmt("Cheat: Free Movement"), COLOUR.warning, false, false, 0.5)
    if Movie_active then
      gui.drawText(OPTIONS.left_gap, Border_bottom_start + BIZHAWK_FONT_HEIGHT, "Disable cheat while recording movies!", COLOUR.warning)
    end
    
    -- Get current position and direction
    local x_pos, y_pos = Santa_x, Santa_y
    local direction = u8(WRAM.player_flags) -- only bit 7 matters
    
    -- Set movement speed
    local pixels = (Joypad["X"] and 4) or (Joypad["A"] and 8) or (Joypad["L"] and 16) or 1  -- how many pixels per frame

    -- Math
    if Joypad["Left"] then x_pos = x_pos - pixels ; bit.set(direction, 7)  end
    if Joypad["Right"] then x_pos = x_pos + pixels ; bit.clear(direction, 7) end
    if Joypad["Up"] then y_pos = y_pos - pixels end
    if Joypad["Down"] then y_pos = y_pos + pixels end

    -- Manipulate the addresses
    w16(WRAM.x_pos, x_pos) --\ setting the coordinates
    w16(WRAM.y_pos, y_pos) --/
    w8(WRAM.player_flags, direction) -- set the direction
    if Joypad["Left"] then 
      w16(WRAM.x_speed, 0) -----\ to prevent horizontal speed messing with the free movement
      w16(WRAM.x_subspeed, 0x8928) --/
    elseif Joypad["Right"] then
      w16(WRAM.x_speed, -1)      -----\ to prevent horizontal speed messing with the free movement
      w16(WRAM.x_subspeed, -0x8928) --/
    end
    w16(WRAM.y_speed, -1)      -----\ to account for gravity, otherwise it keeps falling
    w16(WRAM.y_subspeed, -0x6928) --/
    w8(WRAM.invincibility_timer, 30) -- to avoid taking damage
    Cheat.is_cheating = false
  end
end


-- Cheat: invincibility, for research and tests
function Cheat.invincibility()
  if not Cheat.under_invincibility then return end
  
  -- Write memory
  w8(WRAM.invincibility_timer, 30)
  w8(WRAM.hats, 5)
  
  -- Warning display
  draw_text(Buffer_middle_x, Border_bottom_start - BIZHAWK_FONT_HEIGHT, fmt("Cheat: Invincibility"), COLOUR.warning, false, false, 0.5)
  if Movie_active then
    gui.drawText(OPTIONS.left_gap, Border_bottom_start + BIZHAWK_FONT_HEIGHT, "Disable cheat while recording movies!", COLOUR.warning)
  end
end


-- ##################################################################################################################################################################################################################
-- MAIN


-- Check minimum size for the lateral gaps
if OPTIONS.left_gap < 10 then OPTIONS.left_gap = 10 end
if OPTIONS.right_gap < 10 then OPTIONS.right_gap = 10 end
if OPTIONS.top_gap < 10 then OPTIONS.top_gap = 10 end
if OPTIONS.bottom_gap < 10 then OPTIONS.bottom_gap = 10 end

-- Create lateral gaps
client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)


-- Options menu window
function Options_form.create_window()
  --- MAIN ---------------------------------------------------------------------------------------

  -- Create form
  local form_width, form_height = 260, 580
  Options_form.form = forms.newform(form_width, form_height, "DBC Options")
  -- Set form location based on the emu window
  local emu_window_x, emu_window_y = client.xpos(), client.ypos()
  local form_x_pos, form_y_pos = 4, 4 -- top left corner
  if emu_window_x >= form_x_pos + form_width then form_x_pos = emu_window_x - form_width + 6 end
  --forms.setlocation(Options_form.form, form_x_pos, form_y_pos) -- TODO:reactivate?
  
  local xform, yform, delta_x, delta_y = 4, 4, 120, 20
  
  --- SHOW/HIDE ---------------------------------------------------------------------------------------
  
  Options_form.show_hide_label = forms.label(Options_form.form, "Show/hide options", xform, yform)
  forms.setproperty(Options_form.show_hide_label, "AutoSize", true)
  forms.setlocation(Options_form.show_hide_label, (form_width-16)/2 - forms.getproperty(Options_form.show_hide_label, "Width")/2, yform)
  forms.label(Options_form.form, string.rep("-", 150), xform - 2, yform, form_width, 20)
  
  yform = yform + 1.25*delta_y
  
  local y_section, y_bigger = yform  -- 1st row
  
  -- Player
  forms.label(Options_form.form, "Player:", xform, yform)
  yform = yform + delta_y
  
  Options_form.player_info = forms.checkbox(Options_form.form, "Info", xform, yform)
  forms.setproperty(Options_form.player_info, "Checked", OPTIONS.display_player_info)
  yform = yform + delta_y
  
  Options_form.interaction_points = forms.checkbox(Options_form.form, "Solid interaction", xform, yform)
  forms.setproperty(Options_form.interaction_points, "Checked", OPTIONS.display_interaction_points)
  yform = yform + delta_y
  
  y_bigger = yform 
  
  -- Sprite
  xform, yform = xform + delta_x, y_section
  Options_form.sprite_info = forms.checkbox(Options_form.form, "Sprite", xform, yform)
  forms.setproperty(Options_form.sprite_info, "Checked", OPTIONS.display_sprite_info)
  forms.setproperty(Options_form.sprite_info, "Width", 60)
  forms.setproperty(Options_form.sprite_info, "TextAlign", "TopRight")
  forms.setproperty(Options_form.sprite_info, "CheckAlign", "TopRight")
  yform = yform + delta_y
  
  Options_form.sprite_table = forms.checkbox(Options_form.form, "Table", xform, yform)
  forms.setproperty(Options_form.sprite_table, "Checked", OPTIONS.display_sprite_table)
  yform = yform + delta_y
  
  Options_form.sprite_info_near = forms.checkbox(Options_form.form, "Info near sprite", xform, yform)
  forms.setproperty(Options_form.sprite_info_near, "Checked", OPTIONS.display_sprite_info_near)
  yform = yform + delta_y
  
  Options_form.sprite_on_map = forms.checkbox(Options_form.form, "Slot on map", xform, yform)
  forms.setproperty(Options_form.sprite_on_map, "Checked", OPTIONS.display_sprite_on_map)
  yform = yform + delta_y
  
  forms.addclick(Options_form.sprite_info, function() -- to enable/disable Sprite child options on click
    OPTIONS.display_sprite_info = forms.ischecked(Options_form.sprite_info) or false
    
    forms.setproperty(Options_form.sprite_table, "Enabled", OPTIONS.display_sprite_info)
    forms.setproperty(Options_form.sprite_info_near, "Enabled", OPTIONS.display_sprite_info)
    forms.setproperty(Options_form.sprite_on_map, "Enabled", OPTIONS.display_sprite_info)
  end)
  
  if yform > y_bigger then y_bigger = yform end
  
  y_section = y_bigger + delta_y  -- 2nd row
  
  -- General
  xform, yform = 4, y_section
  forms.label(Options_form.form, "General:", xform, yform)
  yform = yform + delta_y
  
  Options_form.general_info = forms.checkbox(Options_form.form, "Main game info", xform, yform)
  forms.setproperty(Options_form.general_info, "Checked", OPTIONS.display_general_info)
  yform = yform + delta_y
  
  Options_form.movie_info = forms.checkbox(Options_form.form, "Movie info", xform, yform)
  forms.setproperty(Options_form.movie_info, "Checked", OPTIONS.display_movie_info)
  yform = yform + delta_y
  
  Options_form.tilemap_info = forms.checkbox(Options_form.form, "Tilemap", xform, yform)
  forms.setproperty(Options_form.tilemap_info, "Checked", OPTIONS.display_tilemap_info)
  yform = yform + delta_y
  
  Options_form.mouse_coordinates = forms.checkbox(Options_form.form, "Mouse coordinates", xform, yform)
  forms.setproperty(Options_form.mouse_coordinates, "Checked", OPTIONS.display_mouse_coordinates)
  forms.setproperty(Options_form.mouse_coordinates, "Width", 116)
  yform = yform + delta_y
  
  if yform > y_bigger then y_bigger = yform end
  
  -- Level
  xform, yform = xform + delta_x, y_section
  forms.label(Options_form.form, "Level:", xform, yform)
  yform = yform + delta_y
  
  Options_form.level_info = forms.checkbox(Options_form.form, "Info", xform, yform)
  forms.setproperty(Options_form.level_info, "Checked", OPTIONS.display_level_info)
  forms.setproperty(Options_form.level_info, "Width", 48)
  yform = yform + delta_y
  
  Options_form.level_map = forms.checkbox(Options_form.form, "Map", xform, yform)
  forms.setproperty(Options_form.level_map, "Checked", OPTIONS.display_level_map)
  forms.setproperty(Options_form.level_map, "Width", 48)
  yform = yform + delta_y
  
  Options_form.scale_label = forms.label(Options_form.form, "Map scale:", xform, yform+4)
  forms.setproperty(Options_form.scale_label, "AutoSize", true)
  
  xform = xform + forms.getproperty(Options_form.scale_label, "Width")
  local scale_table = {"a. 1:1", "b. 1:2", "c. 1:4", "d. 1:8", "e. 1:16", "f. 1:32", "g. 1:64"}
  Options_form.scale_dropdown = forms.dropdown(Options_form.form, scale_table, xform, yform, 58, 20)
  forms.setproperty(Options_form.scale_dropdown, "SelectedIndex", 4) -- scale 1:16 fits in the screen
  yform = yform + delta_y
  
  forms.addclick(Options_form.level_map, function() -- to enable/disable map scale option on click
    OPTIONS.display_level_map = forms.ischecked(Options_form.level_map) or false
    
    forms.setproperty(Options_form.scale_label, "Enabled", OPTIONS.display_level_map)
    forms.setproperty(Options_form.scale_dropdown, "Enabled", OPTIONS.display_level_map)
  end)
  
  if yform > y_bigger then y_bigger = yform end
  
  
  --- SETTINGS ---------------------------------------------------------------------------------------
  
  y_section = y_bigger + delta_y -- 3rd row
  xform, yform = 4, y_section
  
  Options_form.script_settings_label = forms.label(Options_form.form, "Script settings", xform, yform)
  forms.setproperty(Options_form.script_settings_label, "AutoSize", true)
  forms.setlocation(Options_form.script_settings_label, (form_width-16)/2 - forms.getproperty(Options_form.script_settings_label, "Width")/2, yform)
  forms.label(Options_form.form, string.rep("-", 150), xform - 2, yform, form_width, 20)
  yform = yform + delta_y
  
  -- Emu gaps
  function Options_form.emu_gaps_update(side)
    client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
    forms.settext(Options_form[side .. "_label"], fmt("%d", OPTIONS[side]))
  end
  
  xform, yform = (form_width-64)/2, y_section + 2*delta_y
  -- top gap
  Options_form.top_gap_label = forms.label(Options_form.form, fmt("%d", OPTIONS.top_gap), xform, yform - 20, 48, delta_y)
  forms.setproperty(Options_form.top_gap_label, "TextAlign", "BottomCenter")
  forms.button(Options_form.form, "-", function()
    if OPTIONS.top_gap - 10 >= BIZHAWK_FONT_HEIGHT then OPTIONS.top_gap = OPTIONS.top_gap - 10 end
    Options_form.emu_gaps_update("top_gap")
  end, xform, yform, 24, 24)
  xform = xform + 24
  forms.button(Options_form.form, "+", function()
    OPTIONS.top_gap = OPTIONS.top_gap + 10
    Options_form.emu_gaps_update("top_gap")
  end, xform, yform, 24, 24)
  -- left gap
  xform, yform = xform - 3*24, yform + 24
  Options_form.left_gap_label = forms.label(Options_form.form, fmt("%d", OPTIONS.left_gap), xform, yform - 20, 48, delta_y)
  forms.setproperty(Options_form.left_gap_label, "TextAlign", "BottomCenter")
  forms.button(Options_form.form, "-", function()
    if OPTIONS.left_gap - 10 >= BIZHAWK_FONT_HEIGHT then OPTIONS.left_gap = OPTIONS.left_gap - 10 end
    Options_form.emu_gaps_update("left_gap")
  end, xform, yform, 24, 24)
  xform = xform + 24
  forms.button(Options_form.form, "+", function()
    OPTIONS.left_gap = OPTIONS.left_gap + 10
    Options_form.emu_gaps_update("left_gap")
  end, xform, yform, 24, 24)
  -- right gap
  xform = xform + 3*24
  Options_form.right_gap_label = forms.label(Options_form.form, fmt("%d", OPTIONS.right_gap), xform, yform - 20, 48, delta_y)
  forms.setproperty(Options_form.right_gap_label, "TextAlign", "BottomCenter")
  forms.button(Options_form.form, "-", function()
    if OPTIONS.right_gap - 10 >= BIZHAWK_FONT_HEIGHT then OPTIONS.right_gap = OPTIONS.right_gap - 10 end
    Options_form.emu_gaps_update("right_gap")
  end, xform, yform, 24, 24)
  xform = xform + 24
  forms.button(Options_form.form, "+", function()
    OPTIONS.right_gap = OPTIONS.right_gap + 10
    Options_form.emu_gaps_update("right_gap")
  end, xform, yform, 24, 24)
  -- bottom gap
  xform, yform = xform - 3*24, yform + 24
  Options_form.bottom_gap_label = forms.label(Options_form.form, fmt("%d", OPTIONS.bottom_gap), xform, yform + 24, 48, delta_y)
  forms.setproperty(Options_form.bottom_gap_label, "TextAlign", "TopCenter")
  forms.button(Options_form.form, "-", function()
    if OPTIONS.bottom_gap - 10 >= BIZHAWK_FONT_HEIGHT then OPTIONS.bottom_gap = OPTIONS.bottom_gap - 10 end
    Options_form.emu_gaps_update("bottom_gap")
  end, xform, yform, 24, 24)
  xform = xform + 24
  Options_form.bottom_plus = forms.button(Options_form.form, "+", function()
    OPTIONS.bottom_gap = OPTIONS.bottom_gap + 10
    Options_form.emu_gaps_update("bottom_gap")
  end, xform, yform, 24, 24)
  if yform > y_bigger then y_bigger = yform end
  -- label
  xform, yform = xform - 26, yform - 20
  forms.label(Options_form.form, "Emu gaps", xform, yform, 70, 20)
  
  --- CHEATS ---------------------------------------------------------------------------------------
  
  y_section = y_bigger + 2.5*delta_y -- 4th row
  xform, yform = 4, y_section
  
  Options_form.allow_cheats = forms.checkbox(Options_form.form, "Cheats", xform, yform)
  forms.setproperty(Options_form.allow_cheats, "Checked", Cheat.allow_cheats)
  forms.setproperty(Options_form.allow_cheats, "TextAlign", "TopRight")
  forms.setproperty(Options_form.allow_cheats, "CheckAlign", "TopRight")
  forms.setproperty(Options_form.allow_cheats, "AutoSize", true)
  forms.setlocation(Options_form.allow_cheats, (form_width-16)/2 - forms.getproperty(Options_form.allow_cheats, "Width")/2, yform)
  forms.label(Options_form.form, string.rep("-", 150), xform - 2, yform, form_width, 20)
  
  -- Free movement cheat
  yform = yform + 1.5*delta_y
  Options_form.free_movement = forms.checkbox(Options_form.form, "Free movement", xform, yform)
  forms.setproperty(Options_form.free_movement, "Checked", Cheat.under_free_move)
  forms.setproperty(Options_form.free_movement, "Enabled", Cheat.allow_cheats)
  
  -- Invincibility cheat
  xform = xform + delta_x
  Options_form.invincibility = forms.checkbox(Options_form.form, "Invincibility", xform, yform)
  forms.setproperty(Options_form.invincibility, "Checked", Cheat.under_invincibility)
  forms.setproperty(Options_form.invincibility, "Enabled", Cheat.allow_cheats)
  yform = yform + delta_y
  
  -- Enabling/disabling Cheat child options on click
  forms.addclick(Options_form.allow_cheats, function()
    Cheat.allow_cheats = forms.ischecked(Options_form.allow_cheats) or false
    
    forms.setproperty(Options_form.free_movement, "Enabled", Cheat.allow_cheats)
    forms.setproperty(Options_form.invincibility, "Enabled", Cheat.allow_cheats)
  end)
  
  if yform > y_bigger then y_bigger = yform end
  
  -- Resize options form height base on the amount of options
  forms.setproperty(Options_form.form, "Height", y_bigger + 50)
  
  --- DEBUG ---------------------------------------------------------------------------------------
  
  -- Background for dev/debug tests
  Options_form.picture_box = forms.pictureBox(Options_form.form, 0, 0, form_width, tonumber(forms.getproperty(Options_form.form, "Height")))
  --forms.clear(Options_form.picture_box, 0xffFF0000)
  
end


-- Update the options based on the form
function Options_form.evaluate_form()
  --- Show/hide -------------------------------------------------------------------------------------------
  -- Player
  OPTIONS.display_player_info = forms.ischecked(Options_form.player_info) or false
  OPTIONS.display_interaction_points = forms.ischecked(Options_form.interaction_points) or false
  -- Sprites
  OPTIONS.display_sprite_info = forms.ischecked(Options_form.sprite_info) or false
  OPTIONS.display_sprite_table = forms.ischecked(Options_form.sprite_table) or false
  OPTIONS.display_sprite_info_near = forms.ischecked(Options_form.sprite_info_near) or false
  OPTIONS.display_sprite_on_map = forms.ischecked(Options_form.sprite_on_map) or false
  -- Level
  OPTIONS.display_level_info = forms.ischecked(Options_form.level_info) or false
  OPTIONS.display_level_map =  forms.ischecked(Options_form.level_map) or false
  local scale_table = {1, 2, 4, 8, 16, 32, 64}
  OPTIONS.map_scale = scale_table[tonumber(forms.getproperty(Options_form.scale_dropdown, "SelectedIndex")) + 1]
  -- General
  OPTIONS.display_general_info = forms.ischecked(Options_form.general_info) or false
  OPTIONS.display_movie_info = forms.ischecked(Options_form.movie_info) or false
  OPTIONS.display_tilemap_info = forms.ischecked(Options_form.tilemap_info) or false
  OPTIONS.display_mouse_coordinates = forms.ischecked(Options_form.mouse_coordinates) or false
  --- Cheats -------------------------------------------------------------------------------------------
  Cheat.allow_cheats = forms.ischecked(Options_form.allow_cheats) or false
  Cheat.under_free_move = forms.ischecked(Options_form.free_movement) or false
  Cheat.under_invincibility = forms.ischecked(Options_form.invincibility) or false
end

-- Initialize forms
forms.destroyall() -- to prevent more than one forms (usually happens when script has an error)
Options_form.create_window()
Options_form.is_form_closed = false


-- Functions to run when script is stopped or reset
event.onexit(function()
  
  forms.destroyall()
  
  gui.clearImageCache()
  
	client.SetGameExtraPadding(0, 0, 0, 0)
  
  print("Finishing Daze Before Christmas script.\n------------------------------------")
end)


-- Script load success message (ONLY MAIN LOOP AFTER THIS)
print("Daze Before Christmas Lua script loaded successfully at " .. os.date("%X") .. ".\n") -- %c for date and time


-- Main script loop
while true do
 
  -- Update forms options
  Options_form.is_form_closed = forms.gettext(Options_form.form) == ""
  if not Options_form.is_form_closed then Options_form.evaluate_form() end
  
  -- Initial values, don't make drawings here
  bizhawk_status()
  bizhawk_screen_info()
  scan_game()
  input_update()
  
  -- Drawings
  OPTIONS.map_x = OPTIONS.map_x_offset
  if OPTIONS.map_x + floor(Santa_x/OPTIONS.map_scale) > Buffer_middle_x then OPTIONS.map_x = OPTIONS.map_x_offset + (Buffer_middle_x - (OPTIONS.map_x + floor(Santa_x/OPTIONS.map_scale))) end -- translate the map if Santa x pos is too big, to properly display it in the emu screen
  OPTIONS.map_y = Border_bottom_start + OPTIONS.map_y_offset
  if Is_lagged then
    gui.drawText(Buffer_middle_x - 20, OPTIONS.top_gap + 2*BIZHAWK_FONT_HEIGHT, " LAG ", COLOUR.warning, COLOUR.warning_bg)
    gui.clearImageCache() -- unload unused images, "inside lag" to no run every frame
  end
  level_mode()
  show_movie_info()
  show_general_info()
  show_mouse_info()
  
  -- Cheats
  if Cheat.allow_cheats then
    Cheat.free_movement()
    Cheat.invincibility()
  end
  
  emu.frameadvance()
end