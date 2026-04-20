local ansi = require("ansi")
local lde = require("lde-core")

---@param args clap.Args
local function sync(args)
	local pkg, err = lde.Package.open()
	if not pkg then
		ansi.printf("{red}%s", err)
		return
	end

	pkg:build()
	pkg:installDependencies()
	if not args:flag("production") then
		pkg:installDevDependencies()
	end

	ansi.printf("{green}All dependencies installed successfully.")
end

return sync
