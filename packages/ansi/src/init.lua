local ansi = {}

---@alias ansi.Color
--- | "reset"
--- | "red"
--- | "green"
--- | "yellow"
--- | "blue"
--- | "magenta"
--- | "cyan"
--- | "white"
--- | "gray"

---@type table<ansi.Color, string>
local colors = {
	reset = "\27[0m",
	red = "\27[31m",
	green = "\27[32m",
	yellow = "\27[33m",
	blue = "\27[34m",
	magenta = "\27[35m",
	cyan = "\27[36m",
	white = "\27[37m",
	gray = "\27[90m"
}

---@param name ansi.Color
---@param s string
function ansi.colorize(name, s)
	return colors[name] .. s .. colors.reset
end

---@param f string
---@param ... any
function ansi.format(f, ...)
	return string.format(string.gsub(f, "{([^}]+)}", colors), ...) .. colors.reset
end

---@param f string
---@param ... any
function ansi.printf(f, ...)
	print(ansi.format(f, ...))
end

return ansi
