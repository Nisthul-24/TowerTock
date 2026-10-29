$desktop = [Environment]::GetFolderPath("Desktop")
$wsh = New-Object -ComObject WScript.Shell
$shortcutPath = Join-Path $desktop "Play TowerTock.lnk"
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "C:\Users\nisth\godot_bin\Godot_v4.3-stable_win64.exe"
$shortcut.Arguments = '--path "C:\Users\nisth\towertock"'
$shortcut.WorkingDirectory = "C:\Users\nisth\towertock"
$shortcut.Description = "Play TowerTock"
$shortcut.Save()
Write-Host "Created shortcut at $shortcutPath"
