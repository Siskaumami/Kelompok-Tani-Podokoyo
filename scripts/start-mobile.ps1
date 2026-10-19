$ErrorActionPreference = "Stop"

$Repo = "D:\Coding\BM-Web-Operasional\Kelompok-Tani-Podokoyo"
$Mobile = "$Repo\apps\mobile"
$Emulator = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"
$Adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

Write-Host "Starting Android emulator..."

$device = & $Adb devices

if ($device -notmatch "emulator-5554\s+device") {
    Start-Process -FilePath $Emulator -ArgumentList @(
        "-avd","Pixel_9_Pro",
        "-memory","2048",
        "-no-boot-anim",
        "-gpu","swiftshader",
        "-feature","-Vulkan"
    )
}

& $Adb wait-for-device

do {
    Start-Sleep -Seconds 2
    $boot = (& $Adb -s emulator-5554 shell getprop sys.boot_completed).Trim()
} until ($boot -eq "1")

Write-Host "Android boot completed."

if (-not ("Win32EmuFix" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Win32EmuFix {
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(
        IntPtr hWnd,
        int nCmdShow
    );

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags
    );

    [DllImport("user32.dll")]
    public static extern bool RedrawWindow(
        IntPtr hWnd,
        IntPtr lprcUpdate,
        IntPtr hrgnUpdate,
        uint flags
    );
}
"@
}

$emu = $null

for ($i = 0; $i -lt 30; $i++) {
    $emu = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1

    if ($emu) {
        break
    }

    Start-Sleep -Seconds 1
}

if ($emu) {
    $h = [IntPtr]$emu.MainWindowHandle

    [void][Win32EmuFix]::ShowWindowAsync($h, 6)
    Start-Sleep -Milliseconds 500

    [void][Win32EmuFix]::ShowWindowAsync($h, 9)

    [void][Win32EmuFix]::SetWindowPos(
        $h,
        [IntPtr]::Zero,
        100,
        100,
        520,
        920,
        0x0020
    )

    [void][Win32EmuFix]::RedrawWindow(
        $h,
        [IntPtr]::Zero,
        [IntPtr]::Zero,
        0x0185
    )

    Write-Host "Emulator window fixed."
}
else {
    Write-Warning "Emulator window handle was not found."
}

Set-Location $Mobile

Write-Host "Starting Tani Desa..."

flutter run --profile -d emulator-5554 `
    --dart-define=API_BASE_URL=http://10.0.2.2:3000 `
    --dart-define=APP_ORIGIN=http://10.0.2.2:5173