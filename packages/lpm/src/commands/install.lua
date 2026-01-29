local ansi = require("ansi")

local Package = require("lpm.package")

---@param args clap.Args
local function install(args)
	local pkg = Package.open()

	pkg:installDependencies()
	if not args:flag("production") then
		pkg:installDevDependencies()
	end

	ansi.printf("{green}All dependencies installed successfully.")
end

return install
