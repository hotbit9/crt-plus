# CRT Plus

> **Cool Retro Term — Supercharged**

A fork of [cool-retro-term](https://github.com/Swordfish90/cool-retro-term) with enhanced profile management and authentic CRT simulation features.

|Default Amber|C:\ IBM DOS|$ Default Green|
|---|---|---|
|![Default Amber Cool Retro Term](https://user-images.githubusercontent.com/121322/32070717-16708784-ba42-11e7-8572-a8fcc10d7f7d.gif)|![IBM DOS](https://user-images.githubusercontent.com/121322/32070716-16567e5c-ba42-11e7-9e64-ba96dfe9b64d.gif)|![Default Green Cool Retro Term](https://user-images.githubusercontent.com/121322/32070715-163a1c94-ba42-11e7-80bb-41fbf10fc634.gif)|

## New Features

### Per-Tab/Window Profiles
Each tab and window maintains its own independent profile. Change the look of one terminal without affecting others.

### Default Profile System
- **Set Default** button to choose which profile loads on startup and for new windows/tabs
- Star indicator (★) shows which profile is set as default
- **Update** button to save current settings to the selected profile
- **Reset** button to restore built-in profiles to their original values

### Profile Menu Sections
The Profiles menu separates built-in and custom profiles with a visible divider for quick access.

### 75Ω/Hi-Z Impedance Switch
Simulates the input termination switch found on real CRT monitors:
- **75Ω (terminated)** — Normal signal levels
- **Hi-Z (unterminated)** — Boosted brightness and glow, just like a real overdriven CRT

### Dynamic Window & Tab Titles
Titles update automatically as you work, showing the current directory with `~` substitution — just like macOS Terminal.
- Default display: `~/Projects` or `~/Projects: vim`
- When a CLI app sets its own title, it shows until the app exits, then reverts to the directory
- **Rename**: Right-click a tab or use **File > Rename Tab** (Cmd+R / Ctrl+Shift+R)
- **Reset**: Right-click a tab and select "Reset Name", or use **File > Reset Tab Name**
- Custom names show as `Custom Name (~/dir)` or `Custom Name (~/dir): process`

### Split Panes
Split any terminal into multiple panes for side-by-side workflows:
- **Split Right**: Cmd+D (Ctrl+Shift+D on Linux)
- **Split Down**: Cmd+Shift+D (Ctrl+Shift+E on Linux)
- **Navigate**: Cmd+] / Cmd+[ to cycle focus between panes
- **Close Pane**: Cmd+Shift+W
- Each pane maintains its own independent profile, directory, and process tracking
- Panes can be split recursively — split any pane further in either direction

### Clickable File Paths & URLs
Cmd+click (macOS) or Ctrl+click (Linux) to open file paths, URLs, and directories directly from terminal output:
- **File paths**: Opens in your editor — auto-detects Cursor, VS Code, Sublime Text, or uses `$VISUAL`/`$EDITOR`
- **URLs**: Opens in default browser
- **Directories**: Opens in Finder (macOS) / file manager (Linux)
- **Line numbers**: Supports `file.ext:line:col` — jumps straight to the right line
- **Hover preview**: Hold Cmd/Ctrl and hover to see underline highlighting before clicking
- **Smart detection**: Handles filenames with spaces, wrapped lines, and quoted paths
- **Right-click menu**: "Open" item appears when right-clicking on a clickable target
- **Remote sessions**: Over SSH/mosh, sends editor commands to the remote terminal instead
- **Configurable**: Set preferred editor in Settings > Advanced

### Dock Badge Notifications
Get notified when background tabs, panes, or windows need attention:
- **Terminal bell** (`\a`) increments the dock icon badge count
- **Background activity** sets a badge when new output appears in unfocused panes
- Tab bar shows a **●** dot on tabs with pending notifications
- Window title shows a **●** dot when any tab/pane has a badge
- Badges clear automatically when you focus the relevant pane or tab

### Drag & Drop Support
- **Into terminal window**: Drag a file or folder and its path is inserted at the cursor — ready for `cd`, `cat`, or any command
- **Onto dock icon** (macOS): Drag a folder onto the dock icon to open a new terminal window in that directory

### macOS Improvements
- Multi-window support with a single dock icon
- **New Window** and **New Window with Profile** from dock menu (right-click) and File menu
- Cmd+, opens Settings

## Description
CRT Plus is a terminal emulator which mimics the look and feel of the old cathode tube screens.
It has been designed to be eye-candy, customizable, and reasonably lightweight.

It uses the QML port of qtermwidget (Konsole): https://github.com/Swordfish90/qmltermwidget.

This terminal emulator works under Linux and macOS and requires Qt6.

Settings such as colors, fonts, and effects can be accessed via context menu.

## Screenshots
![Image](<https://i.imgur.com/TNumkDn.png>)
![Image](<https://i.imgur.com/hfjWOM4.png>)
![Image](<https://i.imgur.com/GYRDPzJ.jpg>)

## Building

### macOS
```bash
brew install qt6
git clone --recursive https://github.com/hotbit9/cool-retro-term.git
cd cool-retro-term
qmake6 && make
```

### Linux
Check out the wiki for [Linux build instructions](https://github.com/Swordfish90/cool-retro-term/wiki/Build-Instructions-(Linux)).

## Credits
Based on [cool-retro-term](https://github.com/Swordfish90/cool-retro-term) by Filippo Scognamiglio.
