# Desktop Toggle

A small floating button for Windows that hides and shows your desktop icons with one click.

A normal desktop shortcut can't do this job, because it would hide itself along with everything else. Desktop Toggle is a tiny round button that lives on the desktop layer instead, so it is always there to bring your icons back.

- **Click** to hide or show the desktop icons
- **Drag** to move it anywhere; it remembers the spot
- **Right-click** to exit
- Sits behind your windows, stays out of the taskbar and Alt+Tab, and dims until you hover over it
- Starts with Windows
- No admin rights, nothing to compile: two small script files

## Requirements

Windows 10 or 11. It uses the Windows PowerShell that ships with Windows.

## Install

Open **PowerShell** (press Start, type `powershell`, press Enter), paste this line and press Enter:

```powershell
irm https://raw.githubusercontent.com/AverageBENNAL/DesktopToggle/main/install.ps1 | iex
```

The button appears in the bottom-right corner of your desktop.

### Manual install

1. Click **Code > Download ZIP** at the top of this page and extract it.
2. Right-click `install.ps1` and choose **Run with PowerShell**.

If Windows blocks the script, run this from PowerShell inside the extracted folder instead:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Either way, the files are copied to `%LOCALAPPDATA%\Programs\DesktopToggle` and a shortcut is added to your Startup folder.

## Uninstall

```powershell
irm https://raw.githubusercontent.com/AverageBENNAL/DesktopToggle/main/uninstall.ps1 | iex
```

Or run `uninstall.ps1` from a downloaded copy. If your icons are hidden when you uninstall, right-click the desktop and choose **View > Show desktop icons** to bring them back.

## Customising the look

The button is defined in the XAML block near the top of `DesktopToggle.ps1` (size, colours, corner radius, idle opacity). Edit the installed copy, then right-click the button to exit and run `DesktopToggle.vbs` to start it again.

## How it works

`DesktopToggle.ps1` draws a borderless transparent WPF window and, when clicked, sends Explorer the same command as the desktop's own **View > Show desktop icons** menu item. Your icons and their layout are not touched, only their visibility. `DesktopToggle.vbs` just starts the script without a console window.

## License

[MIT](LICENSE)
