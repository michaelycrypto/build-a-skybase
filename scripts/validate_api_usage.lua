#!/usr/bin/env lua

--[[
	validate_api_usage.lua - Simple API Validation Script

	Validates API usage in the codebase to prevent common mistakes
	like using non-existent methods or incorrect event registration.

	Usage: lua scripts/validate_api_usage.lua
--]]

-- Simple file reading function (no external dependencies)
local function read_file(filename)
    local file = io.open(filename, "r")
    if not file then
        return nil
    end
    local content = file:read("*all")
    file:close()
    return content
end

-- Simple directory scanning function
local function scan_directory(dirpath, callback)
    local handle = io.popen("find " .. dirpath .. " -name '*.lua' 2>/dev/null")
    if not handle then
        return
    end

    for filename in handle:lines() do
        callback(filename)
    end
    handle:close()
end

-- Configuration
local CONFIG = {
	-- File patterns to check
	FILE_PATTERNS = {
		"%.lua$" -- Only check .lua files
	},

	-- Directories to scan
	SCAN_DIRECTORIES = {
		"src/ServerScriptService",
		"src/StarterPlayerScripts"
	},

	-- API definitions
	APIS = {
		EventManager = {
			valid_methods = {
				"RegisterEventHandler",
				"RegisterEvent",
				"FireEvent",
				"FireEventToAll",
				"SendToServer",
				"ConnectToServer"
			},
			invalid_methods = {
				"RegisterServerEvent",
				"RegisterClientEvent"
			}
		},
		ProximityGridService = {
			valid_methods = {
				"Initialize",
				"CreateGrid",
				"RemoveGrid",
				"GetGridData",
				"UpdateGridData"
			}
		},
		WorldService = {
			valid_methods = {
				"Initialize",
				"CreatePlayerGrid",
				"CleanupPlayer",
				"HandleTileClick"
			}
		}
	},

	-- Error patterns to check for
	ERROR_PATTERNS = {
		-- Common API mistakes
		"EventManager:RegisterServerEvent",
		"EventManager:RegisterClientEvent",
		"EventManager:FireToServer",
		"EventManager:FireToClient",

		-- Common service mistakes
		"ProximityGridService:CreateGridVisual",
		"WorldService:CreateGridVisual",
	}
}

-- State
local errors = {}
local warnings = {}
local files_checked = 0

--[[
	Check if file matches patterns
	@param filename: string - File name to check
	@return: boolean - True if file should be checked
--]]
local function should_check_file(filename)
	for _, pattern in ipairs(CONFIG.FILE_PATTERNS) do
		if filename:match(pattern) then
			return true
		end
	end
	return false
end

--[[
	Check file for API usage errors
	@param filepath: string - Path to file to check
--]]
local function check_file(filepath)
	local content = read_file(filepath)
	if not content then
		return
	end

	local lines = {}
	for line in content:gmatch("([^\n]*)\n?") do
		table.insert(lines, line)
	end

	-- Check for error patterns
	for line_num, line in ipairs(lines) do
		for _, pattern in ipairs(CONFIG.ERROR_PATTERNS) do
			if line:find(pattern, 1, true) then
				table.insert(errors, {
					file = filepath,
					line = line_num,
					content = line:gsub("^%s*", ""),
					pattern = pattern,
					message = "Invalid API usage detected"
				})
			end
		end

		-- Check for specific API method usage
		for service_name, api_info in pairs(CONFIG.APIS) do
			-- Check for invalid methods
			if api_info.invalid_methods then
				for _, invalid_method in ipairs(api_info.invalid_methods) do
					local pattern = service_name .. ":" .. invalid_method
					if line:find(pattern, 1, true) then
						table.insert(errors, {
							file = filepath,
							line = line_num,
							content = line:gsub("^%s*", ""),
							pattern = pattern,
							message = "Invalid method '" .. invalid_method .. "' on " .. service_name
						})
					end
				end
			end
		end
	end

	files_checked = files_checked + 1
end

--[[
	Scan directory for files
	@param dirpath: string - Directory path to scan
--]]
local function scan_directory(dirpath)
	scan_directory(dirpath, function(filepath)
		check_file(filepath)
	end)
end

--[[
	Print results
--]]
local function print_results()
	print("🔍 API Usage Validation Results")
	print("================================")
	print("Files checked: " .. files_checked)
	print("Errors found: " .. #errors)
	print("Warnings found: " .. #warnings)
	print("")

	if #errors > 0 then
		print("❌ ERRORS:")
		for _, error in ipairs(errors) do
			print("  " .. error.file .. ":" .. error.line)
			print("    " .. error.message)
			print("    " .. error.content)
			print("")
		end
	end

	if #warnings > 0 then
		print("⚠️ WARNINGS:")
		for _, warning in ipairs(warnings) do
			print("  " .. warning.file .. ":" .. warning.line)
			print("    " .. warning.message)
			print("    " .. warning.content)
			print("")
		end
	end

	if #errors == 0 and #warnings == 0 then
		print("✅ No API usage errors found!")
	end
end

--[[
	Main function
--]]
local function main()
	print("🔍 Starting API usage validation...")

	-- Scan directories
	for _, dir in ipairs(CONFIG.SCAN_DIRECTORIES) do
		scan_directory(dir)
	end

	-- Print results
	print_results()

	-- Exit with error code if errors found
	if #errors > 0 then
		os.exit(1)
	end
end

-- Run main function
main()
