
--[[

$0000 (4 bytes) = Clock, minutes 2nd digit (y position, x position, value in graphics, ?)
$0004 (4 bytes) = Clock, minutes 1st digit (y position, x position, value in graphics, ?)
$0008 (4 bytes) = Clock, seconds 2nd digit (y position, x position, value in graphics, ?)
$000C (4 bytes) = Clock, seconds 1st digit (y position, x position, value in graphics, ?)
$0010 (4 bytes) = Clock, tenths of a second (y position, x position, value in graphics, ?)

$003C (32 bytes) = OAM - Moving platforms first tile info: y position, x position, tile ID, ??. Each platform uses 4 bytes, and it can have 8 platforms
$005C (32 bytes) = OAM - Moving platforms second tile info: y position, x position, tile ID, ??. Each platform uses 4 bytes, and it can have 8 platforms
$007C (32 bytes) = OAM - Moving platforms third tile info: y position, x position, tile ID, ??. Each platform uses 4 bytes, and it can have 8 platforms

$009C (4 bytes) = OAM - Ball: y position, x position, tile ID, ??

$00A1 = Current menu option

$00A3 = In game: last block type updated. In menu: Current letter selected in password (graphically)

$00A8 = Button input, format: Ssba-dulr
$00A9 = Button input previous frame, format: Ssba-dulr

$00AE = Menu scrolling background animation frame

$00B0 = Moving platform currently processed x position?

$00B5 = Current level

$00C1 (2 bytes) = X position
$00C3 (2 bytes) = Y position
$00C5 (2 bytes) = X speed
$00C7 (2 bytes) = Y speed

$00C8 = Ball ascending (0xff) or descending (0x00)

$00C9 = Level mode. 0x00 = fading in/out; 0x01 = controlling ball; 0x02 = flying via cannon ;0x04 = dying; 0x05 = winning; 0x06 = level load/password screen 

$00CA = X position in blocks
$00CB = Y position in blocks

$00CC (2 bytes) = Block type the ball is touching (top)
$00CE (2 bytes) = Block type the ball is touching (bottom)
$00D0 (2 bytes) = Block type the ball is touching (left)
$00D2 (2 bytes) = Block type the ball is touching (right)

$00D6 = Hearts remaining to get in the level.

$00D7 (16 bytes) = Moving platforms x position table, 2 bytes per platform
$00E7 (16 bytes) = Moving platforms y position table, 2 bytes per platform
$00F7 (8 bytes) = Moving platforms type table, 1 byte per platform
$00FF (8 bytes) = Moving platforms direction table, 1 byte per platform

$0107 (3 bytes) = Clock, in frames (tenths of a second, seconds, minutes)

$0157 (8 bytes) = Password letters (A = 0x00, B = 0x01, ... , P = 0x0F)

$0166 (2 bytes) = Frame counter (global)

]]--


--- ###########################################################################################################################
--- INITIAL STATEMENTS

local OPTIONS = {
  left_gap = 104,
  top_gap = 32,
  right_gap = 100,
  bottom_gap = 256,
  
  display_platform_info = false,
  display_grid = false,
  display_out_of_bounds_blocks = false,
  display_movie_info = true,
  display_movie_input = true,
  
}

local COLOUR = {
  GB_pal_1 = 0xffA4C505,
  GB_pal_2 = 0xff88A905,
  GB_pal_3 = 0xff1D551D,
  GB_pal_4 = 0xff052505,

  GB_pal_inv_1 = 0xff2605c5,
  GB_pal_inv_2 = 0xff2605a9,
  GB_pal_inv_3 = 0xff551d55,
  GB_pal_inv_4 = 0xff250525,

  GB_pal_tri_1_1 = 0xffA4C505,
  GB_pal_tri_1_2 = 0xff05A4C5,
  GB_pal_tri_1_3 = 0xffC505A4,

  GB_pal_tri_2_1 = 0xff88A905,
  GB_pal_tri_2_2 = 0xff0588A9,
  GB_pal_tri_2_3 = 0xffA90588,

  GB_pal_tri_3_1 = 0xff1D551D,
  GB_pal_tri_3_2 = 0xff1D1D55,
  GB_pal_tri_3_3 = 0xff551D1D,

  GB_pal_tri_4_1 = 0xff052505,
  GB_pal_tri_4_2 = 0xff050525,
  GB_pal_tri_4_3 = 0xff250505,
  
  positive = 0xff00FF00,
  warning = 0xffFF0000,
  weak = 0x80808080,
}

local WRAM = {
  last_block_updated = 0x00A3,
  controller_input = 0x00A8, -- format: Ssba-dulr
  controller_input_prev = 0x00A9,
  current_level = 0x00B5,
  x_pos = 0x00C1, -- 2 bytes
  y_pos = 0x00C3, -- 2 bytes
  x_speed = 0x00C5, -- 2 bytes
  y_speed = 0x00C7, -- 2 bytes
  vertical_direction = 0x00C8, -- ascending = 0xff, descending = 0x00
  level_mode = 0x00C9, -- 0x00 = fading in/out; 0x01 = controlling ball; 0x02 = flying via cannon ;0x04 = dying; 0x05 = winning; 0x06 = level load/password screen
  x_pos_block = 0x00CA,
  y_pos_block = 0x00CB,
  block_type_top = 0x00CC, -- 2 bytes
  block_type_bottom = 0x00CE, -- 2 bytes
  block_type_left = 0x00D0, -- 2 bytes
  block_type_right = 0x00D2, -- 2 bytes
  hearts_remaining = 0x00D6,
  platform_x_pos = 0x00D7, -- 16 bytes, 2 bytes/platform
  platform_y_pos = 0x00E7, -- 16 bytes, 2 bytes/platform
  platform_type = 0x00F7, -- 8 bytes, 1 byte/platform
  platform_direction = 0x00FF, -- 8 bytes, 1 byte/platform
  on_level = 0x011A,
  frame_counter = 0x0166, -- 2 bytes
  
}

local GB_FRAMERATE = 59.727500569606


--- ###########################################################################################################################
--- SCRIPT UTILS

-- Basic functions renaming
local fmt = string.format
local floor = math.floor
local ceil = math.ceil
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local pi = math.pi

function math.round(num, decimal_places)
  local mult = 10^(decimal_places or 0)
  if num >= 0 then return math.floor(num * mult + 0.5) / mult
  else return math.ceil(num * mult - 0.5) / mult end
end

-- Compatibility of the memory read/write functions
local u8 =  mainmemory.read_u8
local s8 =  mainmemory.read_s8
local w8 =  mainmemory.write_u8
local u16 = mainmemory.read_u16_le
local s16 = mainmemory.read_s16_le
local w16 = mainmemory.write_u16_le
local u24 = mainmemory.read_u24_le
local s24 = mainmemory.read_s24_le
local w24 = mainmemory.write_u24_le
local u32 = mainmemory.read_u32_le
local s32 = mainmemory.read_s32_le
local w32 = mainmemory.write_u32_le
memory.usememorydomain("VRAM")
local u8_vram =  memory.read_u8
local s8_vram =  memory.read_s8
local w8_vram =  memory.write_u8
local u16_vram = memory.read_u16_le
local s16_vram = memory.read_s16_le
local w16_vram = memory.write_u16_le
local u24_vram = memory.read_u24_le
local s24_vram = memory.read_s24_le
local w24_vram = memory.write_u24_le

-- Variables generally used
local Previous = {}

-- Drawing constants and operations
local draw = {}
draw.BIZHAWK_FONT_WIDTH = 10
draw.BIZHAWK_FONT_HEIGHT = 14

-- Draw an arrow given (x1, y1) and (x2, y2)
function draw.arrow(x1, y1, x2, y2, head, colour)
	
	local angle = math.atan((y2-y1)/(x2-x1)) -- in radians
	
	-- Arrow head
	local head_size = head or 10
	local angle1, angle2 = angle + pi/4, angle - pi/4 --0.785398163398, angle - 0.785398163398 -- 45° in radians
	--local delta_x1, delta_y1 = floor(head_size*cos(angle1)), floor(head_size*sin(angle1))
	local delta_x1, delta_y1 = head_size*cos(angle1), head_size*sin(angle1)
	--local delta_x2, delta_y2 = floor(head_size*cos(angle2)), floor(head_size*sin(angle2))
	local delta_x2, delta_y2 = head_size*cos(angle2), head_size*sin(angle2)
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
  if colour == nil then colour = "white" end
	draw.line(x1, y1, x2, y2, colour)
	draw.line(head1_x1, head1_y1, head1_x2, head1_y2, colour)
	draw.line(head2_x1, head2_y1, head2_x2, head2_y2, colour)
end

-- General emulation info
local Movie_active, Readonly, Framecount, Lagcount, Rerecords, Is_lagged, Lastframe_emulated, Nextframe
local function bizhawk_status()
  Movie_active = movie.isloaded()
  Readonly = movie.getreadonly()
  Framecount = movie.length()
  Lagcount = emu.lagcount()
  Rerecords = movie.getrerecordcount()
  Is_lagged = emu.islagged()
  Lastframe_emulated = emu.framecount()
  Nextframe = Lastframe_emulated + 1
end

-- Get screen values of the game and emulator areas
local function bizhawk_screen_info()
  -- Gaps
  draw.Left_gap = OPTIONS.left_gap
  draw.Top_gap = OPTIONS.top_gap
  draw.Right_gap = OPTIONS.right_gap
  draw.Bottom_gap = OPTIONS.bottom_gap

  -- Scale
  if client.borderwidth() == 0 then -- to avoid division by zero bug when borders are not yet ready when loading the script
    draw.Scale_x = 2
    draw.Scale_y = 2
  else
    draw.Scale_x = math.min(client.borderwidth()/OPTIONS.left_gap, client.borderheight()/OPTIONS.top_gap) -- Pixel scale
    draw.Scale_y = draw.Scale_x -- assumming square pixels only
  end
  
  -- Main dimensions
  draw.Screen_width = client.screenwidth()/draw.Scale_x  -- Emu screen width CONVERTED to game pixels
  draw.Screen_height = client.screenheight()/draw.Scale_y  -- Emu screen height CONVERTED to game pixels
  draw.Buffer_width = client.bufferwidth()  -- Game area width, in game pixels
  draw.Buffer_height = client.bufferheight()  -- Game area height, in game pixels
  
  -- Derived dimensions
  draw.Buffer_width = client.bufferwidth()  -- Game area width, in game pixels
  draw.Buffer_height = client.bufferheight()  -- Game area height, in game pixels
  draw.Buffer_middle_x = OPTIONS.left_gap + draw.Buffer_width/2  -- Game area middle x relative to emu window, in game pixels
  draw.Buffer_middle_y = OPTIONS.top_gap + draw.Buffer_height/2  -- Game area middle y relative to emu window, in game pixels
  draw.Border_right_start = OPTIONS.left_gap + draw.Buffer_width
  draw.Border_bottom_start = OPTIONS.top_gap + draw.Buffer_height
  draw.BizHawk_font_width = 10/draw.Scale_x -- to make compatible to the scale
  draw.BizHawk_font_height = 18/draw.Scale_y
  
  --[[ DEBUG
  local y_tmp = 20
  draw.text(0, y_tmp, fmt("draw.Scale_x = %d",   draw.Scale_x)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.Scale_y = %d",   draw.Scale_y)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.Screen_width = %d",   draw.Screen_width)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.Screen_height = %d",   draw.Screen_height)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.Buffer_width = %d",   draw.Buffer_width)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.Buffer_height = %d",   draw.Buffer_height)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.Buffer_middle_x = %d",   draw.Buffer_middle_x)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.Buffer_middle_y = %d",   draw.Buffer_middle_y)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.Border_right_start = %d",   draw.Border_right_start)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.Border_bottom_start = %d",   draw.Border_bottom_start)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.BizHawk_font_width = %d",   draw.BizHawk_font_width)) ; y_tmp = y_tmp + draw.BizHawk_font_height
  draw.text(0, y_tmp, fmt("draw.BizHawk_font_height = %d",   draw.BizHawk_font_height)) ; y_tmp = y_tmp + draw.BizHawk_font_height]]

end

-- Scaling text drawing function
local function draw_text(x_pos, y_pos, text, text_color, bg_color)
  gui.text(draw.Scale_x*x_pos, draw.Scale_y*y_pos, text, text_color, bg_color)
end

-- Drawing functions renaming
draw.text = draw_text
draw.line = gui.drawLine
draw.cross = gui.drawAxis
draw.pixel = gui.drawPixel
draw.rectangle = gui.drawRectangle
draw.box = gui.drawBox
draw.ellipse = gui.drawEllipse
draw.image = gui.drawImage
draw.image_region = gui.drawImageRegion
draw.polygon = gui.drawPolygon
draw.pixel_text = gui.pixelText

-- Transform unsigned byte to signed in hex string
local function signed8hex(num, signal)
  local maxval = 128
  if signal == nil then signal = true end
  
  if num < maxval then -- positive
    return fmt("%s%02X", signal and "+" or "", num)
  else -- negative
    return fmt("%s%02X", signal and "-" or "", 2*maxval - num)
  end  
end

-- Transform unsigned word to signed in hex string
local function signed16hex(num, signal)
  local maxval = 32768
  if signal == nil then signal = true end
  
  if num < maxval then -- positive
    return fmt("%s%04X", signal and "+" or "", num)
  else -- negative
    return fmt("%s%04X", signal and "-" or "", 2*maxval - num)
  end  
end

-- Verify if a point is inside a rectangle
local function inside_rectangle(xpoint, ypoint, x1, y1, x2, y2)
  -- From top-left to bottom-right
  if x2 < x1 then
    x1, x2 = x2, x1
  end
  if y2 < y1 then
    y1, y2 = y2, y1
  end

  -- Verification
  if xpoint >= x1 and xpoint <= x2 and ypoint >= y1 and ypoint <= y2 then
    return true
  else
    return false
  end
end

-- Returns frames-time conversion
local function frame_time(frame)
  local total_seconds = frame/GB_FRAMERATE
  local hours = floor(total_seconds/3600)
  local tmp = total_seconds - 3600*hours
  local minutes = floor(tmp/60)
  tmp = tmp - 60*minutes
  local seconds = floor(tmp)

  local miliseconds = 1000* (total_seconds%1)
  if hours == 0 then hours = "" else hours = string.format("%d:", hours) end
  local str = string.format("%s%02d:%02d.%03.0f", hours, minutes, seconds, miliseconds)
  return str
end


--- ###########################################################################################################################
--- INFO FUNCTIONS

local function general_info()
  
  local x_pos = 2
  local y_pos = draw.BizHawk_font_height
  
  local frame_counter = u16(WRAM.frame_counter)
  local frame_counter_str = fmt("Frame: %04X", frame_counter)
  draw.text(x_pos, y_pos, frame_counter_str)
  x_pos = x_pos + (string.len(frame_counter_str)+2)*draw.BizHawk_font_width
  
  local level_mode = u8(WRAM.level_mode)
  local level_mode_str = fmt("Mode: %02X", level_mode)
  draw.text(x_pos, y_pos, level_mode_str)
  x_pos = x_pos + (string.len(level_mode_str)+2)*draw.BizHawk_font_width
  
  local hearts_remaining = u8(WRAM.hearts_remaining)
  local hearts_remaining_str = fmt("Hearts: %d", hearts_remaining)
  draw.text(x_pos, y_pos, hearts_remaining_str)
  x_pos = x_pos + (string.len(hearts_remaining_str)+2)*draw.BizHawk_font_width
  
end

local function level_info()
  
  local current_level = u8(WRAM.current_level)
  local current_level_str = fmt("Level: %02d", current_level)
  draw.text(draw.Buffer_middle_x - string.len(current_level_str)*draw.BizHawk_font_width/2, OPTIONS.top_gap - draw.BizHawk_font_height, current_level_str)
  
end

local function blocks_info()
  
  local colour
  
  -- Grid
  if OPTIONS.display_grid then
    for j = 0x00, 0x12-1 do -- 160 x 144
      for i = 0x00, 0x14-1 do
        
        if (i+j%2)%2 == 1 then colour = COLOUR.GB_pal_tri_2_3 - 0x80000000 else colour = COLOUR.GB_pal_tri_2_3 - 0xC0000000 end
        draw.rectangle(i*8 + draw.Left_gap, j*8 + draw.Top_gap, 7, 7, colour)--0x80FFFFFF)
      
      end
    end
  end
  
  -- Out-of-bounds blocks
  if OPTIONS.display_out_of_bounds_blocks then
  
    local tilemap_file = "The Bouncing Ball Tilemap.png"
    local level_vram_addr = 0x1800
    local block_id
    local x_level, y_level = draw.Left_gap, draw.Top_gap
    local x, y = x_level, y_level
    local tilemap_x, tilemap_y
    
    gui.clearImageCache()
    
    for i = 0, 0x2000 - 1 do -- GPU is 0x2000 bytes, half backgroung half window
      
      block_id = u8_vram(level_vram_addr + i)
      tilemap_x = bit.band(block_id, 0xF)*8
      tilemap_y = floor(block_id/0x10)*8
      
      if block_id ~= 0x00 then -- to minimize lag, don't need to draw void
        if not inside_rectangle(x, y, x_level, y_level, x_level + draw.Buffer_width - 1, y_level + draw.Buffer_height - 1) then
          draw.image_region(tilemap_file, tilemap_x, tilemap_y, 8, 8, x, y)
          if i%0x20 == 0x1f and i <= 0x023F then
            draw.image_region(tilemap_file, tilemap_x, tilemap_y, 8, 8, x - 0x100, y - 7*8)
          end
        end
        --draw.pixel_text(x, y, fmt("%02X", block_id), COLOUR.weak, 0) -- don't need actually
      end
      
      x = x + 8
      if i%0x20 == 0x1f then x = x_level ; y = y + 8 end
      
    end
  
  end
  
  -- Some out-of-bounds guide lines
  draw.rectangle(OPTIONS.left_gap, draw.Border_bottom_start, 159, 7, "red")
  draw.rectangle(OPTIONS.left_gap, draw.Border_bottom_start + 13*8, 159, 7, "olive")
  draw.rectangle(OPTIONS.left_gap + 6*8, draw.Border_bottom_start + 13*8, 7, 7, "green")
  draw.rectangle(OPTIONS.left_gap + 6*8, draw.Border_bottom_start + 22*8, 7, 7, "blue")
  draw.rectangle(OPTIONS.left_gap + 6*8, draw.Border_bottom_start + 22*8 -256, 7, 7, 0x800000FF)
  
end

local function platforms_info()
  if not OPTIONS.display_platform_info then return end
  
  local table_x, table_y = 2, draw.Buffer_middle_y + 16
  local platform_x_pos, platform_y_pos, platform_type, platform_type
  local colour
  
  for slot = 0, 8 - 1 do
    
    -- RAM reading
    platform_x_pos = u16(WRAM.platform_x_pos + 2*slot) -- 16 bytes, 2 bytes/platform
    platform_y_pos = u16(WRAM.platform_y_pos + 2*slot) -- 16 bytes, 2 bytes/platform
    platform_type = u8(WRAM.platform_type + slot) -- 8 bytes, 1 byte/platform
    platform_direction = u8(WRAM.platform_direction + slot) -- 8 bytes, 1 byte/platform
    
    -- Position interpretation
    local x_pos_int = floor(platform_x_pos/0x10)
    local y_pos_int = floor(platform_y_pos/0x10)
    local x_pos_frac = platform_x_pos - x_pos_int*0x10
    local y_pos_frac = platform_y_pos - y_pos_int*0x10
    
    -- Drawings
    colour = platform_direction ~= 0 and "white" or COLOUR.weak
    draw.text(table_x, table_y + slot*draw.BizHawk_font_height, fmt("#%02d %02X (%02X.%x, %02X.%x) %s",
    slot, platform_type, x_pos_int, x_pos_frac, y_pos_int, y_pos_frac, platform_direction == 1 and "<-" or "->"), colour)
    
  end
  
  --[[
  platform_x_pos = 0x00D7, -- 16 bytes, 2 bytes/platform
  platform_y_pos = 0x00E7, -- 16 bytes, 2 bytes/platform
  platform_type = 0x00F7, -- 8 bytes, 1 byte/platform
  platform_direction = 0x00FF, -- 8 bytes, 1 byte/platform
  ]]

end

-- Player info
Previous.x_pos_int, Previous.y_pos_int = -100, -100
local function player_info()
  
  -- Settings
  local i = 0
  local delta_x = draw.BizHawk_font_width
  local delta_y = draw.BizHawk_font_height
  local table_x = 2
  local table_y = draw.Top_gap
  local y_temp, x_temp = 0,table_x
  local colour
  
  -- RAM reading
  local x_pos = s16(WRAM.x_pos)
  local y_pos = s16(WRAM.y_pos)
  local x_speed = s16(WRAM.x_speed)
  local x_speed_u = u8(WRAM.x_speed)
  local y_speed = s16(WRAM.y_speed)
  local y_speed_u = u8(WRAM.y_speed)
  local x_pos_block = u8(WRAM.x_pos_block)
  local y_pos_block = u8(WRAM.y_pos_block)
  local vertical_direction = u8(WRAM.vertical_direction)
  local block_type_top = u16(WRAM.block_type_top)
  local block_type_bottom = u16(WRAM.block_type_bottom)
  local block_type_left = u16(WRAM.block_type_left)
  local block_type_right = u16(WRAM.block_type_right)
  local last_block_updated = u8(WRAM.last_block_updated)
  
  --- Display info  
  local x_pos_int = floor(x_pos/0x10)
  local y_pos_int = floor(y_pos/0x10)
  local x_pos_frac = x_pos - x_pos_int*0x10
  local y_pos_frac = y_pos - y_pos_int*0x10
  
  -- Position data
  draw.text(table_x, table_y + i*delta_y, fmt("Pos (%03X.%x, %03X.%x)\n    (%02X, %02X)", bit.band(x_pos_int, 0xFFFF), x_pos_frac, bit.band(y_pos_int, 0xFFFF), y_pos_frac, x_pos_block, y_pos_block))
  
  -- Position pixel (nominal and collision)
  draw.cross(x_pos_int + draw.Left_gap, y_pos_int + draw.Top_gap, 2, COLOUR.GB_pal_tri_2_2)
  draw.cross(x_pos_int + 2 + draw.Left_gap, y_pos_int + 2 + draw.Top_gap, 2, COLOUR.GB_pal_tri_1_2)
  
  -- Position mod 256 pixel (nominal and collision)
  --[[
  draw.cross(bit.band(x_pos_int, 0xFF) + draw.Left_gap, bit.band(y_pos_int, 0xFF) + draw.Top_gap, 2, COLOUR.GB_pal_tri_2_2 - 0x80000000)
  draw.cross(bit.band(x_pos_int, 0xFF) + 2 + draw.Left_gap, bit.band(y_pos_int, 0xFF) + 2 + draw.Top_gap, 2, COLOUR.GB_pal_tri_1_2 - 0x80000000)
  draw.cross(bit.band(x_pos_int, 0xFF) + 2 + draw.Left_gap - 0x100, bit.band(y_pos_int, 0xFF) + 2 + draw.Top_gap, 2, COLOUR.GB_pal_tri_1_2 - 0x80000000)]]
  i = i + 2
  
  -- Speed
  if math.abs(x_speed) >= 0x10 then colour = COLOUR.positive -- lateral springblock speed
  elseif math.abs(x_speed) >= 0x08 then colour = "yellow" -- max running speed
  else colour = "white" end
  draw.text(table_x, table_y + i*delta_y, fmt("Speed (   , %s) %s", signed8hex(y_speed_u, true), vertical_direction == 0 and "v" or "^"))
  draw.text(table_x, table_y + i*delta_y, fmt("       %s", signed8hex(x_speed_u, true)), colour)
  i = i + 1
  
  -- Blocked status
  local ball_file = "The Bouncing Ball Ball.png"
  local tilemap_file = "The Bouncing Ball Tilemap.png" 
  local tilemap_x, tilemap_y
  -- ball
  draw.image(ball_file, table_x + 12, (table_y + i*delta_y*draw.Scale_y) + 4 + 11)
  -- top
  tilemap_x, tilemap_y = bit.band(block_type_top, 0xF)*8, floor(block_type_top/0x10)*8
  draw.image_region(tilemap_file, tilemap_x, tilemap_y, 8, 8, table_x + 10, (table_y + i*delta_y*draw.Scale_y) + 4)
  draw.rectangle(table_x + 9, (table_y + i*delta_y*draw.Scale_y) + 3, 9, 9)
  -- bottom
  tilemap_x, tilemap_y = bit.band(block_type_bottom, 0xF)*8, floor(block_type_bottom/0x10)*8
  draw.image_region(tilemap_file, tilemap_x, tilemap_y, 8, 8, table_x + 10, (table_y + i*delta_y*draw.Scale_y) + 3 + 17 + 2)
  draw.rectangle(table_x + 9, (table_y + i*delta_y*draw.Scale_y) + 4 + 17, 9, 9)
  -- left
  tilemap_x, tilemap_y = bit.band(block_type_left, 0xF)*8, floor(block_type_left/0x10)*8
  draw.image_region(tilemap_file, tilemap_x, tilemap_y, 8, 8, table_x + 1, (table_y + i*delta_y*draw.Scale_y) + 3 + 8 + 2)
  draw.rectangle(table_x + 0, (table_y + i*delta_y*draw.Scale_y) + 4 + 8, 9, 9)
  -- right
  tilemap_x, tilemap_y = bit.band(block_type_right, 0xF)*8, floor(block_type_right/0x10)*8
  draw.image_region(tilemap_file, tilemap_x, tilemap_y, 8, 8, table_x + 19, (table_y + i*delta_y*draw.Scale_y) + 3 + 8 + 2)
  draw.rectangle(table_x + 18, (table_y + i*delta_y*draw.Scale_y) + 4 + 8, 9, 9)
  
  -- OOB ball display
  --if not (Previous.x_pos_int < 0x9D) and not (Previous.y_pos_int < 0x8D) then
  local in_bounds = false
  if Previous.x_pos_int >= 0 and Previous.x_pos_int < 0x9D and Previous.y_pos_int >= 0 and Previous.y_pos_int < 0x8D then in_bounds = true end
  --if Previous.x_pos_int >= 0x9D or Previous.y_pos_int >= 0x8D then
  if not in_bounds then
    draw.image(ball_file, Previous.x_pos_int + draw.Left_gap, Previous.y_pos_int + draw.Top_gap)
  end
  
  
  Previous.x_pos_int = x_pos_int
  Previous.y_pos_int = y_pos_int
end

-- Movie info
local function movie_info()
  if not OPTIONS.display_movie_info then return end
  
  -- Font
  local width = draw.BizHawk_font_width
  local x_text, y_text = 8*width, 0

  local rec_color = (Readonly or not Movie_active) and "white" or "red"

  -- Read-only or read-write?
  local movie_type = (not Movie_active and "No movie ") or (Readonly and "Movie " or "REC")
  draw.text(x_text, y_text, movie_type, rec_color)
  x_text = x_text + width*(string.len(movie_type) + 1)

  -- Frame count
  local movie_info
  if Readonly and Movie_active then
    movie_info = fmt("%d/%d", Lastframe_emulated, Framecount)
  else
    movie_info = fmt("%d", Lastframe_emulated)
  end
  draw.text(x_text, y_text, movie_info)  -- Shows the latest frame emulated, not the frame being run now
  x_text = x_text + width*string.len(movie_info)

  if Movie_active then
    -- Rerecord count
    local rr_info = fmt(" %d ", Rerecords)
    draw.text(x_text, y_text, rr_info, COLOUR.weak)
    x_text = x_text + width*string.len(rr_info)

    -- Lag count
    draw.text(x_text, y_text, Lagcount, COLOUR.warning)
    x_text = x_text + width*string.len(Lagcount)
  end

  -- Time
  local time_str = frame_time(Lastframe_emulated)   -- Shows the latest frame emulated, not the frame being run now
  draw.text(x_text, y_text, fmt(" (%s)", time_str))
  
  -- Lag warning
  x_text, y_text = 0, y_text + draw.BizHawk_font_height
  if Is_lagged then
    --draw.text(x_text, y_text, "LAG", COLOUR.warning)
    gui.drawText(draw.Border_right_start - 24, 10, "LAG", COLOUR.warning, 0xA00040FF)
  end
  
end

-- Movie input display
local function movie_input()
  if not OPTIONS.display_movie_input then return end
  if not Movie_active then return end
  
  local table_x = draw.Border_right_start + 8
  local delta_y = draw.BizHawk_font_height
  
  -- Header
  draw.text(table_x, 0, "|Frame|UDLRSsBA|")
  
  -- Input piano roll
  local input
  for frame = -23, 23 do
    if Lastframe_emulated + frame > 0 then
      input = string.sub(movie.getinputasmnemonic(Lastframe_emulated + frame), 1, -3) .. "|"
      draw.text(table_x, 8 + (frame+23)*draw.BizHawk_font_height, fmt("|%.5d%s", Lastframe_emulated + frame, input), frame == 0 and "white" or 0x80FFFFFF) -- frame == 0 is the current input
    end
  end
end

local function draw_info()
  
  general_info()
  level_info()
  blocks_info()
  platforms_info()
  player_info()
  movie_info()
  movie_input()
  
  -- DEBUG
  --[[
  draw.rectangle(30, 0*8+1, 8, 8, COLOUR.GB_pal_1, COLOUR.GB_pal_1) ; draw.pixel_text(40, 0*8+1 , "GB_pal_1")
  draw.rectangle(30, 1*8+1, 8, 8, COLOUR.GB_pal_2, COLOUR.GB_pal_2) ; draw.pixel_text(40, 1*8+1 , "GB_pal_2")
  draw.rectangle(30, 2*8+1, 8, 8, COLOUR.GB_pal_3, COLOUR.GB_pal_3) ; draw.pixel_text(40, 2*8+1 , "GB_pal_3")
  draw.rectangle(30, 3*8+1, 8, 8, COLOUR.GB_pal_4, COLOUR.GB_pal_4) ; draw.pixel_text(40, 3*8+1 , "GB_pal_4")
  draw.rectangle(30, 4*8+1, 8, 8, COLOUR.GB_pal_inv_1, COLOUR.GB_pal_inv_1) ; draw.pixel_text(40, 4*8+1 , "GB_pal_inv_1")
  draw.rectangle(30, 5*8+1, 8, 8, COLOUR.GB_pal_inv_2, COLOUR.GB_pal_inv_2) ; draw.pixel_text(40, 5*8+1 , "GB_pal_inv_2")
  draw.rectangle(30, 6*8+1, 8, 8, COLOUR.GB_pal_inv_3, COLOUR.GB_pal_inv_3) ; draw.pixel_text(40, 6*8+1 , "GB_pal_inv_3")
  draw.rectangle(30, 7*8+1, 8, 8, COLOUR.GB_pal_inv_4, COLOUR.GB_pal_inv_4) ; draw.pixel_text(40, 7*8+1 , "GB_pal_inv_4")
  draw.rectangle(30, 8*8+1, 8, 8, COLOUR.GB_pal_tri_1_1, COLOUR.GB_pal_tri_1_1) ; draw.pixel_text(40, 8*8+1 , "GB_pal_tri_1_1")
  draw.rectangle(30, 9*8+1, 8, 8, COLOUR.GB_pal_tri_1_2, COLOUR.GB_pal_tri_1_2) ; draw.pixel_text(40, 9*8+1 , "GB_pal_tri_1_2")
  draw.rectangle(30, 10*8+1, 8, 8, COLOUR.GB_pal_tri_1_3, COLOUR.GB_pal_tri_1_3) ; draw.pixel_text(40, 10*8+1 , "GB_pal_tri_1_3")
  draw.rectangle(30, 11*8+1, 8, 8, COLOUR.GB_pal_tri_2_1, COLOUR.GB_pal_tri_2_1) ; draw.pixel_text(40, 11*8+1 , "GB_pal_tri_2_1")
  draw.rectangle(30, 12*8+1, 8, 8, COLOUR.GB_pal_tri_2_2, COLOUR.GB_pal_tri_2_2) ; draw.pixel_text(40, 12*8+1 , "GB_pal_tri_2_2")
  draw.rectangle(30, 13*8+1, 8, 8, COLOUR.GB_pal_tri_2_3, COLOUR.GB_pal_tri_2_3) ; draw.pixel_text(40, 13*8+1 , "GB_pal_tri_2_3")
  draw.rectangle(30, 14*8+1, 8, 8, COLOUR.GB_pal_tri_3_1, COLOUR.GB_pal_tri_3_1) ; draw.pixel_text(40, 14*8+1 , "GB_pal_tri_3_1")
  draw.rectangle(30, 15*8+1, 8, 8, COLOUR.GB_pal_tri_3_2, COLOUR.GB_pal_tri_3_2) ; draw.pixel_text(40, 15*8+1 , "GB_pal_tri_3_2")
  draw.rectangle(30, 16*8+1, 8, 8, COLOUR.GB_pal_tri_3_3, COLOUR.GB_pal_tri_3_3) ; draw.pixel_text(40, 16*8+1 , "GB_pal_tri_3_3")
  draw.rectangle(30, 17*8+1, 8, 8, COLOUR.GB_pal_tri_4_1, COLOUR.GB_pal_tri_4_1) ; draw.pixel_text(40, 17*8+1 , "GB_pal_tri_4_1")
  draw.rectangle(30, 18*8+1, 8, 8, COLOUR.GB_pal_tri_4_2, COLOUR.GB_pal_tri_4_2) ; draw.pixel_text(40, 18*8+1 , "GB_pal_tri_4_2")
  draw.rectangle(30, 19*8+1, 8, 8, COLOUR.GB_pal_tri_4_3, COLOUR.GB_pal_tri_4_3) ; draw.pixel_text(40, 19*8+1 , "GB_pal_tri_4_3")
  draw.rectangle(30, 20*8+1, 8, 8, COLOUR.positive, COLOUR.positive) ; draw.pixel_text(40, 20*8+1 , "positive")
  draw.rectangle(30, 21*8+1, 8, 8, COLOUR.warning, COLOUR.warning) ; draw.pixel_text(40, 21*8+1 , "warning")
  draw.rectangle(30, 22*8+1, 8, 8, COLOUR.weak, COLOUR.weak) ; draw.pixel_text(40, 22*8+1 , "weak")
  ]]


end


--###########################################################################################
-- OPTIONS MENU

-- Declare the group of functions and variables used in the options menu
local Options_form = {}

-- Options menu forms
function Options_form.create_window()

  -- Create form
  local form_width, form_height = 320, 160
  Options_form.form = forms.newform(form_width, form_height, "OPTIONS")
  -- Set form location based on the emu window
  local emu_window_x, emu_window_y = client.xpos(), client.ypos()
  forms.setlocation(Options_form.form, emu_window_x, emu_window_y + client.screenheight() + 77)
  
  local xform, yform, delta_x, delta_y = 4, 4, 120, 20
  
  --- Display options ---
  
  Options_form.display_platform_info = forms.checkbox(Options_form.form, "Platforms info", xform, yform)
  forms.setproperty(Options_form.display_platform_info, "Checked", OPTIONS.display_platform_info)
  yform = yform + 1.4*delta_y
  
  Options_form.display_out_of_bounds_blocks = forms.checkbox(Options_form.form, "Out of bounds blocks", xform, yform)
  forms.setproperty(Options_form.display_out_of_bounds_blocks, "Checked", OPTIONS.display_out_of_bounds_blocks)
  forms.setproperty(Options_form.display_out_of_bounds_blocks, "AutoSize", true)
  yform = yform + delta_y
  
  Options_form.display_grid = forms.checkbox(Options_form.form, "Tile grid", xform, yform)
  forms.setproperty(Options_form.display_grid, "Checked", OPTIONS.display_grid)
  yform = yform + delta_y
  
  Options_form.display_movie_info = forms.checkbox(Options_form.form, "Movie info", xform, yform)
  forms.setproperty(Options_form.display_movie_info, "Checked", OPTIONS.display_movie_info)
  yform = yform + delta_y
  
  Options_form.display_movie_input = forms.checkbox(Options_form.form, "Movie inputs", xform, yform)
  forms.setproperty(Options_form.display_movie_input, "Checked", OPTIONS.display_movie_input)
  yform = yform + delta_y
  
  --- Emu gaps (lateral gaps) ---
  
  xform, yform = xform + 200, 4
  -- top gap
  forms.button(Options_form.form, "-", function()
    if OPTIONS.top_gap - 10 >= draw.BizHawk_font_height then OPTIONS.top_gap = OPTIONS.top_gap - 10 end
    client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
  end, xform, yform, 24, 24)
  xform = xform + 24
  forms.button(Options_form.form, "+", function()
    OPTIONS.top_gap = OPTIONS.top_gap + 10
    client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
  end, xform, yform, 24, 24)
  -- left gap
  xform, yform = xform - 3*24, yform + 24
  forms.button(Options_form.form, "-", function()
    if OPTIONS.left_gap - 10 >= draw.BizHawk_font_height then OPTIONS.left_gap = OPTIONS.left_gap - 10 end
    client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
  end, xform, yform, 24, 24)
  xform = xform + 24
  forms.button(Options_form.form, "+", function()
    OPTIONS.left_gap = OPTIONS.left_gap + 10
    client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
  end, xform, yform, 24, 24)
  -- right gap
  xform = xform + 3*24
  forms.button(Options_form.form, "-", function()
    if OPTIONS.right_gap - 10 >= draw.BizHawk_font_height then OPTIONS.right_gap = OPTIONS.right_gap - 10 end
    client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
  end, xform, yform, 24, 24)
  xform = xform + 24
  forms.button(Options_form.form, "+", function()
    OPTIONS.right_gap = OPTIONS.right_gap + 10
    client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
  end, xform, yform, 24, 24)
  -- bottom gap
  xform, yform = xform - 3*24, yform + 24
  forms.button(Options_form.form, "-", function()
    if OPTIONS.bottom_gap - 10 >= draw.BizHawk_font_height then OPTIONS.bottom_gap = OPTIONS.bottom_gap - 10 end
    client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
  end, xform, yform, 24, 24)
  xform = xform + 24
  forms.button(Options_form.form, "+", function()
    OPTIONS.bottom_gap = OPTIONS.bottom_gap + 10
    client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
  end, xform, yform, 24, 24)
  xform, yform = xform - 26, yform - 20
  forms.label(Options_form.form, "Emu gaps", xform, yform, 70, 20)

end

-- Update the options based on the state of the controls in the options menu
function Options_form.evaluate_form()

  OPTIONS.display_platform_info = forms.ischecked(Options_form.display_platform_info) or false
  OPTIONS.display_out_of_bounds_blocks = forms.ischecked(Options_form.display_out_of_bounds_blocks) or false
  OPTIONS.display_grid = forms.ischecked(Options_form.display_grid) or false
  OPTIONS.display_movie_info = forms.ischecked(Options_form.display_movie_info) or false
  OPTIONS.display_movie_input = forms.ischecked(Options_form.display_movie_input) or false

end

--- ###########################################################################################################################
--- MAIN

-- Create emu extra gaps
client.SetGameExtraPadding(OPTIONS.left_gap, OPTIONS.top_gap, OPTIONS.right_gap, OPTIONS.bottom_gap)
client.SetClientExtraPadding(0, 0, 0, 0)

-- Create the option menu forms
forms.destroyall() -- to prevent more than one forms (usually happens when script has an error)
Options_form.create_window()
Options_form.is_form_closed = false

-- Actions to do when script is closed
event.onexit(function()
  
  forms.destroy(Options_form.form)
  
  gui.clearImageCache()
  
	client.SetGameExtraPadding(0, 0, 0, 0)
  
  print("Finishing The Boucing Ball script.")
end)

print(fmt("\nThe Bouncing Ball script loaded successfully (%s)\n", os.date("%H:%M:%S %d/%m/%Y")))


-- Script main loop
while true do
 
  Options_form.is_form_closed = forms.gettext(Options_form.form) == ""
  if not Options_form.is_form_closed then Options_form.evaluate_form() end 
  
  bizhawk_status()
  
  bizhawk_screen_info()
  
  draw_info()
  
  emu.frameadvance()

end




























