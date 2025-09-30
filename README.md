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

### Managing API Keys with 1Password

The `fetch-api-key` tool provides SSH agent-like workflow for API credentials:

```bash
# Interactive mode - select from fzf menu
eval $(fetch-api-key)

# Non-interactive mode - fetch specific key
eval $(fetch-api-key OPENAI_API_KEY)
```

#### Setting Up API Credentials in 1Password

1. **Create an API Credential item** in any 1Password vault:
   - Click "New Item" → Select "API Credential"
   - **Title**: Human-readable name (e.g., "OpenAI API")
   - **credential**: Paste your actual API key
   - **hostname**: Service URL (e.g., `api.openai.com`) - optional but helpful

2. **Add tag for environment variable name**:
   - Add tag: `env-var-name=OPENAI_API_KEY`
   - Format: `env-var-name=YOUR_VAR_NAME`

3. **Use in your shell**:
   ```bash
   eval $(fetch-api-key --account --account my.1password.com OPENAI_API_KEY)
   opencode  # Now has access to OPENAI_API_KEY
   ```

The tool searches across all accessible 1Password vaults in all signed-in accounts. Credentials are only stored in your current shell session and trigger 1Password's biometric authentication popup when accessed.

### Managing Files

Each family member can manage their personal dotfiles in their respective folder, while server administrators can organize configurations and scripts by server name.
