@echo off
color 0a
cd ../..
echo BUILDING GAME
haxelib run lime build linux
echo.
echo done.
pause
pwd
explorer.exe export/release/android/bin/app/build/outputs/apk/debug