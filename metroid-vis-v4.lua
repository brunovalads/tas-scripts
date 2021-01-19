
-- Metroid off-screen visualization script v4.0
-- Works with FCEUX and BizHawk
-- MetalMachine 2021 & BrunoValads

local readbyte
local drawbox
local drawline
local colors = {}

if (FCEU ~= nil) then

	readbyte = memory.readbyte
	drawline = gui.drawline
	drawbox = function (x0, y0, x1, y1, color)
		gui.drawbox(x0, y0, x1, y1, color, "clear")
	end

	colors.fader = "#00000060"
	colors.edges = "#F0F0F080"
	colors.samus = "#FFFFFFFF"
	colors.enemy = "#F8F80890"
	colors.solid_pri = "#f8f8f890"
	colors.break_pri = "#f8484890"
	colors.solid_sec = "#f8f8f860"
	colors.break_sec = "#f8484860"

end

if (bizstring ~= nil) then

	readbyte = memory.readbyte
	drawline = function (x0, y0, x1, y1, color)
    gui.drawLine(x0, y0, x1, y1, color)
  end
	drawbox = function (x0, y0, x1, y1, color)
		gui.drawBox(x0, y0, x1, y1, 0x00000000, color)
	end

	colors.fader = 0x60000000
	colors.edges = 0x80F0F0F0
	colors.samus = 0xFFFFFFFF
	colors.enemy = 0x90F8F808
	colors.solid_pri = 0x90f8f8f8
	colors.break_pri = 0x90f84848
	colors.solid_sec = 0x60f8f8f8
	colors.break_sec = 0x60f84848

end

local function DrawEntityBox(sx, sy, ent_sx, ent_sy, ent_rx, ent_ry, color)
	drawbox(
		math.floor(sx+ent_sx/2-ent_rx/2-1), 
		math.floor(sy+ent_sy/2-ent_ry/2-1), 
		math.floor(sx+ent_sx/2+ent_rx/2), 
		math.floor(sy+ent_sy/2+ent_ry/2), 
		color)
end

local tile_counter = 0

local nametable_tiles = memory.readbyterange(0x6000, 0x7C0)
if (FCEU ~= nil) then
	nametable_tiles = {string.byte(nametable_tiles, 1, 0x7C0)} -- FCEUX readbyterange returns a byte string, this is a convertion to table
end

local function DrawNametable(nt, sx, sy, color_solid, color_break)

	local addr = 0x6000

	if (nt == 1) then addr = 0x6400 end
  
	for y=0,29 do
		for x=0,31 do
			local tile --= nametable_tiles[addr-0x6000]
			if (FCEU ~= nil) then
				tile = nametable_tiles[addr-0x6000 + 1]
			elseif (bizstring ~= nil) then
				tile = nametable_tiles[addr-0x6000]
			end
			
			-- 00 - 6F  solid
			-- 70 - 97  breakable
			-- 98 - 9F  solid
			-- A0 - FF  air

			local px = sx+x*4
			local py = sy+y*4
			
			if px + 4 > 0 and px < 256 and py - 4 > 0 and py < 232 then -- optmization: only draw tiles that are inside the emu screen
				if (tile < 0x70) then
					-- solid
					drawbox(px-1, py-1, px+4, py+4, color_solid)
					tile_counter = tile_counter + 1
				elseif (tile < 0x98) then
					-- breakable
					drawbox(px-1, py-1, px+4, py+4, color_break)
					tile_counter = tile_counter + 1
				elseif (tile < 0xA0) then
					-- solid
					drawbox(px-1, py-1, px+4, py+4, color_solid)
					tile_counter = tile_counter + 1
				end
			end
			
			addr = addr + 1
		end
	end
	
	local sam_nt = readbyte(0x030C)

	if (sam_nt == nt) then

		local sam_ry = readbyte(0x0301)
		local sam_rx = readbyte(0x0302)
		local sam_sy = readbyte(0x030D)
		local sam_sx = readbyte(0x030E)

		DrawEntityBox(sx, sy, sam_sx, sam_sy, sam_rx, sam_ry, colors.samus)
	end

	for eni=0,5 do
	
		local en_off = eni * 0x10

		local en_st = readbyte(0x6AF4 + en_off)
		local en_nt = readbyte(0x6AFB + en_off)
		
		if (en_st ~= 0 and en_nt == nt) then

			local en_ry = readbyte(0x6AF5 + en_off)
			local en_rx = readbyte(0x6AF6 + en_off)
			local en_sy = readbyte(0x0400 + en_off)
			local en_sx = readbyte(0x0401 + en_off)
		
			DrawEntityBox(sx, sy, en_sx, en_sy, en_rx, en_ry, colors.enemy)
		end

	end

end

local function Process()
  
  tile_counter = 0
  
	local door_status = readbyte(0x0056)
	local scroll_status = readbyte(0x0057)
	local scroll_dir = readbyte(0x0049)
	local scroll_y = readbyte(0x00FC)
	local scroll_x = readbyte(0x00FD)

	drawbox(0, 0, 256, 240, colors.fader)

	local x0 = (256 - scroll_x) % 256
	local x1 = (255 - scroll_x)
	drawline(x0, 0, x0, 240, colors.edges)
	drawline(x1, 0, x1, 240, colors.edges)

	local y0 = (240 - scroll_y) % 256
	local y1 = (239 - scroll_y)

	drawline(0, y0, 256, y0, colors.edges)
	drawline(0, y1, 256, y1, colors.edges)

	local sam_sy = readbyte(0x030D)
	local sam_sx = readbyte(0x030E)
	local sam_nt = readbyte(0x030C)

	if (scroll_dir == 0 or scroll_dir == 1) then 
		-- scroll is vertical
		local y_center = 120 - math.floor(sam_sy/2)
		DrawNametable(sam_nt, 64, y_center, colors.solid_pri, colors.break_pri)
		DrawNametable(1-sam_nt, 64, y_center - 120, colors.solid_sec, colors.break_sec)
		DrawNametable(1-sam_nt, 64, y_center + 120, colors.solid_sec, colors.break_sec)
	else
		-- scroll is horizontal
		local x_center = 128 - math.floor(sam_sx/2)
		DrawNametable(sam_nt, x_center, 60, colors.solid_pri, colors.break_pri)
		DrawNametable(1-sam_nt, x_center - 128, 60, colors.solid_sec, colors.break_sec)
		DrawNametable(1-sam_nt, x_center + 128, 60, colors.solid_sec, colors.break_sec)
	end
  
	if (bizstring ~= nil) then
		gui.DrawFinish()
	end
	
end

local nametable_hash, nametable_hash_prev
local function Get_nametable_hash()
	if (FCEU ~= nil) then
		nametable_hash = table.concat({string.byte(memory.readbyterange(0x6000, 0x7C0), 1, 0x7C0)}) -- concatenating the whole table serves the purpose of a hash for comparison
	elseif (bizstring ~= nil) then
		nametable_hash = memory.hash_region(0x6000, 0x7C0) -- memory hash is BizHawk only
	end
end

Get_nametable_hash()                 --\ read in the first frame, to avoid empty tables
nametable_hash_prev = nametable_hash --/

while true do
	
  if (readbyte(0x1D) == 0) then
		
		-- Update nametable hashes
		nametable_hash_prev = nametable_hash
		Get_nametable_hash()
		
		-- Check if there was a change in the nametable address region, so it will update the tile table accordingly
		if nametable_hash ~= nametable_hash_prev then 
			nametable_tiles = memory.readbyterange(0x6000, 0x7C0)
			if (FCEU ~= nil) then
				nametable_tiles = {string.byte(nametable_tiles, 1, 0x7C0)} -- FCEUX readbyterange returns a byte string, this is a convertion to table
			end
		end
		
    Process()
  end

	emu.frameadvance()

end

