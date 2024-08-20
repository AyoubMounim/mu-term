local M = {}

local show_error = function(msg)
	require("notify")(msg, "error")
end

local default_config = { width = 50, height = 50 }

M.setup = function(config)
	local user_config = config or {}
	M.config = {}
	M.config.height = user_config.height or default_config.height
	M.config.width = user_config.width or default_config.width
end

M.open_term = function()
	local buf = vim.api.nvim_create_buf(true, true)
	if buf == 0 then
		show_error("Buffer creation failed.")
		return
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Hello There!" })
	local win_opts = {
		relative = "win",
		width = M.config.width,
		height = M.config.height,
		row = 0,
		col = 50,
		style = "minimal",
	}
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	if win == 0 then
		show_error("Window creation failed.")
		return
	end
end

return M
