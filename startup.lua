--[[
	.startup.boot
		delay
			description:	delays amount before starting the default selection
			default:		1.5

		preload
			description :	runs before menu is displayed, can be used for password
							locking, drive encryption, etc.
			example :		{ [1] = '/path/somefile.lua', [2] = 'path2/another.lua' }

		menu
			description:	array of menu entries (see .startup.boot for examples)
]]

local colors    = _G.colors
local fs        = _G.fs
local keys      = _G.keys
local os        = _G.os
local settings  = _G.settings
local term      = _G.term
local textutils = _G.textutils

local function loadBootOptions()
	if not fs.exists('.startup.boot') then
		local f = fs.open('.startup.boot', 'w')
		f.write(textutils.serialize({
			delay = 1.5,
			preload = { },
			menu = {
				{ prompt = os.version() },
				{ prompt = 'HorizonOS'         , args = { '/sys/boot/opus.boot' } },
				{ prompt = 'HorizonOS Shell'   , args = { '/sys/boot/opus.boot', 'sys/apps/shell.lua' } },
				{ prompt = 'HorizonOS Kiosk'   , args = { '/sys/boot/kiosk.boot' } },
			},
		}))
		f.close()
	end

	local f = fs.open('.startup.boot', 'r')
	local options = textutils.unserialize(f.readAll())
	f.close()

	return options
end

local bootOptions = loadBootOptions()

local bootOption = 2
if settings then
	settings.load('.settings')
	bootOption = tonumber(settings.get('opus.boot_option')) or bootOption
end

local function startupMenu()
	local x, y = term.getSize()
	local align, selected = 0, bootOption

	local function redraw()
		local title = "Boot Options:"
		term.clear()
		term.setTextColor(colors.white)
		term.setCursorPos((x/2)-(#title/2), (y/2)-(#bootOptions.menu/2)-1)
		term.write(title)
		for i, item in pairs(bootOptions.menu) do
			local txt = i .. ". " .. item.prompt
			term.setCursorPos((x/2)-(align/2), (y/2)-(#bootOptions.menu/2)+i)
			term.write(txt)
		end
	end

	for _, item in pairs(bootOptions.menu) do
		if #item.prompt > align then
			align = #item.prompt
		end
	end

	redraw()
	while true do
		term.setCursorPos((x/2)-(align/2)-2, (y/2)-(#bootOptions.menu/2)+selected)
		term.setTextColor(term.isColor() and colors.yellow or colors.lightGray)

		term.write(">")
		local event, key = os.pullEvent()
		if event == "mouse_scroll" then
			key = key == 1 and keys.down or keys.up
		elseif event == 'key_up' then
			key = nil  -- only process key events
		end

		if key == keys.enter or key == keys.right then
			return selected
		elseif key == keys.down then
			if selected == #bootOptions.menu then
				selected = 0
			end
			selected = selected + 1
		elseif key == keys.up then
			if selected == 1 then
				selected = #bootOptions.menu + 1
			end
			selected = selected - 1
		elseif event == 'char' then
			key = tonumber(key) or 0
			if bootOptions.menu[key] then
				return key
			end
		end

		local cx, cy = term.getCursorPos()
		term.setCursorPos(cx-1, cy)
		term.write(" ")
	end
end

local function splash()
	local w, h = term.current().getSize()

	term.setTextColor(colors.white)
	if not term.isColor() then
		local str = 'HorizonOS'
		term.setCursorPos((w - #str) / 2, h / 2)
		term.write(str)
	else
		term.setBackgroundColor(colors.black)
		term.clear()
		local opus = {
			"000000000000000000000000110205110205000000000000000000000000",
			"0000000000002a040da1152ed11c3cd11c3ca0142e300a130c1010000000",
			"0000002f1109b93828cf3b2ec83a2cc83a2ccf3b2eb73828230e08000000",
			"0100008e3b1ad15826c85523c85524c85524c85523d15825843718010000",
			"0e0801b86214cf6f16ce6e16ce6e16ce6e16ce6e16d06f16b962140e0801",
			"0e0a04b4833ccc9545ca9344ca9344ca9344ca9344cc9545b4833c0e0a04",
			"0101014e6758709a866c94816d94816d94816c9481709a864e6758010101",
			"000000081211274e472a544c29534b29534b2a544c274e47081211000000",
			"0000000000000308060a18140b1c170b1c170a1814030806000000000000",
			"000000000000000000000000000101000101000000000000000000000000"
		}
		
		for k,line in ipairs(opus) do
			term.setCursorPos((w - 18) / 2, k + (h - #opus) / 2)
			term.blit(string.rep(' ', #line), string.rep('a', #line), line)
		end
	end

	local str = 'Press any key for menu'
	term.setCursorPos((w - #str) / 2, h)
	term.write(str)
end

for _, v in pairs(bootOptions.preload) do
	os.run(_ENV, v)
end

term.clear()
splash()

local timerId = os.startTimer(bootOptions.delay)
while true do
	local e, id = os.pullEvent()
	if e == 'timer' and id == timerId then
		break
	end
	if e == 'char' or e == 'key' then
		bootOption = startupMenu()
		if settings then
			settings.set('opus.boot_option', bootOption)
			settings.save('.settings')
		end
		break
	end
end

term.clear()
term.setCursorPos(1, 1)
if bootOptions.menu[bootOption].args then
	os.run(_ENV, table.unpack(bootOptions.menu[bootOption].args))
else
	print(bootOptions.menu[bootOption].prompt)
end

