# Zellij Dashboard Plugin - Architecture Diagrams

## 1. Data Flow: How Dashboard Gets Pane Information

```
┌──────────────────────────────────────────────────────────────┐
│ ZELLIJ SERVER                                                │
│                                                              │
│  ┌─────────────┐      ┌──────────────┐     ┌────────────┐  │
│  │ PTY Bus     │─────→│ Screen Mgmt  │────→│ PaneInfo   │  │
│  │             │      │              │     │ Database   │  │
│  │ (reads ANSI)│      │ (tracks      │     │            │  │
│  └─────────────┘      │  panes)      │     └────────────┘  │
│                       └──────────────┘            ▲         │
│                                                   │         │
│                       Every pane change triggers: │         │
│                       - title changed             │         │
│                       - position/size changed     │         │
│                       - focus changed             │         │
│                       - pane exited               │         │
│                       - pane opened               │         │
│                                                   │         │
│  ┌───────────────────────────────────────────────┴───────┐  │
│  │ broadcast PaneUpdate(PaneManifest) to all subscribed  │  │
│  │ plugins                                               │  │
│  └───────────────────┬───────────────────────────────────┘  │
│                      │                                      │
└──────────────────────┼──────────────────────────────────────┘
                       │
                       │ Event Channel (IPC)
                       │
┌──────────────────────▼──────────────────────────────────────┐
│ DASHBOARD PLUGIN (WASM)                                      │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ update(Event::PaneUpdate(PaneManifest))            │   │
│  │                                                     │   │
│  │  self.panes = manifest.panes                       │   │
│  │  return true  // Request render                    │   │
│  └─────────────────────────┬───────────────────────────┘   │
│                            │                                │
│  ┌─────────────────────────▼───────────────────────────┐   │
│  │ render(rows, cols)                                 │   │
│  │                                                     │   │
│  │  Build Table from self.panes                       │   │
│  │  - For each pane in active tab                     │   │
│  │    - Extract id, title, status, dimensions        │   │
│  │    - Highlight if selected                        │   │
│  │  Print Table to STDOUT                            │   │
│  └─────────────────────────┬───────────────────────────┘   │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
                             │ ANSI escape sequences
                             │
┌────────────────────────────▼────────────────────────────────┐
│ ZELLIJ UI (Terminal)                                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ ╔════════════════════════════════════════════════════╗│ │
│  │ ║ ID │ Title      │ Status     │ Size       │        ║│ │
│  │ ╠════╪════════════╪════════════╪════════════╣        ║│ │
│  │ ║ 1  │ shell      │ running    │ 80x24  [selected]║║ │
│  │ ║ 2  │ editor     │ running    │ 40x24      ║        ║│ │
│  │ ║ 3  │ build      │ exited:0   │ 40x24      ║        ║│ │
│  │ └────────────────────────────────────────────────────┘ │
│  │                                                        │
└────────────────────────────────────────────────────────────┘
```

---

## 2. Event System: All Events Available to Dashboard

```
┌──────────────────────────────────────────────────────────────────┐
│ ZELLIJ EVENT SYSTEM                                              │
│                                                                  │
│ Subscribe to events in load():                                   │
│   subscribe(&[EventType::..., ...])                             │
│                                                                  │
│ Receive in update(event: Event) -> bool                          │
└──────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ STATE UPDATE EVENTS (Permission: ReadApplicationState)          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ PaneUpdate(PaneManifest)                                        │
│   ├─ All panes across all tabs                                 │
│   ├─ ID, title, status, position, size                         │
│   ├─ Exit codes, focus state, layer type                       │
│   └─ Fired: Whenever ANY pane changes [CORE FOR DASHBOARD]    │
│                                                                 │
│ TabUpdate(Vec<TabInfo>)                                         │
│   ├─ Tab names, active tab, pane count                         │
│   ├─ Fullscreen state, sync state                              │
│   └─ Fired: When tab focus/creation/deletion changes           │
│                                                                 │
│ ModeUpdate(ModeInfo)                                            │
│   ├─ Current input mode (Normal, Pane, Tab, etc.)             │
│   ├─ User's color palette (theme colors)                       │
│   ├─ Style information                                         │
│   └─ Fired: When mode changes or periodically                 │
│                                                                 │
│ SessionUpdate(...)                                              │
│   ├─ Active sessions and resurrectable sessions                │
│   └─ Fired: When session state changes                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ USER INPUT EVENTS                                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Key(KeyWithModifier)                                            │
│   ├─ bare_key: ArrowUp, ArrowDown, Char, Enter, Esc, etc.    │
│   ├─ has_shift, has_ctrl, has_alt                             │
│   └─ Fired: When user presses key while dashboard focused      │
│                                                                 │
│ Mouse(Mouse)                                                    │
│   ├─ LeftClick(row, col)                                       │
│   ├─ RightClick(row, col)                                      │
│   ├─ Scroll(Up/Down)                                           │
│   └─ Fired: When user clicks/scrolls while dashboard focused   │
│                                                                 │
│ InputReceived                                                   │
│   └─ Fired: ANY input anywhere (rarely used)                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ LIFECYCLE EVENTS (Permission: ReadApplicationState)             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ CommandPaneOpened, CommandPaneExited                            │
│ EditPaneOpened, EditPaneExited                                  │
│ PaneClosed(u32)                                                 │
│   └─ Pane-specific events (already in PaneUpdate, bonus info)  │
│                                                                 │
│ Visible(bool)                                                   │
│   └─ Plugin became visible/invisible (tab switch)              │
│                                                                 │
│ BeforeClose                                                     │
│   └─ Plugin is about to be unloaded (cleanup opportunity)      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ ASYNC RESULT EVENTS                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ RunCommandResult(...), WebRequestResult(...)                    │
│ CustomMessage(name, payload)                                    │
│   └─ Results from run_command(), web_request(), or workers     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Plugin Lifecycle: State Machine

```
                        ┌─────────────────┐
                        │  Plugin Binary  │
                        │   (WASM file)   │
                        └────────┬────────┘
                                 │
                                 │ Zellij loads plugin
                                 │
                    ┌────────────▼─────────────┐
                    │ new() -> Self::default() │
                    │                          │
                    │ (Initialize state)       │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼──────────────────────────┐
                    │ load(&mut self, config)                │
                    │                                        │
                    │ - request_permission(...)             │
                    │ - subscribe(&[EventType::..., ...])  │
                    │ - set_selectable(true)                │
                    │ - (initialize state)                  │
                    │                                        │
                    │ [returns]                              │
                    └────────────┬──────────────────────────┘
                                 │
                    ┌────────────▼──────────────────────────┐
                    │        Ready for Events                │
                    │    (plugin runs until exit)            │
                    │                                        │
                    │  ┌────────────────────────────────┐   │
                    │  │ Event arrives (e.g., Key)      │   │
                    │  │                                │   │
                    │  │ update(&mut self, event)       │   │
                    │  │   -> match event {             │   │
                    │  │        Event::Key(...) => {...}│   │
                    │  │        ...                     │   │
                    │  │      }                         │   │
                    │  │   -> return true or false      │   │
                    │  │                                │   │
                    │  │ if update() returned true:     │   │
                    │  │   render(&mut self, r, c)      │   │
                    │  │     -> print table to stdout   │   │
                    │  │                                │   │
                    │  │ (loop back, wait for next      │   │
                    │  │  event)                        │   │
                    │  └────────────────────────────────┘   │
                    │                                        │
                    └────────────┬──────────────────────────┘
                                 │
                    ┌────────────▼──────────────────────────┐
                    │   User closes plugin or Zellij        │
                    │         unloads plugin                │
                    │                                        │
                    │   (optional) pipe(msg) with           │
                    │   BeforeClose event allows cleanup    │
                    │                                        │
                    │   Plugin exits                         │
                    └────────────────────────────────────────┘
```

---

## 4. Pane Information Structure: What's Available

```
PaneManifest {
    panes: {
        0 (tab 0): [                              ← Tab index
            PaneInfo {
                id: 1,                            ← Unique ID
                is_plugin: false,                 ← Terminal vs Plugin
                is_focused: true,                 ← Has focus in layer
                is_fullscreen: false,
                is_floating: false,               ← Layer (tiled/floating)
                is_suppressed: false,             ← Hidden but running
                title: "shell",                   ← Display name
                exited: false,                    ← Exit state
                exit_status: None,                ← Exit code (if exited)
                is_held: false,                   ← Paused for input
                
                pane_x: 0,                        ← Position (with frame)
                pane_y: 0,
                pane_columns: 80,
                pane_rows: 24,
                
                pane_content_x: 1,                ← Position (no frame)
                pane_content_y: 1,
                pane_content_columns: 78,
                pane_content_rows: 22,
            },
            PaneInfo {
                id: 2,
                is_plugin: false,
                is_focused: false,
                title: "editor",
                exited: false,
                // ... more fields
            },
        ],
        1 (tab 1): [
            // ... panes in second tab
        ],
    }
}
```

---

## 5. Plugin Control Flow: Dashboard Example

```
┌─────────────────────────────────────────────────────────┐
│ User Presses 'j' (Move Down)                            │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│ Zellij Server captures key                              │
│ Dashboard plugin has focus → sends Key event to plugin  │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│ Dashboard::update(Event::Key(...))                       │
│                                                         │
│  match key.bare_key {                                   │
│    BareKey::Char('j') => {                             │
│      self.selection = (self.selection + 1) % count      │
│      return true  // Request render                    │
│    }                                                    │
│    ...                                                  │
│  }                                                      │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│ update() returned true → Zellij calls render()         │
│                                                         │
│ Dashboard::render(rows, cols)                          │
│   - Build table from self.panes[self.active_tab]       │
│   - Highlight row at self.selection                    │
│   - print_table(table) → ANSI output to stdout         │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│ Dashboard pane on screen updates with new table         │
│ Selection moved down (next pane highlighted)            │
└──────────────────┬──────────────────────────────────────┘
                   │
└──────────────────────────────────────────────────────────┘
```

---

## 6. Dashboard State Machine

```
┌────────────────────────────────────────────────────────────┐
│ DashboardPlugin State                                      │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  panes: HashMap<usize, Vec<PaneInfo>>  ← All panes        │
│  active_tab: usize                     ← Current tab      │
│  selection: usize                      ← Selected row     │
│  mode_info: ModeInfo                   ← Theme/colors     │
│  filter_text: String                   ← Search filter    │
│                                                            │
└────────────────────────────────────────────────────────────┘

Events → State Changes → Render Updates:

Event::PaneUpdate(manifest)
  ├─ self.panes = manifest.panes
  ├─ (selection might be out of bounds now, clamp it)
  └─ render_needed = true

Event::TabUpdate(tabs)
  ├─ self.active_tab = get_active_tab_index(&tabs)
  ├─ (if tab changed, reset selection to 0)
  └─ render_needed = true

Event::Key(Key::Down)
  ├─ self.selection += 1
  ├─ (clamp to pane count)
  └─ render_needed = true

Event::Key(Enter)
  ├─ pane = self.panes[self.active_tab][self.selection]
  ├─ if pane.is_plugin:
  │    focus_plugin_pane(pane.id)
  │  else:
  │    focus_terminal_pane(pane.id)
  └─ render_needed = false (or true for visual feedback)

Event::Mouse(LeftClick(row, col))
  ├─ self.selection = row  (click to select)
  └─ render_needed = true
```

---

## 7. Execution Timeline: One Event → Render Cycle

```
Timeline (milliseconds):
┌─────┬──────────┬───────────┬────────┬───────┐
│  0  │   5      │    10     │   15   │  20   │
└─────┴──────────┴───────────┴────────┴───────┘
  │
  ├─→ User presses 'j'
  │
  ├──────→ Zellij server captures key
  │        (serializes KeyWithModifier)
  │
  ├───────────→ IPC send to dashboard plugin
  │             (via shared memory or channel)
  │
  ├────────────────→ Dashboard::update(Key)
  │                  - Update self.selection
  │                  - Return true
  │
  ├─────────────────→ Dashboard::render()
  │                   - Build table
  │                   - Serialize ANSI
  │                   - Write to stdout
  │
  └──────────────────────→ Zellij UI updates
                           on screen
```

---

## 8. Multi-Tab Support: Navigation

```
Tabs in Session:
┌────────┬────────┬────────┐
│ Tab 0  │ Tab 1  │ Tab 2  │
│ main   │ debug  │ scratch│
│ active │        │        │
└────────┴────────┴────────┘

Panes in Each Tab:
┌────────────────────────────────────────────┐
│ Tab 0 (main):                              │
│  - Pane 1: shell        [selected ▶]       │
│  - Pane 2: editor                          │
│  - Pane 3: monitor                         │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ Tab 1 (debug):                             │
│  - Pane 4: gdb          [not shown]        │
│  - Pane 5: logs                            │
└────────────────────────────────────────────┘

Navigation:
  User presses 'h' (left) or 'l' (right):
  ├─ self.active_tab = (self.active_tab - 1) % tabs.len()
  ├─ self.selection = 0  (reset selection)
  └─ render()  (show panes from new tab)

Result:
  User now sees Tab 1's panes in the table:
  ┌────────────────────────────────────────────┐
  │ Tab 1 (debug):                             │
  │  - Pane 4: gdb          [selected ▶]       │
  │  - Pane 5: logs                            │
  └────────────────────────────────────────────┘
```

---

## 9. Rendering: How ANSI Output Becomes UI

```
Dashboard::render() Output:
┌──────────────────────────────────────────────────┐
│ println!("ID | Title  | Status  | Size"..        │
│ print_table(table)  ← Uses zellij components   │
│ println!("\n[↑↓] Select [→←] Tab [Enter] Focus")│
└──────────────────────────────────────────────────┘
                      ↓
ANSI Escape Sequences:
┌──────────────────────────────────────────────────┐
│ \x1b[1;32m                ← Bold green             │
│ ╔════════════════════╗     (table border)         │
│ ║ ID │ Title │ Status║                           │
│ ╠════╪═══════╪═══════╣                           │
│ ║ 1  │ shell │ run   ║\x1b[7m                    │
│         (selected → reverse video)               │
│ ║ 2  │ edit  │ run   ║\x1b[0m                    │
│         (normal video)                           │
│ \x1b[0m                   ← Reset formatting      │
└──────────────────────────────────────────────────┘
                      ↓
Terminal Renders:
┌──────────────────────────────────────────────────┐
│ ╔════════════════════╗                           │
│ ║ ID │ Title │ Status║                           │
│ ╠════╪═══════╪═══════╣                           │
│ ║ 1  │ shell │ run   ║  ← highlighted            │
│ ║ 2  │ edit  │ run   ║                           │
│ ║ 3  │ mon.  │ exit:0║                           │
│ ╚════════════════════╝                           │
│ [↑↓] Select [→←] Tab [Enter] Focus               │
└──────────────────────────────────────────────────┘
```

---

## 10. Permission Flow

```
User starts Zellij with dashboard plugin:

1. Zellij loads dashboard.wasm
2. dashboard::load() is called
3. Plugin requests permissions:
   request_permission(&[
     PermissionType::ReadApplicationState,
     PermissionType::ChangeApplicationState,  // Optional
   ])
                      │
                      ▼
4. Zellij shows permission prompt:
   ┌──────────────────────────────────────┐
   │ Plugin "zellij-dashboard" requests:   │
   │  □ ReadApplicationState               │
   │  □ ChangeApplicationState             │
   │                                       │
   │ [Grant]  [Deny]  [Ask Later]         │
   └──────────────────────────────────────┘
                      │
    ┌─────────────────┼─────────────────┐
    │                 │                 │
   [Grant]        [Deny]          [Ask Later]
    │                 │                 │
    ▼                 ▼                 ▼
  Stored in      Plugin      Prompt each
  config         blocked       time
                 (limited
                  features)

5. If granted: Full access to pane info
   ├─ ReadApplicationState → receive PaneUpdate events
   ├─ ChangeApplicationState → focus/kill/resize panes
   └─ Continue execution

6. If denied: Plugin can still run
   ├─ No PaneUpdate events received
   ├─ Cannot control panes
   └─ Show "Permission denied" message
```

---

## 11. WASM Sandbox Boundary

```
Host Machine (Zellij Server)
┌──────────────────────────────────────────────────┐
│ File System, Process List, Network              │
│ (Dashboard plugin CANNOT directly access)       │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ WASM Sandbox (Dashboard Plugin)           │   │
│  │                                           │   │
│  │ Can only:                                 │   │
│  │  - Store internal state (HashMap, etc.)  │   │
│  │  - Receive events from server            │   │
│  │  - Call plugin API functions             │   │
│  │  - Return ANSI output                    │   │
│  │                                           │   │
│  │ Cannot:                                   │   │
│  │  - Read/write files (except via API)     │   │
│  │  - Make system calls                     │   │
│  │  - Access network directly               │   │
│  │  - Launch processes (except via API)     │   │
│  │                                           │   │
│  └──────────────────────────────────────────┘   │
│         ▲                    ▼                    │
│         │ Serialized        │ Serialized         │
│         │ Events            │ Output             │
│         │                   │                    │
└─────────┼───────────────────┼──────────────────┘
          │                   │
          │ Zellij Plugin API │
          │ (bridged by       │
          │  zellij-tile      │
          │  crate)           │
          │                   ▼
         Server State    Terminal Display
```

---

## Summary

These diagrams show:

1. **Data Flow** - How pane changes reach the plugin
2. **Event System** - All events available and when they fire
3. **Lifecycle** - Plugin initialization through execution
4. **State Structure** - What pane data looks like
5. **Control Flow** - How user input triggers renders
6. **State Machine** - Dashboard's internal state changes
7. **Timeline** - Millisecond-by-millisecond event processing
8. **Multi-Tab** - How tab navigation works
9. **Rendering** - ANSI escapes become visual UI
10. **Permissions** - User grants access to plugin features
11. **Sandbox** - Security boundary between plugin and OS

All of these enable building a real-time, interactive overview dashboard of all panes in Zellij.
