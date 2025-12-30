local fs = {}

function fs.exists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	else
		return false
	end
end

function fs.mkdir(path)
	os.execute("mkdir -p " .. path)
end

function fs.mklink(src, dest)
	os.execute("ln -s " .. src .. " " .. dest)
end

function fs.cwd()
	local f = io.popen("pwd")
	local cwd = f:read("*all"):gsub("\n$", "")
	f:close()
	return cwd
end

function fs.basename(path)
	return path:match("([^/]+)$") or path
end

function fs.listdir(path)
	local files = {}
	local handle = io.popen("ls -1 " .. path .. " 2>/dev/null")
	if handle then
		for line in handle:lines() do
			table.insert(files, line)
		end
		handle:close()
	end
	return files
end

function fs.isdir(path)
	local handle = io.popen("test -d " .. path .. " && echo true || echo false")
	if handle then
		local result = handle:read("*line")
		handle:close()
		return result == "true"
	end
	return false
end

function fs.copy(src, dest)
	os.execute("cp " .. src .. " " .. dest)
end

return fs
