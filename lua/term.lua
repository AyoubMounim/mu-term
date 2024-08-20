local M = {}

local show_error = function(msg)
	require("notify")(msg, "error")
end

local show_info = function(msg)
	require("notify")(msg, "info")
end

local default_config = { width = 50, height = 50 }

M.setup = function(config)
	local user_config = config or {}
end

M.open_term = function()
	local buf = vim.api.nvim_create_buf(true, true)
	if buf == 0 then
		show_error("Buffer creation failed.")
		return
	end
	local win_opts = {
		style = "minimal",
		vertical = true,
		split = "right",
	}
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	if win == 0 then
		show_error("Window creation failed.")
		return
	end
	vim.api.nvim_cmd({ cmd = "terminal" }, {})
end

M.open_term_float = function(x, y, width, height)
	local buf = vim.api.nvim_create_buf(true, true)
	if buf == 0 then
		show_error("Buffer creation failed.")
		return
	end
	local current_win_width = vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())
	local current_win_height = vim.api.nvim_win_get_height(vim.api.nvim_get_current_win())
	local win_opts = {
		relative = "win",
		width = width or math.floor(current_win_width / 2),
		height = height or current_win_height,
		row = y or 0,
		col = x or current_win_width / 2,
		style = "minimal",
		border = "rounded",
	}
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	if win == 0 then
		show_error("Window creation failed.")
		return
	end
	vim.api.nvim_cmd({ cmd = "terminal" }, {})
end

M._open_term_chan_float = function(x, y, width, height)
	local buf = vim.api.nvim_create_buf(true, true)
	if buf == 0 then
		return 0
	end
	local current_win_width = vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())
	local current_win_height = vim.api.nvim_win_get_height(vim.api.nvim_get_current_win())
	local win_opts = {
		relative = "win",
		width = width or math.floor(current_win_width / 2),
		height = height or current_win_height,
		row = y or 0,
		col = x or current_win_width / 2,
		style = "minimal",
		border = "rounded",
	}
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	if win == 0 then
		return 0
	end
	return vim.api.nvim_open_term(buf, {})
end

M.term_execute = function(path_to_exe, args)
	local exe = path_to_exe or nil
	local args_str = args or nil
	local cwd = vim.fn.getcwd(0)
	if not exe then
		exe = vim.fn.input({ prompt = "Executable path: ", default = cwd })
	end
	if not args_str then
		args_str = vim.fn.input({ prompt = "Arguments string: " })
	end
	local chan_id = M._open_term_chan_float()
	if chan_id == 0 then
		show_error("Terminal opening failed.")
		return
	end
	local obj = vim.system({ exe, args_str }, { text = true }):wait()
	vim.api.nvim_chan_send(chan_id, obj.stdout)
end

return M
