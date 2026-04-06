local test = require("lde-test")
local Archive = require("archive")
local fs = require("fs")
local env = require("env")
local path = require("path")

local tmpBase = path.join(env.tmpdir(), "lde-archive-tests")
fs.rmdir(tmpBase)
fs.mkdir(tmpBase)

local function tmp(name)
	return path.join(tmpBase, name)
end

-- helpers to create real archives for testing
local function makeZip(zipPath, content)
	local dir = tmp("zip-src")
	fs.mkdir(dir)
	fs.write(path.join(dir, "hello.txt"), content)
	local code = os.execute("cd " .. dir .. " && zip -q " .. zipPath .. " hello.txt")
	return code == 0 or code == true
end

local function makeTar(tarPath, content)
	local dir = tmp("tar-src")
	fs.mkdir(dir)
	fs.write(path.join(dir, "hello.txt"), content)
	local code = os.execute("cd " .. dir .. " && tar -cf " .. tarPath .. " -C " .. dir .. " hello.txt")
	return code == 0 or code == true
end

--
-- Archive.new
--

test.it("Archive.new with string returns Archive", function()
	local a = Archive.new("/some/path.tar.gz")
	test.truthy(a)
end)

test.it("Archive.new with table returns Archive", function()
	local a = Archive.new({ ["hello.txt"] = "hello" })
	test.truthy(a)
end)

test.it("extract fails when source is a table", function()
	local a = Archive.new({ ["hello.txt"] = "hello" })
	local ok, err = a:extract(tmp("out-table"))
	test.falsy(ok)
	test.truthy(err)
end)

test.it("save fails when source is a string", function()
	local a = Archive.new("/some/path.tar.gz")
	local ok, err = a:save(tmp("out.zip"))
	test.falsy(ok)
	test.truthy(err)
end)

test.it("save fails for unknown extension", function()
	local a = Archive.new({ ["hello.txt"] = "hello" })
	local ok, err = a:save(tmp("out.rar"))
	test.falsy(ok)
	test.truthy(err)
end)

test.it("save encodes to .zip and files are extractable", function()
	local zipPath = tmp("saved.zip")
	local outDir = tmp("out-saved-zip")
	fs.mkdir(outDir)

	local a = Archive.new({ ["hello.txt"] = "zip content" })
	local ok = a:save(zipPath)
	test.truthy(ok)
	test.truthy(fs.exists(zipPath))

	local b = Archive.new(zipPath)
	local ok2 = b:extract(outDir)
	test.truthy(ok2)
	test.equal(fs.read(path.join(outDir, "hello.txt")), "zip content")
end)

test.it("save encodes to .tar.gz and files are extractable", function()
	local tarPath = tmp("saved.tar.gz")
	local outDir = tmp("out-saved-tar")
	fs.mkdir(outDir)

	local a = Archive.new({ ["hello.txt"] = "tar content" })
	local ok = a:save(tarPath)
	test.truthy(ok)
	test.truthy(fs.exists(tarPath))

	local b = Archive.new(tarPath)
	local ok2 = b:extract(outDir)
	test.truthy(ok2)
	test.equal(fs.read(path.join(outDir, "hello.txt")), "tar content")
end)

--
-- tar extraction
--

test.it("extracts a .tar archive", function()
	local tarPath = tmp("test.tar")
	local outDir = tmp("out-tar")
	fs.mkdir(outDir)

	local made = makeTar(tarPath, "tar content")
	if not made then return end -- skip if tar not available

	local a = Archive.new(tarPath)
	local ok = a:extract(outDir)
	test.truthy(ok)
	test.truthy(fs.exists(path.join(outDir, "hello.txt")))
end)

--
-- zip extraction (linux only — mac/windows always use tar)
--

if jit.os == "Linux" then
	test.it("extracts a .zip archive using unzip on linux", function()
		local zipPath = tmp("test.zip")
		local outDir = tmp("out-zip")
		fs.mkdir(outDir)

		local made = makeZip(zipPath, "zip content")
		if not made then return end -- skip if zip not available

		local a = Archive.new(zipPath)
		local ok = a:extract(outDir)
		test.truthy(ok)
		test.truthy(fs.exists(path.join(outDir, "hello.txt")))
	end)

	test.it("uses tar for non-zip on linux even without .tar extension", function()
		-- a .tar renamed to .bin — magic bytes are not PK, so tar is used
		local tarPath = tmp("test.tar")
		local binPath = tmp("test.bin")
		makeTar(tarPath, "bin content")
		fs.copy(tarPath, binPath)

		local outDir = tmp("out-bin")
		fs.mkdir(outDir)

		local a = Archive.new(binPath)
		local ok = a:extract(outDir)
		test.truthy(ok)
	end)
end
