local Config = require("lpm-core.config")
local Lockfile = require("lpm-core.lockfile")

local global = require("lpm-core.global")

local fs = require("fs")
local env = require("env")
local json = require("json")
local path = require("path")

---@class lpm.Package
---@field dir string
---@field buildfn fun(outDir: string)? # Optional build 'function' in place of a build script.
---@field cachedConfig lpm.Config?
---@field cachedConfigMtime number?
local Package = {}
Package.__index = Package

function Package:__tostring()
	return "Package(" .. self.dir .. ")"
end

-- Add this since files in . will want access to the `Package` class.
package.loaded[(...)] = Package

---@param dir string
local function configPathAtDir(dir)
	return path.join(dir, "lpm.json")
end

function Package:getDir() return self.dir end

function Package:getBuildScriptPath() return path.join(self.dir, "build.lua") end

function Package:getLuarcPath() return path.join(self.dir, ".luarc.json") end

function Package:getModulesDir() return path.join(self.dir, "target") end

function Package:getTargetDir() return path.join(self:getModulesDir(), self:getName()) end

function Package:getSrcDir() return path.join(self.dir, "src") end

function Package:getTestDir() return path.join(self.dir, "tests") end

function Package:getConfigPath() return configPathAtDir(self.dir) end

function Package:getLockfilePath() return path.join(self.dir, "lpm-lock.json") end

---@param dir string?
---@return lpm.Package?, string?
function Package.openLPM(dir)
	dir = dir or env.cwd()

	local configPath = configPathAtDir(dir)
	if fs.exists(configPath) then
		return setmetatable({ dir = dir }, Package), nil
	end

	return nil, "No lpm.json found in directory: " .. dir
end

Package.openRocks = require("lpm-core.package.rocks")

--- Opens a directory, preferring lpm.json and falling back to a *.rockspec.
---@param dir string?
---@return lpm.Package?, string?
function Package.open(dir)
	dir = dir or env.cwd()

	local pkg, err = Package.openLPM(dir)
	if pkg then return pkg, nil end

	local rocksPkg, rocksErr = Package.openRocks(dir)
	if rocksPkg then return rocksPkg, nil end

	return nil, err .. "\n" .. rocksErr
end

--- Scans a directory tree for a package with the given name.
--- Checks lpm.json files first, then *.rockspec files.
---@param dir string
---@param name string
---@return lpm.Package?, string?
function Package.findNamed(dir, name)
	for _, config in ipairs(fs.scan(dir, "**" .. path.separator .. "lpm.json")) do
		local parentDir = path.join(dir, path.dirname(config))
		local pkg = Package.openLPM(parentDir)
		if pkg and pkg:getName() == name then
			return pkg, nil
		end
	end

	for _, spec in ipairs(fs.scan(dir, "**" .. path.separator .. "*.rockspec")) do
		local parentDir = path.join(dir, path.dirname(spec))
		local pkg = Package.openRocks(parentDir)
		if pkg and pkg:getName() == name then
			return pkg, nil
		end
	end

	return nil, "No package named '" .. name .. "' found in: " .. dir
end

---@return lpm.Config
function Package:readConfig()
	local configPath = self:getConfigPath()

	local s = fs.stat(configPath)
	if not s then
		-- No lpm.json on disk (e.g. rockspec-based package); return cached config if available.
		if self.cachedConfig then
			return self.cachedConfig
		end
		error("Could not read lpm.json: " .. configPath)
	end

	if self.cachedConfig and self.cachedConfigMtime == s.modifyTime then
		return self.cachedConfig
	end

	local content = fs.read(configPath)
	if not content then
		error("Could not read lpm.json: " .. configPath)
	end

	local newConfig = Config.new(json.decode(content))
	self.cachedConfig = newConfig
	self.cachedConfigMtime = s.modifyTime

	return newConfig
end

function Package:readLockfile()
	return Lockfile.open(self:getLockfilePath())
end

Package.init = require("lpm-core.package.initialize")

function Package:getDependencies() return self:readConfig().dependencies or {} end

function Package:getDevDependencies() return self:readConfig().devDependencies or {} end

function Package:getName() return self:readConfig().name end

Package.build = require("lpm-core.package.build")

---@param dir string
---@param info lpm.Config.Dependency
---@param relativeTo string?
function Package:getDependencyPath(dir, info, relativeTo)
	if info.git then
		return global.getGitRepoDir(dir, info.branch, info.commit)
	elseif info.path then
		relativeTo = relativeTo or self.dir
		return path.normalize(path.join(relativeTo, info.path))
	end
end

Package.installDependencies = require("lpm-core.package.install")
function Package:installDevDependencies() self:installDependencies(self:getDevDependencies()) end

Package.updateDependencies = require("lpm-core.package.update")
function Package:updateDevDependencies() return self:updateDependencies(self:getDevDependencies()) end

Package.compile = require("lpm-core.package.compile")
Package.runScript = require("lpm-core.package.run")
Package.runTests = require("lpm-core.package.test")

function Package:hasBuildScript()
	if self.buildfn then
		return true
	end

	return fs.exists(self:getBuildScriptPath())
end

---@param outputDir string
function Package:runBuildScript(outputDir)
	if self.buildfn then
		self.buildfn(outputDir)
		return true
	end

	return self:runScript(self:getBuildScriptPath(), nil, { LPM_OUTPUT_DIR = outputDir })
end

return Package
