# Laingville

Family home network management repository for organizing dotfiles and server configurations.

## Structure

### Dotfiles
Personal configuration files for family members:
- `dotfiles/timmmmmmer/` - Timmmmmmer's personal dotfiles
- `dotfiles/mrdavidlaing/` - mrdavidlaing's personal dotfiles  
- `dotfiles/shared/` - Common configurations used by both family members

### Servers
Linux server configurations and management:
- `servers/baljeet/` - Baljeet server configs and scripts
- `servers/phineas/` - Phineas server configs and scripts
- `servers/ferb/` - Ferb server configs and scripts
- `servers/shared/` - Common server tools and scripts

## Usage

### Setting Up Dotfiles

Run the setup script to automatically configure your dotfiles:

```bash
./setup-user
```

The script will:
- Detect your username automatically
- Map users to their dotfiles folders:
  - `timmy` → `dotfiles/timmmmmmer/`
  - `david` → `dotfiles/mrdavidlaing/`
  - Other users → `dotfiles/shared/`
- Create symbolic links from your home directory to the appropriate dotfiles
- Overwrite any existing dotfiles

### Managing Files

Each family member can manage their personal dotfiles in their respective folder, while server administrators can organize configurations and scripts by server name.