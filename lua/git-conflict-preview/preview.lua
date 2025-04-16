-- Configuration for our plugin
local config = {
    key_binding = '<leader>gd',
    virtual_text = {
        text = '󱓌 Preview diff',
        hl_group = 'GitConflictPreview',
    },
}

-- Find git conflict markers and store their locations
local function find_conflict_markers(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local markers = {}
    
    for i, line in ipairs(lines) do
        if line:match('^<<<<<<<') then
            markers[#markers + 1] = {
                start = i - 1,
                marker = 'start',
                line = line
            }
        elseif line:match('^=======') then
            markers[#markers + 1] = {
                start = i - 1,
                marker = 'middle',
                line = line
            }
        elseif line:match('^>>>>>>>') then
            markers[#markers + 1] = {
                start = i - 1,
                marker = 'end',
                line = line
            }
        end
    end
    return markers
end

-- Function to strip ANSI color codes from text
local function strip_ansi(str)
    return str:gsub('\27%[[0-9;]*m', '')
end

-- Extract conflict sections and write to temporary files
local function extract_conflict_sections(bufnr, start_line, middle_line, end_line)
    local ours = vim.fn.tempname()
    local theirs = vim.fn.tempname()
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local ours_content = {}
    local theirs_content = {}
    
    -- Debug print the line ranges
    vim.notify(string.format("Extracting our changes from line %d to %d", start_line + 2, middle_line), vim.log.levels.DEBUG)
    vim.notify(string.format("Extracting their changes from line %d to %d", middle_line + 1, end_line), vim.log.levels.DEBUG)
    
    -- Extract "our" changes (between <<<<<<< and =======)
    -- Skip the <<<<<<< marker line
    for i = start_line + 2, middle_line do
        table.insert(ours_content, lines[i])
    end
    
    -- Extract "their" changes (between ======= and >>>>>>>)
    -- Skip the ======= marker line but include up to the >>>>>>> line
    for i = middle_line + 1, end_line do
        table.insert(theirs_content, lines[i])
    end
    
    -- Write content to temp files
    vim.fn.writefile(ours_content, ours)
    vim.fn.writefile(theirs_content, theirs)
    
    return ours, theirs
end

-- Show diff using delta (if available) or builtin diff in a floating window
local function show_diff(ours_file, theirs_file)
    -- Calculate window size - use more screen space
    local width = math.floor(vim.o.columns * 0.9) -- 90% of screen width
    local height = math.floor(vim.o.lines * 0.8) -- 80% of screen height
    
    -- Create a new buffer and set it up as a terminal
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Configure the floating window
    local opts = {
        relative = 'editor',
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' Conflict Diff ',
        title_pos = 'center',
    }
    
    -- Open the floating window
    local win = vim.api.nvim_open_win(buf, true, opts)
    
    -- Check if delta is available
    local has_delta = vim.fn.executable('delta') == 1
    local cmd
    
    if has_delta then
        cmd = string.format('delta %s %s', ours_file, theirs_file)
    else
        cmd = string.format('diff -u %s %s', ours_file, theirs_file)
    end
    
    -- Open terminal in the buffer
    vim.fn.termopen(cmd, {
        on_exit = function()
            -- Make buffer readonly after command finishes
            vim.api.nvim_buf_set_option(buf, 'modifiable', false)
            -- Clean up temp files
            vim.fn.delete(ours_file)
            vim.fn.delete(theirs_file)
        end
    })
    
    -- Enter normal mode
    vim.cmd('startinsert')
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-\\><C-n>', true, true, true), 'n', false)
    
    -- Set up close keybinding
    vim.keymap.set('n', 'q', function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, noremap = true, silent = true })
    
    return win
end

-- Function to setup virtual text for conflict markers
local function setup_virtual_text(bufnr)
    local ns_id = vim.api.nvim_create_namespace('git_conflict_preview')
    local markers = find_conflict_markers(bufnr)
    
    -- Clear existing virtual text
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    
    -- Create highlight group if it doesn't exist
    pcall(vim.api.nvim_set_hl, 0, config.virtual_text.hl_group, { fg = '#89b4fa', italic = true })
    
    -- Add virtual text to conflict start markers
    for i = 1, #markers do
        if markers[i].marker == 'start' then
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, markers[i].start, 0, {
                virt_text = {{config.virtual_text.text, config.virtual_text.hl_group}},
                virt_text_pos = 'eol',
            })
        end
    end
end

-- Function to handle diff preview request
local function show_conflict_diff()
    local bufnr = vim.api.nvim_get_current_buf()
    local markers = find_conflict_markers(bufnr)
    local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
    
    -- Find the nearest conflict section
    local start_marker, middle_marker, end_marker
    for i = 1, #markers do
        if markers[i].marker == 'start' and markers[i].start <= current_line then
            start_marker = markers[i]
            if i + 1 <= #markers and markers[i + 1].marker == 'middle' then
                middle_marker = markers[i + 1]
            end
            if i + 2 <= #markers and markers[i + 2].marker == 'end' then
                end_marker = markers[i + 2]
            end
        end
    end
    
    if start_marker and middle_marker and end_marker then
        local ours_file, theirs_file = extract_conflict_sections(
            bufnr,
            start_marker.start,
            middle_marker.start,
            end_marker.start
        )
        show_diff(ours_file, theirs_file)
    else
        -- Notify user if no conflict section is found
        vim.notify("No conflict section found at cursor position", vim.log.levels.WARN)
    end
end

-- Return setup function directly
return function(opts)
    -- Merge user config with defaults
    config = vim.tbl_deep_extend('force', config, opts or {})
    
    -- Create autocmd group
    local group = vim.api.nvim_create_augroup('GitConflictPreview', { clear = true })
    
    -- Set up autocommands
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, {
        group = group,
        callback = function(ev)
            -- Only set up virtual text if file has conflict markers
            local has_conflicts = #find_conflict_markers(ev.buf) > 0
            if has_conflicts then
                setup_virtual_text(ev.buf)
            end
        end,
    })
    
    -- Set up keymapping
    vim.keymap.set('n', config.key_binding, show_conflict_diff, {
        desc = 'Show git conflict diff preview',
        silent = true,
    })
end