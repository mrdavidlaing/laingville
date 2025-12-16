-- Hammerspoon configuration
-- Purpose: Make floating windows (from Aerospace) stay on top of tiled windows

-- Apps that should always float on top when their windows appear
local appsToFloat = {
    "System Settings",
    "System Preferences",  -- older macOS
    "Finder",
    "Calculator",
    "1Password",
}

-- Create a window filter for these apps
local floatFilter = hs.window.filter.new(appsToFloat)

-- When a window from these apps is created or focused, make it topmost
floatFilter:subscribe(hs.window.filter.windowCreated, function(win)
    if win then
        win:raise()
        -- Note: setTopmost() requires accessibility permissions
        -- and may not work on all windows
        pcall(function() win:setTopmost(true) end)
    end
end)

floatFilter:subscribe(hs.window.filter.windowFocused, function(win)
    if win then
        win:raise()
    end
end)

-- Hotkey to toggle always-on-top for current window (Cmd+Ctrl+T)
hs.hotkey.bind({"cmd", "ctrl"}, "T", function()
    local win = hs.window.focusedWindow()
    if win then
        local isTopmost = win:isTopmost()
        win:setTopmost(not isTopmost)
        if isTopmost then
            hs.alert.show("Always on top: OFF")
        else
            hs.alert.show("Always on top: ON")
        end
    end
end)

-- Show a notification when Hammerspoon loads
hs.alert.show("Hammerspoon loaded")
