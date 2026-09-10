@echo off
chcp 866 >nul
title Обновление сборки Minecraft Pack 1.20.1
setlocal enabledelayedexpansion

rem ---------------------------------------------------------------
rem  Кнопка обновления. Сначала читает ИНСТРУКЦИЮ ЗАГРУЗКИ (bootstrap.txt),
rem  затем качает пак по перечисленным в ней источникам (порядок = приоритет).
rem  Меняешь инструкцию на сервере - друзьям обновлять свои файлы не нужно.
rem  Аргумент dry: показать, что нашлось, и выйти.
rem ---------------------------------------------------------------

set "PTR_HOST=http://26.26.205.227:8787/bootstrap.txt"
set "PTR_NET=https://raw.githubusercontent.com/CrystalysGolem/minecraft-pack-1201/main/bootstrap.txt"
set "FALLBACK_PACK=https://raw.githubusercontent.com/CrystalysGolem/minecraft-pack-1201/main/pack.toml"

set "BOOTFILE=%TEMP%\mcp1201_%RANDOM%.txt"
set "MODE=%~1"

set "JAVA="
for %%P in ("%APPDATA%\PrismLauncher\java\java-runtime-gamma\bin\java.exe") do if exist %%P set "JAVA=%%~P"
if not defined JAVA for /d %%D in ("%APPDATA%\PrismLauncher\java\*") do if exist "%%D\bin\java.exe" set "JAVA=%%D\bin\java.exe"
if not defined JAVA where java >nul 2>nul && set "JAVA=java"

rem --- 1. инструкция загрузки
set "BOOTSRC="
set "BOOT="
ping -n 1 -w 700 26.26.205.227 >nul 2>nul
if not errorlevel 1 (
  call :fetch "%PTR_HOST%"
  if not errorlevel 1 (set "BOOT=%BOOTFILE%" & set "BOOTSRC=хост (Radmin)")
)
if not defined BOOT (
  call :fetch "%PTR_NET%"
  if not errorlevel 1 (set "BOOT=%BOOTFILE%" & set "BOOTSRC=GitHub")
)

rem --- 2. список источников пака
set "N=0"
set "SRC1="
if defined BOOT (
  for /f "tokens=1,* delims==" %%A in ('type "%BOOT%" 2^>nul') do (
    if /i "%%~A"=="pack" (
      set /a N+=1
      set "SRC!N!=%%~B"
    )
  )
)
if "!N!"=="0" (
  set "N=1"
  set "SRC1=%FALLBACK_PACK%"
  set "BOOTSRC=нет (аварийный адрес GitHub)"
)

if /i "%MODE%"=="dry" (
  echo Инструкция загрузки: !BOOTSRC!
  echo Источников пака: !N!
  for /l %%I in (1,1,!N!) do echo   %%I^) !SRC%%I!
  echo Java: !JAVA!
  exit /b 0
)

echo.
echo Инструкция загрузки: !BOOTSRC!
echo.
if not defined JAVA (
  echo Не найдена Java. Запусти игру один раз через PrismLauncher - он скачает Java, после этого кнопка заработает.
  pause
  exit /b 1
)
if not exist "%~dp0minecraft" (
  echo Не найден каталог minecraft рядом со скриптом.
  pause
  exit /b 1
)
cd /d "%~dp0minecraft"

set "OK="
for /l %%I in (1,1,!N!) do (
  if not defined OK (
    set "U=!SRC%%I!"
    if defined U (
      call :reachable "!U!"
      if not errorlevel 1 (
        echo Источник %%I из !N!: !U!
        "%JAVA%" -jar packwiz-installer-bootstrap.jar "!U!"
        if not errorlevel 1 set "OK=1"
      ) else (
        echo Источник %%I недоступен, пробую следующий...
      )
    )
  )
)
del "%BOOTFILE%" >nul 2>nul
if defined OK (
  echo.
  echo Готово! Можно запускать игру в PrismLauncher.
  pause
  exit /b 0
)
echo.
echo Не удалось обновить сборку ни с одного источника.
echo Проверь интернет (или чтобы хост был включён) и попробуй снова.
pause
exit /b 1

rem ---------------- вспомогательные ----------------
:fetch
rem %~1 = URL инструкции. Скачиваем напрямую (без прокси), проверяем содержимое.
call :direct "%~1"
if exist "%BOOTFILE%" (
  findstr /b /c:"pack=" "%BOOTFILE%" >nul 2>nul
  if not errorlevel 1 exit /b 0
)
exit /b 1

:direct
curl.exe -fsS --noproxy "*" -m 25 -o "%BOOTFILE%" "%~1" >nul 2>nul
if exist "%BOOTFILE%" (
  findstr /b /c:"pack=" "%BOOTFILE%" >nul 2>nul
  if not errorlevel 1 exit /b 0
)
powershell -NoProfile -Command "try{$w=New-Object Net.WebClient;$w.Proxy=$null;$w.DownloadFile('%~1','%BOOTFILE%')}catch{exit 1}" >nul 2>nul
if exist "%BOOTFILE%" (
  findstr /b /c:"pack=" "%BOOTFILE%" >nul 2>nul
  if not errorlevel 1 exit /b 0
)
exit /b 1

:reachable
rem %~1 = URL источника. Для адресов-по-IP быстрый ping (иначе TCP-таймаут ~20 c).
set "H=%1"
set "HOST="
for /f "tokens=1,2,3 delims=:/" %%a in ("%H%") do set "HOST=%%b"
if not defined HOST exit /b 0
echo %HOST%| findstr /r /c:"^[0-9][0-9]*\.[0-9]" >nul
if errorlevel 1 exit /b 0
ping -n 1 -w 700 %HOST% >nul 2>nul
exit /b %errorlevel%
