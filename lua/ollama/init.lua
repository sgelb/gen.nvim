local api = require("ollama.api")
local M = {}

M.prompts = require("ollama.prompts")
M.models = {}

local curr_buffer = nil
local start_pos = nil
local end_pos = nil

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

M.setup = function(config)
	-- Example opts for lazy.nvim
	-- opts = {
	-- 	default_model = "codellama:7b",
	-- 	prompts = {
	-- 		Test = { prompt = "Count from 10 downward to 5", replace = false },
	-- 	}

	api.serve_ollama()
	M.prompts = vim.tbl_deep_extend("force", M.prompts, config.prompts)
	if config.default_model ~= nil then
		M.model = config.default_model
	end
	-- FIXME: remove hardcoded 1000ms and wait until api is up and running
	os.execute("sleep 1")
	M.models = api.get_models()
end

M.command = "ollama run $model $prompt"

M.exec = function(options)
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
	Result_buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(Result_buffer, "filetype", "markdown")

	vim.api.nvim_open_win(Result_buffer, true, get_window_options())

	local on_stdout = function(streamed_result)
		vim.api.nvim_buf_set_lines(Result_buffer, 0, -1, false, vim.split(streamed_result, "\n", { true }))
		vim.api.nvim_win_call(Result_buffer, function()
			vim.fn.feedkeys("$")
		end)
	end

	local on_exit = function(context)
		Context = context
	end

	Job = api.generate({
		model = opts.model,
		prompt = prompt,
		on_stdout = on_stdout,
		on_exit = on_exit,
		context = Context,
	})

	vim.keymap.set("n", "<esc>", function()
		if Job then
			Job:shutdown(0, 3)
		end
	end, { buffer = Result_buffer })

	vim.api.nvim_buf_attach(Result_buffer, false, {
		on_detach = function()
			Result_buffer = nil
		end,
	})
end

M.model = "codellama:7b"

vim.api.nvim_create_user_command("OllamaModel", function(arg)
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
			M.models = api.get_models()
		end

		return complete_for(arg_lead, M.models)
	end,
})

vim.api.nvim_create_user_command("Ollama", function(arg)
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

		if prompt["model"] and M.models[prompt["model"]] == nil then
			print("Invalid model '" .. prompt["model"] .. "' in prompt '" .. arg.args .. "'")
			return
		end
		local p = vim.tbl_deep_extend("force", { mode = mode }, prompt)
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
