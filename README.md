# ollama.nvim

Generate text using LLMs with customizable prompts

## Requires

- [Ollama](https://ollama.ai/)
- Curl

## Usage

Use command `Ollama` to generate text based on predefined and customizable prompts. If Ollama is not running, it is automatically started.

Example key maps:

```lua
vim.keymap.set('v', '<leader>]', ':Ollama<CR>')
vim.keymap.set('n', '<leader>]', ':Ollama<CR>')
```

You can also directly invoke it with a [predefined](./lua/ollama/prompts.lua) or a custom prompt:

```lua
vim.keymap.set('v', '<leader>]', ':Ollama Enhance_Grammar_Spelling<CR>')
```

Use command `OllamaModel` to show locally available models and change the default model for this session.


## Setup with lazy.nvim


```lua
{
    "sgelb/ollama.nvim"
	cmd = { "Ollama", "OllamaModel" },
	dependencies = {
		{ "nvim-lua/plenary.nvim" },
	opts = {
		default_model = "codellama:7b",
        -- custom prompts
		prompts = {
			UnitTest = {
				prompt = "Write unit tests for the following code. Output the result in the format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
				replace = false,
				extract = "```$filetype\n(.-)```",
			},
		},
	},
}
```

## Options

Predefined prompts are available th`require('ollama').prompts`, you can enhance or modify them.

Example:
```lua
require('ollama').prompts['Elaborate_Text'] = {
  prompt = "Elaborate the following text:\n$text",
  replace = true
}
```

You can use the following properties per prompt:

- `prompt`: Prompt which can use the following placeholders:
   - `$text`: Visually selected text
   - `$filetype`: Filetype of the buffer (e.g. `javascript`)
   - `$input`: Additional user input
- `replace`: `true` if the selected text shall be replaced with the generated output
- `extract`: Regular expression used to extract the generated result

You can change the model with

```lua
require('ollama').model = 'your_model' -- default 'mistal:instruct'
```

Here are all [available models](https://ollama.ai/library).

You can also change the complete command with

```lua
require('ollama').command = 'your command' -- default 'ollama run $model $prompt'
```

You can use the placeholders `$model` and `$prompt`.
