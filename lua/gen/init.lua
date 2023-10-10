local M = {}
M.prompts = require("gen.prompts")

local curr_buffer = nil
local start_pos = nil
local end_pos = nil

local function trim_table(tbl)
	local function is_whitespace(str)
		return str:match("^%s*$") ~= nil
	end

	while #tbl > 0 and (tbl[1] == "" or is_whitespace(tbl[1])) do
		table.remove(tbl, 1)
	end

	while #tbl > 0 and (tbl[#tbl] == "" or is_whitespace(tbl[#tbl])) do
		table.remove(tbl, #tbl)
	end

	return tbl
end

local function serve_ollama()
	local ollama_is_not_running = vim.fn.system('ps -axo args | grep "^ollama serve$"') == ""
	if ollama_is_not_running then
		local serve_job_id = vim.fn.jobstart("ollama serve > /dev/null 2>&1")
		vim.api.nvim_create_autocmd("VimLeave", {
			callback = function()
				vim.fn.jobstop(serve_job_id)
			end,
			group = vim.api.nvim_create_augroup("_gen_leave", { clear = true }),
		})
	end
end

local function get_window_options()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local width = vim.api.nvim_win_get_width(0)
	local win_height = vim.api.nvim_win_get_height(0)

	local middle_row = win_height / 2

	local height = math.floor(win_height / 2)
	local win_row
	if cursor[1] <= middle_row then
		win_row = 5
	else
		win_row = -5 - height
	end

	return {
		relative = "cursor",
		width = width,
		height = height,
		row = win_row,
		col = 0,
		style = "minimal",
		border = "single",
	}
end

local function complete_for(arg_lead, tbl)
	-- search for (partial) match
	local matches = {}
	for key, _ in pairs(tbl) do
		if key:match(arg_lead) then
			table.insert(matches, key)
		end
	end

	if next(matches) == nil then
		-- list all models in completion if no match
		return tbl
	else
		-- otherwise only list models matching current input
		return matches
	end
end

-- read setup
M.setup = function(config)
	-- Example opts for lazy.nvim
	-- opts = {
	-- 	default_model = "codellama:7b",
	-- 	prompts = {
	-- 		Test = { prompt = "Count from 10 downward to 5", replace = false },
	-- 	}
	M.prompts = vim.tbl_deep_extend("force", M.prompts, config.prompts)
	if config.default_model ~= nil then
		M.model = config.default_model
	end
end

M.command = "ollama run $model $prompt"

M.exec = function(options)
	serve_ollama()

	local opts = vim.tbl_deep_extend("force", {
		model = M.model,
		command = M.command,
	}, options)

	curr_buffer = vim.fn.bufnr("%")
	local mode = opts.mode or vim.fn.mode()
	if mode == "v" or mode == "V" then
		start_pos = vim.fn.getpos("'<")
		end_pos = vim.fn.getpos("'>")
		end_pos[3] = vim.fn.col("'>") -- in case of `V`, it would be maxcol instead
	else
		local cursor = vim.fn.getpos(".")
		start_pos = cursor
		end_pos = start_pos
	end

	local content = table.concat(
		vim.api.nvim_buf_get_text(curr_buffer, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3] - 1, {}),
		"\n"
	)

	local function substitute_placeholders(input)
		if not input then
			return
		end
		local text = input
		if string.find(text, "%$input") then
			local answer = vim.fn.input("Prompt: ")
			text = string.gsub(text, "%$input", answer)
		end
		text = string.gsub(text, "%$text", content)
		text = string.gsub(text, "%$filetype", vim.bo.filetype)
		return text
	end

	local prompt = vim.fn.shellescape(substitute_placeholders(opts.prompt))
	local extractor = substitute_placeholders(opts.extract)
	local cmd = opts.command
	cmd = string.gsub(cmd, "%$prompt", prompt)
	cmd = string.gsub(cmd, "%$model", opts.model)
	if Result_buffer then
		vim.cmd("bd" .. Result_buffer)
	end
	local win_opts = get_window_options()
	Result_buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(Result_buffer, "filetype", "markdown")

	vim.api.nvim_open_win(Result_buffer, true, win_opts)

	local result_string = ""
	local lines = {}
	local job_id = vim.fn.jobstart(cmd, {
		on_stdout = function(_, data, _)
			result_string = result_string .. table.concat(data, "\n")
			lines = vim.split(result_string, "\n", { true })
			vim.api.nvim_buf_set_lines(Result_buffer, 0, -1, false, lines)
			vim.fn.feedkeys("$")
		end,
		on_exit = function(_, b)
			if b == 0 and opts.replace then
				if extractor then
					local extracted = result_string:match(extractor)
					if not extracted then
						vim.cmd("bd " .. Result_buffer)
						return
					end
					lines = vim.split(extracted, "\n", { true })
				end
				lines = trim_table(lines)
				vim.api.nvim_buf_set_text(
					curr_buffer,
					start_pos[2] - 1,
					start_pos[3] - 1,
					end_pos[2] - 1,
					end_pos[3] - 1,
					lines
				)
				vim.cmd("bd " .. Result_buffer)
			end
		end,
	})
	vim.keymap.set("n", "<esc>", function()
		vim.fn.jobstop(job_id)
	end, { buffer = Result_buffer })

	vim.api.nvim_buf_attach(Result_buffer, false, {
		on_detach = function()
			Result_buffer = nil
		end,
	})
end

-- local function select_prompt(cb)
-- 	local promptKeys = {}
-- 	for key, _ in pairs(M.prompts) do
-- 		table.insert(promptKeys, key)
-- 	end
-- 	vim.ui.select(promptKeys, {
-- 		prompt = "Prompt:",
-- 		format_item = function(item)
-- 			return table.concat(vim.split(item, "_"), " ")
-- 		end,
-- 	}, function(item, idx)
-- 		cb(item)
-- 	end)
-- end

M.model = "codellama:7b"
M.models = {}

vim.api.nvim_create_user_command("GenModel", function(arg)
	serve_ollama()

	-- TODO: if arg.args is empty, show current model
	if next(arg.fargs) == nil then
		print("Current set model: " .. M.model)
	else
		M.model = arg.args
	end
end, {
	nargs = "*",
	complete = function(arg_lead, _, _)
		-- get installed models and cache in M.models
		if next(M.models) == nil then
			local result = vim.fn.system("ollama list")
			for model in result:gmatch("(%w+:%w+)%s+") do
				M.models[model] = model
			end
		end

		return complete_for(arg_lead, M.models)
	end,
})

vim.api.nvim_create_user_command("Gen", function(arg)
	local mode
	if arg.range == 0 then
		mode = "n"
	else
		mode = "v"
	end
	if arg.args ~= "" then
		local prompt = M.prompts[arg.args]
		if not prompt then
			print("Invalid prompt '" .. arg.args .. "'")
			return
		end
		local p = vim.tbl_deep_extend("force", { mode = mode }, prompt)
		require("luadev").print(prompt)
		return M.exec(p)
	end
end, {
	range = true,
	nargs = "*",
	complete = function(arg_lead, _, _)
		return complete_for(arg_lead, M.prompts)
	end,
})

return M
