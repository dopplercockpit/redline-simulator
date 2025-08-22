@echo off
REM === Git Push Helper with Prompt ===

set /p msg=Enter commit message: 

IF "%msg%"=="" (
    echo No message entered. Aborting.
    pause
    exit /b
)

git add .
git commit -m "%msg%"
git push origin main

echo.
echo ✅ Changes pushed with commit message: "%msg%"
pause
