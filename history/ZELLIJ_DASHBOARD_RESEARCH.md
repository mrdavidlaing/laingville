# Zellij Overview Dashboard Research

## Executive Summary

**Goal**: Build an "overview dashboard" plugin for Zellij that shows what is going on across all panes in real-time.

**Feasibility**: ✅ **Highly Feasible**. Zellij's plugin system is specifically designed for this use case with:
- Event-driven architecture exposing complete pane state
- Permission-based access control
- Built-in UI components (Table, Ribbon, Text, NestedList)
- Full access to all panes via `PaneUpdate` events

**Complexity**: Medium. Plugin would be 200-400 lines of Rust code.

---

## 1. Overview Dashboard Concept

### What It Would Show
```
╔════════════════════════════════════════════════════════════════════╗
║ ZELLIJ OVERVIEW DASHBOARD                                         ║
╠════════════════════════════════════════════════════════════════════╣
║ Tab: "main" (active)                                               ║
║ ┌─────────────────────────────────────────────────────────────────┐│
║ │ Pane  │ Title          │ Cmd        │ Status     │ Size        ││
║ ├──────┼────────────────┼────────────┼────────────┼─────────────┤│
║ │ [1]  │ shell          │ /bin/bash  │ running    │ 80x24       ││
║ │ [2]* │ editor         │ vim        │ running    │ 40x24       ││
║ │ [3]  │ build          │ cargo b... │ exited:0   │ 40x24       ││
║ │ [4]  │ monitor        │ watch      │ running    │ 80x12       ││
║ └─────────────────────────────────────────────────────────────────┘│
║                                                                    ║
║ [*] = focused | [H]elp [G]o-to [K]ill [R]esize [C]ommand         ║
╚════════════════════════════════════════════════════════════════════╝
```

### Data Points Per Pane
- **ID** - Pane identifier
- **Title** - User-configured pane name
- **Command** - Current command/binary running (if terminal pane)
- **Status** - running / exited:code / held / fullscreen
- **Dimensions** - WxH (with and without frame)
- **Position** - X,Y coordinates
- **Layer** - tiled / floating / fullscreen
- **Is Plugin** - ✓ if plugin, blank if terminal
- **Focus State** - active in its layer

### Key Features
1. **Real-time Updates** - Instant feedback as panes change
2. **Multi-Tab Support** - Switch between tabs and see different pane sets
3. **Interactive** - Click to focus panes, keyboard shortcuts
4. **Keyboard Navigation** - hjkl or arrow keys to move selection
5. **Quick Actions** - Kill, resize, focus, fullscreen commands
6. **Search/Filter** - Find specific panes by title or command
7. **Theming** - Matches Zellij's configured color scheme

---

## 2. Zellij Plugin Architecture (Relevant to Dashboard)

### Core Plugin Trait
```rust
pub trait ZellijPlugin: Default {
    fn load(&mut self, configuration: BTreeMap<String, String>) {}
    fn update(&mut self, event: Event) -> bool { false }
    fn pipe(&mut self, pipe_message: PipeMessage) -> bool { false }
    fn render(&mut self, rows: usize, cols: usize) {}
}
```

**Lifecycle**:
1. `load()` - Subscribe to events, request permissions
2. `update()` - Receive events, update internal state
3. `render()` - Draw UI (called when update returns `true`)

### Key Plugin Registration
```rust
register_plugin!(DashboardPlugin);
```

### Permissions Required
```rust
fn load(&mut self, _config: BTreeMap<String, String>) {
    request_permission(&[PermissionType::ReadApplicationState]);
    subscribe(&[
        EventType::PaneUpdate,
        EventType::TabUpdate,
        EventType::ModeUpdate,
        EventType::Key,
        EventType::Mouse,
    ]);
}
```

**Only permission needed**: `ReadApplicationState` (read-only, non-invasive)

---

## 3. Event System - Dashboard Perspective

### PaneUpdate Event (PRIMARY)
Contains complete `PaneManifest` with all panes across all tabs:

```rust
pub struct PaneManifest {
    pub panes: HashMap<usize, Vec<PaneInfo>>,  // usize = tab index
}

pub struct PaneInfo {
    pub id: u32,                               // Unique pane ID
    pub is_plugin: bool,                       // Plugin vs terminal
    pub is_focused: bool,                      // Focused in its layer
    pub is_fullscreen: bool,
    pub is_floating: bool,
    pub is_suppressed: bool,                   // Hidden but running
    pub title: String,                         // Pane name/title
    pub exited: bool,                          // Has pane exited?
    pub exit_status: Option<i32>,              // Exit code if exited
    pub is_held: bool,                         // Paused for input
    pub pane_x, pane_y: usize,                 // Position (with frame)
    pub pane_content_x, pane_content_y: usize, // Position (no frame)
    pub pane_rows, pane_columns: usize,        // Size (with frame)
    pub pane_content_rows, pane_content_columns: usize, // Size (no frame)
}
```

**When Triggered**: Whenever any pane changes (title, focus, exit, resize, etc.)

### TabUpdate Event (SECONDARY)
Contains tab information:

```rust
pub struct TabInfo {
    pub name: String,
    pub active: bool,
    pub position: usize,
    pub panes_to_hide: u32,                    // Hidden panes in tab
    pub is_fullscreen_active: bool,
    pub is_sync_panes_active: bool,
}
```

### User Input Events
- `Key(KeyWithModifier)` - When dashboard has focus and user presses key
- `Mouse(Mouse)` - Click/scroll events

### Mode Event
Contains current theme/colors:
```rust
pub struct ModeInfo {
    pub mode: InputMode,
    pub palette: Palette,  // Colors!
    pub style: Style,
    pub session_name: String,
}
```

---

## 4. Building the Dashboard Plugin

### Architecture (Pseudocode)

```rust
#[derive(Default)]
pub struct DashboardPlugin {
    panes: HashMap<usize, Vec<PaneInfo>>,      // Current state
    tabs: Vec<TabInfo>,                        // Tabs
    active_tab: usize,
    active_pane_id: u32,
    active_pane_is_plugin: bool,
    selection: (usize, usize),                 // (tab_idx, pane_idx in that tab)
    mode_info: ModeInfo,
    filter_text: String,
}

impl ZellijPlugin for DashboardPlugin {
    fn load(&mut self, _config: BTreeMap<String, String>) {
        // 1. Request permission to read app state
        request_permission(&[PermissionType::ReadApplicationState]);
        
        // 2. Subscribe to events
        subscribe(&[
            EventType::PaneUpdate,
            EventType::TabUpdate,
            EventType::ModeUpdate,
            EventType::Key,
            EventType::Mouse,
        ]);
        
        // 3. Make it selectable (needs focus for keyboard input)
        set_selectable(true);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            // State updates
            Event::PaneUpdate(panes) => {
                self.panes = panes;
                true  // Request render
            },
            Event::TabUpdate(tabs) => {
                self.tabs = tabs;
                self.active_tab = tabs.iter().position(|t| t.active).unwrap_or(0);
                true
            },
            Event::ModeUpdate(mode_info) => {
                self.mode_info = mode_info;
                false  // No render needed for theme changes (unless tracking color)
            },
            
            // User input
            Event::Key(key) => {
                match key.bare_key {
                    BareKey::Up | BareKey::Char('k') => self.move_selection_up(),
                    BareKey::Down | BareKey::Char('j') => self.move_selection_down(),
                    BareKey::Left | BareKey::Char('h') => self.prev_tab(),
                    BareKey::Right | BareKey::Char('l') => self.next_tab(),
                    BareKey::Enter => self.focus_selected_pane(),
                    BareKey::Char('d') => self.kill_selected_pane(),
                    BareKey::Char('f') => self.toggle_fullscreen(),
                    BareKey::Char('/') => self.start_filter(),
                    BareKey::Esc => self.cancel_filter(),
                    _ => return false,
                }
                true
            },
            Event::Mouse(mouse) => {
                self.handle_mouse(mouse);
                true
            },
            _ => false,
        }
    }

    fn render(&mut self, _rows: usize, _cols: usize) {
        // 1. Get panes for active tab
        let panes_in_tab = self.panes.get(&self.active_tab).unwrap_or(&vec![]);
        
        // 2. Filter based on search
        let filtered = self.filter_panes(panes_in_tab);
        
        // 3. Build table
        let mut table = Table::new()
            .add_row(vec!["ID", "Title", "Command", "Status", "Size"]);
        
        for (idx, pane) in filtered.iter().enumerate() {
            let status = if pane.exited {
                format!("exited:{}", pane.exit_status.unwrap_or(-1))
            } else if pane.is_held {
                "held".to_string()
            } else if pane.is_fullscreen {
                "fullscreen".to_string()
            } else {
                "running".to_string()
            };
            
            let size = format!("{}x{}", pane.pane_columns, pane.pane_rows);
            let title_display = if pane.title.is_empty() {
                if pane.is_plugin { "[plugin]" } else { "[shell]" }
            } else {
                &pane.title
            };
            
            let row = vec![
                format!("[{}]", pane.id),
                title_display.to_string(),
                self.get_command(&pane).unwrap_or_default(),
                status,
                size,
            ];
            
            let row_text = if self.is_selected(idx) {
                row.iter()
                    .map(|s| Text::new(s).selected())
                    .collect()
            } else {
                row.iter()
                    .map(|s| Text::new(s))
                    .collect()
            };
            
            table.add_styled_row(row_text);
        }
        
        // 4. Render with instructions
        print_table(table);
        println!("\n[↑↓/jk] Select [←→/hl] Tab [Enter] Focus [d] Kill [f] Fullscreen [/] Filter");
    }
}

register_plugin!(DashboardPlugin);
```

### Implementation Details

**1. Pane Status Determination**
```rust
fn get_pane_status(pane: &PaneInfo) -> String {
    if pane.exited {
        format!("exited:{}", pane.exit_status.unwrap_or(-1))
    } else if pane.is_held {
        "held".to_string()
    } else if pane.is_suppressed {
        "suppressed".to_string()
    } else if pane.is_fullscreen {
        "fullscreen".to_string()
    } else {
        "running".to_string()
    }
}
```

**2. Command Extraction (Placeholder)**
- **Note**: `PaneInfo` doesn't include the command string directly
- Would need to either:
  - Store command names from when panes are created
  - Use `/proc` parsing (Linux only)
  - Have plugin receive command updates via custom protocol
  - Show limited info and focus on pane titles

**3. Selection Tracking**
```rust
fn move_selection_up(&mut self) {
    let (tab_idx, pane_idx) = self.selection;
    if pane_idx > 0 {
        self.selection = (tab_idx, pane_idx - 1);
    }
}

fn move_selection_down(&mut self) {
    let (tab_idx, pane_idx) = self.selection;
    let tab_panes = self.panes.get(&tab_idx).unwrap_or(&vec![]);
    if pane_idx + 1 < tab_panes.len() {
        self.selection = (tab_idx, pane_idx + 1);
    }
}
```

**4. Focus Selected Pane**
```rust
fn focus_selected_pane(&mut self) {
    let (tab_idx, pane_idx) = self.selection;
    if let Some(panes) = self.panes.get(&tab_idx) {
        if let Some(pane) = panes.get(pane_idx) {
            if pane.is_plugin {
                focus_plugin_pane(pane.id);
            } else {
                focus_terminal_pane(pane.id);
            }
        }
    }
}
```

**5. Kill Pane**
```rust
fn kill_selected_pane(&mut self) {
    let (tab_idx, pane_idx) = self.selection;
    if let Some(panes) = self.panes.get(&tab_idx) {
        if let Some(pane) = panes.get(pane_idx) {
            if pane.is_plugin {
                close_plugin_pane(pane.id);
            } else {
                close_terminal_pane(pane.id);
            }
        }
    }
}
```

---

## 5. Existing Dashboard Plugins (Reference Implementations)

### 1. eikopf/zellij-dashboard
- **Status**: Early stage, personal project, not production-ready
- **Goal**: "Neutral space" like Doom Emacs dashboard
- **Planned Features**:
  - Date & Time
  - Calendar integration
  - Tab view with keybindings
  - Quick-launch shortcuts (T=terminal, J=Julia, E=editor, etc.)
  - Command history display
  - Theme sync with Zellij
- **GitHub**: https://github.com/eikopf/zellij-dashboard
- **Maturity**: 2 stars, 4 commits, very experimental

### 2. Christian-Prather/zellij-load
- **Purpose**: System resource monitor (CPU, memory, GPU)
- **Architecture**: Two-component (daemon + WASM plugin)
- **Status**: Functional, released (v0.1.1)
- **Key Pattern**:
  - Native daemon collects system metrics
  - WASM plugin renders in status bar
  - Communication via Zellij pipes
- **GitHub**: https://github.com/Christian-Prather/zellij-load
- **Maturity**: 2 stars, well-documented

### 3. dj95/zjstatus
- **Purpose**: Configurable statusbar with widgets
- **Features**:
  - Custom widget modules (datetime, session, tabs, mode)
  - Themable appearance
  - Companion tool `zjframes` for frame management
- **GitHub**: https://github.com/dj95/zjstatus
- **Pattern**: Statusbar-focused, not full overview

### 4. Built-in Plugins (Zellij Source)
Best reference implementations:
- **tab-bar** - Multi-tab UI, mouse support, dynamic rendering
- **status-bar** - Mode indicator, command hints
- **strider** - File browser, directory traversal, search
- **session-manager** - Session list, interactive selection
- **layout-manager** - Layout picker

---

## 6. Key Technical Insights

### ✅ Advantages for Dashboard Plugin

1. **Complete Pane Visibility**
   - `PaneUpdate` includes ALL panes across ALL tabs
   - No polling needed, event-driven updates
   - All pane metadata available

2. **Rich Data Structure**
   - Position, dimensions, titles, exit codes, state flags
   - Can determine running vs exited vs suppressed panes
   - Access to focused pane information

3. **Interactive Control**
   - Plugin can focus/kill/resize panes by ID
   - Full control over pane lifecycle
   - Can open new panes

4. **Theme Integration**
   - Access to current color palette via `ModeInfo`
   - Built-in UI components auto-theme
   - Matches user's visual preferences

5. **Cross-Platform**
   - Runs on Linux, macOS, Windows
   - WASM sandbox ensures safety
   - No shell dependencies

### ⚠️ Limitations

1. **Command String Not Available**
   - `PaneInfo` doesn't include the command being run
   - Can work around with custom protocol or proc parsing
   - Tab/title may be sufficient for most use cases

2. **Performance at Scale**
   - Many panes (100+) would be slow
   - Table rendering has O(n) complexity
   - Could virtualize rows for scrolling

3. **Plugin-Terminal Pane Distinction**
   - Shown via `is_plugin` boolean
   - But title may be ambiguous
   - Could color-code or add icon prefix

4. **Permission Model**
   - Requires `ChangeApplicationState` for kill/resize/focus
   - User must grant on first load
   - Not all users may be comfortable with this

---

## 7. Implementation Roadmap

### Phase 1: MVP (100 lines)
- [x] Subscribe to `PaneUpdate`, `TabUpdate` events
- [x] Render table of panes in active tab
- [x] Show: ID, Title, Status, Size
- [x] Arrow key navigation
- [x] Focus selected pane (click pane in table)

### Phase 2: Interactive (150 lines)
- [ ] Kill pane (press 'd')
- [ ] Toggle fullscreen (press 'f')
- [ ] Jump to pane by ID (press number)
- [ ] Show keyboard hints at bottom

### Phase 3: Polish (200+ lines)
- [ ] Search/filter panes (press '/')
- [ ] Display command name (if available)
- [ ] Mouse click to focus
- [ ] Tab switching (← →)
- [ ] Color coding (running=green, exited=red)

### Phase 4: Advanced (300+ lines)
- [ ] Show pane hierarchy/tree
- [ ] Resize pane from dashboard
- [ ] Pane stats (age, CPU?, scrollback size)
- [ ] Favorites/sticky panes
- [ ] Layout management integration

---

## 8. Zellij Plugin Ecosystem

### Notable Existing Plugins
- **tab-bar**, **status-bar** - Built-in, reference quality
- **session-manager** - Multi-session UI
- **strider** - File browser with search
- **zellij-dashboard** - Experimental overview
- **zellij-load** - System monitoring
- **zjstatus** - Statusbar widget framework

### Plugin Development Resources
- Official docs: https://zellij.dev/documentation/plugins
- Example plugins: https://github.com/zellij-org/zellij/tree/main/default-plugins
- SDK crate: `zellij-tile` (Rust only, official)
- Community plugins: GitHub search "zellij-plugin"

---

## 9. Recommended Approach

### Build as Standalone Plugin
1. **Fork or study** `tab-bar` plugin as reference (good structure)
2. **Use `ratatui`** or **`zellij-tile` built-in components** for UI
3. **Start with MVP**: Just table of panes, arrow navigation, focus
4. **Test heavily** with many panes to find performance limits
5. **Consider daemon** for command name extraction (like zellij-load)

### Layout Integration
```kdl
layout {
    pane size=90% {
        pane {
            // your main workspace
        }
    }
    pane size=10% borderless=true {
        plugin location="file:/path/to/dashboard.wasm"
    }
}
```

Or fullscreen:
```kdl
layout {
    pane {
        plugin location="file:/path/to/dashboard.wasm" {
            args "fullscreen" "true"
        }
        pane {
            // workspace
        }
    }
}
```

---

## 10. Sample Code Structure

### Cargo.toml
```toml
[package]
name = "zellij-dashboard"
version = "0.1.0"
edition = "2021"

[dependencies]
zellij-tile = "0.40"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

[lib]
crate-type = ["cdylib"]
```

### src/lib.rs
```rust
use std::collections::HashMap;
use zellij_tile::prelude::*;

#[derive(Default)]
struct DashboardPlugin {
    panes: HashMap<usize, Vec<PaneInfo>>,
    tabs: Vec<TabInfo>,
    active_tab: usize,
    selection_idx: usize,
    // ... more fields
}

impl ZellijPlugin for DashboardPlugin {
    fn load(&mut self, _configuration: BTreeMap<String, String>) {
        request_permission(&[PermissionType::ReadApplicationState]);
        subscribe(&[
            EventType::PaneUpdate,
            EventType::TabUpdate,
            EventType::Key,
            EventType::Mouse,
        ]);
        set_selectable(true);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::PaneUpdate(manifest) => {
                self.panes = manifest.panes;
                true
            }
            Event::TabUpdate(tabs) => {
                self.tabs = tabs.clone();
                self.active_tab = tabs.iter().position(|t| t.active).unwrap_or(0);
                true
            }
            Event::Key(key) => {
                self.handle_key(key);
                true
            }
            Event::Mouse(mouse) => {
                self.handle_mouse(mouse);
                true
            }
            _ => false,
        }
    }

    fn render(&mut self, _rows: usize, _cols: usize) {
        // Render table of panes
        self.render_table();
    }
}

impl DashboardPlugin {
    fn handle_key(&mut self, key: Key) {
        // Handle arrow keys, enter, etc.
    }

    fn handle_mouse(&mut self, mouse: Mouse) {
        // Handle clicks
    }

    fn render_table(&self) {
        // Render table using zellij_tile components
    }
}

register_plugin!(DashboardPlugin);
```

---

## Conclusion

Building an overview dashboard for Zellij is **entirely feasible and straightforward**. The plugin system is mature and provides all necessary hooks:

✅ **Can do**:
- Real-time monitoring of all panes
- Interactive navigation and control
- Theme-integrated UI
- Cross-platform compatibility

⚠️ **Considerations**:
- Command name extraction requires workaround
- Performance with 50+ panes needs optimization
- User must grant `ReadApplicationState` permission

**Estimated development time**: 4-8 hours for MVP, 8-16 hours for production-ready plugin.

**Best reference**: Study `tab-bar` and `strider` plugins in zellij source, then build incrementally.
