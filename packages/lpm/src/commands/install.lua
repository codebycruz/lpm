local ansi = require("ansi")

local Package = require("lpm.package")

---@param args clap.Args
local function install(args)
	Package.open():installDependencies()
	print(ansi.colorize(ansi.green, "All dependencies installed successfully."))
end

return install
