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

		local deps = {} ---@type { name: string, info: lpm.Config.Dependency }[]
		for name, info in pairs(pkg:getDependencies()) do
			deps[#deps + 1] = { name = name, info = info }
		end

		table.sort(deps, function(a, b)
			return a.name < b.name
		end)

		for _, dep in ipairs(deps) do
			printTree(Package.open(pkg:getDependencyPath(dep.name, dep.info)), dep.info, indent .. "  ")
		end
	end

	printTree(Package.open())
end

return tree
