# Floating desktop button that shows/hides the desktop icons.
# Left-click: toggle. Drag: move. Right-click: exit.

$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'DesktopToggle_SingleInstance', [ref]$created)
if (-not $created) { exit }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class DesktopNative
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")]
    static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr")]
    static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int index);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr")]
    static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int index, IntPtr value);
    [DllImport("user32.dll")]
    static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);

    const uint WM_COMMAND = 0x0111;
    const int CMD_TOGGLE_ICONS = 0x7402;
    const int GWL_EXSTYLE = -20;
    const int GWLP_HWNDPARENT = -8;
    const long WS_EX_TOOLWINDOW = 0x80;
    const long WS_EX_NOACTIVATE = 0x08000000;
    static readonly IntPtr HWND_BOTTOM = new IntPtr(1);

    static IntPtr Progman() { return FindWindow("Progman", null); }

    // The icon view lives under Progman, or under a WorkerW once the wallpaper has been re-hosted.
    static IntPtr DefView()
    {
        IntPtr view = FindWindowEx(Progman(), IntPtr.Zero, "SHELLDLL_DefView", null);
        IntPtr worker = IntPtr.Zero;
        while (view == IntPtr.Zero)
        {
            worker = FindWindowEx(IntPtr.Zero, worker, "WorkerW", null);
            if (worker == IntPtr.Zero) break;
            view = FindWindowEx(worker, IntPtr.Zero, "SHELLDLL_DefView", null);
        }
        return view;
    }

    public static void ToggleIcons()
    {
        IntPtr view = DefView();
        if (view != IntPtr.Zero) SendMessage(view, WM_COMMAND, new IntPtr(CMD_TOGGLE_ICONS), IntPtr.Zero);
    }

    public static bool IconsVisible()
    {
        IntPtr list = FindWindowEx(DefView(), IntPtr.Zero, "SysListView32", null);
        return list != IntPtr.Zero && IsWindowVisible(list);
    }

    // Keep the button on the desktop layer: owned by the desktop (survives Win+D),
    // hidden from Alt+Tab, never steals focus, below normal windows.
    public static void PinToDesktop(IntPtr hWnd)
    {
        long ex = GetWindowLongPtr(hWnd, GWL_EXSTYLE).ToInt64();
        SetWindowLongPtr(hWnd, GWL_EXSTYLE, new IntPtr(ex | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE));
        SetWindowLongPtr(hWnd, GWLP_HWNDPARENT, Progman());
        SendToBottom(hWnd);
    }

    public static void SendToBottom(IntPtr hWnd)
    {
        SetWindowPos(hWnd, HWND_BOTTOM, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010); // NOSIZE | NOMOVE | NOACTIVATE
    }
}
'@

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Desktop Toggle" Width="64" Height="64"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" ShowInTaskbar="False" ShowActivated="False"
        WindowStartupLocation="Manual" Opacity="0.55" Cursor="Hand">
    <Grid>
        <Border Name="Disc" Width="40" Height="40" CornerRadius="20" BorderThickness="1">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                    <GradientStop Color="#E62A2A30" Offset="0"/>
                    <GradientStop Color="#E6141417" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
            <Border.BorderBrush>
                <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
                    <GradientStop Color="#55FFFFFF" Offset="0"/>
                    <GradientStop Color="#14FFFFFF" Offset="1"/>
                </LinearGradientBrush>
            </Border.BorderBrush>
            <Border.Effect>
                <DropShadowEffect BlurRadius="12" ShadowDepth="2" Direction="270" Opacity="0.45"/>
            </Border.Effect>
            <TextBlock Name="Glyph" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="16"
                       Foreground="#F2FFFFFF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
    </Grid>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$glyph = $window.FindName('Glyph')

$stateFile = Join-Path $env:LOCALAPPDATA 'DesktopToggle\position.json'

function Update-Glyph {
    if ([DesktopNative]::IconsVisible()) {
        $glyph.Text = [string][char]0xE7B3   # eye
        $window.ToolTip = 'Hide desktop icons'
    } else {
        $glyph.Text = [string][char]0xED1A   # eye, struck through
        $window.ToolTip = 'Show desktop icons'
    }
}

function Set-Fade([double]$to) {
    $anim = New-Object Windows.Media.Animation.DoubleAnimation($to, [TimeSpan]::FromMilliseconds(160))
    $window.BeginAnimation([Windows.Window]::OpacityProperty, $anim)
}

# Start position: last saved spot if it is still on screen, otherwise bottom-right corner.
$area = [Windows.SystemParameters]::WorkArea
$window.Left = $area.Right - 88
$window.Top = $area.Bottom - 88
if (Test-Path $stateFile) {
    try {
        $saved = Get-Content $stateFile -Raw | ConvertFrom-Json
        $vl = [Windows.SystemParameters]::VirtualScreenLeft
        $vt = [Windows.SystemParameters]::VirtualScreenTop
        $vr = $vl + [Windows.SystemParameters]::VirtualScreenWidth
        $vb = $vt + [Windows.SystemParameters]::VirtualScreenHeight
        if ($saved.Left -ge $vl -and $saved.Left -le ($vr - 64) -and $saved.Top -ge $vt -and $saved.Top -le ($vb - 64)) {
            $window.Left = $saved.Left
            $window.Top = $saved.Top
        }
    } catch {}
}

$window.Add_SourceInitialized({
    $script:hwnd = (New-Object Windows.Interop.WindowInteropHelper $window).Handle
    [DesktopNative]::PinToDesktop($script:hwnd)
    Update-Glyph
})

$window.Add_MouseEnter({ Set-Fade 1.0 })
$window.Add_MouseLeave({ Set-Fade 0.55 })

$window.Add_MouseLeftButtonDown({
    $left = $window.Left
    $top = $window.Top
    $window.DragMove()   # returns when the mouse button is released
    if ([Math]::Abs($window.Left - $left) -lt 3 -and [Math]::Abs($window.Top - $top) -lt 3) {
        [DesktopNative]::ToggleIcons()
        Update-Glyph
    } else {
        New-Item -ItemType Directory -Force (Split-Path $stateFile) | Out-Null
        @{ Left = $window.Left; Top = $window.Top } | ConvertTo-Json | Set-Content $stateFile -Encoding utf8
    }
    [DesktopNative]::SendToBottom($script:hwnd)
})

$menu = New-Object Windows.Controls.ContextMenu
$exit = New-Object Windows.Controls.MenuItem
$exit.Header = 'Exit Desktop Toggle'
$exit.Add_Click({ $window.Close() })
[void]$menu.Items.Add($exit)
$window.ContextMenu = $menu

# Icons can also be toggled from the desktop's own right-click menu; keep the glyph in sync.
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(2)
$timer.Add_Tick({ Update-Glyph })
$timer.Start()

[void]$window.ShowDialog()
$mutex.ReleaseMutex()
