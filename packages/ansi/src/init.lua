local ansi = {}

-- Reset
ansi.reset = "\27[0m"

-- Colors
ansi.red = "\27[31m"
ansi.green = "\27[32m"
ansi.yellow = "\27[33m"
ansi.blue = "\27[34m"
ansi.magenta = "\27[35m"
ansi.cyan = "\27[36m"
ansi.white = "\27[37m"
ansi.orange = "\27[38;5;208m"

-- Bright colors
ansi.bright_red = "\27[91m"
ansi.bright_green = "\27[92m"
ansi.bright_yellow = "\27[93m"
ansi.bright_blue = "\27[94m"
ansi.bright_magenta = "\27[95m"
ansi.bright_cyan = "\27[96m"
ansi.bright_white = "\27[97m"

-- Helper function to colorize text
function ansi.colorize(color, text)
	return color .. text .. ansi.reset
end

return ansi
