# Fallback viewer: shows stats.txt in an always-on-top window.
# Use it if the in-game overlay does not appear. Run the game in Borderless/Windowed mode.
# Start: right-click > Run with PowerShell (or: powershell -ExecutionPolicy Bypass -File overlay.ps1)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$statsFile = Join-Path $PSScriptRoot 'stats.txt'

$form = New-Object Windows.Forms.Form
$form.Text = 'Fechtbuch'
$form.TopMost = $true
$form.BackColor = [Drawing.Color]::Black
$form.Opacity = 0.8
$form.Size = New-Object Drawing.Size(620, 640)
$form.StartPosition = 'Manual'
$form.Location = New-Object Drawing.Point(20, 20)

$label = New-Object Windows.Forms.Label
$label.Dock = 'Fill'
$label.ForeColor = [Drawing.Color]::White
$label.Font = New-Object Drawing.Font('Consolas', 10)
$form.Controls.Add($label)

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 250
$timer.Add_Tick({
    try { $label.Text = [IO.File]::ReadAllText($statsFile) } catch { $label.Text = "Waiting for $statsFile ..." }
})
$timer.Start()
[void]$form.ShowDialog()
