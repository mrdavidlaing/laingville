local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Show startup notification to confirm config is loading
wezterm.on('gui-startup', function(cmd)
  wezterm.log_info('Loading custom WezTerm config v4.0 - tmux-aligned version')
end)

-- Terminal optimizations (matching tmux settings)
config.check_for_updates = false
config.automatically_reload_config = true
config.exit_behavior = 'Close'

-- Font configuration (matching Alacritty)
config.font = wezterm.font('JetBrains Mono')
config.font_size = 12.0

-- Window configuration (matching tmux history)
config.window_padding = {
  left = 12,
  right = 12,
  top = 6,
  bottom = 6,
}
config.window_decorations = "RESIZE"
config.scrollback_lines = 50000

-- Transparency settings (simplified for compatibility)
config.window_background_opacity = 0.95  -- Constant subtle transparency

-- Mouse support (matching tmux mouse mode)
config.enable_scroll_bar = false
config.mouse_bindings = {
  -- Single click - complete selection and copy
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  -- Double click - select word and copy
  {
    event = { Up = { streak = 2, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      window:perform_action(wezterm.action.SelectTextAtMouseCursor 'Word', pane)
      window:perform_action(wezterm.action.CopyTo 'ClipboardAndPrimarySelection', pane)
      -- Clear selection after a brief delay to show what was copied
      wezterm.time.call_after(0.3, function()
        window:perform_action(wezterm.action.ClearSelection, pane)
      end)
    end),
  },
  -- Triple click - select line and copy
  {
    event = { Up = { streak = 3, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      window:perform_action(wezterm.action.SelectTextAtMouseCursor 'Line', pane)
      window:perform_action(wezterm.action.CopyTo 'ClipboardAndPrimarySelection', pane)
      -- Clear selection after a brief delay to show what was copied
      wezterm.time.call_after(0.3, function()
        window:perform_action(wezterm.action.ClearSelection, pane)
      end)
    end),
  },
}

-- Theme configuration (matching Alacritty Solarized Dark)
config.colors = {
  foreground = '#eee8d5',
  background = '#002b36',
  
  cursor_bg = '#839496',
  cursor_fg = '#002b36',
  cursor_border = '#839496',
  
  selection_fg = '#002b36',  -- Dark text for contrast
  selection_bg = '#ff8800',  -- Orange background (matching tmux orange theme)
  
  ansi = {
    '#073642', '#dc322f', '#859900', '#b58900',
    '#268bd2', '#d33682', '#2aa198', '#eee8d5',
  },
  
  brights = {
    '#586e75', '#cb4b16', '#586e75', '#657b83',
    '#839496', '#6c71c4', '#93a1a1', '#fdf6e3',
  },
}

-- Tab bar configuration (matching tmux base-index 1)
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.tab_and_split_indices_are_zero_based = false
config.colors.tab_bar = {
  background = '#2d2d2d',
  active_tab = {
    bg_color = '#2d2d2d',
    fg_color = '#ffffff',
    intensity = 'Bold',
  },
  inactive_tab = {
    bg_color = '#2d2d2d',
    fg_color = '#808080',
  },
  inactive_tab_hover = {
    bg_color = '#3d3d3d',
    fg_color = '#909090',
  },
}

-- Inactive pane dimming (matching tmux window-style)
config.inactive_pane_hsb = {
  saturation = 0.8,
  brightness = 0.6,
}

-- Enable key debugging
config.debug_key_events = true


-- Status bar configuration (matching tmux status bar)
config.status_update_interval = 1000
config.show_tab_index_in_tab_bar = true
config.show_tabs_in_tab_bar = true

-- Global variables for status bar
local pomodoro_state = {
  active = false,
  work_time = 25 * 60,  -- 25 minutes in seconds
  break_time = 5 * 60,  -- 5 minutes in seconds
  current_time = 25 * 60,
  is_break = false,
  start_time = nil
}

-- Helper function to get git info
local function get_git_info(cwd)
  if not cwd then return nil end
  
  local success, stdout, stderr = wezterm.run_child_process({
    'git', '-C', cwd.file_path, 'branch', '--show-current'
  })
  
  if not success then return nil end
  
  local branch = stdout:gsub('\n', '')
  if branch == '' then return nil end
  
  -- Check if repo is dirty
  local dirty_success, dirty_stdout = wezterm.run_child_process({
    'git', '-C', cwd.file_path, 'status', '--porcelain'
  })
  
  local status_icon = '✓'
  if dirty_success and dirty_stdout ~= '' then
    status_icon = '✗'
  end
  
  return 'git:' .. branch .. ' ' .. status_icon
end

-- Helper function to format time
local function format_time(seconds)
  local mins = math.floor(seconds / 60)
  local secs = seconds % 60
  return string.format('%d:%02d', mins, secs)
end

-- Custom status bar with git, pomodoro, date/time, and mode info
wezterm.on('update-status', function(window, pane)
  local hostname = wezterm.hostname() or 'unknown'
  local cwd = pane:get_current_working_dir()
  
  -- Update pomodoro timer if active
  local pomodoro_display = ''
  if pomodoro_state.active and pomodoro_state.start_time then
    local elapsed = os.time() - pomodoro_state.start_time
    local remaining = pomodoro_state.current_time - elapsed
    
    if remaining <= 0 then
      -- Timer finished
      pomodoro_state.active = false
      pomodoro_display = '⏱ DONE!'
      
      -- Show notification when timer completes
      if pomodoro_state.is_break then
        window:toast_notification('WezTerm Pomodoro', '☕ Break time finished! Ready to work?', nil, 5000)
      else
        window:toast_notification('WezTerm Pomodoro', '🍅 Work session complete! Time for a break?', nil, 5000)
      end
    else
      local prefix = pomodoro_state.is_break and '⏱ Break ' or '⏱ '
      pomodoro_display = prefix .. format_time(remaining)
    end
  else
    pomodoro_display = '⏱ --:--'
  end
  
  -- Date and time display
  local date_time = os.date('%Y-%m-%d %H:%M')
  
  -- Mode indicator (simplified for now)
  local mode_info = '[NORMAL]'
  local key_table = window:active_key_table()
  if key_table then
    mode_info = '[' .. string.upper(key_table) .. ']'
  end
  
  -- Status left (just hostname)
  local left_status = wezterm.format {
    { Foreground = { Color = '#ff8800' } },
    { Text = ' ' .. hostname .. ' ' },
  }
  
  -- Status right (mode, pomodoro, date/time)
  local right_status = wezterm.format {
    { Foreground = { Color = '#2d2d2d' } },
    { Background = { Color = '#515151' } },
    { Text = '' },
    { Foreground = { Color = '#232323' } },
    { Background = { Color = '#515151' } },
    { Text = ' ' .. mode_info .. ' ' },
    { Background = { Color = '#686868' } },
    { Text = '' },
    { Background = { Color = '#686868' } },
    { Text = ' ' .. pomodoro_display .. ' ' },
    { Background = { Color = '#7a7a7a' } },
    { Text = '' },
    { Background = { Color = '#7a7a7a' } },
    { Text = ' ' .. date_time .. ' ' },
  }
  
  window:set_right_status(right_status)
  window:set_left_status(left_status)
end)

-- Custom tab title formatting (matching tmux window-status-format)
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local background = '#2d2d2d'
  local foreground = '#808080'
  
  if tab.is_active then
    background = '#2d2d2d'
    foreground = '#ffffff'
  end
  
  local title = tab.active_pane.title
  if title == '' then
    title = tab.active_pane.foreground_process_name or 'shell'
  end
  
  -- Trim title if too long
  if #title > 35 then
    title = title:sub(1, 32) .. '...'
  end
  
  return {
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = ' ' .. tab.tab_index + 1 .. ':' .. title .. ' ' },
  }
end)

-- Terminal type configuration (using standard compatibility)
config.term = 'xterm-256color'

-- Enable true color support for SSH + tmux control mode
config.set_environment_variables = {
  COLORTERM = 'truecolor',
  TERM = 'xterm-256color',
}

-- Performance settings (matching tmux optimizations)
config.max_fps = 60
config.animation_fps = 1


-- Launch menu configuration (Windows shell selection)
config.launch_menu = {
  {
    label = 'WSL Arch Linux',
    args = { 'wsl.exe', '-d', 'archlinux' },
  },
  {
    label = 'PowerShell 7+',
    args = { 'pwsh.exe', '-NoLogo' },
  },
  {
    label = 'Git Bash',
    args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '-i', '-l' },
  },
  {
    label = 'Command Prompt',
    args = { 'cmd.exe' },
  },
}

-- Leader key configuration
config.leader = { key = 'b', mods = 'CTRL', timeout_milliseconds = 2000 }

-- Key bindings
config.keys = {
  -- Split panes using ' (for Windows compatibility) and | (matching tmux)
  {
    key = "'",
    mods = 'LEADER',
    action = wezterm.action.SplitPane {
      direction = 'Right',
      top_level = true,
    },
  },
  {
    key = '|',
    mods = 'LEADER',
    action = wezterm.action.SplitPane {
      direction = 'Right',
      top_level = true,
    },
  },
  {
    key = '-',
    mods = 'LEADER',
    action = wezterm.action.SplitPane {
      direction = 'Down',
      top_level = true,
    },
  },
  
  -- Split with shell selection menu
  {
    key = '"',
    mods = 'LEADER',
    action = wezterm.action.ShowLauncherArgs { 
      flags = 'LAUNCH_MENU_ITEMS',
      title = 'Select shell for horizontal split',
    },
  },
  {
    key = '%',
    mods = 'LEADER',
    action = wezterm.action.ShowLauncherArgs { 
      flags = 'LAUNCH_MENU_ITEMS',
      title = 'Select shell for vertical split',
    },
  },
  
  -- New tab/window in current directory (matching tmux.conf line 39)
  {
    key = 'c',
    mods = 'LEADER',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  
  -- Launch menu for new tab with shell selection
  {
    key = 'C',
    mods = 'LEADER',
    action = wezterm.action.ShowLauncherArgs { flags = 'LAUNCH_MENU_ITEMS|TABS' },
  },
  
  -- Paste with prefix + p (matching tmux.conf line 13)
  {
    key = 'p',
    mods = 'LEADER',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  
  -- Reload config with prefix + r (matching tmux.conf line 16)
  {
    key = 'r',
    mods = 'LEADER',
    action = wezterm.action.ReloadConfiguration,
  },
  
  -- Switch panes using vim-style hjkl with leader (matching vim navigation)
  {
    key = 'h',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'l',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  {
    key = 'k',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'j',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Down',
  },
  
  -- Enter resize mode with vim-style Shift+hjkl
  {
    key = 'H',
    mods = 'LEADER',
    action = wezterm.action.Multiple {
      wezterm.action.AdjustPaneSize { 'Left', 2 },
      wezterm.action.ActivateKeyTable {
        name = 'resize_pane',
        one_shot = false,
        timeout_milliseconds = 3000,
      },
    },
  },
  {
    key = 'L',
    mods = 'LEADER',
    action = wezterm.action.Multiple {
      wezterm.action.AdjustPaneSize { 'Right', 2 },
      wezterm.action.ActivateKeyTable {
        name = 'resize_pane',
        one_shot = false,
        timeout_milliseconds = 3000,
      },
    },
  },
  {
    key = 'K',
    mods = 'LEADER',
    action = wezterm.action.Multiple {
      wezterm.action.AdjustPaneSize { 'Up', 2 },
      wezterm.action.ActivateKeyTable {
        name = 'resize_pane',
        one_shot = false,
        timeout_milliseconds = 3000,
      },
    },
  },
  {
    key = 'J',
    mods = 'LEADER',
    action = wezterm.action.Multiple {
      wezterm.action.AdjustPaneSize { 'Down', 2 },
      wezterm.action.ActivateKeyTable {
        name = 'resize_pane',
        one_shot = false,
        timeout_milliseconds = 3000,
      },
    },
  },
  
  -- Tab navigation with number keys (1-9) like tmux
  {
    key = '1',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(0),
  },
  {
    key = '2',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(1),
  },
  {
    key = '3',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(2),
  },
  {
    key = '4',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(3),
  },
  {
    key = '5',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(4),
  },
  {
    key = '6',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(5),
  },
  {
    key = '7',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(6),
  },
  {
    key = '8',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(7),
  },
  {
    key = '9',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(8),
  },
  
  -- Show pane labels (matching tmux display-panes)
  {
    key = 'q',
    mods = 'LEADER',
    action = wezterm.action.PaneSelect { alphabet = "1234567890", mode = "Activate" },
  },
  
  -- Copy mode with vi-style bindings (matching tmux copy-mode-vi)
  {
    key = '[',
    mods = 'LEADER',
    action = wezterm.action.ActivateCopyMode,
  },
  
  -- Toggle synchronize panes (useful for multi-pane operations)
  {
    key = 's',
    mods = 'LEADER',
    action = wezterm.action.Multiple {
      wezterm.action.SendKey { key = 'Escape' },
      wezterm.action.TogglePaneZoomState,
    },
  },
  
  -- Pomodoro timer controls
  {
    key = 'P',
    mods = 'LEADER',
    action = wezterm.action_callback(function(window, pane)
      -- Start work timer
      pomodoro_state.active = true
      pomodoro_state.is_break = false
      pomodoro_state.current_time = pomodoro_state.work_time
      pomodoro_state.start_time = os.time()
    end),
  },
  {
    key = 'B',
    mods = 'LEADER',
    action = wezterm.action_callback(function(window, pane)
      -- Start break timer
      pomodoro_state.active = true
      pomodoro_state.is_break = true
      pomodoro_state.current_time = pomodoro_state.break_time
      pomodoro_state.start_time = os.time()
    end),
  },
  {
    key = 'S',
    mods = 'LEADER',
    action = wezterm.action_callback(function(window, pane)
      -- Stop timer
      pomodoro_state.active = false
      pomodoro_state.start_time = nil
    end),
  },
  
  -- Launcher menu access (changed to 'm' for menu)
  {
    key = 'm',
    mods = 'LEADER',
    action = wezterm.action.ShowLauncherArgs { flags = 'LAUNCH_MENU_ITEMS|TABS' },
  },
  
  -- Standard copy/paste shortcuts
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.Multiple {
      wezterm.action.CopyTo 'ClipboardAndPrimarySelection',
      wezterm.action.ClearSelection,
    },
  },
  {
    key = 'v',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  
  -- Help popup (changed from 'h' to avoid vim navigation conflict)
  {
    key = '/',
    mods = 'LEADER',
    action = wezterm.action.SplitPane {
      direction = 'Right',
      size = { Percent = 50 },
      command = {
        args = { 'pwsh.exe', '-Command', 'Write-Host "=== WEZTERM KEY BINDINGS ===" -ForegroundColor Yellow; Write-Host ""; Write-Host "Leader: Ctrl+b" -ForegroundColor Green; Write-Host ""; Write-Host "-- PANES --" -ForegroundColor Cyan; Write-Host "\' or |  : Split horizontal"; Write-Host "-       : Split vertical"; Write-Host "h/j/k/l : Navigate panes (vim-style)"; Write-Host "H/J/K/L : Enter resize mode (then hjkl/HJKL)"; Write-Host "q       : Show pane numbers"; Write-Host ""; Write-Host "-- TABS --" -ForegroundColor Cyan; Write-Host "c       : New tab"; Write-Host "C       : New tab (shell menu)"; Write-Host "1-9     : Go to tab N"; Write-Host ""; Write-Host "-- TOOLS --" -ForegroundColor Cyan; Write-Host "m       : Launch shell menu"; Write-Host "r       : Reload config"; Write-Host "[       : Enter copy mode"; Write-Host "p       : Paste"; Write-Host ""; Write-Host "-- COPY/PASTE --" -ForegroundColor Cyan; Write-Host "Ctrl+Shift+C: Copy"; Write-Host "Ctrl+Shift+V: Paste"; Write-Host "Double-click: Copy word"; Write-Host "Triple-click: Copy line"; Write-Host ""; Write-Host "-- POMODORO --" -ForegroundColor Cyan; Write-Host "P       : Start work timer (25 min)"; Write-Host "B       : Start break (5 min)"; Write-Host "S       : Stop timer"; Write-Host ""; Write-Host "-- HELP --" -ForegroundColor Cyan; Write-Host "/       : Show this help"; Write-Host ""; Write-Host "[Press Enter to close]" -ForegroundColor Red; Read-Host' },
      },
    },
  },
}

-- Copy mode and resize mode key bindings (enhanced vi-style like tmux)
config.key_tables = {
  resize_pane = {
    -- Resize with hjkl (no modifiers needed in resize mode)
    {
      key = 'h',
      action = wezterm.action.AdjustPaneSize { 'Left', 2 },
    },
    {
      key = 'l',
      action = wezterm.action.AdjustPaneSize { 'Right', 2 },
    },
    {
      key = 'k',
      action = wezterm.action.AdjustPaneSize { 'Up', 2 },
    },
    {
      key = 'j',
      action = wezterm.action.AdjustPaneSize { 'Down', 2 },
    },
    -- Capital letters for bigger adjustments
    {
      key = 'H',
      action = wezterm.action.AdjustPaneSize { 'Left', 5 },
    },
    {
      key = 'L',
      action = wezterm.action.AdjustPaneSize { 'Right', 5 },
    },
    {
      key = 'K',
      action = wezterm.action.AdjustPaneSize { 'Up', 5 },
    },
    {
      key = 'J',
      action = wezterm.action.AdjustPaneSize { 'Down', 5 },
    },
    -- Exit resize mode
    {
      key = 'Escape',
      action = 'PopKeyTable',
    },
    {
      key = 'Enter',
      action = 'PopKeyTable',
    },
    {
      key = 'q',
      action = 'PopKeyTable',
    },
  },
  copy_mode = {
    -- Vi navigation
    {
      key = 'h',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveLeft',
    },
    {
      key = 'j',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveDown',
    },
    {
      key = 'k',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveUp',
    },
    {
      key = 'l',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveRight',
    },
    -- Word movement
    {
      key = 'w',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveForwardWord',
    },
    {
      key = 'b',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveBackwardWord',
    },
    {
      key = 'e',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveForwardWordEnd',
    },
    -- Line movement
    {
      key = '0',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveToStartOfLine',
    },
    {
      key = '^',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveToStartOfLineContent',
    },
    {
      key = '$',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveToEndOfLineContent',
    },
    -- Page movement
    {
      key = 'g',
      mods = 'CTRL',
      action = wezterm.action.CopyMode 'MoveToScrollbackTop',
    },
    {
      key = 'G',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'MoveToScrollbackBottom',
    },
    {
      key = 'u',
      mods = 'CTRL',
      action = wezterm.action.CopyMode 'PageUp',
    },
    {
      key = 'd',
      mods = 'CTRL',
      action = wezterm.action.CopyMode 'PageDown',
    },
    -- Visual selection
    {
      key = 'v',
      mods = 'NONE',
      action = wezterm.action.CopyMode { SetSelectionMode = 'Cell' },
    },
    {
      key = 'V',
      mods = 'NONE',
      action = wezterm.action.CopyMode { SetSelectionMode = 'Line' },
    },
    {
      key = 'v',
      mods = 'CTRL',
      action = wezterm.action.CopyMode { SetSelectionMode = 'Block' },
    },
    -- Copy and search
    {
      key = 'y',
      mods = 'NONE',
      action = wezterm.action.Multiple {
        wezterm.action.CopyTo 'ClipboardAndPrimarySelection',
        wezterm.action.ClearSelection,
        wezterm.action.CopyMode 'Close',
      },
    },
    {
      key = '/',
      mods = 'NONE',
      action = wezterm.action.Search { CaseSensitiveString = '' },
    },
    {
      key = 'n',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'NextMatch',
    },
    {
      key = 'N',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'PriorMatch',
    },
    -- Exit copy mode
    {
      key = 'Escape',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'Close',
    },
    {
      key = 'q',
      mods = 'NONE',
      action = wezterm.action.CopyMode 'Close',
    },
  },
}

return config