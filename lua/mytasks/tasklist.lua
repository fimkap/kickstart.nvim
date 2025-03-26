local M = {}

-- Function to mark task as done and move to end of list
function M.mark_task_done()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local current_line = vim.api.nvim_win_get_cursor(0)[1] -- Get current line number

    if current_line > #lines then return end

    local task = lines[current_line]
    if not task:match("^󰄮 ") then return end -- Ensure it's a task

    -- Mark task as done
    local done_task = task:gsub("^󰄮 ", "󰄲 ")

    vim.api.nvim_buf_set_lines(bufnr, current_line - 1, current_line, false, {done_task})

    -- Delay before moving the task to the end
    vim.defer_fn(function()
        local updated_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        table.remove(updated_lines, current_line) -- Remove from current position
        table.insert(updated_lines, done_task) -- Append to end
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, updated_lines)
    end, 700) -- 500ms delay
end

-- Function to open tasks.md in a floating window
function M.open_task_list()
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local opts = {
        relative = "editor",
        title = "TASKS",
        title_pos = "center",
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = "minimal",
        border = { "╔", "═" ,"╗", "║", "╝", "═", "╚", "║" },
    }
    vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_command("edit ~/tasks.md")
end

-- Create user commands
vim.api.nvim_create_user_command("TaskDone", M.mark_task_done, {})
vim.api.nvim_create_user_command("OpenTasks", M.open_task_list, {})

return M
