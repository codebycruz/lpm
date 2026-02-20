local outDir = os.getenv("LPM_OUTPUT_DIR")
local sep = string.sub(package.config, 1, 1)
local isWindows = jit.os == "Windows"
local isMac = jit.os == "OSX"

local function join(...)
	return table.concat({ ... }, sep)
end

local debug = os.getenv("DEBUG") == "1"
local null = jit.os == "Windows" and "NUL" or "/dev/null"
local redirect = debug and "" or (" >" .. null .. " 2>&1")

local function exec(cmd)
	local ok = os.execute(cmd .. redirect)
	if ok ~= true and ok ~= 0 then
		error("Command failed: " .. cmd)
	end
end

-- Determine output library name and platform flags
local libExt = isWindows and "dll" or isMac and "dylib" or "so"
local libName = "tcc." .. libExt
local outLib = join(outDir, libName)

-- Compute a build directory next to LPM_OUTPUT_DIR
local parentDir = outDir:match("^(.*)" .. sep .. "[^" .. sep .. "]+$") or outDir
local buildDir = join(parentDir, "_tcc_build")

local builtLib = join(buildDir, "libtcc." .. libExt)

if not io.open(builtLib, "r") then
	if not io.open(join(buildDir, "configure"), "r") then
		exec("git clone --depth=1 https://github.com/TinyCC/tinycc " .. buildDir)
	end

	if isWindows then
		exec("cd " .. buildDir .. " && ./configure --disable-static --config-mingw32 && make libtcc.dll libtcc1.a")
	elseif isMac then
		exec("cd " .. buildDir .. " && ./configure --disable-static && make libtcc." .. libExt .. " libtcc1.a")
	else
		-- --with-selinux uses file-backed mmap for executable pages, required on
		-- systems with SELinux enforcing (e.g. Fedora). Safe to pass unconditionally.
		exec("cd " .. buildDir .. " && ./configure --disable-static --with-selinux && make libtcc." .. libExt .. " libtcc1.a")
	end
end

exec("cp " .. builtLib .. " " .. outLib)
exec("cp " .. join(buildDir, "libtcc1.a") .. " " .. join(outDir, "libtcc1.a"))
