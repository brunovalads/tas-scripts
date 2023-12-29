--####################################################################
--##                                                                ##
--##   Little Sisyphus (NES) Script for BizHawk                     ##
--##   http://tasvideos.org/Bizhawk.html                            ##
--##                                                                ##
--##   Author: Bruno Valadão Cunha (BrunoValads) [12/2023]          ##
--##                                                                ##
--##   Git repository: https://github.com/brunovalads/tas-scripts   ##
--##                                                                ##
--####################################################################

--################################################################################################################################################################
-- INITIAL STATEMENTS

-- Game name
local Game_name = "Little Sisyphus"

-- Script options
local OPTIONS = {
    
    -- Script settings
    left_gap = 80, 
    right_gap = 80,
    top_gap = 30,
    bottom_gap = 30,
    
    -- Show/hide options
    display_tile_grid = false,
    display_minimap = true,
    
    -- DEBUG
    DEBUG = false, -- to display debug info for script development only!
    --left_gap = 0, -- 80 if scaled down
    --right_gap = 250,
    --top_gap = 0,
    --bottom_gap = 0, -- 20 is scaled down

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

-- Other global constants
local FRAMERATE = 60.0988138974405
local NES_WIDTH = 256
local NES_HEIGHT = 240


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
    local total_seconds = frame/FRAMERATE
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

-- Draw an arrow given (x1, y1) and (x2, y2)
function draw.arrow(x1, y1, x2, y2, colour, head)
    
    local angle = math.atan((y2-y1)/(x2-x1)) -- in radians
    
    -- Arrow head
    local head_size = head or 10
    local angle1, angle2 = angle + math.pi/4, angle - math.pi/4 --0.785398163398, angle - 0.785398163398 -- 45° in radians
    local delta_x1, delta_y1 = floor(head_size*math.cos(angle1)), floor(head_size*math.sin(angle1))
    local delta_x2, delta_y2 = floor(head_size*math.cos(angle2)), floor(head_size*math.sin(angle2))
    local head1_x1, head1_y1 = x2, y2 
    local head1_x2, head1_y2 
    local head2_x1, head2_y1 = x2, y2
    local head2_x2, head2_y2
    
    if x1 < x2 then -- 1st and 4th quadrant
        head1_x2, head1_y2 = head1_x1 - delta_x1, head1_y1 - delta_y1
        head2_x2, head2_y2 = head2_x1 - delta_x2, head2_y1 - delta_y2
    elseif x1 == x2 then -- vertical arrow
        head1_x2, head1_y2 = head1_x1 - delta_x1, head1_y1 - delta_y1
        head2_x2, head2_y2 = head2_x1 - delta_x2, head2_y1 - delta_y2
    else
        head1_x2, head1_y2 = head1_x1 + delta_x1, head1_y1 + delta_y1
        head2_x2, head2_y2 = head2_x1 + delta_x2, head2_y1 + delta_y2
    end
    
    -- Draw
    draw.line(x1, y1, x2, y2, colour)
    draw.line(head1_x1, head1_y1, head1_x2, head1_y2, colour)
    draw.line(head2_x1, head2_y1, head2_x2, head2_y2, colour)
end

-- Draw an arrow given a start point, an angle in radians and a length, follow the Left Hand Rule due Y being from top to bottom
function draw.arrow_by_angle(startX, startY, angleRadians, length, headSize, colour)
    
    -- Init
    local length = length or 16
    local headSize = headSize or 8
    local colour = colour or 0xffFFFFFF
    
    -- Calculate the arrow end point
    local endX = startX + length*math.cos(angleRadians)
    local endY = startY + length*math.sin(angleRadians)
    
    -- Calculate the angles for the head lines
    local angleLeft = angleRadians + 3*math.pi/4 -- 135° in radians
    local angleRight = angleRadians - 3*math.pi/4
    
    -- Calculate the end points for the head lines
    local headLeftEndX = endX + headSize*math.cos(angleLeft)
    local headLeftEndY = endY + headSize*math.sin(angleLeft)
    local headRightEndX = endX + headSize*math.cos(angleRight)
    local headRightEndY = endY + headSize*math.sin(angleRight)
    
    -- Draw the lines
    draw.line(startX, startY, endX, endY, colour)
    draw.line(endX, endY, headLeftEndX, headLeftEndY, colour)
    draw.line(endX, endY, headRightEndX, headRightEndY, colour)
end

-- Converts the in-game (x, y) to BizHawk-screen coordinates
local function screen_coordinates(x, y, camera_x, camera_y)
    local x_screen = x - camera_x + OPTIONS.left_gap
    local y_screen = y - camera_y + OPTIONS.top_gap

    return x_screen, y_screen
end

-- Convert unsigned byte to signed in hex string
local function signed8hex(num, signal)
    local maxval = 128
    if signal == nil then signal = true end

    if num < maxval then -- positive
        return string.format("%s%02X", signal and "+" or "", num)
    else -- negative
        return string.format("%s%02X", signal and "-" or "", 2*maxval - num)
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

-- Some useful basic function lacking in Lua
function math.round(number, dec_places)
    local mult = 10^(dec_places or 0)
    return math.floor(number * mult + 0.5) / mult
end

function string.insert(str1, str2, pos)
    return str1:sub(1, pos)..str2..str1:sub(pos+1)
end

function distance(x1, x2, y1, y2)
   return sqrt((x1 - x2)^2 + (y1 - y2)^2) 
end

function is_inside_camera(x_screen, y_screen)
    local is_x_inside = (x_screen > Game.left_padding) and (x_screen < Game.right_padding_start)
    local is_y_inside = (y_screen > Game.top_padding)  and (y_screen < Game.bottom_padding_start)
    return is_x_inside and is_y_inside
end            

--################################################################################################################################################################
-- GAME INFO DISPLAY FUNCTIONS

-- RAM addresses
local RAM = {
    -- Player
    x_subpos = 0x001F,
    x_pos = 0x0020, -- 2 bytes
    y_subpos = 0x0022,
    y_pos = 0x0023, -- 2 bytes
    can_jump = 0x04A3,
    x_subspeed = 0x002B,
    x_speed = 0x002C,
    y_subspeed = 0x002D,
    y_speed = 0x002E,
    
    -- Pearl
    pearl_x_subpos = 0x000E,
    pearl_x_pos = 0x000F, -- 2 bytes
    pearl_y_subpos = 0x0011,
    pearl_y_pos = 0x0012, -- 2 bytes
    pearl_x_subspeed = 0x0014,
    pearl_x_speed = 0x0015,
    pearl_y_subspeed = 0x0016,
    pearl_y_speed = 0x0017,
    pearl_subangle = 0x0018,
    pearl_angle = 0x0019,
    
    -- General
    control_enabled = 0x0006,
    game_mode = 0x067A,
    camera_x = 0x04A7, -- 2 bytes, also 0x0035
    camera_y = 0x04A9, -- 2 bytes, also 0x0037controller = 0x0415,
    is_paused = 0x049B,
    current_checkpoint = 0x066D,
    souls = 0x049F,
    tide_elevation = 0x003A, -- 2 bytes
    
    -- Bumbers, 7 bytes per table, 1 per slot
    bumpers_x_pos_low = 0x0601,
    bumpers_x_pos_high = 0x0608,
    bumpers_y_pos_low = 0x060F,
    bumpers_y_pos_high = 0x0616,
    
    -- Checkpoints, 9 bytes per table, 1 per slot
    checkpoints_x_pos_low = 0x0640,
    checkpoints_x_pos_high = 0x0649,
    checkpoints_y_pos_low = 0x0652,
    checkpoints_y_pos_high = 0x065B,
    
    -- Squid
    squid_x_pos = 0x04E8, -- 2 bytes
    squid_y_pos = 0x066E, -- 2 bytes
}

-- ROM addresses
local ROM = {
    blocks = 0x9F00, -- 0x1400 (5120) bytes
}

-- Block types:
local BlockTypes = {}
-- Solid blocks
BlockTypes.Solid = {
    -- Regular solid blocks
    0x02,
    0x0B,
    0x10, 0x11, 0x12, 0x13, 0x1B, 0x1C, 0x1E, 0x1F,
    0x20, 0x21, 0x23, 0x22, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
    0x33, 0x3F, 0x3E,
    0x47, 0x4C, 0x4D, 0x4F,
    0x5D, 0x5E,
    
    -- Slope blocks
    0x1A, 0x1D, 0x5C, 0x5F,
    
    -- Stair blocks
    0x57, 0x58, 0x59
}
BlockTypes.Solid_dict = {}
for id = 1, #BlockTypes.Solid do
    BlockTypes.Solid_dict[BlockTypes.Solid[id]] = true
end
-- One-way blocks
BlockTypes.One_way = {
    0x0A, 0x3D, 0x7A, 0x93, 0xA3, 0xB9, 0xC9, 0xE4, 0xE5, 0xE6, 0xF4, 0xF5, 0xF6, 0xF7,
}
BlockTypes.One_way_dict = {}
for id = 1, #BlockTypes.One_way do
    BlockTypes.One_way_dict[BlockTypes.One_way[id]] = true
end
-- Wind blocks
BlockTypes.Wind = {
    0x25, 0x26, 0x27, 0x28, 0x2A, 0x35, 0x36, 0x37, 0x38, 0x3A, 0x48, 0x4A,
}
BlockTypes.Wind_dict = {}
for id = 1, #BlockTypes.Wind do
    BlockTypes.Wind_dict[BlockTypes.Wind[id]] = true
end




-- Main player RAM read, outside the main_display because I need previous
local X_pos, Y_pos
local X_pos_prev, Y_pos_prev = 0, 0
local function main_player()
    if X_pos then X_pos_prev = X_pos end -- conditional to avoid writing nil to prev
    if Y_pos then Y_pos_prev = Y_pos end
    X_pos = s16(RAM.x_pos)
    Y_pos = s16(RAM.y_pos)
end

-- Main display function, ALL DRAWINGS SHOULD BE CALLED HERE
local function main_display()
    --- Dark filter
    draw.rectangle(OPTIONS.left_gap, OPTIONS.top_gap, NES_WIDTH, NES_HEIGHT, 0x80000000, 0x80000000)
    
    --- Movie timer
    local timer_str = frame_time(Framecount, true)
    draw.text(0, 0, fmt("%s", timer_str), "white", "bottomright")
    
    --- Control enebled and game mode
    local control_enabled = u8(RAM.control_enabled) == 0x01
    if not control_enabled then return end
    local game_mode = u8(RAM.game_mode) -- 00 = Casual, 01 = Frantic
    
    --- Camera info
    Camera_x = s16(RAM.camera_x)
    Camera_y = s16(RAM.camera_y) - 0x20 -- -0x20 to account for the banner
    local camera_str = fmt("Camera (%04X, %04X)", Camera_x, Camera_y)
    draw.text(PC.screen_middle_x - string.len(camera_str) * BIZHAWK_FONT_WIDTH / 2, 0, camera_str)
    
    --- Souls info
    local souls = u8(RAM.souls)
    draw.text(2, 0, fmt("Souls: %02d/80", souls), "white", "topright")
    
    --- Block grid and minimap
    local minimap_x, minimap_y = Game.screen_width - 0x20 - 1, Game.top_padding
    if OPTIONS.display_tile_grid or OPTIONS.display_minimap then
        draw.text(0, PC.top_padding - BIZHAWK_FONT_HEIGHT, fmt("Minimap"), "white", "topright")
        draw.rectangle(minimap_x - 1, minimap_y - 1, 0x21, 0xA1, 0xffFFFFFF)
        local block_id, block_type
        local colour_border, colour_fill
        for y = 0, 0x9F do
            for x = 0, 0x1F do
                -- Get the colour according to the block type
                block_id = y*32 + x
                block_type = memory.read_u8(ROM.blocks + block_id, "PRG ROM")
                empty_block = false
                if BlockTypes.Solid_dict[block_type] then
                    colour_border, colour_fill = 0x800000FF, 0x600000FF
                elseif BlockTypes.One_way_dict[block_type] then
                    colour_border, colour_fill = 0x8000FFFF, 0x6000FFFF
                elseif BlockTypes.Wind_dict[block_type] then
                    colour_border, colour_fill = 0x80FFFF00, 0x60FFFF00
                elseif block_type == 0x07 then -- breakable block
                    colour_border, colour_fill = 0x8000FF00, 0x6000FF00
                elseif block_type == 0x15 then -- skull
                    colour_border, colour_fill = 0x80FF0000, 0x60FF0000
                elseif block_type == 0x16 then -- bouncy block
                    colour_border, colour_fill = 0x80FF00FF, 0x60FF00FF
                elseif block_type == 0x18 then -- anti-pearl block
                    colour_border, colour_fill = 0x80FF7F00, 0x60FF7F00
                else
                    colour_border, colour_fill = 0x80808080, nil
                    empty_block = true
                end
                
                -- Draw the grid
                if OPTIONS.display_tile_grid then
                    local x_screen, y_screen = screen_coordinates(x*16, y*16, Camera_x, Camera_y) 
                    x_screen = x_screen % 0x200
                    local inside_screen = (x_screen > -0x10) and (x_screen < Game.screen_width)
                                      and (y_screen > -0x10) and (y_screen < Game.screen_height)
                    if not empty_block and is_inside_camera(x_screen, y_screen) then
                        draw.rectangle(x_screen, y_screen, 15, 15, colour_border, colour_fill)
                        draw.pixel_text(x_screen, y_screen, fmt("%02X", block_type), 0x40FFFFFF)
                    end
                end
                
                -- Draw the minimap
                if OPTIONS.display_minimap and not empty_block then
                    draw.pixel(minimap_x + x, minimap_y + y, colour_border + 0x4F000000)
                end
            end
        end
    end
    
    --- Player info
    -- Read RAM
    local x_pos = X_pos
    local y_pos = Y_pos
    local x_subpos = u8(RAM.x_subpos)
    local y_subpos = u8(RAM.y_subpos)
    local x_speed = s8(RAM.x_speed)
    local y_speed = s8(RAM.y_speed)
    local x_speed_full = u16(RAM.x_subspeed)
    local y_speed_full = u16(RAM.y_subspeed)
    local can_jump = u8(RAM.can_jump) ~= 0
    
    -- RAM that need calc
    local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
    --x_screen = x_screen & 0xFF
    --y_screen = y_screen & 0xFF
    local x_spd_str = string.insert(signed16hex(x_speed_full, true), ".", 3)
    local y_spd_str = string.insert(signed16hex(y_speed_full, true), ".", 3)
    local dx_pos = X_pos - X_pos_prev
    local dy_pos = Y_pos - Y_pos_prev
    local dx_str = string.insert(signed16hex(dx_pos, true), ".", 3)
    local dy_str = string.insert(signed16hex(dy_pos, true), ".", 3)
    
    -- Display player info
    local i = 0
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, "Sisyphus:"); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Pos (%03X.%02x, %03X.%02x)", x_pos, x_subpos, y_pos, y_subpos)); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Speed (%s, %s)", x_spd_str, y_spd_str)); i = i + 1
    --draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Delta: %+d, %+d", dx_pos, dy_pos)); i = i + 1 -- TODO
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Can jump: %s", can_jump and "yes" or "no")); i = i + 1
  
    -- Show position and interaction points on screen
    draw.cross(x_screen, y_screen, 2, "orange")
    draw.cross(x_screen - 5, y_screen + 7, 2, "blue")
    draw.cross(x_screen + 4, y_screen + 7, 2, "blue")
    draw.cross(x_screen - 5, y_screen - 6, 2, "blue")
    draw.cross(x_screen + 4, y_screen - 6, 2, "blue")
    draw.cross(x_screen + 0x200, y_screen, 2, "orange")
    draw.cross(x_screen + 0x200 - 5, y_screen + 7, 2, "blue")
    draw.cross(x_screen + 0x200 + 4, y_screen + 7, 2, "blue")
    draw.cross(x_screen + 0x200 - 5, y_screen - 6, 2, "blue")
    draw.cross(x_screen + 0x200 + 4, y_screen - 6, 2, "blue")
    
    -- Show position on minimap
    if OPTIONS.display_minimap then
        draw.pixel(minimap_x + floor(x_pos/16), minimap_y + floor(y_pos/16), "orange")
    end
    
    --- Pearl info
    -- Read RAM
    local pearl_x_pos = s16(RAM.pearl_x_pos)
    local pearl_y_pos = s16(RAM.pearl_y_pos)
    local pearl_x_subpos = u8(RAM.pearl_x_subpos)
    local pearl_y_subpos = u8(RAM.pearl_y_subpos)
    local pearl_x_speed = s8(RAM.pearl_x_speed)
    local pearl_y_speed = s8(RAM.pearl_y_speed)
    local pearl_x_speed_full = u16(RAM.pearl_x_subspeed)
    local pearl_y_speed_full = u16(RAM.pearl_y_subspeed)
    local pearl_subangle = u8(RAM.pearl_subangle)
    local pearl_angle = u8(RAM.pearl_angle)
    
    -- RAM that need calc
    local pearl_x_screen, pearl_y_screen = screen_coordinates(pearl_x_pos, pearl_y_pos, Camera_x, Camera_y)
    local pearl_x_spd_str = string.insert(signed16hex(pearl_x_speed_full, true), ".", 3)
    local pearl_y_spd_str = string.insert(signed16hex(pearl_y_speed_full, true), ".", 3)
    
    -- Display pearl info
    i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, "Pearl:"); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Pos (%03X.%02x, %03X.%02x)", pearl_x_pos, pearl_x_subpos, pearl_y_pos, pearl_y_subpos)); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Speed (%s, %s)", pearl_x_spd_str, pearl_y_spd_str)); i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Angle %02X.%02x", pearl_angle, pearl_subangle)); i = i + 1
  
    -- Show position and interaction points on screen
    draw.cross(pearl_x_screen, pearl_y_screen, 2, "purple")
    draw.cross(pearl_x_screen + 0x200, pearl_y_screen, 2, "purple")
    
    -- Show direction to pearl if it's too far away
    local distance1 = distance(X_pos, pearl_x_pos, Y_pos, pearl_y_pos)
    local distance2 = distance(X_pos + 0x200, pearl_x_pos, Y_pos, pearl_y_pos)
    local distance3 = distance(X_pos, pearl_x_pos + 0x200, Y_pos, pearl_y_pos)
    local distance_to_pearl = math.min(distance1, distance2, distance3)
    if distance_to_pearl > 80 then
        local arrow_x1, arrow_y1, arrow_x2, arrow_y2 = nil, y_screen, nil, pearl_y_screen
        if is_inside_camera(x_screen, y_screen) then
            arrow_x1 = x_screen
            if distance(x_screen, pearl_x_screen, y_screen, pearl_y_screen) < distance(x_screen, pearl_x_screen + 0x200, y_screen, pearl_y_screen) then
                arrow_x2 = pearl_x_screen
            else
                arrow_x2 = pearl_x_screen + 0x200
            end 
        elseif is_inside_camera(x_screen + 0x200, y_screen) then
            arrow_x1 = x_screen + 0x200
            if distance(x_screen + 0x200, pearl_x_screen, y_screen, pearl_y_screen) < distance(x_screen + 0x200, pearl_x_screen + 0x200, y_screen, pearl_y_screen) then
                arrow_x2 = pearl_x_screen
            else
                arrow_x2 = pearl_x_screen + 0x200
            end 
        end
        if arrow_x1 ~= nil then
            draw.arrow(arrow_x1, arrow_y1, arrow_x2, arrow_y2, 0x80FFFFFF, 10)
        end
    end
    
    -- Show pearl position on minimap
    if OPTIONS.display_minimap then
        draw.pixel(minimap_x + floor(pearl_x_pos/16), minimap_y + floor(pearl_y_pos/16), "purple")
    end
    
    --- Bumper info
    i = i + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, "Bumpers:"); i = i + 1
    local colour
    local colours = {
        0xa0A0A0FF, -- blue
        0xa0FF80FF, -- magenta
        0xa0FF6060, -- red
        0xa0FFA100, -- orange
        0xa0FFFF80, -- yellow
        0xa040FF40, -- green
        0xa000E0E0  -- cyan
    }
    -- Main bumper loop
    local bumpers_slots = 7
    for slot = 0, bumpers_slots-1 do
        -- Read RAM
        x_pos = u8(RAM.bumpers_x_pos_low + slot) + 0x100 * u8(RAM.bumpers_x_pos_high + slot)
        y_pos = u8(RAM.bumpers_y_pos_low + slot) + 0x100 * u8(RAM.bumpers_y_pos_high + slot)
        
        -- Calculate position on screen
        x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
        
        -- Get slot colour
        colour = colours[slot%#colours+1]
        
        -- Display position and slot on screen
        draw.cross(x_screen, y_screen, 2, colour)
        draw.cross(x_screen + 0x200, y_screen, 2, colour)
        draw.pixel_text(x_screen, y_screen, fmt("%d", slot), colour)
        draw.pixel_text(x_screen + 0x200, y_screen, fmt("%d", slot), colour)
        
        -- Display info on bumpers table
        draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT + slot * BIZHAWK_FONT_HEIGHT, fmt("#%d: (%03X, %03X)", slot, x_pos, y_pos), colour)
    end
    
    --- Checkpoint info
    local current_checkpoint = u8(RAM.current_checkpoint)
    i = i + bumpers_slots + 1
    draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, "Checkpoints:"); i = i + 1
    -- Main checkpoint loop
    local checkpoints_slots = 9
    for slot = 0, checkpoints_slots-1 do
        -- Read RAM
        x_pos = u8(RAM.checkpoints_x_pos_low + slot) + 0x100 * u8(RAM.checkpoints_x_pos_high + slot)
        y_pos = u8(RAM.checkpoints_y_pos_low + slot) + 0x100 * u8(RAM.checkpoints_y_pos_high + slot)
        
        -- Calculate position on screen
        x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
        
        -- Get slot colour
        colour = colours[slot%#colours+1]
        
        -- Find if current slot is the current active checkpoint
        local current = slot == current_checkpoint and "<-" or ""
        
        -- Display position and slot on screen
        draw.cross(x_screen, y_screen, 2, colour)
        draw.cross(x_screen + 0x200, y_screen, 2, colour)
        draw.pixel_text(x_screen, y_screen, fmt("%d", slot), colour)
        draw.pixel_text(x_screen + 0x200, y_screen, fmt("%d", slot), colour)
        
        -- Display info on checkpoints table
        draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT + slot * BIZHAWK_FONT_HEIGHT, fmt("#%d: (%03X, %03X) %s", slot, x_pos, y_pos, current), colour)
    end
    
    --- Frantic exclusive info
    i = i + checkpoints_slots + 1
    if game_mode == 01 then
        -- Tide info
        local tide_elevation = u16(RAM.tide_elevation)
        draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Tide elevation: %03X", tide_elevation), "red"); i = i + 1
        if OPTIONS.display_minimap and tide_elevation < 0xA00 then
            draw.box(minimap_x, minimap_y + floor(tide_elevation/16), minimap_x + 0x20-1, minimap_y + 0xA0-1, 0xC0404040, 0xC0404040)
        end
        
        -- Squid info
        local squid_x_pos = s16(RAM.squid_x_pos)
        local squid_y_pos = s16(RAM.squid_y_pos)
        local squid_x_screen, squid_y_screen = screen_coordinates(squid_x_pos, squid_y_pos, Camera_x, Camera_y)
        draw.text(2, 60 + i * BIZHAWK_FONT_HEIGHT, fmt("Squid pos (%03X, %03X)", squid_x_pos, squid_y_pos), "red"); i = i + 1
        draw.cross(squid_x_screen, squid_y_screen, 2, "red")
        draw.cross(squid_x_screen + 0x200, squid_y_screen, 2, "red")
        if OPTIONS.display_minimap then
            draw.pixel(minimap_x + floor(squid_x_pos/16), minimap_y + floor(squid_y_pos/16), "red")
        end
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
  
    print(fmt("\nFinishing %s Utility Script.\n------------------------------------", Game_name))
end)

-- Script load success message (NOTHING AFTER HERE, ONLY MAIN SCRIPT LOOP)
print(fmt("\n\n%s Utility Script loaded successfully at %s.\n", Game_name, os.date("%X"))) -- %c for date and time

-- Main loop
while true do
    -- Read very important emu stuff
    bizhawk_screen_info()
    bizhawk_status()
    -- Update main game values and display these stuff
    main_player()
    main_display()
    -- DEBUG
    -- Advance The Frame
    emu.frameadvance()
end


