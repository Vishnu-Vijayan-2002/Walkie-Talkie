@echo off
cd /d D:\test\wocky_tocky
call C:\src\flutter\bin\flutter.bat build apk --release > build\release-build.log 2>&1
