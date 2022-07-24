--####################################################################
--##                                                                ##
--##   Capybara Quest (GBC) Script for BizHawk                      ##
--##   https://maxthetics.itch.io/capybara-quest                    ##
--##   http://tasvideos.org/Bizhawk.html                            ##
--##                                                                ##
--##   Author: Bruno Valadão Cunha (BrunoValads) [06/2022]          ##
--##                                                                ##
--##   Git repository: https://github.com/brunovalads/tas-scripts   ##
--##                                                                ##
--####################################################################

--################################################################################################################################################################
-- INITIAL STATEMENTS

-- Script options
local OPTIONS = {
    
    -- Script settings
    left_gap = 120, 
    right_gap = 100,
    top_gap = 50,
    bottom_gap = 50,
    framerate = 59.727500569606,
    
    ---- DEBUG AND CHEATS ----
    DEBUG = false, -- to display debug info for script development only!
    CHEATS = true, -- to help research, ALWAYS DISABLED WHEN RECORDING MOVIES
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
memory.usememorydomain("WRAM") -- in Gambatte "System Bus" is default
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
local BIZHAWK_FONT_WIDTH = 10  -- correction to the scale is done in bizhawk_screen_info()
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


--################################################################################################################################################################
-- GENERAL UTILITIES

-- Get screen dimensions of the emulator and the game
local PC, Game = {}, {}
local Scale
local function bizhawk_screen_info()
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
local function bizhawk_status()
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
	elseif value  < max_value/2 then
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
    camera_x = 0x075F, -- 2 bytes,
    camera_y = 0x0761, -- 2 bytes,
    camera_x_with_shake = 0x0763, -- 2 bytes
    camera_y_with_shake = 0x0765, -- 2 bytes
    level = 0x0, -- couldn't figure out
    level_width = 0x0506, -- 2 bytes, in pixels
    level_height = 0x0508, -- 2 bytes, in pixels
    is_paused = 0x041C,
    reading_flag = 0x0B15,
    text_is_ready_flag = 0x08A7,
    controller = 0x05A7,
    is_level_mode = 0x050E,
    level_identifier = 0x0500,
    fade_phase = 0x05A3,
    fade_timer = 0x05A4,
    window_y_pos = 0x08A4, -- "window" is the second layer of GB's GPU
    window_y_pos_to_be = 0x08A5,
    yuzu_total = 0x0B1C, -- 2 bytes, you can trick the game to think you got all the 19 (0x13) yuzus by simply going back and forth in the same yuzu, it will increment this value
    yuzu_flags = 0x0B1E, -- 0x26 bytes (last: 0x0B43), 2 bytes per level
    
    -- Player (0x32 bytes table, the play is actually the real first entry in the object list)
    base = 0x00B7,
    x_pos = 0x00BA, -- 2 bytes
    y_pos = 0x00BC, -- 2 bytes
    direction = 0x00BE, -- 01 = right, 03 = left
    on_ground = 0x1920, --
    climbing = 0x1921, --
    x_speed = 0x1923, --
    x_subspeed = 0x1922, -- ?
    y_speed = 0x1925, --
    y_subspeed = 0x1924, -- ?
    x_speed_cap = 0x1929, --
    disabled = 0x1952, --
    animation_frame = 0x00C4, -- 
    crouching = 0x00C1, --
    
    -- Objects (0x32 bytes per entry, 0x14 entries, apparently)
    objects_some_pointer = 0x00E9 + 0x00, -- 0x00E9 some pointer (WRAM? because >$C000)
    objects_some_pointer_h = 0x00E9 + 0x01, -- 0x00EA (high)
    objects_flags = 0x00E9 + 0x02, -- 0x00EB
    objects_x_pos = 0x00E9 + 0x03, -- 0x00EC, 2 bytes
    objects_x_pos_h = 0x00E9 + 0x04, -- 0x00ED (high)
    objects_y_pos = 0x00E9 + 0x05, -- 0x00EE, 2 bytes
    objects_y_pos_h = 0x00E9 + 0x06, -- 0x00EF (high)
    objects_direction = 0x00E9 + 0x07, -- 0x00F0
    -- 0x00E9 + 0x08, -- 0x00F1 
    -- 0x00E9 + 0x09, -- 0x00F2 
    -- 0x00E9 + 0x0A, -- 0x00F3 
    -- 0x00E9 + 0x0B, -- 0x00F4 
    objects_index_to_anim_frame = 0x00E9 + 0x0C, -- 0x00F5
    objects_anim_frame = 0x00E9 + 0x0D, -- 0x00F6 
    -- 0x00E9 + 0x0E, -- 0x00F7 
    -- 0x00E9 + 0x0F, -- 0x00F8 
    -- 0x00E9 + 0x10, -- 0x00F9 
    objects_speed = 0x00E9 + 0x11, -- 0x00FA 
    -- 0x00E9 + 0x12, -- 0x00FB 
    -- 0x00E9 + 0x13, -- 0x00FC 
    -- 0x00E9 + 0x14, -- 0x00FD 
    -- 0x00E9 + 0x15, -- 0x00FE 
    -- 0x00E9 + 0x16, -- 0x00FF 
    -- 0x00E9 + 0x17, -- 0x0100 
    -- 0x00E9 + 0x18, -- 0x0101 
    -- 0x00E9 + 0x19, -- 0x0102 
    -- 0x00E9 + 0x1A, -- 0x0103 
    -- 0x00E9 + 0x1B, -- 0x0104 
    -- 0x00E9 + 0x1C, -- 0x0105 
    -- 0x00E9 + 0x1D, -- 0x0106 
    -- 0x00E9 + 0x1E, -- 0x0107 
    -- 0x00E9 + 0x1F, -- 0x0108 
    -- 0x00E9 + 0x20, -- 0x0109 
    -- 0x00E9 + 0x21, -- 0x010A 
    -- 0x00E9 + 0x22, -- 0x010B 
    -- 0x00E9 + 0x23, -- 0x010C 
    -- 0x00E9 + 0x24, -- 0x010D 
    objects_type_pointer = 0x00E9 + 0x25, -- 0x010E, 2 bytes
    objects_type_pointer_h = 0x00E9 + 0x26, -- 0x010F (high)
    -- 0x00E9 + 0x27, -- 0x0110 
    -- 0x00E9 + 0x28, -- 0x0111 
    -- 0x00E9 + 0x29, -- 0x0112 
    -- 0x00E9 + 0x2A, -- 0x0113 
    -- 0x00E9 + 0x2B, -- 0x0114 
    -- 0x00E9 + 0x2C, -- 0x0115 
    -- 0x00E9 + 0x2D, -- 0x0116 
    objects_moving = 0x00E9 + 0x2E, -- 0x0117 
    -- 0x00E9 + 0x2F, -- 0x0118 
    -- 0x00E9 + 0x30, -- 0x0119 
    -- 0x00E9 + 0x31, -- 0x011A 
    -- 0x00E9 + 0x32, -- 0x011B 
    
    -- Cannonballs (0x25 bytes per entry, 3 entries, apparently)
    cannonballs_some_pointer = 0x0672 + 0x00, -- 0x0672, 2 bytes
    cannonballs_some_pointer_h = 0x0672 + 0x01, -- 0x0673, (high)
    -- 0x0672 + 0x02, -- 0x0674, 
    cannonballs_x_pos = 0x0672 + 0x03, -- 0x0675, 2 bytes
    cannonballs_x_pos_h = 0x0672 + 0x04, -- 0x0676, (high)
    cannonballs_y_pos = 0x0672 + 0x05, -- 0x0677, 2 bytes
    cannonballs_y_pos_h = 0x0672 + 0x06, -- 0x0678, (high)
    -- 0x0672 + 0x07, -- 0x0679, 
    -- 0x0672 + 0x08, -- 0x067A, 
    -- 0x0672 + 0x09, -- 0x067B, 
    -- 0x0672 + 0x0A, -- 0x067C, 
    -- 0x0672 + 0x0B, -- 0x067D, 
    -- 0x0672 + 0x0C, -- 0x067E, 
    -- 0x0672 + 0x0D, -- 0x067F, 
    -- 0x0672 + 0x0E, -- 0x0680, 
    -- 0x0672 + 0x0F, -- 0x0681, 
    -- 0x0672 + 0x10, -- 0x0682, 
    -- 0x0672 + 0x11, -- 0x0683, 
    -- 0x0672 + 0x12, -- 0x0684, 
    -- 0x0672 + 0x13, -- 0x0685, 
    -- 0x0672 + 0x14, -- 0x0686, 
    cannonballs_timer = 0x0672 + 0x15, -- 0x0687, 
    -- 0x0672 + 0x16, -- 0x0688, 
    -- 0x0672 + 0x17, -- 0x0689, 
    -- 0x0672 + 0x18, -- 0x068A, 
    -- 0x0672 + 0x19, -- 0x068B, 
    -- 0x0672 + 0x1A, -- 0x068C, 
    -- 0x0672 + 0x1B, -- 0x068D, 
    -- 0x0672 + 0x1C, -- 0x068E, 
    -- 0x0672 + 0x1D, -- 0x068F, 
    -- 0x0672 + 0x1E, -- 0x0690, 
    -- 0x0672 + 0x1F, -- 0x0691, 
    -- 0x0672 + 0x20, -- 0x0692, 
    -- 0x0672 + 0x21, -- 0x0693, 
    -- 0x0672 + 0x22, -- 0x0694, 
    -- 0x0672 + 0x23, -- 0x0695, 
    -- 0x0672 + 0x24, -- 0x0696, 
}

-- Data for all levels
local Level = {}
Level.data = {
    ["4722F05EC824"] = {id = 01, name = "Sunlight Plains - 1"  , objects = 07, width = 0x0640, height = 0x0120},
    ["63231840C824"] = {id = 02, name = "Sunlight Plains - 2"  , objects = 07, width = 0x0640, height = 0x0120},
    ["47234063C824"] = {id = 03, name = "Sunlight Plains - 3"  , objects = 07, width = 0x0640, height = 0x0120},
    ["711100403C3C"] = {id = 04, name = "Sunlight Plains - 4"  , objects = 07, width = 0x01E0, height = 0x01E0},
    ["63242047C824"] = {id = 05, name = "Sunlight Plains - 5"  , objects = 09, width = 0x0640, height = 0x0120},
    
    ["47200040C824"] = {id = 06, name = "Shadowy Forest - 1"   , objects = 11, width = 0x0640, height = 0x0120},
    ["6320285CC824"] = {id = 07, name = "Shadowy Forest - 2"   , objects = 11, width = 0x0640, height = 0x0120},
    ["46211E47C824"] = {id = 08, name = "Shadowy Forest - 3"   , objects = 09, width = 0x0640, height = 0x0120},
    ["63213E63C824"] = {id = 09, name = "Shadowy Forest - 4"   , objects = 11, width = 0x0640, height = 0x0120},
    ["6222D042C824"] = {id = 10, name = "Shadowy Forest - 5"   , objects = 10, width = 0x0640, height = 0x0120},
    
    ["4A11104E3CC6"] = {id = 11, name = "Snowy Peaks - 1"      , objects = 11, width = 0x01E0, height = 0x0630},
    ["4B1264403CC6"] = {id = 12, name = "Snowy Peaks - 2"      , objects = 15, width = 0x01E0, height = 0x0630},
    ["451300403CC6"] = {id = 13, name = "Snowy Peaks - 3"      , objects = 20, width = 0x01E0, height = 0x0630},
    ["4014B84D3CC6"] = {id = 14, name = "Snowy Peaks - 4"      , objects = 18, width = 0x01E0, height = 0x0630},
    ["4A15134D3CC6"] = {id = 15, name = "Snowy Peaks - 5"      , objects = 16, width = 0x01E0, height = 0x0630},
    
    ["42050640C644"] = {id = 16, name = "Construction Site - 1", objects = 16, width = 0x0630, height = 0x0220},
    ["40060640C644"] = {id = 17, name = "Construction Site - 2", objects = 15, width = 0x0630, height = 0x0220},
    ["43070040C644"] = {id = 18, name = "Construction Site - 3", objects = 14, width = 0x0630, height = 0x0220},
    ["43080040C644"] = {id = 19, name = "Construction Site - 4", objects = 16, width = 0x0630, height = 0x0220},
}
Level.dimensions = {}
for k, data in pairs(Level.data) do
    Level.dimensions[data.id] = {width = data.width, height = data.height} -- entry example: [07] = {width = 0x0640, height = 0x0120}
end

--[[
-- Overall progress record, to handle resetting the script without losing progress per level (RESEARCH)
Level.done = {
    [01] = true,
    [02] = true,
    [03] = true,
    [04] = true,
    [05] = true,
    [06] = true,
    [07] = true,
    [08] = true,
    [09] = true,
    [10] = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [14] = true,
    [15] = true,
    [16] = true,
    [17] = true,
    [18] = true,
    [19] = true
}

-- Init level screenshot progress, to make the level map later (RESEARCH)
Level.screenshots = {}
Level.progress = {}
Level.progress_sum = {}
for id = 01, 19 do
    -- Init screenshot coordinates
    Level.screenshots[id] = {}
    -- Init screenshot area flags
    Level.progress[id] = {}
    for y = 0, Level.dimensions[id].height-1 do
        Level.progress[id][y] = {}
        for x = 0, Level.dimensions[id].width-1 do
            Level.progress[id][y][x] = Level.done[id] and 1 or 0
        end
    end
    -- Init screenshot area sum
    Level.progress_sum[id] = Level.done[id] and (Level.dimensions[id].width*Level.dimensions[id].height) or 0
end
]]

-- Objects data, indexed by type_ptr (RAM.objects_type_pointer)
local Objects = {
    [0x0000] = {name = "[empty]", nickname = "[]"},
    [0x71A1] = {name = "Capybara (sleeping)", nickname = "Capy"},
    [0x71F0] = {name = "Springboard", nickname = "Spring"},
    [0x7223] = {name = "Baby Capybara", nickname = "Baby"},
    [0x7264] = {name = "Heart", nickname = "Heart"},
    [0x72D8] = {name = "Save computer", nickname = "Save"},
    [0x730B] = {name = "Sign", nickname = "Sign"},
    [0x74EB] = {name = "Turnip Bandit", nickname = "Bandit"},
    [0x7C8A] = {name = "Skeleton", nickname = "Skelet"},
    [0x7CED] = {name = "Cannon", nickname = "Cannon"},
    [0x7D3E] = {name = "Yuzu", nickname = "Yuzu"},
    [0x7DA9] = {name = "Bat", nickname = "Bat"},
    [0x7DFA] = {name = "Flag", nickname = "Flag"},
    [0x7E68] = {name = "Capybara", nickname = "Capy"},
    [0x7E85] = {name = "???", nickname = "???"},
}


-- Converts the in-game (x, y) to emu-screen coordinates
local function screen_coordinates(x, y, camera_x, camera_y)
  local x_screen = (x - camera_x)
  local y_screen = (y - camera_y)

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
    X_pos = u16(RAM.x_pos)
    Y_pos = u16(RAM.y_pos)
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
Column.on_ground = {}
Column.disabled = {}
Column.animation_frame = {}
Column.climbing = {}

-- Main display function, ALL DRAWINGS SHOULD BE CALLED HERE
local function main_display()
    --- Movie timer
    local timer_str = frame_time(Framecount, true)
    draw.text(0, 0, fmt("%s", timer_str), "white", "bottomright")
    
    --- Check if is level mode
    local is_level_mode = u8(RAM.is_level_mode) ~= 0x00
    if not is_level_mode then gui.clearGraphics() ; return end
    
    --- Dark filter
    local filter_alpha = 0x55
    draw.rectangle(OPTIONS.left_gap, OPTIONS.top_gap, 256, 224, filter_alpha*0x1000000, filter_alpha*0x1000000)
    --[[
    --- Block grid
    local block_id, block_type
    local colour_border, colour_fill
    for y = 0, 14 do
        for x = 0, 15 do
            -- Get the colour according to the block type
            block_id = y*16 + x
            block_type = u8(RAM.blocks + block_id)
            if block_type == 0 then
                colour_border, colour_fill = 0x80808080, nil
            elseif block_type == 1 then
                colour_border, colour_fill = 0x80FF0000, 0x60FF0000
            elseif block_type == 2 then
                colour_border, colour_fill = 0x8000FF00, 0x6000FF00
            else
                colour_border, colour_fill = 0x8000FFFF, nil --0x8000FFFF
            end
            
            -- Draw the grid
            if block_type ~= 0 then
                draw.rectangle(OPTIONS.left_gap + x*16, OPTIONS.top_gap - 8 + y*16, 15, 15, colour_border, colour_fill)
            end
            
            -- Draw the minimap
            draw.pixel(1 + x, 70 + y, colour_border)
        end
    end
    ]]
    --[[
    --- Block grid
    local x_origin, y_origin = screen_coordinates(0, 0, Camera_x, Camera_y)
    --local colour_border, colour_fill = 0x80808080, nil
    local colour_border = {[0] = 0xc0FF0000, [1] = 0xc000FF00}
    local camera_x_offset = Camera_x - floor(Camera_x/0x10)*0x10
    local camera_y_offset = Camera_y - floor(Camera_y/0x10)*0x10
    for block_y = 0, 8+1 do
        for block_x = 0, 9+1 do
            draw.rectangle(OPTIONS.left_gap + block_x*16 - camera_x_offset, OPTIONS.top_gap + block_y*16 - camera_y_offset, 15, 15, colour_border[(block_x + block_y%2)%2], nil)
        end
    end
    --]]
    --if is_inside_rectangle(x_screen, y_screen, -16, -16, Screen_width + 16, Screen_height + 16) then -- to prevent drawing for the whole level
                --x_screen, y_screen = screen_coordinates(x_pos, y_pos, camera_x, camera_y)
    
    --- Player info
    -- Read RAM
    local x_pos_raw = X_pos
    local y_pos_raw = Y_pos
    local x_speed = s8(RAM.x_speed)
    local y_speed = s8(RAM.y_speed)
    local on_ground = u8(RAM.on_ground) == 1
    local climbing = u8(RAM.climbing) == 1
    local player_dir = u8(RAM.direction)
    local disabled = u8(RAM.disabled) == 0
    local is_crouching = u8(RAM.crouching) == 0
    local animation_frame = u8(RAM.animation_frame)
    
    -- RAM that need calc
    local x_pos, y_pos = floor(x_pos_raw/0x10), floor(y_pos_raw/0x10)
    local x_subpos, y_subpos = x_pos_raw - x_pos*0x10, y_pos_raw - y_pos*0x10
    local dx_pos_raw = X_pos - X_pos_prev
    local dy_pos_raw = Y_pos - Y_pos_prev
    local x_screen_player, y_screen_player = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
    local x_speed_str = signed8hex(u8(RAM.x_speed))
    local y_speed_str = signed8hex(u8(RAM.y_speed))
    
    -- Display player info
    local i = 0
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Pos: %03X.%x, %03X.%x %s", x_pos, x_subpos, y_pos, y_subpos, player_dir == 1 and ">" or "<")); i = i + 1
    --draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Speed: %+X, %+X", x_speed, y_speed)); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Speed: %s, %s", x_speed_str, y_speed_str)); i = i + 1
    --draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Delta: %+X, %+X", dx_pos_raw, dy_pos_raw)); i = i + 1
    --draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Delta: %s, %s", signed8hex(dx_pos_raw, true), signed8hex(dy_pos_raw, true))); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("On ground: %s", on_ground and "yes" or "no")); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Climbing: %s", climbing and "yes" or "no")); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Disabled: %s", disabled and "yes" or "no"), disabled and (animation_frame == 0x0B and 0xff00FF00 or "red") or "white"); i = i + 1
    
    -- Show position on screen
    draw.cross(OPTIONS.left_gap + x_screen_player, OPTIONS.top_gap - 8 + y_screen_player, 2, "orange")
    
    -- and solid interaction points
    draw.cross(OPTIONS.left_gap + x_screen_player - 0x0, OPTIONS.top_gap - 8 + y_screen_player + 0xf, 2, "blue") -- bottom left
    draw.cross(OPTIONS.left_gap + x_screen_player + 0xf, OPTIONS.top_gap - 8 + y_screen_player + 0xf, 2, "blue") -- bottom right
    if is_crouching then
        draw.cross(OPTIONS.left_gap + x_screen_player - 0x0, OPTIONS.top_gap - 8 + y_screen_player + 0x8, 2, "blue") -- top left, same as the real position
        draw.cross(OPTIONS.left_gap + x_screen_player + 0xf, OPTIONS.top_gap - 8 + y_screen_player + 0x8, 2, "blue") -- top right
    else
        --draw.cross(OPTIONS.left_gap + x_screen_player - 0x0, OPTIONS.top_gap - 8 + y_screen_player - 0x0, 2, "blue") -- top left, same as the real position
        draw.cross(OPTIONS.left_gap + x_screen_player + 0xf, OPTIONS.top_gap - 8 + y_screen_player - 0x0, 2, "blue") -- top right
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
    -- Get which level is running -- TODO: could be done inside main_game_scan
    local level_identifier = ""
    for addr = RAM.level_identifier, RAM.level_identifier + 5 do
        level_identifier = level_identifier .. fmt("%02X", u8(addr))
    end
    local level_id = 0
    local level_name = "_____"
    local level_width, level_height = 0, 0
    if Level.data[level_identifier] then
        level_id = Level.data[level_identifier].id
        level_name = Level.data[level_identifier].name
        level_width = u16(RAM.level_width) -- could be Level.data[level_identifier].width
        level_height = u16(RAM.level_height) -- could be Level.data[level_identifier].height
    end
    
    -- Display the level info
    local colour = Level.data[level_identifier] and "white" or "red"
    local level_str = fmt("Level: %02d (%s)", level_id, level_name)
    draw.text(PC.buffer_middle_x - BIZHAWK_FONT_WIDTH*string.len(level_str)/2, PC.bottom_padding_start, level_str, colour)
    
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
    local yuzu_taken = false
    local have_cannons = false
    local ending_x, ending_y = 0, 0
    --local anim_frames, type_ptrs = {}, {} -- RESEARCH/REMOVE
    for slot = 0x0, 0x13 do
        -- Fade slots not used in the current level
        local empty_slot = false
        if Level.data[level_identifier] then
            if slot+1 > Level.data[level_identifier].objects then
                empty_slot = true
                --break
            end
        end
        
        -- Read RAM
        local offset = slot*0x32
        local x_pos_raw = u16(RAM.objects_x_pos + offset)
        local y_pos_raw = u16(RAM.objects_y_pos + offset)
        local flags = u8(RAM.objects_flags + offset)
        local type_ptr = u16(RAM.objects_type_pointer + offset)
        local direction = u8(RAM.objects_direction + offset)
        local speed = u8(RAM.objects_speed + offset)
        local anim_frame = u8(RAM.objects_anim_frame + offset)
        
        -- Calculations
        local x_pos, y_pos = floor(x_pos_raw/0x10), floor(y_pos_raw/0x10)
        local x_subpos, y_subpos = x_pos_raw - x_pos*0x10, y_pos_raw - y_pos*0x10
        local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
        local is_processed = bit.check(flags, 0)
        
        -- Get display colour
        local colour = colours[slot%6+1]
        if not is_processed then colour = colour - 0x80000000 end
        if empty_slot then colour = 0x80FFFFFF end
        
        -- Get direction
        direction = directions[direction] and directions[direction] or " "
        
        -- Get name and nickname
        local name, nickname = "____________", "_____"
        if Objects[type_ptr] then
            name = Objects[type_ptr].name
            nickname = Objects[type_ptr].nickname
        end
        if empty_slot then name = "[empty]" end
        
        -- Display pixel position on screen
        if not empty_slot then
            draw.cross(OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, 2, colour)
        end
        
        -- Display hitbox (and some extra info) on screen, if object is being processed/rendered
        if is_processed and not empty_slot then
            --draw.rectangle(OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, 15, 15, colour-0x80000000)
            -- Special cases:
            -- for Save Computers and Signs
            if type_ptr == 0x72D8 or type_ptr == 0x730B then
                if player_dir == 1 then -- player is facing right
                    draw.rectangle(OPTIONS.left_gap + x_screen - 8, OPTIONS.top_gap - 8 + y_screen, 15+8, 15, colour-0x80000000)
                else
                    draw.rectangle(OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, 15+8, 15, colour-0x80000000)
                end
            -- for Flags and Baby Capybara
            elseif type_ptr == 0x7DFA or type_ptr == 0x7223 then
                draw.line(OPTIONS.left_gap + x_screen - 0x29, OPTIONS.top_gap - 24 + y_screen, OPTIONS.left_gap + x_screen - 0x29, OPTIONS.top_gap + 7 + y_screen, colour)
                draw.pixel_text(OPTIONS.left_gap + x_screen - 0x27, OPTIONS.top_gap - 24 + y_screen, "AAA here", colour)
                draw.rectangle(OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, 15, 15, colour-0x80000000)
            -- Everyone else
            else
                draw.rectangle(OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, 15, 15, colour-0x80000000)
            end
        end
        
        -- Display slot and nickname near positon on screen
        if not empty_slot then
            draw.pixel_text(OPTIONS.left_gap + x_screen + 2, OPTIONS.top_gap - 16 + y_screen, fmt("%02X", slot), colour)
            draw.pixel_text(OPTIONS.left_gap + x_screen, OPTIONS.top_gap + 09 + y_screen, fmt("%s", nickname), colour)
        end
        
        -- DEBUG
        local debug_str = ""
        if OPTIONS.DEBUG then
            for addr = 0, 0x32-1 do
                local value = u8(0x00E9 + offset + addr)
                debug_str = debug_str .. fmt("%02X ", value)
                if slot == 0 then -- could be any, just want to do this once
                    -- Check if address is already documented
                    local documented = false
                    for k, v in pairs(RAM) do
                        if 0x00E9 + addr == v then documented = true end
                    end
                    draw.text(table_x + 23*BIZHAWK_FONT_WIDTH + addr*3*BIZHAWK_FONT_WIDTH, table_y + (slot-1) * BIZHAWK_FONT_HEIGHT, fmt("%02X", addr), documented and 0xff00FF00 or "white")
                end
            end
            debug_str = debug_str .. fmt("$%04X ", 0xC000 + 0x00E9 + offset)
            
            --type_ptrs[slot] = type_ptr -- RESEARCH/REMOVE
            --anim_frames[slot] = anim_frame -- RESEARCH/REMOVE
        end
        
        -- Display object table
        draw.text(table_x, table_y + slot * BIZHAWK_FONT_HEIGHT, fmt("#%02X: (%03X.%x, %03X.%x) %s %s %s", slot, x_pos, x_subpos, y_pos, y_subpos, direction, OPTIONS.DEBUG and "" or name, debug_str), colour)
        
        -- Check if yuzu was taken in this level (could use RAM.yuzu_flags), and draw direction line if not taken
        if type_ptr == 0x7D3E and not empty_slot then
            if bit.check(flags, 2) then
                yuzu_taken = true
            else
                draw.line(OPTIONS.left_gap + x_screen_player, OPTIONS.top_gap - 8 + y_screen_player, OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, colour-0xFF000000)
            end
        end

        -- Check if there is at least a cannon in this level, in order to display cannonballs later
        if type_ptr == 0x7CED then
            have_cannons = true
        end
        
        -- Store the level ending position (Flag or Baby Capybara)
        if (type_ptr == 0x7DFA or type_ptr == 0x7223) and not empty_slot then
            ending_x, ending_y = x_pos_raw, y_pos_raw
        end
    end
    
    --- Display yuzu info
    i = i - 3
    local yuzu_taken = u16(RAM.yuzu_flags + (level_id-1)*2) ~= 0x00
    local yuzu_total = u16(RAM.yuzu_total)
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Yuzu taken: %s", yuzu_taken and "yes" or "no"), yuzu_taken and 0xff00FF00 or "red")
    local colour = 0xff00FF00
    if yuzu_taken and yuzu_total ~= level_id then
        colour = "red"
    elseif not yuzu_taken and yuzu_total == level_id-1 then
        colour = 0xffFFA100
    elseif math.abs(yuzu_total - level_id) >= 2 then
        colour = "red"
    end
    draw.text(2 + 16*BIZHAWK_FONT_WIDTH, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("(%02d/19)", yuzu_total), colour); i = i + 1
    
    
    --- Display cannoballs info
    if have_cannons then
        -- Set display constants
        local table_x = 2
        local table_y = OPTIONS.DEBUG and (PC.bottom_padding_start + (2 + 0x14 + 2)*BIZHAWK_FONT_HEIGHT) or (60 + 30*BIZHAWK_FONT_HEIGHT)
        
        -- Title
        draw.text(table_x, table_y - BIZHAWK_FONT_HEIGHT, "Cannonballs:")
        
        -- Cannoballs loop
        for slot = 0, 2 do
            -- Read RAM
            local offset = slot*0x25
            local x_pos_raw = u16(RAM.cannonballs_x_pos + offset)
            local y_pos_raw = u16(RAM.cannonballs_y_pos + offset)
            local timer = u8(RAM.cannonballs_timer + offset)
        
            -- Calculations
            local x_pos, y_pos = floor(x_pos_raw/0x10), floor(y_pos_raw/0x10)
            local x_subpos, y_subpos = x_pos_raw - x_pos*0x10, y_pos_raw - y_pos*0x10
            local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
            
            -- Fade slots not used
            local empty_slot = false
            if (timer == 0x00) or (x_screen < -0x08) or (x_screen > 0x98) or (y_screen < -0x08) or (y_screen > 0x88) then
                empty_slot = true
            end
            
            -- Get display colour
            local colour = 0xff00FFFF
            if empty_slot then colour = 0x80FFFFFF end
            
            -- Display pixel position, hitbox and slot on screen
            if not empty_slot then
                draw.cross(OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, 2, colour)
                draw.rectangle(OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, 15, 15, colour-0x80000000)
                draw.pixel_text(OPTIONS.left_gap + x_screen + 2, OPTIONS.top_gap - 16 + y_screen, fmt("%X", slot, x_screen, y_screen), colour)
            end
            
            -- DEBUG
            local debug_str = ""
            if OPTIONS.DEBUG then
                for addr = 0, 0x25-1 do
                    local value = u8(0x0672 + offset + addr)
                    debug_str = debug_str .. fmt("%02X ", value)
                    if slot == 0 then -- could be any, just want to do this once
                        -- Check if address is already documented
                        local documented = false
                        for k, v in pairs(RAM) do
                            if 0x0672 + addr == v then documented = true end
                        end
                        draw.text(table_x + 19*BIZHAWK_FONT_WIDTH + addr*3*BIZHAWK_FONT_WIDTH, table_y + (slot-1) * BIZHAWK_FONT_HEIGHT, fmt("%02X", addr), documented and 0xff00FF00 or "white")
                    end
                end
                debug_str = debug_str .. fmt("$%04X ", 0xC000 + 0x0672 + offset)
            end
            
            -- Display cannoball table
            draw.text(table_x, table_y + slot * BIZHAWK_FONT_HEIGHT, fmt("#%X: (%03X.%x, %03X.%x) %s", slot, x_pos, x_subpos, y_pos, y_subpos, debug_str), colour)
            
        end
    end
    
    --- TAStudio extra column(s) export (DON'T FORGET EACH ONE NEEDS TO BE INITIALIZED)
    Column.x_speed[Framecount] = x_speed
    Column.x_speed_str[Framecount] = x_speed_str
    Column.y_speed[Framecount] = y_speed
    Column.y_speed_str[Framecount] = y_speed_str
    Column.on_ground[Framecount] = on_ground
    Column.disabled[Framecount] = disabled
    Column.animation_frame[Framecount] = animation_frame
    Column.climbing[Framecount] = climbing
    
    
    --- RESEARCH
    local controller = u8(RAM.controller)
    local button_Right = bit.check(controller, 0)
    local button_Left = bit.check(controller, 1)
    local button_Up = bit.check(controller, 2)
    local button_Down = bit.check(controller, 3)
    local button_A = bit.check(controller, 4)
    local button_B = bit.check(controller, 5)
    local button_Select = bit.check(controller, 6)
    local button_Start = bit.check(controller, 7)
    
    --[[ Print level sprite pointers, to document level data
    if button_Up and button_Down then
        local level_sprite_ptrs = "\n"
        for slot = 0x00, 0x13 do
            local type_ptr = u16(RAM.objects_type_pointer + slot*0x32)
            level_sprite_ptrs = level_sprite_ptrs .. fmt("%04X-", type_ptr)
        end
        print(level_sprite_ptrs)
        --local level_sprite_ptrs = "\n"; for slot = 0x00, 0x13 do level_sprite_ptrs = level_sprite_ptrs .. string.format("%04X-", memory.read_u16_le(0x00E9 + 0x25 + slot*0x32, "WRAM")) end; print(level_sprite_ptrs)
    end]]
    
    --[[ Print level width and height
    if button_Up and button_Down then
        print(fmt("\n, width = 0x%04X, height = 0x%04X", Camera_x + 160, Camera_y + 144))
    end]]
    
    --[[ Print level "identifier"
    if button_Up and button_Down then
        local level_identifier = ""
        for addr = 0x0500, 0x0505 do
            level_identifier = level_identifier .. fmt("%02X", u8(addr))
        end
        print("\n\""..level_identifier.."\"")
    end]]
    --[[
    -- Screenshot and store progress, to make the level map later
    if button_Up and button_Down then 
        Generic_current = true
        -- Condition to execute this only one time, instead of every frame holding this input
        if Generic_current and not Generic_previous then
            -- Create screenshot name
            local path = "Level Screenshots\\"
            local file_name = fmt("%02d - %04X, %04X.png", level_id, Camera_x_prev, Camera_y_prev) -- prev is more precise for this matter
            
            -- Shot the screen
            client.screenshot(path .. file_name)
            
            -- Store screenshot coordinates for this level
            table.insert(Level.screenshots[level_id], {Camera_x_prev, Camera_y_prev})
            
            -- Store area progress for this level
            for y = 0, 144-1 do 
                for x = 0, 160-1 do
                    Level.progress[level_id][Camera_y_prev + y][Camera_x_prev + x] = 1
                end
            end
            
            -- Update screenchot progress sum
            local sum_temp = 0
            for y = 0, level_height-1 do
                for x = 0, level_width-1 do
                    sum_temp = sum_temp + Level.progress[level_id][y][x]
                end
            end
            Level.progress_sum[level_id] = sum_temp
            
            -- Check if screenshoted the whole level, to dump screenshot coordinates
            if Level.progress_sum[level_id] == level_width*level_height then
                print(fmt("\nLevel %02d:\n", level_id))
                local level_str = fmt("[%02d] = {", level_id)
                for entry = 1, #Level.screenshots[level_id] do
                    local x = Level.screenshots[level_id][entry][1]
                    local y = Level.screenshots[level_id][entry][2]
                    local entry_str = fmt("{0x%04X, 0x%04X}, ", x, y)
                    level_str = level_str .. entry_str
                end
                level_str = level_str .. "},\n"
                print(level_str)
            end
        end
    else
        Generic_current = false
    end
    
    -- Display the level boundaries
    local x_origin_screen, y_origin_screen = screen_coordinates(OPTIONS.left_gap + 0, OPTIONS.top_gap + 0, Camera_x, Camera_y)
    draw.rectangle(x_origin_screen, y_origin_screen, level_width-1, level_height-1, 0x40FF0000, 0x40FF0000)
    
    -- Display level screenshot progress
    if #Level.screenshots[level_id] > 0 then
        for entry = 1, #Level.screenshots[level_id] do
            local x = Level.screenshots[level_id][entry][1]
            local y = Level.screenshots[level_id][entry][2]
            local x_screen, y_screen = screen_coordinates(OPTIONS.left_gap + x, OPTIONS.top_gap + y, Camera_x, Camera_y)
            draw.rectangle(x_screen, y_screen, 160-1, 144-1, 0x4000FF00, 0x4000FF00)
        end
    end
    --draw.text(PC.screen_middle_x, PC.top_padding/2 - BIZHAWK_FONT_HEIGHT, fmt("Width: %d(0x%04X), Height: %d(0x%04X)", level_width, level_width, level_height, level_height))
    draw.text(PC.right_padding_start + 2, PC.top_padding, "Screenshot progress:")
    for id = 1, 19 do
        local percentage = floor(100*Level.progress_sum[id]/(Level.dimensions[id].width*Level.dimensions[id].height))
        local progress_str = fmt("%02d: %d%%", id, percentage)
        if id == level_id then progress_str = fmt("%02d: %d%% (%d/%d)", id, percentage, Level.progress_sum[id], level_width*level_height) end
        draw.text(PC.right_padding_start + 2, PC.top_padding + id*BIZHAWK_FONT_HEIGHT, progress_str, percentage == 100 and 0xff00FF00 or "white")
    end
    ]]
    
    --[[ Highlight undocumented object animation frame
    local objects_anim_frames = {
        [0x71F0] = {00, 01, 02}, -- Springboard
        [0x7223] = {00}, -- Baby Capybara
        [0x7264] = {00, 01}, -- Heart
        [0x72D8] = {00, 01}, -- Save computer
        [0x730B] = {00}, -- Sign
        [0x74EB] = {00, 01}, -- Turnip Bandit
        [0x7C8A] = {00, 01, 02, 03}, -- Skeleton
        [0x7CED] = {00, 01, 03}, -- Cannon
        [0x7D3E] = {00, 01, 02, 03}, -- Yuzu
        [0x7DA9] = {00, 01, 02, 03, 04}, -- Bat
        [0x7DFA] = {00, 01, 02, 03}, -- Flag
        [0x7E68] = {00, 01, 02, 03, 05, 06, 07, 08, 09, 0A, 0B, 0C}, -- Capybara
    }
    draw.rectangle(310, 179, 2*BIZHAWK_FONT_WIDTH/Scale + 2, BIZHAWK_FONT_HEIGHT/Scale*(Level.data[level_identifier].objects), "red")
    for slot = 0, Level.data[level_identifier].objects-1 do
        local type_ptr = type_ptrs[slot]
        local anim_frame = anim_frames[slot]
        local anim_documented = false
        for anim = 1, #objects_anim_frames[type_ptr] do
            if anim_frame == objects_anim_frames[type_ptr][anim] then
                anim_documented = true
            end
        end
        if not anim_documented then
            draw.text(table_x + 23*BIZHAWK_FONT_WIDTH + 0x0D*3*BIZHAWK_FONT_WIDTH, table_y + slot*BIZHAWK_FONT_HEIGHT, fmt("%02X", anim_frame), "red")
        end
    end]]
    
    --- CHEAT
    -- Global cheat warning
    if OPTIONS.CHEATS then
        draw.text(PC.screen_middle_x - string.len("Cheats allowed!")*BIZHAWK_FONT_WIDTH/2, 0, "Cheats allowed!", "red")
    end
    
    -- Free moving cheat
    if OPTIONS.CHEATS and button_Select and not button_A then
        -- Get current position
        local x_pos, y_pos = X_pos, Y_pos
        -- Set movement speed
        local speed = button_B and 0x08 or 0x01  -- how many pixels per frame
        speed = 0x10*speed -- to actually make it pixels per frame, since each pixel has 0x10 subpixels
        -- Math
        if button_Left then x_pos = x_pos - speed end --; w8_sram(SRAM.direction, 2)  end
        if button_Right then x_pos = x_pos + speed end --; w8_sram(SRAM.direction, 0) end
        if button_Up then y_pos = y_pos - speed end
        if button_Down then y_pos = y_pos + speed end
        -- Manipulate the addresses
        w16(RAM.x_pos, x_pos) --\ setting the coordinates
        w16(RAM.y_pos, y_pos) --/
        w8(RAM.x_speed, 0) -----\ disabling normal horizontal speed
        w8(RAM.x_subspeed, 0) --/
        w8(RAM.y_speed, -7) -- accounting for gravity, otherwise it keeps falling
        -- Display cheat warning
        gui.drawText(Game.left_padding, Game.top_padding, "CHEAT: FREE MOVEMENT", "red", 0x80000000, 11, "Consolas")
    end
    
    -- Beat level cheat
    if OPTIONS.CHEATS and button_Select and button_A then
        -- Manipulate the addresses
        w16(RAM.x_pos, ending_x)
        w16(RAM.y_pos, ending_y)
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
    
    --gui.clearGraphics()
  
	client.SetGameExtraPadding(0, 0, 0, 0)
  
    print("\nFinishing Capybara Quest Utility Script.\n------------------------------------")
end)

-- Add column(s) for useful info on TAStudio piano roll
tastudio.addcolumn("x_speed", "X spd", 40)
tastudio.addcolumn("y_speed", "Y spd", 40)
tastudio.addcolumn("on_ground", "On ground", 70)
tastudio.addcolumn("disabled", "Disabled", 60)
tastudio.addcolumn("climbing", "Climbing", 60)

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
    
    -- on_ground column
    if column_name == "on_ground" then
        if Column.on_ground[frame] == nil then
            return ""
        else
            return Column.on_ground[frame] and "       yes" or "       no"
        end
    end
    
    -- disabled column
    if column_name == "disabled" then
        if Column.disabled[frame] == nil then
            return ""
        else
            return Column.disabled[frame] and "     yes" or "     no"
        end
    end
    
    -- climbing column
    if column_name == "climbing" then
        if Column.climbing[frame] == nil then
            return ""
        else
            return Column.climbing[frame] and "     yes" or "     no"
        end
    end
end

-- Function to update column(s) colour
local function column_colour(frame, column_name)
    -- x_speed column
    if column_name == "x_speed" then
        if Column.x_speed[frame] ~= nil then
            return gradient_good_bad(math.abs(Column.x_speed[frame]), 0x19)
        else
            return "0xffFFFFFF" -- white
        end
    end
    
    -- y_speed column
    if column_name == "y_speed" then
        if Column.y_speed[frame] ~= nil then
            if Column.y_speed[frame] ~= 0x00 then
                return gradient_good(math.abs(Column.y_speed[frame]), 0x4E)
            else
                return "0xffFFFFFF" -- white
            end
        else
            return "0xffFFFFFF" -- white
        end
    end
    
    -- on_ground column
    if column_name == "on_ground" then
        if Column.on_ground[frame] then
            return 0xff00FF00 -- green
        else
            return "0xffFFFFFF" -- white
        end
    end
    
    -- disabled column
    if column_name == "disabled" then
        if Column.disabled[frame] ~= nil then
            if Column.disabled[frame] then
                if Column.animation_frame[frame] == 0x0B then
                    return 0xff00FF00 -- green
                else
                    return "red"
                end
            else
                return "0xffFFFFFF" -- white
            end
        else
            return "0xffFFFFFF" -- white
        end
    end
    
    -- climbing column
    if column_name == "climbing" then
        if Column.climbing[frame] then
            return 0xff00FF00 -- green
        else
            return "0xffFFFFFF" -- white
        end
    end
end

-- Add "hooks" for updating the new column(s) on TAStudio
if tastudio.engaged() then
    tastudio.onqueryitemtext(column_text)
    tastudio.onqueryitembg(column_colour)
    --tastudio.ongreenzoneinvalidated(greenzone_invalidated) -- not working
end

-- Script load success message (NOTHING AFTER HERE, ONLY MAIN SCRIPT LOOP)
print("\n\nCapybara Quest Utility Script loaded successfully at " .. os.date("%X") .. ".\n") -- %c for date and time

-- Main loop
while true do
    -- Prevent cheats while recording movie
    if movie.isloaded() then OPTIONS.CHEATS = false end
    -- Read very important emu stuff
    bizhawk_screen_info()
    bizhawk_status()
    Generic_previous = Generic_current
    -- Update main game values and display these stuff
    main_game_scan()
    main_display()
    -- DEBUG
    
    -- Advance The Frame
    emu.frameadvance()
end


