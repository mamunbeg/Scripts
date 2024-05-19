@echo OFF
title Ping Test
echo Running continuous ping to destination device and logging...
echo.
color 0b

echo off

set /p host=host Address: 
set logfile=PingLog_%host%.log

title Ping Test to %host%

echo Target Host = %host% >%logfile%
for /f "tokens=*" %%A in ('ping %host% -n 1 ') do (echo %%A>>%logfile% && GOTO Ping)
:Ping
for /f "tokens=* skip=2" %%A in ('ping %host% -n 1 ') do (
    echo %date% %time:~0,2%:%time:~3,2%:%time:~6,2% %%A>>%logfile%
    echo %date% %time:~0,2%:%time:~3,2%:%time:~6,2% %%A
    timeout 1 >NUL 
    GOTO Ping)

echo %date% %time:~0,2%:%time:~3,2%:%time:~6,2% Error>>%logfile%
echo %date% %time:~0,2%:%time:~3,2%:%time:~6,2% Error
timeout 1 >NUL
GOTO Ping