# Copied from Gluttony app/tests/build.ps1; CONESTRUCTOR_ names and option.
# Configures and builds the app and its tests (Debug, tests on) from a plain shell.
# Paths default to the owner's machine; override with CONESTRUCTOR_QT / CONESTRUCTOR_QT_TOOLS / CONESTRUCTOR_VCVARS.
$ErrorActionPreference = 'Stop'
$qt     = if ($env:CONESTRUCTOR_QT)       { $env:CONESTRUCTOR_QT }       else { 'D:\allNewQT6\6.11.1\msvc2022_64' }
$tools  = if ($env:CONESTRUCTOR_QT_TOOLS) { $env:CONESTRUCTOR_QT_TOOLS } else { 'D:\allNewQT6\Tools' }
$vcvars = if ($env:CONESTRUCTOR_VCVARS)   { $env:CONESTRUCTOR_VCVARS }   else { 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat' }
$src    = Split-Path $PSScriptRoot -Parent
$build  = Join-Path $src 'build\tests'

$env:PATH = "$tools\CMake_64\bin;$tools\Ninja;$qt\bin;$env:PATH"
cmd /c "`"$vcvars`" >nul && cmake -S `"$src`" -B `"$build`" -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=$qt -DCONESTRUCTOR_BUILD_TESTS=ON && cmake --build `"$build`""
exit $LASTEXITCODE
