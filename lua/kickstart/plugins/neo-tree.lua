-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim
--
return {
  'nvim-neo-tree/neo-tree.nvim',
  branch = 'v3.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
    -- 'saifulapm/neotree-file-nesting-config', -- add plugin as dependency. no need any other config or setup call
  },
  cmd = 'Neotree',
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  opts = {
    -- recommanded config for better UI
    hide_root_node = true,
    retain_hidden_root_indent = true,
    filesystem = {
      filtered_items = {
        show_hidden_count = false,
        never_show = {
          '.DS_Store',
        },
      },
    },
    default_component_configs = {
      indent = {
        with_expanders = true,
        expander_collapsed = '',
        expander_expanded = '',
        with_markers = false,
      },
    },
    -- others config
  },
  -- config = function(_, opts)
  --   vim.schedule(function()
  --     -- Unlink NeoTreeNormalNC from NormalNC
  --     vim.cmd 'highlight! link NeoTreeNormalNC NONE'
  --
  --     -- Set the background color for NeoTreeNormalNC
  --     vim.api.nvim_set_hl(0, 'NeoTreeNormalNC', { bg = '#181919' })
  --   end)
  -- end,
}
