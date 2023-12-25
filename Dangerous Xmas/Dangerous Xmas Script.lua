--####################################################################
--##                                                                ##
--##   Dangerous Xmas (GBA) Script for BizHawk                      ##
--##   http://tasvideos.org/Bizhawk.html                            ##
--##                                                                ##
--##   Author: Bruno Valadão Cunha (BrunoValads) [11/2023]          ##
--##                                                                ##
--##   Git repository: https://github.com/brunovalads/tas-scripts   ##
--##                                                                ##
--####################################################################

--################################################################################################################################################################
-- INITIAL STATEMENTS

-- Script options
local OPTIONS = {
    
    -- Script settings
    left_gap = 65, 
    right_gap = 68,
    top_gap = 70,
    bottom_gap = 85,
    
    ---- DEBUG ----
    DEBUG = false, -- to display debug info for script development only!
}
if DEBUG then
    OPTIONS.left_gap = 90 -- 80 if scaled down
    OPTIONS.right_gap = 340
    OPTIONS.top_gap = 8
    OPTIONS.bottom_gap = 250 -- 20 is scaled down 
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
local u8 =  memory.read_u8
local s8 =  memory.read_s8
local w8 =  memory.write_u8
local u16 = memory.read_u16_le
local s16 = memory.read_s16_le
local w16 = memory.write_u16_le
local u24 = memory.read_u24_le
local s24 = memory.read_s24_le
local w24 = memory.write_u24_le
memory.usememorydomain("EWRAM")

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

-- Font settings
local BIZHAWK_FONT_WIDTH = 10  -- correction to the scale is done in Biz.screen_info()
local BIZHAWK_FONT_HEIGHT = 18
local PIXEL_FONT_WIDTH = 4
local PIXEL_FONT_HEIGHT = 8

-- Other global constants
local FRAMERATE = 59.727500569606
local GBA_WIDTH = 240
local GBA_HEIGHT = 160


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
    
    PC.bizhawk_font_width = BIZHAWK_FONT_WIDTH   --\ Dimensions for the font BizHawk uses in gui.text
    PC.bizhawk_font_height = BIZHAWK_FONT_HEIGHT --/
    
    PC.pixel_font_width = PIXEL_FONT_WIDTH*Scale   --\ Dimensions for the font BizHawk uses in gui.pixelText
    PC.pixel_font_height = PIXEL_FONT_HEIGHT*Scale --/

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
    
    Game.bizhawk_font_width = PC.bizhawk_font_width/Scale
    Game.bizhawk_font_height = PC.bizhawk_font_height/Scale
    
    Game.pixel_font_width = PIXEL_FONT_WIDTH
    Game.pixel_font_height = PIXEL_FONT_HEIGHT
 
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


--################################################################################################################################################################
-- GAME INFO DISPLAY FUNCTIONS

-- RAM addresses
local RAM = {
    
    -- General
    level_id = 0x01F9,
    camera_x = 0x01FA, -- 2 bytes
    camera_y = 0x01FC, -- 2 bytes
    camera_y_limit = 0x01FE, -- 2 bytes
    controller = 0x0415,
    is_paused = 0x0085,
    lives = 0x041F,
    score = 0x01B0, -- 4 bytes
    blocks = 0x0F28, -- 0xA20 bytes?
    
    -- Player
    x_pos = 0x0EBC,
    y_pos = 0x0EBE,
    status = 0x0ED2,
    gifts = 0x01B4,
    bullets = 0x01B5,
    dynamites = 0x01B6,
    lives = 0x01B7,
    bullet_x_pos = 0x0EE0, -- 2 bytes
    bullet_y_pos = 0x0EE2, -- 2 bytes
    bullet_active = 0x0EFB,
    dynamite_x_pos = 0x0F04, -- 2 bytes
    dynamite_y_pos = 0x0F06, -- 2 bytes
    dynamite_timer = 0x0F16,
    dynamite_status = 0x0F1A,
    dynamite_active = 0x0F1F,
    --interaction_points_blocks = 0x0200, -- 16 bytes
    
    -- Projectile, 0x24 bytes per table, 1 per slot
    projectiles_entry_size = 0x24,
    projectiles_x_pos = 0x06AC, -- 2 bytes
    projectiles_y_pos = 0x06AE, -- 2 bytes
    
    -- Items, 0x24 bytes per table, 1 per slot
    items_entry_size = 0x24,
    items_x_pos = 0x2F40, -- 2 bytes
    items_y_pos = 0x2F42, -- 2 bytes
    items_status = 0x2F56,
    items_type = 0x2F5A,
    items_active = 0x2F5B,
    
    -- Enemies, 0x24 bytes per table, 1 per slot
    objects_entry_size = 0x24,
    objects_x_pos = 0x31D4, -- 2 bytes
    objects_y_pos = 0x31D6, -- 2 bytes
    objects_status = 0x31EA,
    objects_type = 0x31EE,
    objects_active = 0x31EF,
    
    enemy01_x_pos = 0x3288, -- 2 bytes
    enemy01_y_pos = 0x328A, -- 2 bytes
    enemy01_x_patrol_start = 0x328C, -- 2 bytes
    enemy01_y_patrol_start = 0x328E, -- 2 bytes
    enemy01_x_patrol_end = 0x3290, -- 2 bytes
    enemy01_y_patrol_end = 0x3292, -- 2 bytes
    enemy01_a = 0x3294, -- 2 bytes
    enemy01_aa = 0x3296, -- 2 bytes
    enemy01_aaa = 0x3298, -- 2 bytes
    enemy01_aaaa = 0x329A, -- 2 bytes
    enemy01_anim_frame = 0x329C, -- 2 bytes
    enemy01_aaaaaa = 0x329E,
    enemy01_direction = 0x329F,
    
    -- Ice objects, 0x24 bytes per table, 1 per slot
    ice_objects_entry_size = 0x24,
    ice_objects_x_pos = 0x0544,
    ice_objects_x_pos_h = 0x0545,
    ice_objects_y_pos = 0x0546,
    ice_objects_y_pos_h = 0x0547,
    ice_objects_status = 0x055A,
    ice_objects_type = 0x055E,
    ice_objects_active = 0x055F,
}

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
    draw.rectangle(OPTIONS.left_gap, OPTIONS.top_gap, 256, 224, 0x80000000, 0x80000000)
    
    --- Movie timer
    local timer_str = frame_time(Framecount, true)
    draw.text(0, 0, fmt("%s", timer_str), "white", "bottomright")
    
    --- Camera info
    Camera_x = u16(RAM.camera_x)
    Camera_y = u16(RAM.camera_y)
    local camera_str = fmt("Camera (%04X, %04X)", Camera_x, Camera_y)
    draw.text(PC.screen_middle_x - string.len(camera_str) * BIZHAWK_FONT_WIDTH / 2, 0, camera_str)
    
    --- Level info
    local level_id = u8(RAM.level_id)
    local level_max = 07
    draw.text(0, 2 + 0*BIZHAWK_FONT_HEIGHT, fmt("Level %02X/%02X", level_id, level_max), "white", "topright")
    --draw.text(0, 2 + 1*BIZHAWK_FONT_HEIGHT, fmt("%02X x %02X blocks", Level_width, Level_height), "white", 0, 0, "topright")
    local level_height_blocks = (u16(RAM.camera_y_limit) + GBA_HEIGHT) / 8
    
    --- Block grid
    local block_id, block_type
    local block_x_screen, block_y_screen
    local colour_border, colour_fill
    local minimap_y_pos = OPTIONS.DEBUG and 102 or 12 * Game.bizhawk_font_height
    -- GBA_WIDTH = 240
    -- GBA_HEIGHT = 160
    for y = 0, level_height_blocks - 1 do
        for x = 0, GBA_WIDTH/8 + 1 do
            block_x_screen, block_y_screen = screen_coordinates(x*8, y*8, Camera_x, Camera_y)
            -- Get the colour according to the block type
            block_id = y*32 + x
            block_type = u8(RAM.blocks + block_id)
            if block_type == 0x00 then -- Empty block
                colour_border, colour_fill = 0x80808080, nil
            elseif block_type == 0x78 then -- Solid platform block
                colour_border, colour_fill = 0x8000FF00, 0x6000FF00
            elseif block_type == 0x8C then -- Spike block
                colour_border, colour_fill = 0x80FF0000, 0x60FF0000
            elseif block_type == 0x14 then -- Climbable tree block and ladders
                colour_border, colour_fill = 0x80FF7F00, 0x60FF7F00
            else
                colour_border, colour_fill = 0x80FFFF00, 0x60FFFF00
            end
            
            if block_type ~= 0x00 then
	            -- Draw the grid
                if block_x_screen > 0 and block_y_screen > 0 and
                   block_x_screen < Game.screen_width and block_y_screen < Game.screen_height then
                    draw.rectangle(block_x_screen, block_y_screen, 7, 7, colour_border, colour_fill)
                end
                
	            -- Draw the minimap
	            draw.pixel(1 + x, minimap_y_pos + y, colour_border)
            end
            
            -- Aid grid
            --draw.rectangle(OPTIONS.left_gap + x*16 - Camera_x, OPTIONS.top_gap + y*16 - Camera_y, 15, 15, 0x60FFFFFF, 0x60000000)
        end
        -- Display y block value
        --draw.pixel_text(Game.left_padding - 5 * Game.pixel_font_width, block_y_screen, fmt("%02X", y), 0x80FFFFFF)
    end
    
    --- Player info
    -- Read RAM
    local x_pos = X_pos
    local y_pos = Y_pos
    local status = u8(RAM.status)
    local gifts = u8(RAM.gifts)
    local bullets = u8(RAM.bullets)
    local dynamites = u8(RAM.dynamites)
    local lives = u8(RAM.lives)
    local bullet_x_pos = s16(RAM.bullet_x_pos)
    local bullet_y_pos = s16(RAM.bullet_y_pos)
    local bullet_active = u8(RAM.bullet_active) == 1
    local dynamite_x_pos = s16(RAM.dynamite_x_pos)
    local dynamite_y_pos = s16(RAM.dynamite_y_pos)
    local dynamite_timer = u8(RAM.dynamite_timer)
    local dynamite_status = u8(RAM.dynamite_status)
    local dynamite_active = u8(RAM.dynamite_active) == 1
    
    -- RAM that need calc
    local dx_pos = X_pos - X_pos_prev
    local dy_pos = Y_pos - Y_pos_prev
    
    -- Display player info
    local table_x = 2
    local table_y = 2 * BIZHAWK_FONT_HEIGHT
    local i = 0
    draw.text(table_x, table_y + i * BIZHAWK_FONT_HEIGHT, fmt("Pos: %03X, %03X", x_pos & 0xFFFF, y_pos & 0xFFFF)); i = i + 1
    draw.text(table_x, table_y + i * BIZHAWK_FONT_HEIGHT, fmt("Delta: %+d, %+d", dx_pos, dy_pos)); i = i + 1
    draw.text(table_x, table_y + i * BIZHAWK_FONT_HEIGHT, fmt("Status: %02X", status), status == 9 and "red" or "white"); i = i + 2
    draw.text(table_x, table_y + i * BIZHAWK_FONT_HEIGHT, fmt("Gifts: %02d/%02d", gifts, 2+0+2+5+0+2+0+13)); i = i + 1
    draw.text(table_x, table_y + i * BIZHAWK_FONT_HEIGHT, fmt("Bullets: %d", bullets)); i = i + 1
    draw.text(table_x, table_y + i * BIZHAWK_FONT_HEIGHT, fmt("Dynamites: %d", dynamites)); i = i + 1
    draw.text(table_x, table_y + i * BIZHAWK_FONT_HEIGHT, fmt("Lives: %d", lives)); i = i + 1
    
    -- Show position on screen
    local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
    
    -- Show block interaction points on screen
    draw.cross(x_screen, y_screen, 2, "orange")
    draw.cross(x_screen + 4 , y_screen + 23, 2, "blue")
    draw.cross(x_screen + 19, y_screen + 23, 2, "blue")
    draw.cross(x_screen + 4 , y_screen + 3 , 2, "blue")
    draw.cross(x_screen + 19, y_screen + 3 , 2, "blue")
    
    -- Show hitbox
    draw.box(x_screen + 0x04, y_screen + 0x03, x_screen + 0x13, y_screen + 0x17, 0x800000FF, 0x400000FF)
    
    -- Show climbing guide
    draw.line(x_screen + 0x0C, y_screen + 0x01, x_screen + 0x0C, y_screen + 0x04, 0x8000FFFF)
    draw.line(x_screen + 0x0B, y_screen + 0x01, x_screen + 0x0B, y_screen + 0x04, 0x8000FFFF)
    
    -- Show position on minimap
    draw.rectangle(1 + floor((x_pos)/8), minimap_y_pos + floor((y_pos)/8), 2, 2, 0xA0FF8000, 0xA0FF8000)
    --draw.pixel(1 + floor((x_pos)/8), Game.bottom_padding_start + floor((y_pos)/8), "orange")
    
    -- Show bullet position
    if bullet_active then
        local bullet_x_screen, bullet_y_screen = screen_coordinates(bullet_x_pos, bullet_y_pos, Camera_x, Camera_y)
        draw.cross(bullet_x_screen, bullet_y_screen, 2, "red")
        draw.box(bullet_x_screen + 0x04, bullet_y_screen, bullet_x_screen + 0x0A, bullet_y_screen + 0x05, 0x80FF0000, 0x40FF0000)
    end
    
    -- Show dynamite position
    if dynamite_active then
        local dynamite_x_screen, dynamite_y_screen = screen_coordinates(dynamite_x_pos, dynamite_y_pos, Camera_x, Camera_y)
        draw.cross(dynamite_x_screen, dynamite_y_screen, 2, "red")
        draw.box(dynamite_x_screen - 0x08, dynamite_y_screen, dynamite_x_screen + 0x1B, dynamite_y_screen + 0x17, 0x80FF0000, 0x40FF0000)
        local dynamite_effective_timer = dynamite_status == 0 and 35 - dynamite_timer or 21 - dynamite_timer
        draw.pixel_text(dynamite_x_screen, dynamite_y_screen - Game.pixel_font_height, fmt("%d", dynamite_effective_timer), 0x80FF0000)
    end
    
    --- Object info
    
    -- Display constans
    table_x = PC.right_padding_start + 4*BIZHAWK_FONT_WIDTH
    table_y = OPTIONS.DEBUG and (PC.bottom_padding_start + 2*BIZHAWK_FONT_HEIGHT) or (4 * BIZHAWK_FONT_HEIGHT)
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
    i = 0
    for slot = 0x00, 0x0D do
        -- Read RAM
        local offset = slot*RAM.objects_entry_size
        local x_pos = s16(RAM.objects_x_pos + offset)
        local y_pos = s16(RAM.objects_y_pos + offset)
        local status = u8(RAM.objects_status + offset)
        
        -- Calculations
        local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
        local empty_slot = (status == 0x00) or (x_pos == 0x0000 and y_pos == 0x0000)
        
        -- Get display colour
        local colour = colours[slot%6+1]
        if empty_slot then colour = 0x80FFFFFF end
        
        -- Display pixel position on screen
        if not empty_slot then
            draw.cross(x_screen, y_screen, 2, colour)
        end
        
        -- DEBUG
        local debug_str = ""
        
        -- Display object table
        draw.text(table_x, table_y + slot * BIZHAWK_FONT_HEIGHT, fmt("#%02X: (%03X, %03X) %s %s", slot, x_pos & 0xFFFF, y_pos & 0xFFFF, (OPTIONS.DEBUG or not OPTIONS.display_object_names) and "" or name, debug_str), colour)
        
        -- Display hitbox
        if not empty_slot then
            draw.box(x_screen, y_screen + 0x03, x_screen + 0x18, y_screen + 0x17, colour, colour - 0x80000000)
        end
        
        i = i + 1
    end
    
    --- Other objects info
    
    -- Display constans
    table_y = table_y + (i+2) * BIZHAWK_FONT_HEIGHT
    
    -- Title
    --draw.text(table_x, table_y - BIZHAWK_FONT_HEIGHT, "Items:")
    
    local gifts_in_level_taken = 0
    local gifts_in_level_total = 0
    
    -- Main items loop
    for slot = 0x00, 0x10 do
        -- Read RAM
        local offset = slot*RAM.items_entry_size
        local x_pos = s16(RAM.items_x_pos + offset)
        local y_pos = s16(RAM.items_y_pos + offset)
        local status = u8(RAM.items_status + offset)
        local type = u8(RAM.items_type + offset)
        local active = u8(RAM.items_active + offset) ~= 0
        
        -- Calculations
        local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
        local x_pos_str = signed16hex(x_pos, false)
        local y_pos_str = signed16hex(y_pos, false)
        local empty_slot = (status == 0x00) or (x_pos == 0x0000 and y_pos == 0x0000)
        
        -- Get display colour
        local colour = colours[slot%6+1]
        --if not is_processed then colour = colour - 0x80000000 end
        if empty_slot then colour = 0x80FFFFFF end
        
        -- Display pixel position on screen
        if not empty_slot then
            draw.cross(x_screen, y_screen, 2, colour)
        end
        
        -- DEBUG
        local debug_str = ""
        if OPTIONS.DEBUG then
            for addr = 0, RAM.items_entry_size-1 do
                local value = u8(RAM.items_x_pos + offset + addr)
                debug_str = debug_str .. fmt("%02X ", value)
                if slot == 0 then -- could be any, just want to do this once
                    -- Check if address is already documented
                    local documented = false
                    for k, v in pairs(RAM) do
                        if RAM.items_x_pos + addr == v then documented = true end
                    end
                    draw.text(table_x + 17*BIZHAWK_FONT_WIDTH + addr*3*BIZHAWK_FONT_WIDTH, table_y + (slot-1) * BIZHAWK_FONT_HEIGHT, fmt("%02X", addr), documented and 0xff00FF00 or "white")
                end
            end
            debug_str = debug_str .. fmt("$%04X ", 0x0000 + RAM.items_x_pos + offset)
        end
        
        -- Display items table
        --draw.text(table_x, table_y + slot * BIZHAWK_FONT_HEIGHT, fmt("#%02X: (%03X, %03X) %s %s", slot, x_pos & 0xFFFF, y_pos & 0xFFFF, (OPTIONS.DEBUG or not OPTIONS.display_object_names) and "" or name, debug_str), colour)
        
        -- Display hitbox
        if not empty_slot then
            draw.box(x_screen - 0x02, y_screen, x_screen + 0x1A, y_screen + 0x18, colour, colour - 0x80000000)
        end
        
        -- Increment gift count for the current level
        if type == 0x03 or type == 0x04 then
            gifts_in_level_total = gifts_in_level_total + 1
            if status == 0 then
                gifts_in_level_taken = gifts_in_level_taken + 1
            end
        end
        
        -- Display items on minimap
        if status ~= 0 then
            if (type == 0x03 or type == 0x04) then colour = 0xA0FF00FF else  colour = 0xA0404040 end
            draw.rectangle(1 + floor((x_pos)/8), minimap_y_pos + floor((y_pos)/8), 2, 2, colour, colour)
        end
    end
    
    -- Display gift count
    --draw.text(table_x + 7 * BIZHAWK_FONT_WIDTH, table_y - BIZHAWK_FONT_HEIGHT, fmt("(%d gifts)", gifts_in_level))
    local gift_taken_colour = gifts_in_level_taken == gifts_in_level_total and 0xff00FF00 or 0xffFF0000
    draw.text(0, 2 + 1*BIZHAWK_FONT_HEIGHT, fmt("Gifts in level: %d/%d", gifts_in_level_taken, gifts_in_level_total), gift_taken_colour, "topright")
    
    --- Ice object info
    
    -- Title
    draw.text(table_x, table_y - BIZHAWK_FONT_HEIGHT, "Ice objects:")
    
    -- Ice object hitbox offsets
    local ice_objects_hitbox_offsets = {
        [0x15] = {x1 = -0x02, y1 = 0x00, x2 = 0x19, y2 = 0x17},
        [0x16] = {x1 = -0x01, y1 = -0x01, x2 = 0x1C, y2 = 0x0F},
        [0x17] = {x1 = -0x05, y1 = -0x01, x2 = 0x10, y2 = 0x0F},
        [0x18] = {x1 = 0x02, y1 = 0x00, x2 = 0x16, y2 = 0x10},
        [0x19] = {x1 = 0x06, y1 = 0x03, x2 = 0x0B, y2 = 0x05},
    }
    
    -- Main ice objects loop
    for slot = 0x00, 0x0D do
        -- Read RAM
        local offset = slot*RAM.ice_objects_entry_size
        local x_pos = s16(RAM.ice_objects_x_pos + offset)
        local y_pos = s16(RAM.ice_objects_y_pos + offset)
        local status = u8(RAM.ice_objects_status + offset)
        local type = u8(RAM.ice_objects_type + offset)
        local active = u8(RAM.ice_objects_active + offset) ~= 0
        
        local x_screen, y_screen = screen_coordinates(x_pos, y_pos, Camera_x, Camera_y)
        
        -- Get display colour
        local colour = colours[slot%6+1]
        if not active then colour = 0x80FFFFFF end
        
        if active then
            draw.cross(x_screen, y_screen, 2, colour)
            draw.pixel_text(x_screen + 2, y_screen - 8, fmt("%02X", slot), colour)
            if ice_objects_hitbox_offsets[type] ~= nil then
                local offsets = ice_objects_hitbox_offsets[type]
                draw.box(x_screen + offsets.x1, y_screen + offsets.y1, x_screen + offsets.x2, y_screen + offsets.y2, colour - 0x7f000000, colour - 0xbf000000)
            end
        end
        
        -- DEBUG
        local debug_str = ""
        if OPTIONS.DEBUG then
            for addr = 0, RAM.ice_objects_entry_size-1 do
                local value = u8(RAM.ice_objects_x_pos + offset + addr)
                debug_str = debug_str .. fmt("%02X ", value)
                if slot == 0 then -- could be any, just want to do this once
                    -- Check if address is already documented
                    local documented = false
                    for k, v in pairs(RAM) do
                        if RAM.ice_objects_x_pos + addr == v then documented = true end
                    end
                    draw.text(table_x + 17*BIZHAWK_FONT_WIDTH + addr*3*BIZHAWK_FONT_WIDTH, table_y + (slot-1) * BIZHAWK_FONT_HEIGHT, fmt("%02X", addr), documented and 0xff00FF00 or "white")
                end
            end
            debug_str = debug_str .. fmt("$%04X ", 0x0000 + RAM.ice_objects_x_pos + offset)
        end
        
        -- Display object table
        draw.text(table_x, table_y + slot * BIZHAWK_FONT_HEIGHT, fmt("#%02X: (%03X, %03X) %s %s", slot, x_pos & 0xFFFF, y_pos & 0xFFFF, (OPTIONS.DEBUG or not OPTIONS.display_object_names) and "" or name, debug_str), colour)
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
  
    print("\nFinishing Dangerous Xmas Utility Script.\n------------------------------------")
end)

-- Script load success message (NOTHING AFTER HERE, ONLY MAIN SCRIPT LOOP)
print("\n\nDangerous Xmas Utility Script loaded successfully at " .. os.date("%X") .. ".\n") -- %c for date and time

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

    