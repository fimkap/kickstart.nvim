local M = {}

-- Function to mark task as done and move to end of list
function M.mark_task_done()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local current_line = vim.api.nvim_win_get_cursor(0)[1] -- Get current line number

    if current_line > #lines then return end

    local task = lines[current_line]
    if not task:match("^%[ %] ") then return end -- Ensure it's a task

    -- Mark task as done
    local done_task = task:gsub("^%[ %]", "[v]")
    table.remove(lines, current_line) -- Remove from current position
    table.insert(lines, done_task) -- Append to end

    -- Update buffer
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

-- Create a command to trigger task completion
vim.api.nvim_create_user_command("TaskDone", M.mark_task_done, {})

return M
