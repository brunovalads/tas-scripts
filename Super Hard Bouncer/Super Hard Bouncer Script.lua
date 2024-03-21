--####################################################################
--##                                                                ##
--##   Super Hard Bouncer (GB) Script for BizHawk                   ##
--##   https://libra-bits.itch.io/super-hard-bouncer-gameboy-game   ##
--##   http://tasvideos.org/Bizhawk.html                            ##
--##                                                                ##
--##   Author: Bruno Valadão Cunha (BrunoValads) [02/2024]          ##
--##                                                                ##
--##   Git repository: https://github.com/brunovalads/tas-scripts   ##
--##                                                                ##
--####################################################################

--################################################################################################################################################################
-- INITIAL STATEMENTS

-- Script options
local OPTIONS = {
    
    -- Script settings
    left_gap = 100, 
    right_gap = 100,
    top_gap = 20,
    bottom_gap = 20,
    framerate = 59.727500569606,
    
    ---- DEBUG AND CHEATS ----
    DEBUG = false, -- to display debug info for script development only!
    CHEATS = false, -- to help research, ALWAYS DISABLED WHEN RECORDING MOVIES
}
if OPTIONS.DEBUG then
    OPTIONS.left_gap = 100
    OPTIONS.right_gap = 650
    OPTIONS.top_gap = 18
    OPTIONS.bottom_gap = 250
end

-- Basic functions renaming
local fmt = string.format
local floor = math.floor
local ceil = math.ceil
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local pi = math.pi

-- Memory read/write functions
memory.usememorydomain("WRAM")
local u8 =  memory.read_u8
local s8 =  memory.read_s8
local w8 =  memory.write_u8
local u16 = memory.read_u16_le
local s16 = memory.read_s16_le
local w16 = memory.write_u16_le
local u24 = memory.read_u24_le
local s24 = memory.read_s24_le
local w24 = memory.write_u24_le

-- Font settings
local BIZHAWK_FONT_WIDTH = 10  -- correction to the scale is done in biz.screen_info()
local BIZHAWK_FONT_HEIGHT = 18

-- Drawing function renaming
local draw = {
  box = gui.drawBox,
  ellipse = gui.drawEllipse,
  image = gui.drawImage,
  image_region = gui.drawImageRegion,
  line = gui.drawLine,
  cross = gui.drawAxis,
  pixel = gui.drawPixel,
  polygon = gui.drawPolygon,
  rectangle = gui.drawRectangle,
  text = gui.text,
  pixel_text = gui.pixelText,
}

-- Global variable to handle current/previous situations
local Generic_current = false
local Generic_previous = false

-- Other global constants
local FRAMERATE = 60.0988138974405
local GB_WIDTH = 160
local GB_HEIGHT = 144


--################################################################################################################################################################
-- GENERAL UTILITIES

local biz = {}

-- Check if the script is running on BizHawk
function biz.check_emulator()
    if not bizstring then
        error("\n\nThis script only works with BizHawk emulator.\nVisit https://tasvideos.org/Bizhawk/ReleaseHistory to download the latest version.")
    end
end
biz.check_emulator()

-- Check the name of the ROM domain (as it might have differences between cores)
biz.memory_domain_list = memory.getmemorydomainlist()
function biz.check_ROM_domain()
    for key, domain in ipairs(biz.memory_domain_list) do
        if domain:find("ROM") then return domain end
    end
    -- If didn't find ROM domain then
    error("This core doesn't have ROM domain exposed for the script, please change the core!")
end
biz.ROM_domain = biz.check_ROM_domain()

-- Check the game name in ROM
function biz.game_name()
    local game_name = ""
    for i = 0x0, 0xC do
        game_name = game_name .. string.char(memory.read_u8(0x0134 + i, biz.ROM_domain))
    end
    return game_name
end

-- Check game version and prevent script running with other games
local Game_version = ""
local Game_versions_hashes = {
    ["76E63211179FE4192A8BA38825EAE28FC660CD1EF5CA518BCE92FCFA9263A633"] = "1.0",
    ["A0A0486F9CCDA072C284D59357EF9A1E73B377BC3AE3EA263F875DFCF857BC09"] = "1.1",
}
local Current_hash = memory.hash_region(0, memory.getmemorydomainsize(biz.ROM_domain), biz.ROM_domain)
Game_version = Game_versions_hashes[Current_hash]
if Game_version == nil then
    error("\n\nThis script is only for Super Hard Bouncer (GB)!\n"..
          "Get the game here: https://libra-bits.itch.io/super-hard-bouncer-gameboy-game \n"..
          "Contact the script author here: https://github.com/brunovalads/tas-scripts \n\n" ..
          "Game hash: " .. Current_hash)
end

-- Get screen dimensions of the emulator and the game
local PC, Game = {}, {}
local Scale
function biz.screen_info()
    -- Get/calculate screen scale -------------------------------------------------
    if client.borderwidth() == 0 then -- to avoid division by zero bug when borders are not yet ready when loading the script
        Scale = 2 -- because is the one I always use
    elseif OPTIONS.left_gap > 0 and OPTIONS.top_gap > 0 then -- to make sure this method won't get div/0
        Scale = math.min(client.borderwidth()/OPTIONS.left_gap, client.borderheight()/OPTIONS.top_gap) -- Pixel scale
    else
        Scale = client.getwindowsize()
    end

    -- Dimensions in PC pixels ----------------------------------------------------
    PC.screen_width = client.screenwidth()   --\ Emu screen drawing area (doesn't take menu and status bar into account)
    PC.screen_height = client.screenheight() --/ 

    PC.left_padding = client.borderwidth()         --\
    PC.right_padding = OPTIONS.right_gap * Scale   -- | Emu extra paddings around the game area
    PC.top_padding = client.borderheight()         -- |
    PC.bottom_padding = OPTIONS.bottom_gap * Scale --/

    PC.buffer_width = PC.screen_width - PC.left_padding - PC.right_padding   --\ Game area
    PC.buffer_height = PC.screen_height - PC.top_padding - PC.bottom_padding --/

    PC.buffer_middle_x = PC.left_padding + PC.buffer_width/2 --\ Middle coordinates of the game area, referenced to the whole emu screen
    PC.buffer_middle_y = PC.top_padding + PC.buffer_height/2 --/

    PC.screen_middle_x = PC.screen_width/2  --\ Middle coordinates of the emu screen drawing area
    PC.screen_middle_y = PC.screen_height/2 --/

    PC.right_padding_start = PC.left_padding + PC.buffer_width  --\ Coordinates for the start of right and bottom paddings
    PC.bottom_padding_start = PC.top_padding + PC.buffer_height --/

    -- Dimensions in game pixels ----------------------------------------------------
    Game.buffer_width = client.bufferwidth()
    Game.buffer_height = client.bufferheight()

    Game.screen_width = PC.screen_width/Scale
    Game.screen_height = PC.screen_height/Scale

    Game.left_padding = PC.left_padding/Scale
    Game.right_padding = PC.right_padding/Scale
    Game.top_padding = PC.top_padding/Scale
    Game.bottom_padding = PC.bottom_padding/Scale

    Game.buffer_middle_x = Game.left_padding + Game.buffer_width/2
    Game.buffer_middle_y = Game.top_padding + Game.buffer_height/2

    Game.screen_middle_x = Game.screen_width/2
    Game.screen_middle_y = Game.screen_height/2

    Game.right_padding_start = Game.left_padding + Game.buffer_width
    Game.bottom_padding_start = Game.top_padding + Game.buffer_height
 
end

-- Returns frames-time conversion
local function frame_time(frame, mili)
    local total_seconds = frame/OPTIONS.framerate
    local hours = floor(total_seconds/3600)
    local tmp = total_seconds - 3600*hours
    local minutes = floor(tmp/60)
    tmp = tmp - 60*minutes
    local seconds = floor(tmp)

    local miliseconds = 1000* (total_seconds%1)
    local miliseconds_str = fmt(".%03.0f", miliseconds)
    local str = fmt("%.2d:%.2d:%.2d%s", hours, minutes, seconds, mili and miliseconds_str or "")
    return str
end

-- Get main BizHawk status
local Framecount, Movie_active, Movie_size
function biz.movie_status()
    Framecount = emu.framecount()
    if Movie_active and not Movie_size then
        Movie_size = movie.length()
    end
end

-- This can be read just once, because it shouldn't change when making encodes (if using TAStudio the movie length will keep incrementing if you reach the end, so this is a workaround)
Movie_active = movie.isloaded()
if Movie_active then
    Movie_size = movie.length()
end

-- Convert unsigned byte to signed in hex string
function signed8hex(num, signal)
    local maxval = 128
    if signal == nil then signal = true end

    if num < maxval then -- positive
        return fmt("%s%02X", signal and "+" or "", num)
    else -- negative
        return fmt("%s%02X", signal and "-" or "", 2*maxval - num)
    end
end

-- Return a single colour from <value> in a red to green gradient (red is 00, green is <max_value>) (adapted from "Kirby Dream Land 3 (USA).lua")
function gradient_good_bad(value, max_value)
    local alpha, red, green, blue = 0xFF, 0x00, 0x00, 0x00
    
	if value < 0 then
        red = 0xFF
		green = 0
		blue = 0
	elseif value < max_value/2 then
        red = 0xFF	
		green = math.floor((0xFF/(max_value - max_value/2))*math.abs(value))
		blue = 0
	elseif math.abs(value) < max_value then
        red = math.floor(-(0xFF/(max_value - max_value/2))*math.abs(value)+510)
		green = 0xFF
		blue = 0
    else
        red = 0
        green = 0xFF
        blue = 0
	end

	return alpha*0x1000000 + red*0x10000 + green*0x100 + blue
end

-- Return a single colour from <value> in white to green gradient (white is 00, green is <max_value>)
function gradient_good(value, max_value)
    
    local ratio = 1 - value/max_value
    local hex = floor(ratio*0xFF)
    
    local alpha, red, green, blue = 0xff, hex, 0xFF, hex
    
    if value <= max_value then
        return alpha*0x1000000 + red*0x10000 + green*0x100 + blue
    else
        return 0xff7F00FF -- purple
    end
end

-- Return a single colour from <value> in white to red gradient (white is 00, red is <max_value>)
function gradient_bad(value, max_value)
    
    local ratio = 1 - value/max_value
    local hex = floor(ratio*0xFF)
    
    local alpha, red, green, blue = 0xff, 0xFF, hex, hex
    
    if value <= max_value then
        return alpha*0x1000000 + red*0x10000 + green*0x100 + blue
    else
        return 0xff7F00FF -- purple
    end
end


--################################################################################################################################################################
-- GAME INFO DISPLAY FUNCTIONS
 
-- RAM addresses
local RAM = {
    
    -- General
    camera_x = 0x0349, -- 2 bytes
    camera_y = 0x034B, -- 2 bytes
    level_id = 0x00C5, --
    level_width = 0x00C6, -- in 8x8 pixel blocks
    level_height = 0x00C7, -- in 8x8 pixel blocks
    game_mode = 0x00B1,
    exit_x_pos = 0x00BB,
    exit_y_pos = 0x00BD,
    blocks = 0x00D2,
 
    -- Player (0x32 bytes table, the play is actually the real first entry in the object list)
    x_pos = 0x00B4,
    x_subpos = 0x00B3,
    y_pos = 0x00B6,
    y_subpos = 0x00B5,
    x_speed = 0x00B8,
    x_subspeed = 0x00B7,
    y_speed = 0x00BA,
    y_subspeed = 0x00B9,
    player_status = 0x00B2,
    player_status_timer = 0x00C8,
    lives = 0x0360,
    powerup = 0x035F,
    bounce_power = 0x0362,
    bounce_power_timer = 0x0363,
    
    -- Objects (Tables for 5 slots)
    objects_active = 0x0312,
    objects_x_pos = 0x0317, -- 2 bytes
    objects_y_pos = 0x0321, -- 2 bytes
    objects_x_speed = 0x032B, -- 2 bytes
    objects_y_speed = 0x0335, -- 2 bytes
    objects_animation = 0x033F, -- 2 bytes
}

-- RAM addresses adjust for differente game versions
if Game_version == "1.1" then
    for label, address in pairs(RAM) do
        --print(fmt("label: %s, address: $%04X, RAM[label]: $%04X", label, address, RAM[label]))
        if address >= 0x00D2 then
            RAM[label] = RAM[label] + 2
            print(fmt("label: %s, address: $%04X, RAM[label]: $%04X", label, address, RAM[label]))
        end
    end
end

-- Converts the in-game (x, y) to emu-screen coordinates
local function screen_coordinates(x, y, camera_x, camera_y)
  local x_screen = x - camera_x + OPTIONS.left_gap
  local y_screen = y - camera_y + OPTIONS.top_gap

  return x_screen, y_screen
end

-- Main player RAM read, outside the main_display because i need previous
local X_pos, Y_pos
local X_pos_prev, Y_pos_prev = 0, 0
local Camera_x, Camera_y
local Camera_x_prev, Camera_y_prev = 0, 0
local function main_game_scan()
    -- Player coordinates
    if X_pos then X_pos_prev = X_pos end -- conditional to avoid writing nil to prev
    if Y_pos then Y_pos_prev = Y_pos end
    X_pos = u8(RAM.x_pos)
    Y_pos = u8(RAM.y_pos)
    -- Camera coordinates
    if Camera_x then Camera_x_prev = Camera_x end -- conditional to avoid writing nil to prev
    if Camera_y then Camera_y_prev = Camera_y end
    Camera_x = u16(RAM.camera_x)
    Camera_y = u16(RAM.camera_y)
end

-- Init tables used for extra columns on TAStudio
local Column = {}
Column.x_speed = {}
Column.x_speed_str = {}
Column.y_speed = {}
Column.y_speed_str = {}
Column.status = {}
Column.status_str = {}

-- Main display function, ALL DRAWINGS SHOULD BE CALLED HERE
local function main_display()
    --- Movie timer
    local timer_str = frame_time(Framecount, true)
    draw.text(0, 0, fmt("%s", timer_str), "white", "bottomright")
    
    --- Display game version
    draw.text(0, BIZHAWK_FONT_HEIGHT, fmt("Game version: %s", Game_version), "white", "bottomright")
    
    --- Display game mode
    local game_mode = u8(RAM.game_mode)
    draw.text(0, 0, fmt("Game mode: %X", game_mode), "white", "topright")
    
    --- Check if is level mode
    local is_level_mode = game_mode == 0x01
    if not is_level_mode then gui.clearGraphics() ; return end
    
    --- Dark filter
    local filter_alpha = 0x55
    draw.rectangle(OPTIONS.left_gap, OPTIONS.top_gap, 256, 224, filter_alpha*0x1000000, filter_alpha*0x1000000)
    
    --- Player info
    -- Read RAM
    local x_pos = X_pos
    local y_pos = Y_pos
    local x_subpos = u8(RAM.x_subpos)
    local y_subpos = u8(RAM.y_subpos)
    local x_speed = s8(RAM.x_speed)
    local y_speed = s8(RAM.y_speed)
    local x_subspeed = u8(RAM.x_subspeed)
    local y_subspeed = u8(RAM.y_subspeed)
    local player_status = u8(RAM.player_status)
    local player_status_timer = u8(RAM.player_status_timer)
    local bounce_power = u8(RAM.bounce_power)
    local bounce_power_timer = u8(RAM.bounce_power_timer)
    
    -- RAM that need calc
    local dx_pos_raw = X_pos - X_pos_prev
    local dy_pos_raw = Y_pos - Y_pos_prev
    local x_screen_player, y_screen_player = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
    local x_speed_str = signed8hex(u8(RAM.x_speed))
    local y_speed_str = signed8hex(u8(RAM.y_speed))
    local player_status_timer_inv = 90 - player_status_timer
    if x_speed < 0 then -- corretions for negative horizontal speed
        x_speed = x_speed + 1
        x_subspeed = 0x100 - x_subspeed
        if x_subspeed == 0x100 then x_subspeed = 0 ; x_speed = x_speed - 1 end
        if x_speed == 0 then x_speed_str = fmt("-%d.%02x", x_speed, x_subspeed) -- force negative signal due to previous math -- TODO: speed is in decimal, should be hex
        else x_speed_str = fmt("%d.%02x", x_speed, x_subspeed) end
    else
        x_speed_str = fmt("%+d.%02x", x_speed, x_subspeed)
    end
    if y_speed < 0 then -- corretions for negative vertical speed
        y_speed = y_speed + 1
        y_subspeed = 0x100 - y_subspeed
        if y_subspeed == 0x100 then y_subspeed = 0 ; y_speed = y_speed - 1 end
        if y_speed == 0 then y_speed_str = fmt("-%d.%02x", y_speed, y_subspeed) -- force negative signal due to previous math
        else y_speed_str = fmt("%d.%02x", y_speed, y_subspeed) end
    else
        y_speed_str = fmt("%+d.%02x", y_speed, y_subspeed)
    end
    
    -- Display player info
    local i = 0
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Pos: %02X.%02x, %02X.%02x", x_pos, x_subpos, y_pos, y_subpos)); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Speed: %s, %s", x_speed_str, y_speed_str)); i = i + 1
    --draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Delta: %+X, %+X", dx_pos_raw, dy_pos_raw)); i = i + 1
    --draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Delta: %s, %s", signed8hex(dx_pos_raw, true), signed8hex(dy_pos_raw, true))); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Status: %X%s", player_status, player_status_timer > 0 and fmt(" (%02d)", player_status_timer_inv) or "")); i = i + 1
 
    -- Show position on screen
    draw.cross(x_screen_player, y_screen_player, 2, "orange")
    
    -- and solid interaction points
    draw.cross(x_screen_player + 0x1, y_screen_player + 0x7, 2, "blue") -- bottom left
    draw.cross(x_screen_player + 0x7, y_screen_player + 0x7, 2, "blue") -- bottom right
    draw.cross(x_screen_player + 0x1, y_screen_player + 0x0, 2, "blue") -- top left
    draw.cross(x_screen_player + 0x7, y_screen_player + 0x0, 2, "blue") -- top right
    
    -- Bounce power timer
    if bounce_power_timer > 0 then
        draw.pixel_text(x_screen_player + 0x9, y_screen_player, fmt("%d", bounce_power_timer), 0x8000FFFF)
    end
    
    --- Display camera info
    -- Camera coordinates
    local camera_str = fmt("Camera: %04X, %04X", Camera_x, Camera_y)
    draw.text(PC.buffer_middle_x - BIZHAWK_FONT_WIDTH*string.len(camera_str)/2, PC.top_padding - BIZHAWK_FONT_HEIGHT, camera_str)
    
    -- Region that forces the camera to move
    local cam_min_x, cam_min_y = OPTIONS.left_gap + (Camera_x > 0x0000 and 0x44 or 0x00), OPTIONS.top_gap + (Camera_y > 0x0000 and 0x30 or 0x00) - 8
    local cam_max_x, cam_max_y = OPTIONS.left_gap + (Camera_x + 160 < u16(RAM.level_width) and 0x4C or 0xFF), OPTIONS.top_gap + (Camera_y + 144 < u16(RAM.level_height) and 0x50 or 0xFF) - 8
    --draw.box(cam_min_x, cam_min_y, cam_max_x, cam_max_y, 0x40000000, 0x40000000)
    
    --- Level info
    -- Main level info
    local level_id = u8(RAM.level_id)
    local level_width = u8(RAM.level_width)
    local level_height = u8(RAM.level_height)
    local level_str = fmt("Level: %02d (%02Xx%02X)", level_id, level_width, level_height)
    draw.text(PC.buffer_middle_x - BIZHAWK_FONT_WIDTH*string.len(level_str)/2, PC.bottom_padding_start, level_str)
    
    -- Block grid
    local block_id, block_type
    local block_x_screen, block_y_screen
    local colour_border, colour_fill
    for y = 0, level_height - 1 +1 do
        for x = 0, 0x20 - 1 do
            block_x_screen, block_y_screen = screen_coordinates(x*8, y*8, Camera_x, Camera_y)
            -- Get the colour according to the block type
            block_id = y*level_width + x
            block_type = u8(RAM.blocks + block_id)
            if block_type == 0x00 then -- Empty block
                colour_border, colour_fill = 0x80808080, nil
            elseif block_type == 0x02 then -- Solid platform block
                colour_border, colour_fill = 0x8000FF00, 0x6000FF00
            elseif block_type == 0x06 then -- Breakable block
                colour_border, colour_fill = 0x80FF7F00, 0x60FF7F00
            elseif block_type > 0x20 then -- Spike block
                colour_border, colour_fill = 0x80FF0000, 0x60FF0000
            else
                colour_border, colour_fill = 0x80FFFF00, 0x60FFFF00
            end
            
            if block_type ~= 0x00 then
                -- Draw the grid
                if block_x_screen > 0 and block_y_screen > 0 and
                   block_x_screen < Game.screen_width and block_y_screen < Game.screen_height then
                    draw.rectangle(block_x_screen, block_y_screen, 7, 7, colour_border, colour_fill)
                end
            end
            
            -- Aid grid
            --draw.rectangle(OPTIONS.left_gap + x*16 - Camera_x, OPTIONS.top_gap + y*16 - Camera_y, 15, 15, 0x60FFFFFF, 0x60000000)
        end
        -- Display y block value
        --draw.pixel_text(Game.left_padding - 5 * Game.pixel_font_width, block_y_screen, fmt("%02X", y), 0x80FFFFFF)
    end
    
    -- Exit position
    local exit_x, exit_y = u8(RAM.exit_x_pos), u8(RAM.exit_y_pos)
    local exit_x_screen, exit_y_screen = screen_coordinates(exit_x, exit_y, Camera_x, Camera_y)
    draw.cross(exit_x_screen, exit_y_screen, 2, 0xff00FF00)
    draw.box(exit_x_screen + 0x3, exit_y_screen + 0x3, exit_x_screen + 0x5, exit_y_screen + 0x4, 0xA000FF00, 0x4000FF00)
    
    --- Object info
    i = i + 3
    -- Display constans
    local table_x = 2
    local table_y = OPTIONS.DEBUG and (PC.bottom_padding_start + 2*BIZHAWK_FONT_HEIGHT) or (60 + i * BIZHAWK_FONT_HEIGHT)
    local colours = {
        0xffA0A0FF, -- blue
        0xffFF80FF, -- magenta
        0xffFF6060, -- red
        0xffFFA100, -- orange
        0xffFFFF80, -- yellow
        0xff40FF40  -- green
    }
    local directions = {[0]="V", [1]=">", [2]="^", [3]="<"}
    -- Title
    draw.text(table_x, table_y - BIZHAWK_FONT_HEIGHT, "Objects:")
    -- Main object loop
    for slot = 0x0, 0x05-1 do
        -- Read RAM
        local x_pos = u8(RAM.objects_x_pos + 1 + 2*slot)
        local y_pos = u8(RAM.objects_y_pos + 1 + 2*slot)
        local x_subpos = u8(RAM.objects_x_pos + 2*slot)
        local y_subpos = u8(RAM.objects_y_pos + 2*slot)
        local active = u8(RAM.objects_active + slot) == 1
        
        -- Calculations
        local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
        local is_on_screen = (x_pos - Camera_x > 0) and (x_pos - Camera_x < GB_WIDTH)
        
        -- Fade slots not used in the current level
        local empty_slot = x_pos == 0x000 and y_pos == 0x000
        
        -- Get display colour
        local colour = colours[slot%6+1]
        if not is_on_screen or not active then colour = colour - 0x80000000 end
        if empty_slot then colour = 0x80FFFFFF end
        
        -- Display pixel position on screen
        if not empty_slot then
            draw.cross(x_screen, -8 + y_screen, 2, colour)
        end
        
        -- Display slot and nickname near positon on screen
        if not empty_slot then
            draw.pixel_text(x_screen + 2, -16 + y_screen, fmt("%02X", slot), colour)
        end
        
        -- Display object table
        draw.text(table_x, table_y + slot * BIZHAWK_FONT_HEIGHT, fmt("#%02X: (%02X.%02x, %02X.%02x)", slot, x_pos, x_subpos, y_pos, y_subpos, direction), colour)
    end
    
    
    --- TAStudio extra column(s) export (DON'T FORGET EACH ONE NEEDS TO BE INITIALIZED)
    local x_speed_dec = tonumber(x_speed_str:gsub("%.", ""), 16)/0x100
    local y_speed_dec = tonumber(y_speed_str:gsub("%.", ""), 16)/0x100
    Column.x_speed[Framecount] = x_speed_dec
    Column.x_speed_str[Framecount] = x_speed_str
    Column.y_speed[Framecount] = y_speed_dec
    Column.y_speed_str[Framecount] = y_speed_str
    Column.status[Framecount] = player_status
    Column.status_str[Framecount] = fmt("%s", player_status)
    
    
    --- CHEAT
    -- Global cheat warning
    if OPTIONS.CHEATS then
        draw.text(PC.screen_middle_x - string.len("Cheats allowed!")*BIZHAWK_FONT_WIDTH/2, 0, "Cheats allowed!", "red")
    end
    
    -- Read input
    local input = joypad.get();
    input.left = input["P1 Left"]
    input.right = input["P1 Right"]
    input.up = input["P1 Up"]
    input.down = input["P1 Down"]
    input.a = input["P1 A"]
    input.b = input["P1 B"]
    input.start = input["P1 Start"]
    input.select = input["P1 Select"]
    
    -- Free moving cheat
    if OPTIONS.CHEATS and input.select and not input.a then
        -- Get current position
        local x_pos, y_pos = X_pos, Y_pos
        -- Set movement speed
        local speed = input.b and 0x08 or 0x01  -- how many pixels per frame
        -- Math
        if input.left then x_pos = x_pos - speed end --; w8_sram(SRAM.direction, 2)  end
        if input.right then x_pos = x_pos + speed end --; w8_sram(SRAM.direction, 0) end
        if input.up then y_pos = y_pos - speed end
        if input.down then y_pos = y_pos + speed end
        -- Manipulate the addresses
        w8(RAM.x_pos, x_pos) --\ setting the coordinates
        w8(RAM.y_pos, y_pos) --/
        w8(RAM.x_speed, 0) -----\ disabling normal horizontal speed
        w8(RAM.x_subspeed, 0) --/
        w8(RAM.y_speed, 0) -- accounting for gravity, otherwise it keeps falling
        w8(RAM.y_subspeed, 0) -- accounting for gravity, otherwise it keeps falling
        -- Display cheat warning
        gui.drawText(Game.left_padding, Game.top_padding, "CHEAT: FREE MOVEMENT", "red", 0x80000000, 11, "Consolas")
    end
    
    -- Beat level cheat
    if OPTIONS.CHEATS and input.select and input.a then
        -- Manipulate the addresses
        w16(RAM.x_pos, exit_x)
        w16(RAM.y_pos, exit_y)
        -- Display cheat warning
        gui.drawText(Game.left_padding, Game.top_padding, "CHEAT: BEAT LEVEL", "red", 0x80000000, 11, "Consolas")
    end
end


--################################################################################################################################################################
-- MAIN

-- Create lateral gaps
client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)

-- Functions to run when script is stopped or reset
event.onexit(function()
  
    forms.destroyall()
  
    --gui.clearImageCache()
    
    gui.clearGraphics()
  
	client.SetGameExtraPadding(0, 0, 0, 0)
  
    print("\nFinishing Super Hard Bouncer Utility Script.\n------------------------------------")
end)

-- Add column(s) for useful info on TAStudio piano roll
tastudio.addcolumn("x_speed", "X spd", 40)
tastudio.addcolumn("y_speed", "Y spd", 40)
tastudio.addcolumn("status", "Status", 50)

-- Function to update column(s) text
local function column_text(frame, column_name)
    -- x_speed column
    if column_name == "x_speed" then
        if Column.x_speed_str[frame] == nil then
            return ""
        else
            return " " .. Column.x_speed_str[frame]
        end
    end
    
    -- y_speed column
    if column_name == "y_speed" then
        if Column.y_speed_str[frame] == nil then
            return ""
        else
            return " " .. Column.y_speed_str[frame]
        end
    end
    
    -- status column
    if column_name == "status" then
        if Column.status_str[frame] == nil then
            return ""
        else
            return " " .. Column.status_str[frame]
        end
    end
    
    -- Default
    return nil
end

-- Function to update column(s) colour
local function column_colour(frame, column_name)
    -- x_speed column
    if column_name == "x_speed" then
        if Column.x_speed[frame] ~= nil then
            return gradient_good_bad(math.abs(Column.x_speed[frame]), 1.0625)
        else
            return "0xffFFFFFF" -- white
        end
    end
    
    -- y_speed column
    if column_name == "y_speed" then
        if Column.y_speed[frame] ~= nil then
            if Column.y_speed[frame] ~= 0x00 then
                return gradient_good(-(Column.y_speed[frame]), 2.0)
            else
                return "0xffFFFFFF" -- white
            end
        else
            return "0xffFFFFFF" -- white
        end
    end
    
    -- status column
    if column_name == "status" then
        if Column.status[frame] ~= nil then
            return gradient_good_bad((Column.status[frame]+1)%3, 2)
        else
            return "0xffFFFFFF" -- white
        end
    end
    
    -- Default
    return nil
end

-- Add "hooks" for updating the new column(s) on TAStudio
if tastudio.engaged() then
    tastudio.onqueryitemtext(column_text)
    tastudio.onqueryitembg(column_colour)
end

-- Script load success message (NOTHING AFTER HERE, ONLY MAIN SCRIPT LOOP)
print("\n\nSuper Hard Bouncer Utility Script loaded successfully at " .. os.date("%X") .. ".\n") -- %c for date and time

-- Main loop
while true do
    -- Prevent cheats while recording movie
    if movie.isloaded() then OPTIONS.CHEATS = false end
    -- Read very important emu stuff
    biz.screen_info()
    biz.movie_status()
    Generic_previous = Generic_current
    -- Update main game values and display these stuff
    main_game_scan()
    main_display()
    -- DEBUG
    
    -- Advance The Frame
    emu.frameadvance()
end


