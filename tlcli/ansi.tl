
local M = {
	fg = {
		rgb: function(number,number,number):string = nil,
		hex: function(string|number):string = nil,
	},
	bg = {
		rgb: function(number,number,number):string = nil,
		hex: function(string|number):string = nil,
	},
}

local CSI = string.char(27) .. "[%sm"

local dark = {
	black = "30",
	red = "31",
	green = "32",
	yellow = "33",
	blue = "34",
	magenta = "35",
	cyan = "36",
	white = "37",
}

local bright = {
	black = "90",
	red = "91",
	green = "92",
	yellow = "93",
	blue = "94",
	magenta = "95",
	cyan = "96",
	white = "97",
}

function M.dark(cname: string): string
	return CSI:format(dark[cname])
end

function M.bright(cname: string): string
	return CSI:format(bright[cname])
end

local CSIfg = string.char(27) .. "[38;2;%d;%d;%dm"
local CSIbg = string.char(27) .. "[48;2;%d;%d;%dm"
M.fg = {
	rgb = function(r: number, g: number, b: number): string
		return CSIfg:format(r, g, b)
	end,
	hex = function(hex: string | number): string
		if hex is string then
			if string.sub(hex, 1, 1) == "#" then
				hex = string.sub(hex, 2, -1)
			end
			hex = tonumber(hex, 16)
		end
		-- poor man's bit shifting
		local red = math.floor((hex as number) / 2 ^ 16) * 0xFF
		local green = math.floor((hex as number) / 2 ^ 8) * 0xFF
		local blue = math.floor((hex as number)) * 0xFF
		return CSI:format(red, green, blue)
	end
}
M.bg = {
	rgb = function(r: number, g: number, b: number): string
		return CSIbg:format(r, g, b)
	end,
	hex = function(hex: string | number): string
		if hex is string then
			if string.sub(hex, 1, 1) == "#" then
				hex = string.sub(hex, 2, -1)
			end
			hex = tonumber(hex, 16)
		end
		-- poor man's bit shifting
		local red = math.floor((hex as number) / 2 ^ 16) * 0xFF
		local green = math.floor((hex as number) / 2 ^ 8) * 0xFF
		local blue = math.floor((hex as number)) * 0xFF
		return CSIbg:format(red, green, blue)
	end
}

local reset = CSI:format(0)
function M.reset(): string
	return reset
end

--print(M.bright"red" .. "hello" .. M.reset())
--print(M.fg.rgb(100, 100, 100) .. "hello" .. M.reset())
--print(M.bg.rgb(100, 100, 100) .. "hello" .. M.reset())

return M
