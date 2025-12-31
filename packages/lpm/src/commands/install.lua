local ansi = require("ansi")

local Package = require("lpm.package")

---@param args clap.Args
local function install(args)
	local pkg = Package.open()

	pkg:installDependencies()
	if not args:has("production") then
		pkg:installDevDependencies()
	end

	print(ansi.colorize(ansi.green, "All dependencies installed successfully."))
end

return install
