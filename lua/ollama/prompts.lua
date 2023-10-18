-- You can use the following properties per prompt:
-- "prompt" can use the following placeholders:
--   $text: Visually selected text
--   $filetype: Filetype of the buffer (e.g. javascript)
--   $input: Additional user input
--   $register: Value of the unnamed register (yanked text)
-- replace: true if the selected text shall be replaced with the generated output
-- extract: Regular expression used to extract the generated result
-- model: The model to use for this prompt


return {
	Generate = { prompt = "$input", replace = true },
	Ask = { prompt = "Regarding the following text, $input:\n$text" },
	Summarize = { prompt = "Summarize the following text:\n$text" },
	-- Change = {
	-- 	prompt = "Change the following text, $input:\n$text",
	-- 	replace = true,
	-- },
	-- Enhance_Grammar_Spelling = {
	-- 	prompt = "Modify the following text to improve grammar and spelling:\n$text",
	-- 	replace = true,
	-- },
	-- Enhance_Wording = {
	-- 	prompt = "Modify the following text to use better wording:\n$text",
	-- 	replace = true,
	-- },
	-- Make_Concise = {
	-- 	prompt = "Modify the following text to make it as simple and concise as possible:\n$text",
	-- 	replace = true,
	-- },
	-- Make_List = {
	-- 	prompt = "Render the following text as a markdown list:\n$text",
	-- 	replace = true,
	-- },
	-- Make_Table = {
	-- 	prompt = "Render the following text as a markdown table:\n$text",
	-- 	replace = true,
	-- },
	Comment = {
		prompt = "Take the following code, $input, and add a concise and useful KDoc comment to it. Output the result only in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
	},
	Review_Code = {
		prompt = "Review the following code and make concise suggestions:\n```$filetype\n$text\n```",
	},
	Enhance_Code = {
		prompt = "Enhance the following code, output the result only in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
		replace = true,
		extract = "```$filetype\n(.-)```",
	},
	Change_Code = {
		prompt = "Regarding the following code, $input, output the result only in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
		replace = true,
		extract = "```$filetype\n(.-)```",
	},
}
