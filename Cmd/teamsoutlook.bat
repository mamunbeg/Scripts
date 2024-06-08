@echo off
cd "C:\Program Files\Microsoft Office\root\Office16\"
start OUTLOOK.EXE
cd "C:\Users\ittech\AppData\Local\Microsoft\Teams\"
start Update.exe --processStart "Teams.exe"
exit