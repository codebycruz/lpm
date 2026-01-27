local ansi = require("ansi")

local Package = require("lpm.package")

---@param args clap.Args
local function tree(args)
	---@param pkg lpm.Package
	---@param dep lpm.Config.Dependency?
	---@param indent string?
	local function printTree(pkg, dep, indent)
		indent = indent or ""

		if dep then
			local desc
			if dep.git then
				desc = "git: " .. dep.git
			elseif dep.path then
				desc = "path: " .. dep.path
			end

			ansi.printf("%s{blue}%s {gray}(%s)", indent, pkg:getName(), desc)
		else
			ansi.printf("%s{blue}%s", indent, pkg:getName())
		end
		for name, info in pairs(pkg:getDependencies()) do
			printTree(Package.open(pkg:getDependencyPath(name, info)), info, indent .. "  ")
		end
	end

	printTree(Package.open())
end

return tree
