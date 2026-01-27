local ansi = require("ansi")

local Package = require("lpm.package")

---@type ansi.Color[]
local depthColors = {
	"yellow",
	"magenta",
	"cyan"
}

---@param args clap.Args
local function tree(args)
	---@param pkg lpm.Package
	---@param cfg lpm.Config.Dependency?
	---@param depth number?
	local function printTree(pkg, cfg, depth)
		depth = depth or 0

		local indent = string.rep("  ", depth)
		local name = ansi.colorize(depthColors[depth % #depthColors + 1], pkg:getName())

		if cfg then
			local desc
			if cfg.git then
				desc = "git: " .. cfg.git
			elseif cfg.path then
				desc = "path: " .. cfg.path
			end

			ansi.printf("%s%s {gray}(%s)", indent, name, desc)
		else
			ansi.printf("%s%s", indent, name)
		end

		local deps = {} ---@type { name: string, info: lpm.Config.Dependency }[]
		for name, info in pairs(pkg:getDependencies()) do
			deps[#deps + 1] = { name = name, info = info }
		end

		table.sort(deps, function(a, b)
			return a.name < b.name
		end)

		for _, dep in ipairs(deps) do
			printTree(Package.open(pkg:getDependencyPath(dep.name, dep.info)), dep.info, depth + 1)
		end
	end

	printTree(Package.open())
end

return tree
