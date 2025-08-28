# Neovim Configuration

This is mrdavidlaing's personal Neovim configuration, part of the Laingville dotfiles system.

## Philosophy

This configuration prioritizes **simplicity, reliability, and consistency** with the broader terminal environment:

### Core Principles

- **Minimal but Powerful** - Essential features without bloat
- **Treesitter Over Legacy** - Modern syntax highlighting, no vim syntax conflicts  
- **Theme Consistency** - Perfect Solarized Dark matching across WezTerm/tmux/nvim
- **Error-Free Startup** - Robust configuration that never crashes
- **Repository-Focused** - Optimized for dotfiles, scripts, and documentation editing

### Visual Design

- **Solarized Dark** theme with exact color matching to WezTerm terminal
- **Background**: `#002b36`, **Foreground**: `#eee8d5`, **Selection**: `#ff8800`
- Consistent visual experience across the entire development environment

## Structure

```
.config/nvim/
├── init.lua              # Entry point - minimal bootstrap
├── lua/
│   ├── config/           # Core Neovim settings
│   │   ├── options.lua   # Editor behavior & preferences
│   │   ├── keymaps.lua   # Key bindings & shortcuts
│   │   └── autocmds.lua  # Automatic commands & events
│   └── plugins/          # Plugin specifications (lazy.nvim)
│       ├── colorscheme.lua  # Solarized Dark theme
│       ├── treesitter.lua   # Modern syntax highlighting
│       ├── telescope.lua    # Fuzzy finder & search
│       ├── lsp.lua         # Language server support
│       ├── which-key.lua   # Key binding discovery
│       └── editor.lua      # Editor enhancements
└── CLAUDE.md            # This documentation
```

## Key Features

### 🎨 **Theme & Visual**
- **Solarized Dark** perfectly matched to WezTerm
- **Consistent colors** across terminal and editor
- **Clean UI** with subtle visual enhancements

### 🌳 **Syntax Highlighting**
- **Treesitter-powered** - modern, fast, accurate
- **Repository languages** - bash, lua, yaml, markdown, json, nix, terraform, go, kubernetes, docker
- **No vim syntax conflicts** - eliminates E1155 errors

### 🔍 **File Navigation**
- **Telescope** fuzzy finder for files, buffers, search
- **Git integration** - commits, branches, status browsing
- **Quick access** via `<leader>f` prefix

### 🧠 **Language Support**
- **LSP servers** for intelligent editing (when installed)
  - `lua-language-server` - Lua (for nvim config)
  - `bash-language-server` - Bash (for scripts)  
  - `marksman` - Markdown (for documentation)
  - `nil` - Nix (for nix expressions and configurations)
  - `terraform-ls` - Terraform (for infrastructure as code)
  - `gopls` - Go (for golang applications)
  - `yaml-language-server` - YAML (with K8s, GitHub Actions, Docker Compose schemas)
  - `docker-langserver` - Docker (for Dockerfiles and containerization)
- **Auto-completion** with nvim-cmp
- **Graceful degradation** when LSP servers aren't available

### ⚙️ **Editor Enhancements**
- **Auto-pairs** - Smart bracket/quote completion
- **Smart commenting** - Context-aware comment toggling  
- **Git integration** - Changes shown in gutter
- **Indent guides** - Visual indentation helpers
- **Surround operations** - Quick text manipulation

## Key Bindings

### Leader Key: `<space>`

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ff` | Find files | Telescope file finder |
| `<leader>fs` | Live grep | Search text in files |
| `<leader>fb` | Browse buffers | Switch between open files |
| `<leader>gc` | Git commits | Browse commit history |
| `gd` | Go to definition | Jump to symbol definition |
| `gr` | Find references | Show all references |
| `K` | Hover help | Show documentation |
| `<leader>ca` | Code actions | Available code fixes |

### Quick Navigation
- `jk` - Exit insert mode (faster than Escape)
- `<leader>sv/sh` - Split windows vertically/horizontally
- `<leader>to/tx` - Open/close tabs

## Dependencies

### Required
- **Neovim 0.8+** - Core editor
- **Git** - For lazy.nvim plugin manager

### Optional (LSP)
- `lua-language-server` - Lua LSP support
- `bash-language-server` - Bash LSP support  
- `marksman` - Markdown LSP support
- `nil` - Nix LSP support
- `terraform-ls` - Terraform LSP support
- `gopls` - Go LSP support
- `yaml-language-server` - YAML LSP support
- `dockerfile-language-server-nodejs` - Docker LSP support

All LSP servers are automatically installed via `./setup-user` from `packages.yaml`

## Installation

This configuration is managed by the Laingville dotfiles system:

```bash
# Install neovim and LSP servers via packages.yaml
./setup-user

# The nvim config is automatically symlinked via symlinks.yaml
# Works on: Arch Linux, WSL, macOS, Windows
```

## Maintenance

### Plugin Management
- **Lazy.nvim** handles all plugins automatically
- **Lazy loading** - plugins load only when needed
- **Auto-install** - missing plugins install on first run

### Updates
- `:Lazy` - Open plugin manager interface
- `:Lazy update` - Update all plugins
- `:TSUpdate` - Update Treesitter parsers

### Health Checks
- `:checkhealth` - Verify nvim installation
- `:checkhealth lazy` - Check plugin manager
- `:checkhealth treesitter` - Verify syntax highlighting

## Troubleshooting

### Common Issues

**LSP not working?**
- Check if language servers are installed: `lua-language-server --version`
- Install via package manager or see warnings on nvim startup

**Colors look wrong?** 
- Ensure terminal supports 24-bit color
- Check that WezTerm is using Solarized Dark theme

**Plugins not loading?**
- Run `:Lazy` to see plugin status
- Check internet connection for plugin downloads

This configuration is designed to be reliable, fast, and perfectly integrated with your terminal environment while providing modern editing capabilities.