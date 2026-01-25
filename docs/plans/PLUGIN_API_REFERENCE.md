# Zellij Plugin API - Quick Reference for Dashboard

## Plugin Trait & Lifecycle

```rust
pub trait ZellijPlugin: Default {
    fn load(&mut self, configuration: BTreeMap<String, String>) {}
    fn update(&mut self, event: Event) -> bool { false }
    fn pipe(&mut self, pipe_message: PipeMessage) -> bool { false }
    fn render(&mut self, rows: usize, cols: usize) {}
}

register_plugin!(YourPluginName);
```

| Method | Called When | Return Value | Purpose |
|--------|------------|--------------|---------|
| `load()` | Plugin starts | n/a | Subscribe to events, request permissions |
| `update(event)` | Event occurs | `bool` - true if render needed | Update state, handle user input |
| `render(rows,cols)` | update() returns true | n/a | Print UI to STDOUT |
| `pipe(msg)` | Message piped to plugin | `bool` - true if render needed | Receive messages from other plugins |

---

## Core Events for Dashboard

### State Update Events (Permission: ReadApplicationState)

#### PaneUpdate(PaneManifest) - PRIMARY EVENT
```rust
pub struct PaneManifest {
    pub panes: HashMap<usize, Vec<PaneInfo>>,  // usize = tab index
}

pub struct PaneInfo {
    pub id: u32,                               // ← Unique pane ID
    pub is_plugin: bool,                       // ← Is this a plugin (vs terminal)?
    pub is_focused: bool,                      // ← Focused in its layer
    pub is_fullscreen: bool,
    pub is_floating: bool,
    pub is_suppressed: bool,                   // ← Hidden but running
    pub title: String,                         // ← Pane name
    pub exited: bool,                          // ← Has it exited?
    pub exit_status: Option<i32>,              // ← Exit code if exited
    pub is_held: bool,                         // ← Paused for input
    
    // Coordinates and sizes (with frame)
    pub pane_x: usize,
    pub pane_y: usize,
    pub pane_rows: usize,
    pub pane_columns: usize,
    
    // Coordinates and sizes (without frame/border)
    pub pane_content_x: usize,
    pub pane_content_y: usize,
    pub pane_content_rows: usize,
    pub pane_content_columns: usize,
}
```

**Fired**: Whenever any pane changes (title, status, position, exit, etc.)

#### TabUpdate(Vec<TabInfo>)
```rust
pub struct TabInfo {
    pub name: String,
    pub active: bool,              // ← Is this the active tab?
    pub position: usize,
    pub panes_to_hide: u32,        // ← Number of hidden panes in this tab
    pub is_fullscreen_active: bool,
    pub is_sync_panes_active: bool,
}
```

**Fired**: When tabs are created, closed, or focus changes

#### ModeUpdate(ModeInfo)
```rust
pub struct ModeInfo {
    pub mode: InputMode,           // Normal, Locked, Pane, Tab, Resize, etc.
    pub palette: Palette,          // Colors! (match user's theme)
    pub style: Style,              // Font styles
    pub session_name: String,
}
```

**Fired**: When input mode changes, or for periodic updates

### User Input Events

#### Key(KeyWithModifier)
```rust
pub struct KeyWithModifier {
    pub bare_key: BareKey,
    pub has_shift: bool,
    pub has_ctrl: bool,
    pub has_alt: bool,
}

pub enum BareKey {
    ArrowUp, ArrowDown, ArrowLeft, ArrowRight,
    Char(char),
    Enter,
    Esc,
    // ... etc
}
```

**Fired**: When user presses a key while plugin is focused

#### Mouse(Mouse)
```rust
pub enum Mouse {
    LeftClick(usize, usize),       // (row, col)
    RightClick(usize, usize),
    Scroll(ScrollDirection),
    // ...
}
```

**Fired**: When user clicks or scrolls while plugin is focused

---

## Essential Commands for Dashboard

### Subscribe to Events
```rust
fn load(&mut self, _config: BTreeMap<String, String>) {
    subscribe(&[
        EventType::PaneUpdate,
        EventType::TabUpdate,
        EventType::ModeUpdate,
        EventType::Key,
        EventType::Mouse,
    ]);
}
```

### Request Permissions
```rust
fn load(&mut self, _config: BTreeMap<String, String>) {
    request_permission(&[
        PermissionType::ReadApplicationState,      // Required for events
        // PermissionType::ChangeApplicationState, // Only if you want to control panes
    ]);
}
```

### Get Plugin Info
```rust
let plugin_ids = get_plugin_ids();
println!("My plugin ID: {}", plugin_ids.plugin_id);
println!("Initial working directory: {}", plugin_ids.initial_cwd);
```

### Focus/Control Panes
```rust
// Focus a pane
focus_terminal_pane(pane_id);       // Terminal pane
focus_plugin_pane(pane_id);         // Plugin pane

// Close a pane
close_terminal_pane(pane_id);
close_plugin_pane(pane_id);

// Make plugin selectable
set_selectable(true);               // Let user give it focus

// Toggle fullscreen
toggle_pane_id_fullscreen(pane_id);
```

### Render Output
```rust
// Simple text
println!("Hello {}", name);

// With ANSI colors
println!("\x1b[32mGreen text\x1b[0m");  // Green
println!("\x1b[1;31mBold red\x1b[0m");  // Bold red

// Using zellij built-in components
print_table(my_table);
print_ribbon_with_coordinates(my_ribbon, x, y, width, height);
```

---

## Rendering: Built-in Components

Zellij provides cross-platform, theme-aware UI components in WASM:

### Table Component
```rust
let mut table = Table::new()
    .add_row(vec!["Header1", "Header2", "Header3"])
    .add_row(vec!["Cell1", "Cell2", "Cell3"]);

// Style rows
table.add_styled_row(vec![
    Text::new("Content").selected(),      // Highlighted
    Text::new("Content").color_range(0, 0..2),  // Colored
    Text::new("Content"),
]);

print_table(table);
// Or with coordinates:
print_table_with_coordinates(table, x, y, Some(width), Some(height));
```

### Text Component
```rust
let text = Text::new("My text")
    .selected()                            // Highlight
    .color_range(0, 0..2)                  // Color indices 0-2
    .color_range(1, 3..5);                 // Color indices 3-5

print_text_with_coordinates(text, x, y, Some(width), Some(height));
```

### Ribbon Component (Tabs/Buttons)
```rust
let ribbon = Text::new("Tab 1")
    .selected_if(is_active);

print_ribbon_with_coordinates(ribbon, x, y, Some(width), Some(height));
```

### NestedList Component (Hierarchical)
```rust
let mut items = vec![
    NestedListItem::new("Item 1"),
    NestedListItem::new("Item 1.1").indent(1),
    NestedListItem::new("Item 2").selected(),
];

print_nested_list_with_coordinates(items, x, y, Some(width), Some(height));
```

---

## Event Handling Pattern (Typical)

```rust
#[derive(Default)]
struct DashboardState {
    panes: HashMap<usize, Vec<PaneInfo>>,
    active_tab: usize,
    selection: usize,  // Selected pane index
    mode_info: ModeInfo,
}

impl ZellijPlugin for DashboardState {
    fn load(&mut self, _config: BTreeMap<String, String>) {
        request_permission(&[PermissionType::ReadApplicationState]);
        subscribe(&[
            EventType::PaneUpdate,
            EventType::TabUpdate,
            EventType::ModeUpdate,
            EventType::Key,
            EventType::Mouse,
        ]);
        set_selectable(true);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            // State updates
            Event::PaneUpdate(manifest) => {
                self.panes = manifest.panes;
                true  // Request render
            },
            Event::TabUpdate(tabs) => {
                self.active_tab = tabs.iter().position(|t| t.active).unwrap_or(0);
                true
            },
            Event::ModeUpdate(mode) => {
                self.mode_info = mode;
                false  // No render needed
            },
            
            // User input
            Event::Key(key) => {
                match key.bare_key {
                    BareKey::Down => self.selection = (self.selection + 1) % self.pane_count(),
                    BareKey::Up => self.selection = self.selection.saturating_sub(1),
                    BareKey::Enter => self.focus_selected_pane(),
                    BareKey::Char('d') => self.kill_selected_pane(),
                    _ => return false,
                }
                true
            },
            Event::Mouse(Mouse::LeftClick(row, _col)) => {
                self.selection = row;  // Simplified
                true
            },
            _ => false,
        }
    }

    fn render(&mut self, rows: usize, cols: usize) {
        // Get panes in active tab
        let panes = self.panes.get(&self.active_tab).unwrap_or(&vec![]);
        
        // Build table
        let mut table = Table::new()
            .add_row(vec!["ID", "Title", "Status", "Size"]);
        
        for (idx, pane) in panes.iter().enumerate() {
            let status = if pane.exited {
                format!("exited:{}", pane.exit_status.unwrap_or(-1))
            } else {
                "running".to_string()
            };
            
            let row = vec![
                format!("[{}]", pane.id),
                pane.title.clone(),
                status,
                format!("{}x{}", pane.pane_columns, pane.pane_rows),
            ];
            
            // Highlight selected row
            let row_text: Vec<_> = if idx == self.selection {
                row.iter().map(|s| Text::new(s).selected()).collect()
            } else {
                row.iter().map(|s| Text::new(s)).collect()
            };
            
            table.add_styled_row(row_text);
        }
        
        print_table(table);
        println!("\n[↑↓] Navigate [Enter] Focus [d] Kill [?] Help");
    }
}

impl DashboardState {
    fn focus_selected_pane(&mut self) {
        if let Some(panes) = self.panes.get(&self.active_tab) {
            if let Some(pane) = panes.get(self.selection) {
                if pane.is_plugin {
                    focus_plugin_pane(pane.id);
                } else {
                    focus_terminal_pane(pane.id);
                }
            }
        }
    }

    fn kill_selected_pane(&mut self) {
        if let Some(panes) = self.panes.get(&self.active_tab) {
            if let Some(pane) = panes.get(self.selection) {
                if pane.is_plugin {
                    close_plugin_pane(pane.id);
                } else {
                    close_terminal_pane(pane.id);
                }
            }
        }
    }

    fn pane_count(&self) -> usize {
        self.panes.get(&self.active_tab).map(|p| p.len()).unwrap_or(0)
    }
}

register_plugin!(DashboardState);
```

---

## Cargo.toml Template

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

[profile.release]
opt-level = "z"      # Optimize for size
lto = true           # Link-time optimization
strip = true         # Strip symbols
```

---

## Build & Install

```bash
# Build WASM plugin
cargo build --release --target wasm32-wasip1

# Plugin binary location
target/wasm32-wasip1/release/zellij_dashboard.wasm

# Add to Zellij config/layout
layout {
    pane size=85% {
        // your workspace
    }
    pane size=15% borderless=true {
        plugin location="file:/path/to/zellij_dashboard.wasm"
    }
}
```

---

## Permission Types

```rust
pub enum PermissionType {
    ReadApplicationState,      // Read panes, tabs, sessions, mode
    ChangeApplicationState,    // Modify layout, focus, open/close panes
    OpenFiles,                 // Open files in editor
    RunCommands,              // Run shell commands
    WriteToStdin,             // Write to pane STDIN
    OpenTerminalsOrPlugins,   // Open new terminal/plugin panes
    WebAccess,                // Make HTTP requests
    FullHdAccess,             // Full hard drive access
    Reconfigure,              // Modify configuration
    // ... more
}
```

---

## Common Patterns

### Get pane by ID
```rust
fn get_pane(&self, pane_id: u32, is_plugin: bool) -> Option<&PaneInfo> {
    for (_tab_idx, panes) in &self.panes {
        if let Some(pane) = panes.iter().find(|p| p.id == pane_id && p.is_plugin == is_plugin) {
            return Some(pane);
        }
    }
    None
}
```

### Determine pane status string
```rust
fn status_string(pane: &PaneInfo) -> String {
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

### Handle arrow keys
```rust
match key.bare_key {
    BareKey::ArrowUp | BareKey::Char('k') if !key.has_ctrl => {
        // Move up
    },
    BareKey::ArrowDown | BareKey::Char('j') if !key.has_ctrl => {
        // Move down
    },
    BareKey::ArrowLeft | BareKey::Char('h') if !key.has_ctrl => {
        // Move left (switch tab)
    },
    BareKey::ArrowRight | BareKey::Char('l') if !key.has_ctrl => {
        // Move right (switch tab)
    },
    _ => {}
}
```

---

## Resources

- **Official Docs**: https://zellij.dev/documentation/plugins
- **Event Reference**: https://zellij.dev/documentation/plugin-api-events
- **Commands Reference**: https://zellij.dev/documentation/plugin-api-commands
- **zellij-tile Crate**: https://docs.rs/zellij-tile/
- **Built-in Plugins**: https://github.com/zellij-org/zellij/tree/main/default-plugins
- **Community Examples**: GitHub search "zellij-plugin"
