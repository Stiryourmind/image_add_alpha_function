@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ======================= Settings =======================
set "WATCH=assets"          & rem folder to watch
set "OUT=assets\output"     & rem where results are saved
set "INTERVAL=1"            & rem seconds between folder checks
set "JOBS=4"                & rem images processed at the same time
set "SCALE=0.5"             & rem 1 = full size, 0.5 = 50%%, 0.25 = 25%%
set "COMPRESSION=3"         & rem PNG compression 0-9 (0 = fastest/biggest, 9 = slowest/smallest)
set "PRED=none"             & rem none = fastest, mixed = smaller files but slower
set "USE_PNGQUANT=0"        & rem 1 = lossy 256-color compression (much smaller)
set "QUALITY=65-85"         & rem pngquant quality range, min-max (0-100)
set "FFMPEG=ffmpeg"         & rem or full path, e.g. C:\ffmpeg\bin\ffmpeg.exe
set "PNGQUANT=pngquant"     & rem or full path, e.g. C:\tools\pngquant.exe
rem ========================================================

set "SELF=%~f0"
cd /d "%~dp0"
set "STATE=%OUT%\_state"

rem Build the filter (merge alpha, then scale if needed)
if "%SCALE%"=="1" (set "SCALE_F=") else set "SCALE_F=,scale=iw*%SCALE%:ih*%SCALE%:flags=lanczos"
set "FILTER=[1:v]format=gray[a];[0:v][a]alphamerge%SCALE_F%,format=rgba[out]"

rem Background workers re-enter the script here
if "%~1"==":work" goto work

if not exist "%OUT%"   mkdir "%OUT%"
if not exist "%STATE%" mkdir "%STATE%"
rem Clean up leftovers from a previous run
del /q "%STATE%\*.lock" "%STATE%\*.pending" "%STATE%\*_tmp.png" "%STATE%\*_q.png" 2>nul

"%FFMPEG%" -version >nul 2>&1 || (
  echo ffmpeg not found. Install it with: winget install --id Gyan.FFmpeg
  pause & exit /b 1
)
if "%USE_PNGQUANT%"=="1" (
  "%PNGQUANT%" --version >nul 2>&1 || (
    echo pngquant not found. Continuing without it.
    set "USE_PNGQUANT=0"
  )
)

echo Watching "%WATCH%"  ^|  scale=%SCALE%  compression=%COMPRESSION%  jobs=%JOBS%  pngquant=%USE_PNGQUANT%
echo Press Ctrl+C to stop.

:loop
if not exist "%STATE%" mkdir "%STATE%"
for %%F in ("%WATCH%\*.png") do (
  set "name=%%~nF"
  if /i not "!name:~-6!"=="_alpha" (
    if exist "%WATCH%\!name!_alpha.png" call :check "%%~fF" "%WATCH%\!name!_alpha.png" "!name!"
  )
)
timeout /t %INTERVAL% /nobreak >nul
goto loop


rem ---------- Decide whether a pair needs processing ----------
:check
set "rgb=%~1"
set "matte=%~2"
set "name=%~3"

rem Already being processed
if exist "%STATE%\%name%.lock" exit /b

rem Empty file = still being created
for %%A in ("%rgb%")   do if "%%~zA"=="0" exit /b
for %%B in ("%matte%") do if "%%~zB"=="0" exit /b

rem "Signature" = size + modified time of both files
for %%A in ("%rgb%") do for %%B in ("%matte%") do set "sig=%%~zA_%%~tA_%%~zB_%%~tB"

rem Up to date: already done with these exact files
set "old="
if exist "%STATE%\%name%.done" set /p old=<"%STATE%\%name%.done"
if "!old!"=="!sig!" if exist "%OUT%\%name%.png" exit /b

rem Failed before, and the files haven't changed since
set "old="
if exist "%STATE%\%name%.failed" set /p old=<"%STATE%\%name%.failed"
if "!old!"=="!sig!" exit /b

rem Files must look the same on two checks in a row (copy finished)
set "prev=!seen_%name%!"
set "seen_%name%=!sig!"
if not "!prev!"=="!sig!" exit /b

rem File is still locked by a copy in progress
2>nul (>>"%rgb%" call ) || exit /b
2>nul (>>"%matte%" call ) || exit /b

rem Limit how many run at the same time
:waitslot
set /a running=0
for %%L in ("%STATE%\*.lock") do set /a running+=1
if !running! geq %JOBS% (
  timeout /t 1 /nobreak >nul
  goto waitslot
)

>"%STATE%\%name%.lock" echo running
>"%STATE%\%name%.pending" echo !sig!
echo %time:~0,8%  [..] %name% ...
start "" /b cmd /c call "%SELF%" :work "%name%" "%rgb%" "%matte%"
exit /b


rem ---------- Worker: runs in the background for one image ----------
:work
set "name=%~2"
set "rgb=%~3"
set "matte=%~4"
set "tmp=%STATE%\%name%_tmp.png"

"%FFMPEG%" -y -loglevel error -i "%rgb%" -i "%matte%" -filter_complex "%FILTER%" -map "[out]" -frames:v 1 -compression_level %COMPRESSION% -pred %PRED% "%tmp%"
if errorlevel 1 goto work_fail

if "%USE_PNGQUANT%"=="1" (
  rem If pngquant can't reach the quality target, the lossless version is kept
  "%PNGQUANT%" --quality=%QUALITY% --speed 3 --force --output "%STATE%\%name%_q.png" -- "%tmp%" && move /y "%STATE%\%name%_q.png" "%tmp%" >nul
  del /q "%STATE%\%name%_q.png" 2>nul
)

move /y "%tmp%" "%OUT%\%name%.png" >nul
move /y "%STATE%\%name%.pending" "%STATE%\%name%.done" >nul
del /q "%STATE%\%name%.failed" 2>nul
for %%S in ("%OUT%\%name%.png") do set /a kb=%%~zS/1024
echo %time:~0,8%  [OK] %name%  (!kb! KB)
del /q "%STATE%\%name%.lock" 2>nul
exit /b

:work_fail
del /q "%tmp%" 2>nul
move /y "%STATE%\%name%.pending" "%STATE%\%name%.failed" >nul
echo %time:~0,8%  [FAIL] %name% (are both images the same size?)
del /q "%STATE%\%name%.lock" 2>nul
exit /b