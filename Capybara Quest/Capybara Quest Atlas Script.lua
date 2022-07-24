--####################################################################
--##                                                                ##
--##   Capybara Quest (GBC) Atlas Script for BizHawk                ##
--##   https://maxthetics.itch.io/capybara-quest                    ##
--##   http://tasvideos.org/Bizhawk.html                            ##
--##                                                                ##
--##   Author: Bruno Valadão Cunha (BrunoValads) [07/2022]          ##
--##                                                                ##
--##   Git repository: https://github.com/brunovalads/tas-scripts   ##
--##                                                                ##
--####################################################################

--################################################################################################################################################################
-- INITIAL STATEMENTS

-- Script options
local OPTIONS = {
    
    -- Script settings
    left_gap = 400, -- 560 for 720p, 160 for 270p
    right_gap = 400, -- 560 for 720p, 160 for 270p
    top_gap = 198, -- 216 for 720p, 63 for 270p
    bottom_gap = 198, -- 216 for 720p, 63 for 270p
    framerate = 59.727500569606,
    
    ---- DEBUG AND CHEATS ----
    DEBUG = false, -- to display debug info for script development only!
    CHEATS = false, -- to help research, ALWAYS DISABLED WHEN RECORDING MOVIES
}
OPTIONS.left_gap_base = OPTIONS.left_gap
OPTIONS.right_gap_base = OPTIONS.right_gap
OPTIONS.top_gap_base = OPTIONS.top_gap
OPTIONS.bottom_gap_base = OPTIONS.bottom_gap

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
local Current, Previous = {}, {}
Current.object_anim, Previous.object_anim = {}, {}
Current.object_x_screen, Previous.object_x_screen = {}, {}
Current.object_y_screen, Previous.object_y_screen = {}, {}
Current.cannonball_x_pos_raw, Previous.cannonball_x_pos_raw = {}, {}
Current.cannonball_x_screen, Previous.cannonball_x_screen = {}, {}
Current.cannonball_y_screen, Previous.cannonball_y_screen = {}, {}
for slot = 0x0, 0x13 do
    Current.object_anim[slot], Previous.object_anim[slot] = 9999, 9999
    Current.object_x_screen[slot], Previous.object_x_screen[slot] = 9999, 9999
    Current.object_y_screen[slot], Previous.object_y_screen[slot] = 9999, 9999
    if slot <= 0x2 then
        Current.cannonball_x_pos_raw[slot], Previous.cannonball_x_pos_raw[slot] = 9999, 9999
        Current.cannonball_x_screen[slot], Previous.cannonball_x_screen[slot] = 9999, 9999
        Current.cannonball_y_screen[slot], Previous.cannonball_y_screen[slot] = 9999, 9999
    end
end



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

-- Check if files exists
function file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then io.close(f) return true else return false end
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

-- Palettes, indexed by palette, then colour, then fade phase
local Palettes = {
    [0] = {
        [0] = {0xffF3E0D5, 0xffF3E0D5, 0xffF6F0E2, 0xffF8F8F8, 0xffF8F8F8, 0xffF8F8F8},
        [1] = {0xffC67E6C, 0xffC7846D, 0xffC88878, 0xffE8A898, 0xffF0D8A0, 0xffF8F8F8},
        [2] = {0xff8F263A, 0xff902840, 0xffA03850, 0xffA03850, 0xffE07890, 0xffF8F8F8},
        [3] = {0xff2F2643, 0xff36284A, 0xff36284A, 0xff3C4864, 0xff787878, 0xffF8F8F8}
    },
    [1] = {
        [0] = {0xffDFE2B7, 0xffE6E4BE, 0xffF4E8CC, 0xffF4E8CC, 0xffF8F8F8, 0xffF8F8F8},
        [1] = {0xff7EA456, 0xff7EA456, 0xff80B058, 0xff84C85C, 0xff88D888, 0xffF8F8F8},
        [2] = {0xff4D6C2F, 0xff4D6C2F, 0xff5C7834, 0xff7C9854, 0xff88D888, 0xffF8F8F8},
        [3] = {0xff0A140A, 0xff0A140A, 0xff181818, 0xff383838, 0xff787878, 0xffF8F8F8}
    },
    [2] = {
        [0] = {0xffEFCCBD, 0xffEFCCBD, 0xffF0D0C8, 0xffF4E8CC, 0xffF8F8F8, 0xffF8F8F8},
        [1] = {0xffD29C91, 0xffD99C93, 0xffE8A898, 0xffE8A898, 0xffF0D8A0, 0xffF8F8F8},
        [2] = {0xff75647F, 0xff75647F, 0xff76688A, 0xff7C88A4, 0xff8098D0, 0xffF8F8F8},
        [3] = {0xff072425, 0xff0F2C2D, 0xff1E3832, 0xff383838, 0xff787878, 0xffF8F8F8}
    },
    [3] = {
        [0] = {0xffBCD0CB, 0xffBED8D2, 0xffBED8D2, 0xffC4F8EC, 0xffF8F8F8, 0xffF8F8F8},
        [1] = {0xffCD96CD, 0xffCE9CCE, 0xffD0A8D0, 0xffF0C8F0, 0xffF8F8F8, 0xffF8F8F8},
        [2] = {0xff722886, 0xff7A308E, 0xff8A409E, 0xffA858A8, 0xffE898E8, 0xffF8F8F8},
        [3] = {0xff2E0210, 0xff2F0811, 0xff32181E, 0xff383838, 0xff787878, 0xffF8F8F8}
    },
    [4] = {
        [0] = {0xffF4E8CC, 0xffF4E8CC, 0xffF4E8CC, 0xffF4E8CC, 0xffF8F8F8, 0xffF8F8F8},
        [1] = {0xff9AC8BD, 0xffA1C8BF, 0xffA4D8CC, 0xffC4F8EC, 0xffF8F8F8, 0xffF8F8F8},
        [2] = {0xff4F6C6D, 0xff4F6C6D, 0xff5E7872, 0xff787878, 0xff787878, 0xffF8F8F8},
        [3] = {0xff0F2A37, 0xff103038, 0xff204048, 0xff3C4864, 0xff787878, 0xffF8F8F8}
    },
    [5] = {
        [0] = {0xffEFCEC2, 0xffF0D0C8, 0xffF0D0C8, 0xffF4E8CC, 0xffF8F8F8, 0xffF8F8F8},
        [1] = {0xffAF7050, 0xffB67052, 0xffC68062, 0xffE4986C, 0xffF0D8A0, 0xffF8F8F8},
        [2] = {0xffA42E45, 0xffAC3448, 0xffBA3856, 0xffD4385C, 0xffE07890, 0xffF8F8F8},
        [3] = {0xff4D201B, 0xff4D201B, 0xff503028, 0xff6C3844, 0xff787878, 0xffF8F8F8}
    },
    [6] = {
        [0] = {0xffE9F2E4, 0xffEAF4EA, 0xffF8F8F8, 0xffF8F8F8, 0xffF8F8F8, 0xffF8F8F8},
        [1] = {0xffB5D69C, 0xffBDDC9F, 0xffBEE0AA, 0xffC0E8C0, 0xffF8F8F8, 0xffF8F8F8},
        [2] = {0xff5B9074, 0xff629076, 0xff629076, 0xff80A880, 0xff88D888, 0xffF8F8F8},
        [3] = {0xff243242, 0xff2B3449, 0xff3A404E, 0xff3C4864, 0xff787878, 0xffF8F8F8}
    },
    [7] = {
        [0] = {0xffF4E8CC, 0xffF4E8CC, 0xffF4E8CC, 0xffF4E8CC, 0xffF8F8F8, 0xffF8F8F8},
        [1] = {0xffC2AE9F, 0xffC3B0A5, 0xffD0B0A8, 0xffECB8C4, 0xffF8F8F8, 0xffF8F8F8},
        [2] = {0xff725A54, 0xff736055, 0xff767062, 0xff787878, 0xff787878, 0xffF8F8F8},
        [3] = {0xff3F1A17, 0xff402018, 0xff503028, 0xff6C3844, 0xff787878, 0xffF8F8F8}
    }
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
Previous.Camera_x, Previous.Camera_y = u16(RAM.camera_x), u16(RAM.camera_y)
local function main_game_scan()
    -- Player coordinates
    if X_pos then X_pos_prev = X_pos end -- conditional to avoid writing nil to prev
    if Y_pos then Y_pos_prev = Y_pos end
    X_pos = u16(RAM.x_pos)
    Y_pos = u16(RAM.y_pos)
    -- Camera coordinates
    if Camera_x then Previous.Camera_x = Camera_x end -- conditional to avoid writing nil to prev
    if Camera_y then Previous.Camera_y = Camera_y end
    Camera_x = u16(RAM.camera_x_with_shake) -- _with_shake is a TEST
    Camera_y = u16(RAM.camera_y_with_shake) -- _with_shake is a TEST
end

-- Main display function, ALL DRAWINGS SHOULD BE CALLED HERE
local function main_display()
    --- Movie timer
    if OPTIONS.DEBUG then
        local timer_str = frame_time(Framecount, true)
        draw.text(0, 0, fmt("%s", timer_str), "white", "bottomright")
    end
    
    --- Check if is level mode
    local is_level_mode = u8(RAM.is_level_mode) ~= 0x00
    if not is_level_mode then
        -- Draw background solid colour for cutscenes...
        local vram_bg_top_row_table = memory.read_bytes_as_array(0x3800, 0x14, "VRAM") -- 
        local top_row_is_same_palette = true
        for tile = 1, 0x14 do
            if vram_bg_top_row_table[tile] ~= vram_bg_top_row_table[1] then top_row_is_same_palette = false end
        end
        if top_row_is_same_palette then
            local palette = bit.band(vram_bg_top_row_table[1], 0x7)
            local palette_phase = u8(RAM.fade_phase)
            local bg_colour = Palettes[palette][3][palette_phase+1]
            --draw.text(0, 40 + 1*BIZHAWK_FONT_HEIGHT, fmt("palette = %d", palette)) -- DEBUG
            --draw.text(0, 40 + 2*BIZHAWK_FONT_HEIGHT, fmt("palette_phase = %d", palette_phase)) -- DEBUG
            --draw.text(0, 40 + 3*BIZHAWK_FONT_HEIGHT, fmt("bg_colour = #%06X", bg_colour)) -- DEBUG
            local vram_0C00 = memory.read_bytes_as_array(0x0C00, 0xC0, "VRAM") -- always zero during bios
            if table.concat(vram_0C00) == string.rep("0", 192) then bg_colour = 0xffF8F8F9 end -- bios has 0xffF8F8F8 background
            -- ...left
            draw.rectangle(0, 0, OPTIONS.left_gap-1, Game.screen_height-1, bg_colour, bg_colour)
            -- ...right
            draw.rectangle(Game.right_padding_start, 0, OPTIONS.right_gap-1, Game.screen_height-1, bg_colour, bg_colour)
            -- ...top
            draw.rectangle(OPTIONS.left_gap, 0, Game.buffer_width-1, OPTIONS.top_gap-1, bg_colour, bg_colour)
            -- ...bottom
            draw.rectangle(OPTIONS.left_gap, Game.bottom_padding_start, Game.buffer_width-1, OPTIONS.bottom_gap-1, bg_colour, bg_colour)
            -- ...game area
            if bg_colour == 0xffF8F8F8 then draw.rectangle(OPTIONS.left_gap, OPTIONS.top_gap, Game.buffer_width-1, Game.buffer_height-1, bg_colour, bg_colour) end
        end
        --gui.clearGraphics()
        return
    end
    
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
    
    --- Level info
    -- Get which level is running -- TODO: could be done inside main_game_scan
    local level_identifier = ""
    for addr = RAM.level_identifier, RAM.level_identifier + 5 do
        level_identifier = level_identifier .. fmt("%02X", u8(addr))
    end
    local level_id = 0
    local level_name = "_____"
    local level_width, level_height = 0, 0
    local world = 0
    if Level.data[level_identifier] then
        level_id = Level.data[level_identifier].id
        level_name = Level.data[level_identifier].name
        level_width = u16(RAM.level_width) -- could be Level.data[level_identifier].width
        level_height = u16(RAM.level_height) -- could be Level.data[level_identifier].height
        if level_id <= 5 then world = 1
        elseif level_id <= 10 then world = 2
        elseif level_id <= 15 then world = 3
        else world = 4
        end
    end
    
    --[[Handle avoiding black borders
    local x_origin_screen, y_origin_screen = screen_coordinates(OPTIONS.left_gap + 0, OPTIONS.top_gap + 0, Camera_x, Camera_y)
    draw.text(0, 40 + 0*BIZHAWK_FONT_HEIGHT, fmt("origin_screen = (%d, %d)", x_origin_screen, y_origin_screen), "cyan")
    local x_limit_screen, y_limit_screen = screen_coordinates(OPTIONS.left_gap + level_width, OPTIONS.top_gap + level_height, Camera_x, Camera_y)
    draw.text(0, 40 + 1*BIZHAWK_FONT_HEIGHT, fmt("limit_screen = (%d, %d)", x_limit_screen, y_limit_screen), "cyan")
    draw.text(0, 40 + 2*BIZHAWK_FONT_HEIGHT, fmt("screen = (%d, %d)", Game.screen_width, Game.screen_height), "cyan")
    draw.text(0, 40 + 4*BIZHAWK_FONT_HEIGHT, fmt("left = %d", OPTIONS.left_gap + x_origin_screen), x_origin_screen > 0 and 0xffFF0000 or 0xff00FF00)
    if x_origin_screen > 0 then
        OPTIONS.left_gap = OPTIONS.left_gap - x_origin_screen
        client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
    end]]
    
    -- Cover black borders with plain colour, according to current world and current palette phase...
    local bg_colours = {
        [01] = {0xffBCD0CB, 0xffBED8D2, 0xffBED8D2, 0xffC4F8EC, 0xffF8F8F8, 0xffF8F8F8},
        [02] = {0xffE9F2E4, 0xffEAF4EA, 0xffF8F8F8, 0xffF8F8F8, 0xffF8F8F8, 0xffF8F8F8},
        [03] = {0xffF4E8CC, 0xffF4E8CC, 0xffF4E8CC, 0xffF4E8CC, 0xffF8F8F8, 0xffF8F8F8},
        [04] = {0xffF4E8CC, 0xffF4E8CC, 0xffF4E8CC, 0xffF4E8CC, 0xffF8F8F8, 0xffF8F8F8},
    }
    local palette_phase = u8(RAM.fade_phase)
    local bg_colour = bg_colours[world][palette_phase+1]
    -- ...left
    draw.rectangle(0, 0, OPTIONS.left_gap-1, Game.screen_height-1, bg_colour, bg_colour)
    -- ...right
    draw.rectangle(Game.right_padding_start, 0, OPTIONS.right_gap-1, Game.screen_height-1, bg_colour, bg_colour)
    -- ...top
    draw.rectangle(OPTIONS.left_gap, 0, Game.buffer_width-1, OPTIONS.top_gap-1, bg_colour, bg_colour)
    -- ...bottom
    draw.rectangle(OPTIONS.left_gap, Game.bottom_padding_start, Game.buffer_width-1, OPTIONS.bottom_gap-1, bg_colour, bg_colour)
    
    -- Display level image on screen padding...
    local path = "Level Maps\\"
    local file_name = fmt("Level %02d pal %d.png", level_id, palette_phase)
    --gui.drawImageRegion(string path, int source_x, int source_y, int source_width, int source_height, int dest_x, int dest_y, [int? dest_width = nil], [int? dest_height = nil], [string surfacename = nil])
    -- ...left
    draw.image_region(path..file_name, Previous.Camera_x - OPTIONS.left_gap, Previous.Camera_y - OPTIONS.top_gap, OPTIONS.left_gap, Game.screen_height, 0, 0)
    -- ...right
    draw.image_region(path..file_name, Previous.Camera_x + Game.buffer_width, Previous.Camera_y - OPTIONS.top_gap, OPTIONS.right_gap, Game.screen_height, Game.right_padding_start, 0)
    -- ...top
    draw.image_region(path..file_name, Previous.Camera_x, Previous.Camera_y - OPTIONS.top_gap, Game.buffer_width, OPTIONS.top_gap, OPTIONS.left_gap, 0)
    -- ...bottom
    draw.image_region(path..file_name, Previous.Camera_x, Previous.Camera_y + Game.buffer_height, Game.buffer_width, OPTIONS.bottom_gap, OPTIONS.left_gap, Game.bottom_padding_start)
    -- ...game area
    if bg_colour == 0xffF8F8F8 then draw.rectangle(OPTIONS.left_gap, OPTIONS.top_gap, Game.buffer_width-1, Game.buffer_height-1, bg_colour, bg_colour) end
    
    -- Display the level info
    if OPTIONS.DEBUG then
        local colour = Level.data[level_identifier] and "white" or "red"
        local level_str = fmt("Level: %02d (%s)", level_id, level_name)
        draw.text(PC.buffer_middle_x - BIZHAWK_FONT_WIDTH*string.len(level_str)/2, PC.bottom_padding_start, level_str, colour)
    end
    
    --- Object info
    -- Main object loop
    local have_cannons = false
    local ending_x, ending_y = 0, 0
    --local anim_frames, type_ptrs = {}, {} -- RESEARCH/REMOVE
    for slot = 0x0, 0x13 do
        -- Fade slots not used in the current level
        local empty_slot = false
        if Level.data[level_identifier] then
            if slot+1 > Level.data[level_identifier].objects then
                empty_slot = true
            end
        end
        
        -- Read RAM
        local offset = slot*0x32
        local x_pos_raw = u16(RAM.objects_x_pos + offset)
        local y_pos_raw = u16(RAM.objects_y_pos + offset)
        local flags = u8(RAM.objects_flags + offset)
        local type_ptr = u16(RAM.objects_type_pointer + offset)
        local anim_frame = u8(RAM.objects_anim_frame + offset)
        
        -- Calculations
        local x_pos, y_pos = floor(x_pos_raw/0x10), floor(y_pos_raw/0x10)
        local x_subpos, y_subpos = x_pos_raw - x_pos*0x10, y_pos_raw - y_pos*0x10
        local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
        
        -- Update previous/current values frame
        Previous.object_anim[slot] = Current.object_anim[slot]
        Current.object_anim[slot] = anim_frame
        Previous.object_x_screen[slot] = Current.object_x_screen[slot]
        Current.object_x_screen[slot] = x_screen
        Previous.object_y_screen[slot] = Current.object_y_screen[slot]
        Current.object_y_screen[slot] = y_screen
        
        -- Display object image on screen
        if not empty_slot then
            local path = "Object Images\\"
            local file_name = fmt("$%04X - %02X pal %d.png", type_ptr, Previous.object_anim[slot], palette_phase) -- prev is more precise for this matter
            if file_exists(path..file_name) then
                if type_ptr == 0x7D3E and bit.check(flags, 2) then -- Yuzu taken
                    -- don't draw object image
                else
                    if Previous.object_x_screen[slot] < 0 or Previous.object_x_screen[slot] + 16 > 160 or Previous.object_y_screen[slot]-8 < 0 or Previous.object_y_screen[slot]-8 + 16 > 144 then -- check if object is outside the game screen area
                        draw.image(path..file_name, OPTIONS.left_gap + Previous.object_x_screen[slot], OPTIONS.top_gap - 8 + Previous.object_y_screen[slot]) -- prev is more precise for this matter
                    end
                end
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
        
        -- DEBUG
        
    end
    
    --- Display cannoballs info
    if have_cannons then
        
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
        
            -- Update previous/current values frame
            Previous.cannonball_x_pos_raw[slot] = Current.cannonball_x_pos_raw[slot]
            Current.cannonball_x_pos_raw[slot] = x_pos_raw
            Previous.cannonball_x_screen[slot] = Current.cannonball_x_screen[slot]
            Current.cannonball_x_screen[slot] = x_screen
            Previous.cannonball_y_screen[slot] = Current.cannonball_y_screen[slot]
            Current.cannonball_y_screen[slot] = y_screen
            
            -- Fade slots not used
            local empty_slot = false
            if (timer == 0x00) or (x_screen < -0x08) or (x_screen > 0x98) or (y_screen < -0x08) or (y_screen > 0x88) then
                empty_slot = true
            end
            
            -- Get display colour
            local colour = 0xff00FFFF
            if empty_slot then colour = 0x80FFFFFF end
            
            -- Display cannonball image on screen
            local x_pos_diff = math.abs(Previous.cannonball_x_pos_raw[slot] - Current.cannonball_x_pos_raw[slot])
            if not empty_slot and x_pos_diff <= 0x20 and x_pos_diff >= 0x10 then -- cannonball moving always has speed 0x20, also it prevents displaying the first frame of cannonball displaced                
                local file_name = "Object Images\\Cannonball.png"
                if Previous.cannonball_x_screen[slot] < 0 or Previous.cannonball_x_screen[slot] + 16 > 160 or Previous.cannonball_y_screen[slot]-8 < 0 or Previous.cannonball_y_screen[slot]-8 + 16 > 144 then -- check if cannonball is outside the game screen area
                    draw.image(file_name, OPTIONS.left_gap + Previous.cannonball_x_screen[slot], OPTIONS.top_gap - 8 + Previous.cannonball_y_screen[slot]) -- prev is more precise for this matter
                end
            end
            
        end
    end
    
    --- Display camera info
    -- Camera coordinates
    if OPTIONS.DEBUG then
        local camera_str = fmt("Camera: %04X, %04X", Camera_x, Camera_y)
        draw.text(PC.buffer_middle_x - BIZHAWK_FONT_WIDTH*string.len(camera_str)/2, PC.top_padding - BIZHAWK_FONT_HEIGHT, camera_str)
        -- Draw game screen area
        draw.rectangle(OPTIONS.left_gap, OPTIONS.top_gap, 160, 144, 0x80FF0000)
        -- Display the level boundaries
        local x_origin_screen, y_origin_screen = screen_coordinates(OPTIONS.left_gap + 0, OPTIONS.top_gap + 0, Camera_x, Camera_y)
        draw.rectangle(x_origin_screen, y_origin_screen, level_width-1, level_height-1, 0x8000FF00)
    end
    
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
  
    gui.clearImageCache()
    
    gui.clearGraphics()
  
	client.SetGameExtraPadding(0, 0, 0, 0)
  
    print("\nFinishing Capybara Quest Atlas Script.\n------------------------------------")
end)

-- Script load success message (NOTHING AFTER HERE, ONLY MAIN SCRIPT LOOP)
print("\n\nCapybara Quest Atlas Script loaded successfully at " .. os.date("%X") .. ".\n") -- %c for date and time

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


