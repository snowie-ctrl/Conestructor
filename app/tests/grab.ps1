# Opens the built app, saves a screenshot after a delay, then quits. For checking layouts by eye.
#   grab.ps1                               the example track with cones placed, to build\tests\grab.png
#   grab.ps1 -Demo track -Out C:\tmp\a.png the example track without cones
#   grab.ps1 -Demo ''                      the empty window
# Settings go to build\tests\grab-settings, never the owner's.
param([string]$Demo = 'cones', [string]$Out = '', [int]$Delay = 3000)
$ErrorActionPreference = 'Stop'
$qt    = if ($env:CONESTRUCTOR_QT) { $env:CONESTRUCTOR_QT } else { 'D:\allNewQT6\6.11.1\msvc2022_64' }
$src   = Split-Path $PSScriptRoot -Parent
$build = Join-Path $src 'build\tests'
if (-not $Out) { $Out = Join-Path $build 'grab.png' }

$env:PATH = "$qt\bin;$env:PATH"
$env:CONESTRUCTOR_SETTINGS_DIR = Join-Path $build 'grab-settings'
$env:CONESTRUCTOR_DEMO = $Demo
$env:CONESTRUCTOR_GRAB = $Out
$env:CONESTRUCTOR_GRAB_DELAY = "$Delay"
# Piping a window program to Out-Null makes PowerShell wait for it to quit.
& (Join-Path $build 'appConestructor.exe') | Out-Null
Write-Output $Out
