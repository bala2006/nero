@echo off
setlocal DisableDelayedExpansion
set "signTool=%NERO_DESKTOP_WINDOWS_SIGNTOOL%"
set "certificateFile=%NERO_DESKTOP_WINDOWS_CER_FILE%"
set "tokenPin=%NERO_DESKTOP_WINDOWS_TOKEN_PIN%"
set "keyContainer=%NERO_DESKTOP_WINDOWS_KEY_CONTAINER%"
set "targetFile=%NERO_DESKTOP_WINDOWS_SIGN_TARGET%"
set "appendSignature="
if "%NERO_DESKTOP_WINDOWS_SIGN_APPEND%"=="1" set "appendSignature=/as"
set "NERO_DESKTOP_WINDOWS_SIGNTOOL="
set "NERO_DESKTOP_WINDOWS_CER_FILE="
set "NERO_DESKTOP_WINDOWS_TOKEN_PIN="
set "NERO_DESKTOP_WINDOWS_KEY_CONTAINER="
set "NERO_DESKTOP_WINDOWS_SIGN_TARGET="
set "NERO_DESKTOP_WINDOWS_SIGN_APPEND="
set "signTool=" & set "certificateFile=" & set "tokenPin=" & set "keyContainer=" & set "targetFile=" & set "appendSignature=" & "%signTool%" sign /v /fd sha256 /f "%certificateFile%" /kc "[{{%tokenPin%}}]=%keyContainer%" /csp "eToken Base Cryptographic Provider" %appendSignature% "%targetFile%"
exit /b %errorlevel%
