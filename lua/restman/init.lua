local M = {}
local api = vim.api

M.namespace = vim.api.nvim_create_namespace("ExecuteParagraph")

function M.parse_stderr(lines)
  local headers = {}
  local out_lines = {}
  for _, line in ipairs(lines) do
    local match = line:match("^%< (.*)")
    if match then
      match = vim.trim(match)
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
      if match:len() > 0 then
        table.insert(out_lines, match)
      end
    end
  end
  return headers, out_lines
end

local function create_scratch_buffer()
  local buffer = api.nvim_create_buf(false, true)
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].bufhidden = "wipe"
  return buffer
end

--- @param result vim.SystemCompleted
function M.on_exit(result)
  local stdout_buffer = create_scratch_buffer()
  local stderr_buffer = create_scratch_buffer()
  local stderr_json, stderr_lines = M.parse_stderr(vim.split(result.stderr or "", "\n"))
  local stdout = vim.split(result.stdout or "", "\n")
  api.nvim_buf_set_lines(stderr_buffer, -2, -1, false, stderr_lines)
  vim.bo[stderr_buffer].ft = "http"
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

  local content_type = stderr_json["Content-Type"] or ""
  local type = content_type:match("^application/(%w+)")
  if type then
    vim.bo[stdout_buffer].ft = type
  end

  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format({
      bufnr = stdout_buffer,
      async = true,
    })
  end

  local stdout_window = api.nvim_open_win(stdout_buffer, true, {
    split = "right",
  })
  local height = api.nvim_buf_line_count(stderr_buffer)
  local stderr_window = api.nvim_open_win(stderr_buffer, false, {
    split = "below",
    height = height,
  })

  local function delete_buffers()
    if api.nvim_buf_is_valid(stderr_buffer) then
      api.nvim_buf_delete(stderr_buffer, { force = true })
    end
    if api.nvim_buf_is_valid(stdout_buffer) then
      api.nvim_buf_delete(stdout_buffer, { force = true })
    end
  end

  api.nvim_create_autocmd({ "WinResized", "WinScrolled" }, {
    callback = function()
      if not api.nvim_buf_is_valid(stderr_buffer) then
        return
      end
      if not api.nvim_win_is_valid(stderr_window) then
        return
      end
      api.nvim_win_set_height(stderr_window, api.nvim_buf_line_count(stderr_buffer))
    end,
  })

  api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(stdout_window),
    callback = delete_buffers,
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
    api.nvim_buf_clear_namespace(buffer, M.namespace, start_index, end_index)
  end, 100)
  local lines = api.nvim_buf_get_lines(buffer, start_index, end_index, false)
  lines = vim.tbl_filter(
    function(line)
      return line ~= nil and line:match("^%s*$") == nil
    end,
    vim.tbl_map(function(line)
      local stripped = line:match("^[^#]*")
      if line:match("\\%s*$") and not stripped:match("\\%s*$") then
        return stripped .. "\\"
      end
      return stripped
    end, lines)
  )
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
