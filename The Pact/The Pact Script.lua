--####################################################################
--##                                                                ##
--##   The Pact (GBC) Script for BizHawk                            ##
--##   https://allalonegamez.itch.io/the-pact                       ##
--##   http://tasvideos.org/Bizhawk.html                            ##
--##                                                                ##
--##   Author: Bruno Valadão Cunha (BrunoValads) [05/2023]          ##
--##                                                                ##
--##   Git repository: https://github.com/brunovalads/tas-scripts   ##
--##                                                                ##
--####################################################################

--################################################################################################################################################################
-- INITIAL STATEMENTS

-- Script options
local OPTIONS = {
    
    -- General settings
    left_gap = 75, 
    right_gap = 20,
    top_gap = 20,
    bottom_gap = 20,
    framerate = 59.727500569606,
    
    -- Display settings
    display_object_names = false,
    display_block_grid = false,
    display_ghost = false,
    
    ---- DEBUG AND CHEATS ----
    DEBUG = false, -- to display debug info for script development only!
    CHEATS = false, -- to help research, ALWAYS DISABLED WHEN RECORDING MOVIES
}
if OPTIONS.DEBUG then
    OPTIONS.left_gap = 160
    OPTIONS.right_gap = 610
    OPTIONS.top_gap = 18
    OPTIONS.bottom_gap = 250
end
if OPTIONS.display_object_names then
    OPTIONS.left_gap = math.max(120, OPTIONS.left_gap)
end

-- Ghost from previous TAS, to quickly make comparison
local Ghost = {}
Ghost.frame_start = 5061
Ghost.frame_end = 6197
Ghost.offset = 3 -- offset = Ghost.frame_start - current_start
Ghost.data = { -- TODO
    [5061] = {x = 0x180, y = 0xC80},
    [5062] = {x = 0x181, y = 0xCA3},
}

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
    for i = 0x0, 0x8 do
        game_name = game_name .. string.char(memory.read_u8(0x0134 + i, biz.ROM_domain))
    end
    return game_name
end

-- Check if it's The Pact (any version)
local Is_The_Pact = false
if biz.game_name() == "JEUSURGBS" then Is_The_Pact = true end

-- Failsafe to prevent script running with other games
if not Is_The_Pact then
    error("\n\nThis script is only for The Pact (GBC)!\n"..
          "Get the game here: https://allalonegamez.itch.io/the-pact \n"..
          "Contact the script author here: https://github.com/brunovalads/tas-scripts")
end

-- Check game version
local Game_version = ""
local Game_versions_hashes = {
    ["54D2DDC9755150ED2D4AF64A538EF4B0EC1460C9BC95FC4C0BECDFDFC867CEFF"] = "1.0",
    ["?????????????????????????????????????????????????????????????1.1"] = "1.1",
    ["?????????????????????????????????????????????????????????????1.2"] = "1.2",
    ["16EFFE52B56125E4D43C2BBE7B57C2103D062D849868AC106368E7C8353D3693"] = "1.3",
}
local Game_hash = memory.hash_region(0, memory.getmemorydomainsize(biz.ROM_domain), biz.ROM_domain)
--print(fmt("\nGame_hash:\n%s\n", Game_hash)) -- DEBUG
Game_version = Game_versions_hashes[Game_hash]
if Game_version == nil then
    error("\n\nThe script is not ready for this version of The Pact (GBC)!\n"..
      "Contact the script author here: https://github.com/brunovalads/tas-scripts")
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

-- Convert unsigned word to signed in hex string
local function signed16hex(num, signal)
    local maxval = 32768
    if signal == nil then signal = true end

    if num < maxval then -- positive
        return string.format("%s%04X", signal and "+" or "", num)
    else -- negative
        return string.format("%s%04X", signal and "-" or "", 2*maxval - num)
    end
end

-- Convert unsigned word to signed
local function sign_u16(num)
    local maxval = 32768

    if num < maxval then -- positive
        return num
    else -- negative
        return 2*maxval - num
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
    controller = 0x0617,
    is_level_mode = 0x0580,
    level_identifier = 0x0527, -- 5 bytes, arbitrarily
    fruit_taken = 0x0BA7, -- 2 bytes
    fruit_total = 0x0BA9, -- 2 bytes
    
    -- Player (0x34 bytes table, the play is actually the real first entry in the object list)
    base = 0x00B7,
    x_pos = 0x00BA, -- 2 bytes
    y_pos = 0x00BC, -- 2 bytes
    direction = 0x00BE, -- 01 = right, 03 = left
    on_ground = 0x1A05, --
    can_jump_frame_buffer = 0x19DC, --
    x_speed = 0x19F2, --
    x_subspeed = 0x19F1, -- ?
    y_speed = 0x19F4, --
    y_subspeed = 0x19F3, -- ?
    x_speed_cap = 0x1929, --
    animation_frame = 0x00C4, -- 
    
    -- Objects (0x34 bytes per entry, 0x0A entries??, apparently)
    objects_entry_size = 0x34,
    objects_slots = 0x0A,
    fruit_x_pos = 0x0156, -- 2 bytes
    fruit_y_pos = 0x0158, -- 2 bytes
    dragon_statue_x_pos = 0x00EE, -- 2 bytes
    dragon_statue_y_pos = 0x00F0, -- 2 bytes
    rabbit_statue_x_pos = 0x0122, -- 2 bytes
    rabbit_statue_y_pos = 0x0124, -- 2 bytes
    objects_some_pointer = 0x00EB + 0x00, -- 0x00EB some pointer (WRAM? because >$C000)
    objects_some_pointer_h = 0x00EB + 0x01, -- 0x00EC (high)
    objects_flags = 0x00EB + 0x02, -- 0x00ED
    objects_x_pos = 0x00EB + 0x03, -- 0x00EE, 2 bytes
    objects_x_pos_h = 0x00EB + 0x04, -- 0x00EF (high)
    objects_y_pos = 0x00EB + 0x05, -- 0x00F0, 2 bytes
    objects_y_pos_h = 0x00EB + 0x06, -- 0x00F1 (high)
    objects_direction = 0x00EB + 0x07, -- 0x00F2
    -- 0x00EB + 0x08, -- 0x00F3
    -- 0x00EB + 0x09, -- 0x00F4
    -- 0x00EB + 0x0A, -- 0x00F5
    -- 0x00EB + 0x0B, -- 0x00F6 
    objects_index_to_anim_frame = 0x00EB + 0x0C, -- 0x00F7
    objects_anim_frame = 0x00EB + 0x0D, -- 0x00F8
    -- 0x00EB + 0x0E, -- 0x00F9
    -- 0x00EB + 0x0F, -- 0x00FA
    -- 0x00EB + 0x10, -- 0x00FB
    objects_speed = 0x00EB + 0x11, -- 0x00FC
    -- 0x00EB + 0x12, -- 0x00FD
    -- 0x00EB + 0x13, -- 0x00FE
    -- 0x00EB + 0x14, -- 0x00FF
    -- 0x00EB + 0x15, -- 0x0100
    -- 0x00EB + 0x16, -- 0x0101
    -- 0x00EB + 0x17, -- 0x0102
    -- 0x00EB + 0x18, -- 0x0103
    -- 0x00EB + 0x19, -- 0x0104
    -- 0x00EB + 0x1A, -- 0x0105
    -- 0x00EB + 0x1B, -- 0x0106
    -- 0x00EB + 0x1C, -- 0x0107
    -- 0x00EB + 0x1D, -- 0x0108
    -- 0x00EB + 0x1E, -- 0x0109
    -- 0x00EB + 0x1F, -- 0x010A
    -- 0x00EB + 0x20, -- 0x010B
    -- 0x00EB + 0x21, -- 0x010C
    -- 0x00EB + 0x22, -- 0x010D
    -- 0x00EB + 0x23, -- 0x010E
    -- 0x00EB + 0x24, -- 0x010F
    objects_type_pointer = 0x00EB + 0x25, -- 0x0110, 2 bytes
    objects_type_pointer_h = 0x00EB + 0x26, -- 0x0111 (high)
    -- 0x00EB + 0x27, -- 0x0112
    -- 0x00EB + 0x28, -- 0x0113
    -- 0x00EB + 0x29, -- 0x0114
    -- 0x00EB + 0x2A, -- 0x0115
    -- 0x00EB + 0x2B, -- 0x0116
    -- 0x00EB + 0x2C, -- 0x0117
    -- 0x00EB + 0x2D, -- 0x0118 
    objects_moving = 0x00EB + 0x2E, -- 0x0119 
    -- 0x00EB + 0x2F, -- 0x011A
    -- 0x00EB + 0x30, -- 0x011B
    -- 0x00EB + 0x31, -- 0x011C
    -- 0x00EB + 0x32, -- 0x011D
    -- 0x00EB + 0x33, -- 0x011E
}

-- Data for all levels
local Level = {}
Level.data = { -- Indexed by RAM.level_identifier, by lack of better way to find out
    -- 1.0 -- TODO: Figure out way to have just one list, with a field for the game version
    ["1D5107004707"] = {id = 01, name = "(Tutorial 1/4)" , objects = 03, exit = {x = 0x80, y = 0x48}},
    ["995807D04907"] = {id = 02, name = "(Tutorial 2/4)" , objects = 03, exit = {x = 0x70, y = 0x78}},
    ["E55807A04C07"] = {id = 03, name = "(Tutorial 3/4)" , objects = 03, exit = {x = 0x80, y = 0x38}},
    ["395907704F07"] = {id = 04, name = "(Tutorial 4/4)" , objects = 03, exit = {x = 0x80, y = 0x48}},
    ["584C07405207"] = {id = 05, name = ""               , objects = 03, exit = {x = 0x80, y = 0x58}},
    ["A15508505908"] = {id = 06, name = ""               , objects = 04, exit = {x = 0x50, y = 0x18}},
    ["3F5A07224407"] = {id = 07, name = ""               , objects = 05, exit = {x = 0x80, y = 0x78}},
    ["DB5A07105507"] = {id = 08, name = ""               , objects = 05, exit = {x = 0x88, y = 0x70}},
    ["435608F05E08"] = {id = 09, name = ""               , objects = 07, exit = {x = 0x90, y = 0x48}},
    ["3D4D07E05707"] = {id = 10, name = ""               , objects = 07, exit = {x = 0x80, y = 0x78}},
    ["624E07B05A07"] = {id = 11, name = ""               , objects = 03, exit = {x = 0x80, y = 0x68}},
    ["094F07805D07"] = {id = 12, name = ""               , objects = 05, exit = {x = 0x88, y = 0x20}},
    ["EB4F07506007"] = {id = 13, name = ""               , objects = 05, exit = {x = 0x10, y = 0x58}},
    ["E55608C06108"] = {id = 14, name = ""               , objects = 06, exit = {x = 0x10, y = 0x28}},
    ["965007206307"] = {id = 15, name = ""               , objects = 10, exit = {x = 0x88, y = 0x58}},
    ["B95107926707"] = {id = 16, name = ""               , objects = 05, exit = {x = 0x80, y = 0x30}},
    ["685208004007"] = {id = 17, name = ""               , objects = 06, exit = {x = 0x80, y = 0x78}},
    ["175308D04208"] = {id = 18, name = ""               , objects = 05, exit = {x = 0x80, y = 0x10}},
    ["D05308A04508"] = {id = 19, name = ""               , objects = 03, exit = {x = 0x88, y = 0x70}},
    ["B95708205C08"] = {id = 20, name = ""               , objects = 03, exit = {x = 0x80, y = 0x38}},
    ["875408704808"] = {id = 21, name = ""               , objects = 07, exit = {x = 0x00, y = 0x48}},
    
    -- 1.3
    ["935107EC4507"] = {id = 01, name = "(Tutorial 1/4)" , objects = 03, exit = {x = 0x80, y = 0x48}},
    ["7F5907BC4807"] = {id = 02, name = "(Tutorial 2/4)" , objects = 03, exit = {x = 0x70, y = 0x78}},
    ["CB59078C4B07"] = {id = 03, name = "(Tutorial 3/4)" , objects = 03, exit = {x = 0x80, y = 0x38}},
    ["1F5A075C4E07"] = {id = 04, name = "(Tutorial 4/4)" , objects = 03, exit = {x = 0x80, y = 0x48}},
    ["CE4C072C5107"] = {id = 05, name = ""               , objects = 03, exit = {x = 0x80, y = 0x58}},
    ["875608205C08"] = {id = 06, name = ""               , objects = 04, exit = {x = 0x50, y = 0x18}},
    ["255B071C4307"] = {id = 07, name = ""               , objects = 05, exit = {x = 0x80, y = 0x78}},
    ["C15B07FC5307"] = {id = 08, name = ""               , objects = 05, exit = {x = 0x88, y = 0x70}},
    ["295708C06108"] = {id = 09, name = ""               , objects = 07, exit = {x = 0x90, y = 0x48}},
    ["B34D07CC5607"] = {id = 10, name = ""               , objects = 07, exit = {x = 0x80, y = 0x78}},
    ["D84E079C5907"] = {id = 11, name = ""               , objects = 03, exit = {x = 0x80, y = 0x68}},
    ["7F4F076C5C07"] = {id = 12, name = ""               , objects = 05, exit = {x = 0x88, y = 0x20}},
    ["6150073C5F07"] = {id = 13, name = ""               , objects = 05, exit = {x = 0x10, y = 0x58}},
    ["CB5708906408"] = {id = 14, name = ""               , objects = 06, exit = {x = 0x10, y = 0x28}},
    ["0C51070C6207"] = {id = 15, name = ""               , objects = 10, exit = {x = 0x88, y = 0x58}},
    ["4F5208004007"] = {id = 16, name = ""               , objects = 05, exit = {x = 0x80, y = 0x30}},
    ["DE5208D04208"] = {id = 17, name = ""               , objects = 06, exit = {x = 0x80, y = 0x78}},
    ["8D5308A04508"] = {id = 18, name = ""               , objects = 05, exit = {x = 0x80, y = 0x10}},
    ["465408704808"] = {id = 19, name = ""               , objects = 03, exit = {x = 0x88, y = 0x70}},
    ["9F5808F05E08"] = {id = 20, name = ""               , objects = 03, exit = {x = 0x80, y = 0x38}},
    ["D55408404B08"] = {id = 21, name = ""               , objects = 07, exit = {x = 0x00, y = 0x48}},
}
Level.last_id = 21

-- Objects data, indexed by Game_version then type_ptr (RAM.objects_type_pointer)
local Objects_by_version = { -- TODO: Instead of having this huge dictionary for each version, having just one list and the type_ptr index by Game_version inside each list entry
    ["1.0"] = {
        [0x0000] = {name = "[empty]", nickname = "[]"},
        [0x68E8] = {name = "Dragon Statue", nickname = "Dragon"},
        [0x6B45] = {name = "Rabbit Statue", nickname = "Rabbit"},
        [0x7DD8] = {name = "Torch", nickname = "Torch"},
        [0x695D] = {name = "Fruit", nickname = "Fruit"},
        [0x6A38] = {name = "Yellow Key", nickname = "Key(Y)"},
        [0x6E69] = {name = "Yellow Door", nickname = "Door(Y)"},
        [0x6A05] = {name = "Green Key", nickname = "Key(G)"},
        [0x6E36] = {name = "Green Door", nickname = "Door(G)"},
        [0x69D2] = {name = "Blue Key", nickname = "Key(B)"},
        [0x6E03] = {name = "Blue Door", nickname = "Door(B)"},
        [0x67DB] = {name = "Bubble (normal)", nickname = "Bubble"},
        [0x6766] = {name = "Bubble (compressed)", nickname = "Bubble"},
    },
    ["1.3"] = {
        [0x0000] = {name = "[empty]", nickname = "[]"},
        [0x6A3B] = {name = "Dragon Statue", nickname = "Dragon"},
        [0x6C98] = {name = "Rabbit Statue", nickname = "Rabbit"},
        [0x7FED] = {name = "Torch", nickname = "Torch"},
        [0x6AB0] = {name = "Fruit", nickname = "Fruit"},
        [0x6B8B] = {name = "Yellow Key", nickname = "Key(Y)"},
        [0x6FBC] = {name = "Yellow Door", nickname = "Door(Y)"},
        [0x6B58] = {name = "Green Key", nickname = "Key(G)"},
        [0x6F89] = {name = "Green Door", nickname = "Door(G)"},
        [0x6B25] = {name = "Blue Key", nickname = "Key(B)"},
        [0x6F56] = {name = "Blue Door", nickname = "Door(B)"},
        [0x692E] = {name = "Bubble (normal)", nickname = "Bubble"},
        [0x68B9] = {name = "Bubble (compressed)", nickname = "Bubble"},
    },
}
local Objects = Objects_by_version[Game_version]


-- Converts the in-game (x, y) to emu-screen coordinates
local function screen_coordinates(x, y, camera_x, camera_y)
  local x_screen = (x - camera_x)
  local y_screen = (y - camera_y)

  return x_screen, y_screen
end

-- Main player RAM read, outside the main_display because i need previous
local X_pos, Y_pos
local X_pos_prev, Y_pos_prev = 0, 0
Level.id, Level.name = -1, ""
Level.id_prev, Level.name_prev = 0x00, ""
local function main_game_scan()
    -- Player coordinates
    if X_pos then X_pos_prev = X_pos end -- conditional to avoid writing nil to prev
    if Y_pos then Y_pos_prev = Y_pos end
    X_pos = u16(RAM.x_pos)
    Y_pos = u16(RAM.y_pos)
    
    -- Get which level is running
    Level.id_prev = Level.id
    Level.name_prev = Level.name
    Level.identifier = ""
    for addr = RAM.level_identifier, RAM.level_identifier + 5 do
        Level.identifier = Level.identifier .. fmt("%02X", u8(addr))
    end
    if Level.data[Level.identifier] then
        Level.id = Level.data[Level.identifier].id
        Level.name = Level.data[Level.identifier].name
    else
        Level.id = -1
        Level.name = ""
    end
end

-- Init tables used for extra columns on TAStudio
local Column = {}
Column.x_speed = {}
Column.x_speed_str = {}
Column.y_speed = {}
Column.y_speed_str = {}
Column.on_ground = {}
Column.animation_frame = {}

-- Main display function, ALL DRAWINGS SHOULD BE CALLED HERE
local function main_display()
    --- Movie timer
    local timer_str = frame_time(Framecount, true)
    draw.text(0, 0, fmt("%s", timer_str), "white", "bottomright")
    
    --- Display game version
    draw.text(0, 0, fmt("Game version: %s", Game_version), "white", "topright")
    
    --- Check if is level mode
    local is_level_mode = u8(RAM.is_level_mode) == 0x30
    if not is_level_mode then gui.clearGraphics() ; return end
    
    --- Dark filter
    local filter_alpha = 0x55
    draw.rectangle(OPTIONS.left_gap, OPTIONS.top_gap, 256, 224, filter_alpha*0x1000000, filter_alpha*0x1000000)
    
    --- Block grid
    if OPTIONS.display_block_grid then
        local x_origin, y_origin = 0, 0
        --local colour_border, colour_fill = 0x80808080, nil
        local colour_border = {[0] = 0x60FF0000, [1] = 0x6000FF00}
        for block_y = 0, 8+1 do
            for block_x = 0, 8+1 do
                draw.rectangle(OPTIONS.left_gap + block_x*16, OPTIONS.top_gap + block_y*16 - 8, 15, 15, colour_border[(block_x + block_y%2)%2], nil)
                if block_y == 0 then
                   draw.pixel_text(OPTIONS.left_gap + block_x*16, OPTIONS.top_gap - 16, fmt("%02X", block_x*0x10)) 
                end
            end
            draw.pixel_text(OPTIONS.left_gap - 10, OPTIONS.top_gap + block_y*16 - 8, fmt("%02X", block_y*0x10)) 
        end
    end
    
    --- Player info
    -- Read RAM
    local x_pos_raw = X_pos
    local y_pos_raw = Y_pos
    local x_speed = s16(RAM.x_subspeed)
    local y_speed = s16(RAM.y_subspeed)
    local on_ground = u8(RAM.on_ground) == 1
    local can_jump_frame_buffer = u8(RAM.can_jump_frame_buffer)
    local player_dir = u8(RAM.direction)
    local animation_frame = u8(RAM.animation_frame)
    
    -- RAM that need calc
    local x_pos, y_pos = floor(x_pos_raw/0x10), floor(y_pos_raw/0x10)
    local x_subpos, y_subpos = x_pos_raw - x_pos*0x10, y_pos_raw - y_pos*0x10
    local x_speed_str = signed16hex(u16(RAM.x_subspeed))
    local y_speed_str = signed16hex(u16(RAM.y_subspeed))
    local dx_pos_raw = (X_pos - X_pos_prev) & 0xFFFF
    local dy_pos_raw = (Y_pos - Y_pos_prev) & 0xFFFF
    local x_screen_player, y_screen_player = screen_coordinates(x_pos, y_pos, 0, 0)
    
    -- Display player info
    local display_y_base = 42
    local i = 0
    local temp_colour = "white"
    draw.text(2, display_y_base + i * BIZHAWK_FONT_HEIGHT, fmt("Pos: %03X.%x, %03X.%x %s", x_pos, x_subpos, y_pos, y_subpos, player_dir == 1 and ">" or "<")); i = i + 1
    draw.text(2, display_y_base + i * BIZHAWK_FONT_HEIGHT, fmt("Speed: %s, %s", x_speed_str, y_speed_str)); i = i + 1
    draw.text(2, display_y_base + i * BIZHAWK_FONT_HEIGHT, fmt("Delta:      , %s", signed16hex(dy_pos_raw, true)))
    if math.abs(sign_u16(dx_pos_raw)) > math.abs(x_speed) then
        temp_colour = 0xff00FF00 -- green
    elseif math.abs(sign_u16(dx_pos_raw)) < math.abs(x_speed) then
        temp_colour = 0xffFF0000 -- red
    else
        temp_colour = "white"
    end
    draw.text(2 + 7 * BIZHAWK_FONT_WIDTH, display_y_base + i * BIZHAWK_FONT_HEIGHT, fmt("%s", signed16hex(dx_pos_raw, true)), temp_colour); i = i + 1
    draw.text(2, display_y_base + i * BIZHAWK_FONT_HEIGHT, fmt("On ground: %s", on_ground and "yes" or "no")); i = i + 1
    draw.text(2, display_y_base + i * BIZHAWK_FONT_HEIGHT, fmt("Can jump: %d %s", can_jump_frame_buffer, can_jump_frame_buffer > 0 and "yes" or "no")); i = i + 1
    
    -- Show position on screen
    draw.cross(OPTIONS.left_gap + x_screen_player, OPTIONS.top_gap - 8 + y_screen_player, 2, "orange")
    
    -- and solid interaction points
    draw.cross(OPTIONS.left_gap + x_screen_player - 0x0, OPTIONS.top_gap - 8 + y_screen_player + 0xf, 2, "blue") -- bottom left
    draw.cross(OPTIONS.left_gap + x_screen_player + 0xf, OPTIONS.top_gap - 8 + y_screen_player + 0xf, 2, "blue") -- bottom right
    --draw.cross(OPTIONS.left_gap + x_screen_player - 0x0, OPTIONS.top_gap - 8 + y_screen_player - 0x0, 2, "blue") -- top left, same as the real position
    draw.cross(OPTIONS.left_gap + x_screen_player + 0xf, OPTIONS.top_gap - 8 + y_screen_player - 0x0, 2, "blue") -- top right
    
    -- Display ghost position
    if OPTIONS.display_ghost then
        if Framecount >= Ghost.frame_start - Ghost.offset and Framecount <= Ghost.frame_end - Ghost.offset then
            local ghost_x, ghost_y = Ghost.data[Framecount + Ghost.offset].x, Ghost.data[Framecount + Ghost.offset].y
            ghost_x, ghost_y = floor(ghost_x/0x10), floor(ghost_y/0x10) -- subpos is irrelevant here
            local ghost_x_screen, ghost_y_screen = screen_coordinates(ghost_x, ghost_y, 0, 0)
            
            draw.rectangle(OPTIONS.left_gap + ghost_x_screen, OPTIONS.top_gap - 8 + ghost_y_screen, 15, 15, 0x808000FF)
        end
    end
    
    --- Level info
    -- Display the level info
    local colour = Level.id ~= -1 and "white" or "red"
    local level_str = fmt("Level: %02d/%02d %s", Level.id, Level.last_id, Level.name)
    draw.text(PC.buffer_middle_x - BIZHAWK_FONT_WIDTH*string.len(level_str)/2, PC.bottom_padding_start, level_str, colour)
    
    -- Display the exit
    local exit_x, exit_y = 0x00, 0x00
    if Level.data[Level.identifier] then
        exit_x = Level.data[Level.identifier].exit.x
        exit_y = Level.data[Level.identifier].exit.y
        draw.cross(OPTIONS.left_gap + exit_x, OPTIONS.top_gap - 8 + exit_y, 2, 0xff40FF40)
        draw.rectangle(OPTIONS.left_gap + exit_x, OPTIONS.top_gap - 8 + exit_y, 15, 15, 0x7f40FF40)
        draw.pixel_text(OPTIONS.left_gap + exit_x, OPTIONS.top_gap + 09 + exit_y, "Exit", 0x7f40FF40)
    end
    
    --- Object info
    i = i + 3
    -- Display constans
    local table_x = 2
    local table_y = OPTIONS.DEBUG and (PC.bottom_padding_start + 2*BIZHAWK_FONT_HEIGHT) or (display_y_base + i * BIZHAWK_FONT_HEIGHT)
    local colours = {
        0xffA0A0FF, -- blue
        0xffFF80FF, -- magenta
        0xffFF6060, -- red
        0xffFFA100, -- orange
        0xffFFFF80, -- yellow
        0xff40FF40  -- green
    }
    -- Title
    draw.text(table_x, table_y - BIZHAWK_FONT_HEIGHT, "Objects:")
    -- Main object loop
    local fruit_taken = false
    local have_cannons = false
    local anim_frames, type_ptrs = {}, {} -- RESEARCH
    for slot = 0x00, RAM.objects_slots-1 do
        -- Fade slots not used in the current level
        local empty_slot = false
        if Level.data[Level.identifier] then
            if slot+1 > Level.data[Level.identifier].objects then
                empty_slot = true
            end
        end
        
        -- Read RAM
        local offset = slot*RAM.objects_entry_size
        local x_pos_raw = u16(RAM.objects_x_pos + offset)
        local y_pos_raw = u16(RAM.objects_y_pos + offset)
        local flags = u8(RAM.objects_flags + offset)
        local type_ptr = u16(RAM.objects_type_pointer + offset)
        local speed = u8(RAM.objects_speed + offset)
        local anim_frame = u8(RAM.objects_anim_frame + offset)
        
        -- Calculations
        local x_pos, y_pos = floor(x_pos_raw/0x10), floor(y_pos_raw/0x10)
        local x_subpos, y_subpos = x_pos_raw - x_pos*0x10, y_pos_raw - y_pos*0x10
        local x_screen, y_screen = screen_coordinates(x_pos, y_pos, 0, 0)
        local is_processed = bit.check(flags, 0)
        
        -- Get display colour
        local colour = colours[slot%6+1]
        if not is_processed then colour = colour - 0x80000000 end
        if empty_slot then colour = 0x80FFFFFF end
        
        -- Get name and nickname
        local name, nickname = "____________", "_____"
        if Objects[type_ptr] then
            name = Objects[type_ptr].name
            nickname = Objects[type_ptr].nickname
        end
        if name == "____________" then name = fmt("$%04X !!!", type_ptr) end
        if nickname == "_____" then nickname = fmt("$%04X !!!", type_ptr) end
        if empty_slot then name = "[empty]" end
        
        -- Display pixel position on screen
        if not empty_slot then
            draw.cross(OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, 2, colour)
        end
        
        -- Display hitbox (and some extra info) on screen, if object is being processed/rendered
        if is_processed then -- TODO: and not empty_slot then
            draw.rectangle(OPTIONS.left_gap + x_screen, OPTIONS.top_gap - 8 + y_screen, 15, 15, colour-0x80000000)
        end
        
        -- Display slot and nickname near positon on screen
        if not empty_slot then
            draw.pixel_text(OPTIONS.left_gap + x_screen + 2, OPTIONS.top_gap - 16 + y_screen, fmt("%02X", slot), colour)
            if OPTIONS.display_object_names then
                draw.pixel_text(OPTIONS.left_gap + x_screen, OPTIONS.top_gap + 09 + y_screen, fmt("%s", nickname), colour)
            end
        end
        
        -- DEBUG
        local debug_str = ""
        if OPTIONS.DEBUG then
            for addr = 0, RAM.objects_entry_size-1 do
                local value = u8(0x00EB + offset + addr)
                debug_str = debug_str .. fmt("%02X ", value)
                if slot == 0 then -- could be any, just want to do this once
                    -- Check if address is already documented
                    local documented = false
                    for k, v in pairs(RAM) do
                        if 0x00EB + addr == v then documented = true end
                    end
                    draw.text(table_x + 23*BIZHAWK_FONT_WIDTH + addr*3*BIZHAWK_FONT_WIDTH, table_y + (slot-1) * BIZHAWK_FONT_HEIGHT, fmt("%02X", addr), documented and 0xff00FF00 or "white")
                end
            end
            debug_str = debug_str .. fmt("$%04X ", 0xC000 + 0x00EB + offset)
            
            type_ptrs[slot] = type_ptr -- RESEARCH
            anim_frames[slot] = anim_frame -- RESEARCH
        end
        
        -- Display object table
        draw.text(table_x, table_y + slot * BIZHAWK_FONT_HEIGHT, fmt("#%02X: (%03X.%x, %03X.%x) %s %s", slot, x_pos, x_subpos, y_pos, y_subpos, (OPTIONS.DEBUG or not OPTIONS.display_object_names) and "" or name, debug_str), colour)
    end
    
    --- Display fruit info
    i = i - 3
    local fruit_taken = u16(RAM.fruit_taken) ~= 0x00
    local fruit_total = u16(RAM.fruit_total)
    local fruit_got_str = fmt("Got fruit: %s", fruit_taken and "yes" or "no")
    draw.text(2, display_y_base + i * BIZHAWK_FONT_HEIGHT, fruit_got_str, fruit_taken and 0xff00FF00 or "red")
    local colour = 0xff00FF00
    if fruit_taken and fruit_total == Level.id-1 then
        colour = 0xffFFA100
    elseif fruit_taken and fruit_total ~= Level.id then
        colour = "red"
    elseif not fruit_taken and fruit_total == Level.id-1 then
        colour = 0xffFFA100
    elseif math.abs(fruit_total - Level.id) >= 2 then
        colour = "red"
    end
    draw.text(2 + (string.len(fruit_got_str)+1)*BIZHAWK_FONT_WIDTH, display_y_base + i * BIZHAWK_FONT_HEIGHT, fmt("(%02d/21)", fruit_total), colour); i = i + 1
    
    --- TAStudio extra column(s) export (DON'T FORGET EACH ONE NEEDS TO BE INITIALIZED)
    Column.x_speed[Framecount] = x_speed
    Column.x_speed_str[Framecount] = x_speed_str
    Column.y_speed[Framecount] = y_speed
    Column.y_speed_str[Framecount] = y_speed_str
    Column.on_ground[Framecount] = on_ground
    Column.animation_frame[Framecount] = animation_frame
    
    
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
        for slot = 0x00, RAM.objects_slots-1 do
            local type_ptr = u16(RAM.objects_type_pointer + slot*RAM.objects_entry_size)
            level_sprite_ptrs = level_sprite_ptrs .. fmt("%04X-", type_ptr)
        end
        print(level_sprite_ptrs)
        --local level_sprite_ptrs = "\n"; for slot = 0x00, RAM.objects_slots-1 do level_sprite_ptrs = level_sprite_ptrs .. string.format("%04X-", memory.read_u16_le(0x00EB + 0x25 + slot*RAM.objects_entry_size, "WRAM")) end; print(level_sprite_ptrs)
    end]]
    
    -- Print level "identifier"
    if button_Up and button_Down then
        print("\n\""..Level.identifier.."\"")
    end
    
    --[[
    -- Screenshot and store progress, to make the level map later
    if button_Up and button_Down then 
        Generic_current = true
        -- Condition to execute this only one time, instead of every frame holding this input
        if Generic_current and not Generic_previous then
            -- Create screenshot name
            local path = "Level Screenshots\\"
            local file_name = fmt("%02d.png", Level.id)
            
            -- Shot the screen
            client.screenshot(path .. file_name)
            
        end
    else
        Generic_current = false
    end
    ]]
    
    --[[ Print level markers for the tasproj
    if Level.id_prev == -1 and Level.id ~= -1 then
        print(fmt("%d\tLevel %02d start", Framecount+15, Level.id))
    elseif Level.id_prev ~= -1 and Level.id == -1 then
        print(fmt("%d\tLevel %02d end", Framecount, Level.id_prev))
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
        local speed = 0x01  -- how many pixels per frame
        speed = 0x10*speed -- to actually make it pixels per frame, since each pixel has 0x10 subpixels
        -- Math
        if button_Left then x_pos = x_pos - speed end --; w8_sram(SRAM.direction, 2)  end
        if button_Right then x_pos = x_pos + speed end --; w8_sram(SRAM.direction, 0) end
        if button_Up then y_pos = y_pos - 6*speed end
        if button_Down then y_pos = y_pos + speed end
        -- Manipulate the addresses
        w16(RAM.x_pos, x_pos) --\ setting the coordinates
        w16(RAM.y_pos, y_pos) --/
        w8(RAM.x_speed, 0) -----\ disabling normal horizontal speed
        w8(RAM.x_subspeed, 0) --/
        w16(RAM.y_subspeed, -0x55) -- accounting for gravity, otherwise it keeps falling
        -- Display cheat warning
        gui.drawText(Game.left_padding, Game.top_padding, "CHEAT: FREE MOVEMENT", "red", 0x80000000, 11, "Consolas")
    end
    
    -- Beat level cheat
    if OPTIONS.CHEATS and button_Select and button_A and (exit_x > 0x00 or exit_y > 0x00) then
        -- Manipulate the addresses
        w16(RAM.x_pos, exit_x*0x10)
        w16(RAM.y_pos, exit_y*0x10)
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
  
    print("\nFinishing The Pact Utility Script.\n------------------------------------")
end)

-- Add column(s) for useful info on TAStudio piano roll
--tastudio.addcolumn("x_speed", "X spd", 40)
--tastudio.addcolumn("y_speed", "Y spd", 40)
--tastudio.addcolumn("on_ground", "On ground", 70)

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
end

-- Add "hooks" for updating the new column(s) on TAStudio
if tastudio.engaged() then
    --tastudio.onqueryitemtext(column_text) -- Index out of range...
    --tastudio.onqueryitembg(column_colour) -- Index out of range...
    --tastudio.ongreenzoneinvalidated(greenzone_invalidated) -- not working
end

-- Script load success message (NOTHING AFTER HERE, ONLY MAIN SCRIPT LOOP)
print("\n\nThe Pact Utility Script loaded successfully at " .. os.date("%X") .. ".\n") -- %c for date and time

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


