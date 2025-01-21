local M = {}
local api = vim.api

M.namespace = vim.api.nvim_create_namespace("ExecuteParagraph")

function M.parse_stderr(lines)
  local headers = {}
  for _, line in ipairs(lines) do
    if line:match("^%< ") then
      if line:match(":") then
        local split = vim.split(line, ":")
        local name, value = split[1], split[2]
        name = vim.trim(name:sub(3))
        value = vim.trim(value)
        headers[name] = value
      end
      local _, code, message = vim.split(line, " ")
      headers.code = code
      headers.message = message
    end
  end
  return headers
end

--- @param result vim.SystemCompleted
function M.on_exit(result)
  local stdout_buffer = api.nvim_create_buf(false, true)
  local stderr_buffer = api.nvim_create_buf(false, true)
  local stderr = M.parse_stderr(vim.split(result.stderr or "", "\n"))
  local stdout = vim.split(result.stdout or "", "\n")
  api.nvim_buf_set_lines(stderr_buffer, -2, -1, false, vim.split(vim.json.encode(stderr), "\n"))
  vim.bo[stderr_buffer].ft = "json"
  if result.code ~= 0 then
    api.nvim_buf_set_lines(
      stderr_buffer,
      -2,
      -1,
      false,
      { "Command exited with code " .. result.code }
    )
  end
  api.nvim_buf_set_lines(stdout_buffer, -2, -1, false, stdout)
  local content_type = stderr["Content-Type"] or ""
  if content_type:match("application/json") then
    vim.bo[stdout_buffer].ft = "json"
  elseif content_type:match("application/html") then
    vim.bo[stdout_buffer].ft = "html"
  end
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format({
      bufnr = stdout_buffer,
      async = true,
    })
    conform.format({
      bufnr = stderr_buffer,
      async = true,
    })
  end
  api.nvim_open_win(stderr_buffer, true, {
    split = "right",
  })
  api.nvim_open_win(stdout_buffer, true, {
    split = "above",
  })
end

function M.execute_paragraph(window)
  window = window or api.nvim_get_current_win()
  local buffer = api.nvim_win_get_buf(window)
  local line_index = api.nvim_win_get_cursor(window)[1]
  local line_count = api.nvim_buf_line_count(buffer)
  local start_index = line_index - 1
  local end_index = line_index + 2
  while start_index > 0 do
    local line = api.nvim_buf_get_lines(buffer, start_index, start_index + 1, false)[1]
    if line == nil or line:match("^%s*$") then
      break
    end
    start_index = start_index - 1
  end
  while end_index <= line_count do
    local line = api.nvim_buf_get_lines(buffer, end_index, end_index + 1, false)[1]
    if line == nil or line:match("^%s*$") then
      break
    end
    end_index = end_index + 1
  end
  vim.highlight.range(buffer, M.namespace, "IncSearch", { start_index, 0 }, { end_index, -1 })
  vim.defer_fn(function()
    api.nvim_buf_clear_highlight(buffer, M.namespace, start_index, end_index)
  end, 100)
  local lines = api.nvim_buf_get_lines(buffer, start_index, end_index, false)
  -- M.on_exit({
  --   code = 0,
  --   stdout = vim.iter(lines):join("\n"),
  -- })
  vim.system({ "sh" }, {
    stdin = lines,
    text = true,
  }, vim.schedule_wrap(M.on_exit))
end

return M
