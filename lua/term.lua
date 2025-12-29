local M = {}

local Executable = {}

function Executable:new(exe_path, args_str, alias, cwd, env)
	local obj = {
		name = exe_path or "",
		args = args_str or "",
		alias = alias or nil,
		cwd = cwd or vim.fs.dirname(exe_path),
		env = env or {},
	}
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function Executable:new_from_file(file)
	if not file then
		M:show_warn("File arg is nil.")
		return nil
	end
	local f = io.open(file, "r")
	if not f then
		M:show_warn("File open failed.")
		return nil
	end
	local json_str = f:read("*all")
	f:close()
	local ok, data = pcall(vim.json.decode, json_str, { luanil = { object = true, array = true } })
	if not ok then
		M:show_error("Config file parsing failed.")
		return nil
	end
	local exes = data["commands"] or nil
	if not exes then
		M:show_warn("Config parsing error.")
		return nil
	end
	if #exes == 0 then
		exes = { exes }
	end
	local parsed_exes = {}
	for _, d in ipairs(exes) do
		local exe_path = nil
		if d["name"] then
			exe_path = vim.fs.joinpath(vim.fs.dirname(file), d["name"])
		end
		if exe_path then
			local cmd_alias = d["alias"] or d["name"]
			table.insert(parsed_exes, Executable:new(exe_path, d["args"], cmd_alias, d["cwd"], d["env"]))
		end
	end
	return parsed_exes
end

function Executable:new_from_input()
	local cwd = vim.fn.getcwd(0)
	local exe = vim.fn.input({ prompt = "Executable path: ", default = cwd, cancelreturn = nil })
	if not exe then
		return nil
	end
	local args = vim.fn.input({ prompt = "Executable args string: ", cancelreturn = "" })
	return Executable:new(exe, args)
end

function Executable:get_cmd_string()
	local cmd = vim.split(self.args, " ", { trimempty = true })
	table.insert(cmd, 1, self.name)
	return cmd
end

M._default_config = {
	verbose = false,
	exe_float_win = { x = nil, y = nil, width = 0.8, height = 0.8 },
	term_float_win = { x = nil, y = nil, width = 0.8, height = 0.8 },
	term_win = { vertical = true, split = "right" },
}

function M:show_error(msg)
	if not self._conf.verbose then
		return
	end
	require("notify")(msg, "error", { title = "mu-term" })
end

function M:show_info(msg)
	if not self._conf.verbose then
		return
	end
	require("notify")(msg, "info", { title = "mu-term" })
end

function M:show_warn(msg)
	if not self._conf.verbose then
		return
	end
	require("notify")(msg, "warn", { title = "mu-term" })
end

M.setup = function(config)
	local conf = config or {}
	M._conf = vim.tbl_deep_extend("force", M._default_config, conf)
end

function M:open_term()
	local buf = vim.api.nvim_create_buf(true, true)
	if buf == 0 then
		M:show_error("Buffer creation failed.")
		return
	end
	local win_opts = {
		style = "minimal",
		vertical = self._conf.term_win.vertical,
		split = self._conf.term_win.split,
	}
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	if win == 0 then
		M:show_error("Window creation failed.")
		return
	end
	vim.api.nvim_cmd({ cmd = "terminal" }, {})
end

function M:open_term_float(x, y, width, height)
	M._open_win_float(
		x or self._conf.term_float_win.x,
		y or self._conf.term_float_win.y,
		width or self._conf.term_float_win.width,
		height or self._conf.term_float_win.height
	)
	vim.api.nvim_cmd({ cmd = "terminal" }, {})
end

M._open_win_float = function(x, y, width, height)
	local res = { buf = 0, win = 0 }
	local buf = vim.api.nvim_create_buf(true, true)
	res.buf = buf
	if buf == 0 then
		return res
	end
	local current_win_width = vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())
	local current_win_height = vim.api.nvim_win_get_height(vim.api.nvim_get_current_win())
	local w = math.floor(current_win_width / 2)
	if width then
		w = math.floor(width * current_win_width)
	end
	local h = math.floor(current_win_height / 2)
	if height then
		h = math.floor(height * current_win_height)
	end
	local row = math.abs((current_win_height - h) / 2)
	if y then
		row = y * current_win_height
	end
	local col = math.abs((current_win_width - w) / 2)
	if x then
		col = x * current_win_width
	end
	local win_opts = {
		relative = "win",
		width = w,
		height = h,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	}
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	res.win = win
	return res
end

M._find_config_file = function()
	local file = vim.fs.find("muterm.json", { type = "file" })[1] or nil
	return file
end

function M:_execute(executable, buf)
	local channel_id = vim.api.nvim_open_term(buf, {})
	vim.system(executable:get_cmd_string(), {
		cwd = executable.cwd,
		env = executable.env,
		text = true,
		stdout = vim.schedule_wrap(function(err, data)
			assert(not err, err)
			if data then
				vim.api.nvim_chan_send(channel_id, data)
			end
		end),
		stderr = vim.schedule_wrap(function(err, data)
			assert(not err, err)
			if data then
				vim.api.nvim_chan_send(channel_id, data)
			end
		end),
	})
end

function M:_get_executable()
	local config_file = self._find_config_file()
	local aborted = false
	if not config_file then
		local executable = Executable:new_from_input()
		return executable
	end
	local executable = Executable:new_from_file(config_file)
	if not executable then
		executable = nil
	elseif #executable == 1 then
		executable = executable[1]
	elseif #executable > 1 then
		local options = { "Select the executable to run:" }
		for i, e in ipairs(executable) do
			local cmd_name = e["alias"] or e["name"]
			table.insert(options, tostring(i) .. " " .. cmd_name)
		end
		local c = vim.fn.inputlist(options)
		if c <= 0 then
			aborted = true
			executable = nil
		else
			executable = executable[c]
		end
	else
		executable = nil
	end
	return executable, aborted
end

function M:term_execute(path_to_exe, args)
	local exe_path = path_to_exe or nil
	local args_str = args or nil
	local executable = nil
	local aborted = false
	if exe_path then
		executable = Executable:new(exe_path, args_str or "")
	else
		executable, aborted = M:_get_executable()
	end
	if aborted then
		return
	elseif not executable or not vim.uv.fs_stat(executable.name) then
		M:show_error("Executable not found.")
		return
	end
	local pane = self._open_win_float(
		self._conf.exe_float_win.x,
		self._conf.exe_float_win.y,
		self._conf.exe_float_win.width,
		self._conf.exe_float_win.height
	)
	if pane.buf == 0 or pane.win == 0 then
		M:show_error("Window opening failed.")
		return
	end
	M:_execute(executable, pane.buf)
end

return M
