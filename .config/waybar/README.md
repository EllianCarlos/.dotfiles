# Waybar Configuration

Custom Waybar setup with enhanced monitoring and interactive modules.

## Required Programs

### Essential
- **waybar** - Status bar for Wayland compositors
- **bottom** (btm) - System monitor with customizable views
- **kitty** - Terminal emulator (for launching bottom)
- **wofi** - Application launcher (for clipboard history)
- **hyprland** - Window manager (integration)

### Optional but Recommended
- **cliphist** - Clipboard history manager
- **libnotify** - Desktop notifications
- **wl-clipboard** - Wayland clipboard utilities
- **pamixer** - PulseAudio volume control
- **brightnessctl** - Brightness control
- **playerctl** - Media player control
- **grim** - Screenshot utility
- **slurp** - Screen area selection

### Installation (NixOS)

Add to your `~/.config/home-manager/home.nix`:

```nix
home.packages = with pkgs; [
  waybar
  bottom
  kitty
  wofi
  cliphist
  libnotify
  wl-clipboard
  pamixer
  brightnessctl
  playerctl
  grim
  slurp
];
```

Then run:
```bash
home-manager switch
```

## Features

### 📊 Interactive System Monitoring

Click on system metrics in waybar to launch focused views in bottom:

#### Memory View (Click RAM  30%)

**Layout:**
- **Top 30%**: Memory widget showing RAM/SWAP usage graphs with actual values (GB/MB)
- **Bottom 70%**: Process list sorted by memory consumption

**Columns Displayed:**
- PID - Process ID
- Name - Process name
- Mem% - Memory percentage
- Mem - Actual memory usage (MB/GB)
- R/s - Read speed
- W/s - Write speed
- User - Process owner
- State - Process state

**Features:**
- Shows cache and buffer memory
- Processes displayed with actual memory consumption (not just %)
- Easy to identify RAM hogs and memory leaks
- Includes SWAP usage monitoring

**Usage:**
- Click the  icon (RAM percentage) in waybar
- Sort by clicking column headers
- Use `/` to search for processes
- Press `?` for all keybindings

#### CPU View (Click CPU  15%)

**Layout:**
- **Top 30%**: Split view
  - CPU widget (66%) - per-core usage graphs
  - Temperature widget (33%) - CPU temperatures
- **Bottom 70%**: Process list sorted by CPU usage

**Columns Displayed:**
- PID - Process ID
- Name - Process name
- CPU% - CPU usage percentage
- Mem% - Memory percentage
- User - Process owner
- State - Process state
- Time - CPU time consumed

**Features:**
- Shows current CPU usage per process
- Temperature monitoring alongside CPU usage
- Per-core CPU usage visualization
- Easy to identify CPU-intensive processes
- Thread-aware monitoring

**Usage:**
- Click the  icon (CPU percentage) in waybar
- Monitor temperature spikes with CPU load
- Sort by any column
- Use `/` to search for processes

### 🎨 Enhanced Modules

#### Tooltips
Hover over modules for detailed information:
- **CPU**: Shows usage, load average, and core frequency
- **Memory**: Displays RAM and SWAP usage in GB
- **Battery**: Shows time remaining and power consumption
- **Network**: Signal strength, IP address, bandwidth

#### Disk Space
- Real-time disk usage percentage
- Tooltip shows used/free space

#### Temperature
- System temperature monitoring
- Configurable critical threshold (80°C)
- Path: `/sys/class/hwmon/hwmon2/temp1_input` (adjust if needed)

#### Network
- Live bandwidth monitoring
- Upload/download speeds displayed
- WiFi/Ethernet support

#### Persistent Workspaces
- Workspaces 1-5 always visible
- Simple number display (no icons)
- Easy navigation

## Configuration Files

### Main Configuration
- **config** - Module definitions and settings
- **style.css** - Catppuccin Mocha theme styling

### Bottom Configs
- **bottom-memory.toml** - Memory-focused layout
- **bottom-cpu.toml** - CPU-focused layout

### Scripts
- **bottom-memory.sh** - Launches memory view
- **bottom-cpu.sh** - Launches CPU view
- **mediaplayer.py** - Media player integration
- **weather.sh** - Weather information
- **power-menu.sh** - Power menu
- **keyhint.sh** - Keyboard shortcuts

## Customization

### Adjusting Temperature Sensor

If temperature isn't showing, find your sensor:

```bash
ls /sys/class/hwmon/
```

Then update in `config`:
```json
"temperature": {
    "hwmon-path": "/sys/class/hwmon/hwmonX/temp1_input",  // Change X
    ...
}
```

### Changing Update Intervals

Edit intervals in `config`:
```json
"cpu": {
    "interval": 5,  // Update every 5 seconds
    ...
}
```

### Customizing Bottom Views

Edit the TOML files:
- `bottom-memory.toml` - Change memory view layout/columns
- `bottom-cpu.toml` - Change CPU view layout/columns

Example - Add more columns to process list:
```toml
[processes]
columns = ["PID", "Name", "CPU%", "Mem%", "R/s", "W/s", "User", "State"]
```

### Font Sizes

Adjust in `style.css`:
```css
window#waybar {
    font-size: 14px;  /* Change bar font size */
}

#workspaces {
    font-size: 12px;  /* Workspace numbers */
}
```

## Troubleshooting

### Waybar Not Starting
```bash
# Check for JSON errors
waybar 2>&1 | grep error

# Validate JSON
cat ~/.config/waybar/config | jq .
```

### Bottom Scripts Not Working
```bash
# Make scripts executable
chmod +x ~/.config/waybar/bottom-*.sh

# Test directly
~/.config/waybar/bottom-memory.sh
~/.config/waybar/bottom-cpu.sh
```

### Temperature Not Showing
```bash
# Find your sensor
ls -la /sys/class/hwmon/hwmon*/temp*_input

# Test reading
cat /sys/class/hwmon/hwmon2/temp1_input
```

### Modules Without Background
Check if module is in the CSS selector list in `style.css`:
```css
#battery,
#clock,
#cpu,
#disk,        /* Add missing modules here */
#memory,
...
```

## Reload Waybar

After making changes:
```bash
pkill waybar; waybar &
```

Or add to Hyprland config for hot reload:
```conf
bind = $mainMod SHIFT, W, exec, pkill waybar; waybar &
```

## Theme

Using **Catppuccin Mocha** color scheme with:
- Transparent background
- Rounded corners (20px)
- Custom colors per module
- Intel One Mono Nerd Font

## Key Bindings

| Action | Key/Click |
|--------|-----------|
| Open memory monitor | Click RAM icon |
| Open CPU monitor | Click CPU icon |
| Toggle audio | Click volume icon |
| Open pavucontrol | Right-click volume |
| Network manager | Click network icon |
| Sort processes | Click column headers in bottom |
| Search processes | Press `/` in bottom |
| Help | Press `?` in bottom |

## Resources

- [Waybar Wiki](https://github.com/Alexays/Waybar/wiki)
- [Bottom Documentation](https://github.com/ClementTsang/bottom)
- [Catppuccin Theme](https://github.com/catppuccin/catppuccin)
- [Hyprland Wiki](https://wiki.hyprland.org/)

## Credits

- Theme: Catppuccin Mocha
- Icons: Nerd Fonts
- Font: Intel One Mono Nerd Font
