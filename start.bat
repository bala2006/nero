@echo off
setlocal enabledelayedexpansion
title Nero Harness
cd /d "%~dp0"

set "CHECKONLY="
if /i "%~1"=="--check" set "CHECKONLY=1"

echo ============================================================
echo   Nero Harness
echo   Boots the Web UI and opens it in your default browser.
echo ============================================================
echo.

REM ---------------------------------------------------------------------------
REM 1. Prerequisites: Node.js and corepack (which provides pnpm)
REM ---------------------------------------------------------------------------
where node >nul 2>nul
if errorlevel 1 (
  echo [X] Node.js is not on PATH.
  echo     Install Node.js 22.19+ or 24+ from https://nodejs.org/ and run this again.
  echo.
  pause
  exit /b 1
)

where corepack >nul 2>nul
if errorlevel 1 (
  echo [X] corepack is not on PATH.
  echo     Run "corepack enable" once, then try again.
  echo.
  pause
  exit /b 1
)

for /f "delims=" %%v in ('node -p "process.versions.node"') do set "NODEVER=%%v"
node -e "var v=process.versions.node.split('.').map(Number);process.exit((v[0]===22&&v[1]>=19)||v[0]>=24?0:1)"
if errorlevel 1 (
  echo [warn] Node !NODEVER! is below the supported range ^(^22.19.0 or ^>=24.0.0^).
  echo     Trying anyway - upgrade Node.js if the boot fails.
  echo.
)
echo [1/4] Runtime   : Node !NODEVER!

REM ---------------------------------------------------------------------------
REM 2. Dependencies. Always reconciled, never gated on node_modules existing:
REM    pnpm's pre-run dependency check shells out to a bare `pnpm`, which a
REM    corepack-only setup does not put on PATH, so merely-stale dependencies
REM    turn the build into a confusing «pnpm is not recognized» failure.
REM    A reconciled workspace makes this a fast no-op.
REM ---------------------------------------------------------------------------
if defined CHECKONLY (
  echo [2/4] Deps      : a real launch would reconcile with "corepack pnpm install"
) else (
  echo [2/4] Deps      : reconciling ^(first run: a few minutes^)...
  echo.
  call corepack pnpm install
  if errorlevel 1 goto fail
  echo.
)

REM ---------------------------------------------------------------------------
REM 3. Build artifacts (the harness runs from built output, not from source)
REM ---------------------------------------------------------------------------
if exist ".nero-build\client-build-environment.json" (
  echo [3/4] Build     : up to date
) else (
  if defined CHECKONLY (
    echo [3/4] Build     : MISSING - a real launch would run "corepack pnpm run build"
  ) else (
    echo [3/4] Build     : building ^(first run, several minutes^)...
    echo.
    call corepack pnpm run build
    if errorlevel 1 goto fail
    echo.
  )
)

REM ---------------------------------------------------------------------------
REM 4. Pick a free port. 3080 is the harness default, but another harness or
REM    dev server is often already sitting on it, so probe upward first.
REM ---------------------------------------------------------------------------
set "PORT=3080"
:probe
netstat -ano | findstr /r /c:":!PORT! .*LISTENING" >nul 2>nul
if errorlevel 1 goto portfound
set /a PORT+=1
if !PORT! leq 3099 goto probe
set "PORT=0"
:portfound

if "!PORT!"=="0" (
  echo [4/4] Port      : letting the OS pick a free one
) else (
  echo [4/4] Port      : !PORT!
)

if defined CHECKONLY (
  echo.
  echo --check complete: nothing installed, built, or launched.
  exit /b 0
)

REM ---------------------------------------------------------------------------
REM 5. Boot the Web profile. It prints an authenticated URL and opens the browser.
REM ---------------------------------------------------------------------------
echo.
echo Starting Nero Harness...
echo   - Your browser opens automatically once the server is listening.
echo   - Leave this window open; press Ctrl+C here to stop the server.
echo.
call corepack pnpm nero web --port !PORT!
if errorlevel 1 goto fail

echo.
echo Nero Harness stopped.
pause
exit /b 0

:fail
echo.
echo [X] Nero Harness did not start. Scroll up for the error above.
echo.
echo     Rebuild the harness output:  rmdir /s /q .nero-build ^&^& .\start.bat
echo     Reinstall dependencies:      rmdir /s /q node_modules ^&^& .\start.bat
echo.
pause
exit /b 1
