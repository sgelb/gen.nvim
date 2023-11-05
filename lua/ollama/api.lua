local M = {}
local curl = require("plenary.curl")

local create_callback = function(on_stdout, on_exit)
  local result_string = ""

	return function(data)
		if data == nil then
			return
		end

		local response = vim.json.decode(data)

		if response == nil then
			return
		end

    -- cancel job if floating window was closed
    if not vim.api.nvim_win_is_valid(Float_Win) then
      Job:shutdown(0, 3)
      return
    end

		if response["done"] == false then
			result_string = result_string .. response["response"]
			on_stdout(result_string .. " …")
		else
      -- remove … from buffer when done
      local last_line = string.gsub(table.remove(vim.api.nvim_buf_get_lines(Result_buffer, -2, -1, false), 1), " …", "")
      vim.api.nvim_buf_set_lines(Result_buffer, -2, -1, false, {last_line})
      on_exit(response["context"])
		end
	end
end

M.generate = function(arg)
	local payload = { model = arg.model, prompt = arg.prompt, context = arg.context, stream = true }
	local callback = create_callback(arg.on_stdout, arg.on_exit)

	local job = curl.post({
		url = "http://localhost:11434/api/generate",
		raw = { "--no-buffer" }, -- immediately return stream response
		body = vim.fn.json_encode(payload),
		headers = { content_type = "application/json" },
		stream = vim.schedule_wrap(function(_, data)
			callback(data)
		end),
	})
	return job
end

M.get_models = function()
	local body = vim.json.decode(curl.get({
		url = "http://localhost:11434/api/tags",
  }).body)

  if body == nil then
    return {}
  end

  local models = {}
  for _, model in ipairs(body["models"]) do
    models[model["name"]] = model["name"]
  end
  return models
end

M.serve_ollama = function()
	local ollama_is_not_running = vim.fn.system('pgrep --full --exact "ollama serve"') == ""
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

return M
