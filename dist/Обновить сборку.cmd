@echo off
chcp 866 >nul
title Обновление сборки Minecraft Pack 1.20.1
setlocal enabledelayedexpansion

rem ---------------------------------------------------------------
rem  Кнопка обновления. Читает ИНСТРУКЦИЮ ЗАГРУЗКИ (bootstrap.txt),
rem  качает пак с первого доступного источника (с повторами при обрывах связи)
rem  и один раз докладывает настройки/конфиги тем, у кого их ещё нет.
rem  Меняешь инструкцию на сервере - игрокам обновлять свои файлы не нужно.
rem  Аргумент dry: показать, что нашлось, и выйти.
rem ---------------------------------------------------------------

set "PTR_HOST=http://26.26.205.227:8787/bootstrap.txt"
set "PTR_NET=https://raw.githubusercontent.com/CrystalysGolem/minecraft-pack-1201/main/bootstrap.txt"
set "FALLBACK_PACK=https://raw.githubusercontent.com/CrystalysGolem/minecraft-pack-1201/main/pack.toml"
set "BOOTFILE=%TEMP%\mcp1201_%RANDOM%.txt"
set "STARTER=%TEMP%\mcp1201_starter_%RANDOM%.txt"
set "ATTEMPTS=4"

set "TIMEOUT=30"
set "INSTALL_TRIES=4"
set "WAIT=8"
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
  call :fetch "%PTR_HOST%" "%BOOTFILE%" "pack=" 2
  if not errorlevel 1 (set "BOOT=%BOOTFILE%" & set "BOOTSRC=хост (Radmin)")
)
if not defined BOOT (
  call :fetch "%PTR_NET%" "%BOOTFILE%" "pack=" 2
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
  set "D=!SRC1!"
  set "D=!D:/pack.toml=!"
  call :fetch "!D!/starter/manifest.txt" "%STARTER%" "#version=" 2
  if not errorlevel 1 (
    set "SV="
    for /f "tokens=1,* delims==" %%A in ('type "%STARTER%" 2^>nul') do if /i "%%~A"=="#version" if not defined SV set "SV=%%~B"
    set "SC=0"
    for /f "usebackq tokens=* delims=" %%L in ("%STARTER%") do if not "%%L"=="" if not "%%~L:~0,1!"=="#" set /a SC+=1
    echo Настройки первого запуска: доступны, версия !SV!, файлов !SC!
    del "%STARTER%" >nul 2>nul
  ) else (
    echo Настройки первого запуска: недоступны по адресу источника
  )
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
set "USED="
for /l %%I in (1,1,!N!) do (
  if not defined OK (
    set "U=!SRC%%I!"
    if defined U (
      call :reachable "!U!"
      if not errorlevel 1 (
        echo Источник %%I из !N!: !U!
        call :install "!U!"
        if not errorlevel 1 (
          set "OK=1"
          set "USED=!U!"
        )
      ) else (
        echo Источник %%I недоступен, пробую следующий...
      )
    )
  )
)

if defined USED (
  set "BASE=!USED:/pack.toml=!"
  rem настройки владельца: принудительно, один раз на версию набора
  call :settings
  call :fixpacks
  call :seed "!BASE!"
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
echo Уже скачанное не потеряется: следующий запуск продолжит с того же места.
pause
exit /b 1

:settings
rem Набор настроек владельца кладём ПОВЕРХ настроек игрока - один раз на версию набора.
if not exist "settings\manifest.txt" exit /b 0
set "SVER="
for /f "usebackq tokens=1,* delims==" %%A in ("settings\manifest.txt") do if not defined SVER if /i "%%~A"=="#version" set "SVER=%%~B"
if not defined SVER exit /b 0
set "SOLD="
if exist ".pack_settings" for /f "usebackq delims=" %%X in (".pack_settings") do if not defined SOLD set "SOLD=%%X"
if "!SOLD!"=="!SVER!" exit /b 0
echo Настройки сборки: применяю настройки и конфиги владельца (набор !SVER!)
if not exist "settings\files" exit /b 0
xcopy "settings\files\*" "." /E /I /Y /Q >nul 2>nul
if exist "settings\instance\patches" xcopy "settings\instance\patches\*" "..\patches\" /E /I /Y /Q >nul 2>nul
if exist "settings\instance\instance.cfg.overrides" powershell -NoProfile -EncodedCommand JABzAHIAYwAgAD0AIAAnAHMAZQB0AHQAaQBuAGcAcwBcAGkAbgBzAHQAYQBuAGMAZQBcAGkAbgBzAHQAYQBuAGMAZQAuAGMAZgBnAC4AbwB2AGUAcgByAGkAZABlAHMAJwAKACQAZABzAHQAIAA9ACAAJwAuAC4AXABpAG4AcwB0AGEAbgBjAGUALgBjAGYAZwAnAAoAaQBmACAAKAAtAG4AbwB0ACAAKABUAGUAcwB0AC0AUABhAHQAaAAgACQAcwByAGMAKQAgAC0AbwByACAALQBuAG8AdAAgACgAVABlAHMAdAAtAFAAYQB0AGgAIAAkAGQAcwB0ACkAKQAgAHsAIABlAHgAaQB0ACAAMAAgAH0ACgAkAHMAawBpAHAAIAA9ACAAQAAoACcATQBhAHgATQBlAG0AQQBsAGwAbwBjACcALAAnAE0AaQBuAE0AZQBtAEEAbABsAG8AYwAnACwAJwBPAHYAZQByAHIAaQBkAGUATQBlAG0AbwByAHkAJwAsACcAUABlAHIAbQBHAGUAbgAnACwAJwBKAGEAdgBhAFAAYQB0AGgAJwAsACcASgBhAHYAYQBWAGUAcgBzAGkAbwBuACcALAAnAEoAYQB2AGEAUwBpAGcAbgBhAHQAdQByAGUAJwAsACcASgBhAHYAYQBWAGUAbgBkAG8AcgAnACwAJwBKAGEAdgBhAEEAcgBjAGgAaQB0AGUAYwB0AHUAcgBlACcALAAnAEoAYQB2AGEAUgBlAGEAbABBAHIAYwBoAGkAdABlAGMAdAB1AHIAZQAnACwAJwBBAHUAdABvAG0AYQB0AGkAYwBKAGEAdgBhACcALAAnAE8AdgBlAHIAcgBpAGQAZQBKAGEAdgBhAEwAbwBjAGEAdABpAG8AbgAnACwAJwBPAHYAZQByAHIAaQBkAGUASgBhAHYAYQBBAHIAZwBzACcALAAnAEoAdgBtAEEAcgBnAHMAJwAsACcAbgBhAG0AZQAnACwAJwBpAGMAbwBuAEsAZQB5ACcALAAnAHUAdQBpAGQAJwAsACcAbgBvAHQAZQBzACcALAAnAGwAYQBzAHQATABhAHUAbgBjAGgAVABpAG0AZQAnACwAJwBsAGEAcwB0AFQAaQBtAGUAUABsAGEAeQBlAGQAJwAsACcAdABvAHQAYQBsAFQAaQBtAGUAUABsAGEAeQBlAGQAJwAsACcARQB4AHAAbwByAHQATgBhAG0AZQAnACwAJwBFAHgAcABvAHIAdABWAGUAcgBzAGkAbwBuACcALAAnAEUAeABwAG8AcgB0AFMAdQBtAG0AYQByAHkAJwAsACcARQB4AHAAbwByAHQAQQB1AHQAaABvAHIAJwAsACcARQB4AHAAbwByAHQATwBwAHQAaQBvAG4AYQBsAEYAaQBsAGUAcwAnACwAJwBNAGEAbgBhAGcAZQBkAFAAYQBjAGsAJwAsACcATQBhAG4AYQBnAGUAZABQAGEAYwBrAEkARAAnACwAJwBNAGEAbgBhAGcAZQBkAFAAYQBjAGsATgBhAG0AZQAnACwAJwBNAGEAbgBhAGcAZQBkAFAAYQBjAGsAVAB5AHAAZQAnACwAJwBNAGEAbgBhAGcAZQBkAFAAYQBjAGsAVQBSAEwAJwAsACcATQBhAG4AYQBnAGUAZABQAGEAYwBrAFYAZQByAHMAaQBvAG4ASQBEACcALAAnAE0AYQBuAGEAZwBlAGQAUABhAGMAawBWAGUAcgBzAGkAbwBuAE4AYQBtAGUAJwAsACcAVQBzAGUAQQBjAGMAbwB1AG4AdABGAG8AcgBJAG4AcwB0AGEAbgBjAGUAJwAsACcASQBuAHMAdABhAG4AYwBlAEEAYwBjAG8AdQBuAHQASQBkACcALAAnAGwAaQBuAGsAZQBkAEkAbgBzAHQAYQBuAGMAZQBzACcALAAnAHMAaABvAHIAdABjAHUAdABzACcALAAnAFAAcgBvAGYAaQBsAGUAcgAnACkACgAkAG8AdgAgAD0AIABAAHsAfQAKAGYAbwByAGUAYQBjAGgAIAAoACQAbAAgAGkAbgAgAFsASQBPAC4ARgBpAGwAZQBdADoAOgBSAGUAYQBkAEEAbABsAEwAaQBuAGUAcwAoACQAcwByAGMAKQApACAAewAKACAAIAAkAG0AIAA9ACAAWwByAGUAZwBlAHgAXQA6ADoATQBhAHQAYwBoACgAJABsACwAIAAnAF4AKABbAF4APQBdACsAKQA9ACgALgAqACkAJAAnACkACgAgACAAaQBmACAAKAAkAG0ALgBTAHUAYwBjAGUAcwBzACkAIAB7ACAAJABrACAAPQAgACQAbQAuAEcAcgBvAHUAcABzAFsAMQBdAC4AVgBhAGwAdQBlADsAIABpAGYAIAAoACQAcwBrAGkAcAAgAC0AbgBvAHQAYwBvAG4AdABhAGkAbgBzACAAJABrACkAIAB7ACAAJABvAHYAWwAkAGsAXQAgAD0AIAAkAG0ALgBHAHIAbwB1AHAAcwBbADIAXQAuAFYAYQBsAHUAZQAgAH0AIAB9AAoAfQAKAGkAZgAgACgAJABvAHYALgBDAG8AdQBuAHQAIAAtAGUAcQAgADAAKQAgAHsAIABlAHgAaQB0ACAAMAAgAH0ACgAkAG8AdQB0ACAAPQAgAE4AZQB3AC0ATwBiAGoAZQBjAHQAIABTAHkAcwB0AGUAbQAuAEMAbwBsAGwAZQBjAHQAaQBvAG4AcwAuAEcAZQBuAGUAcgBpAGMALgBMAGkAcwB0AFsAcwB0AHIAaQBuAGcAXQAKACQAcwBlAGUAbgAgAD0AIABAAHsAfQAKAGYAbwByAGUAYQBjAGgAIAAoACQAbAAgAGkAbgAgAFsASQBPAC4ARgBpAGwAZQBdADoAOgBSAGUAYQBkAEEAbABsAEwAaQBuAGUAcwAoACQAZABzAHQAKQApACAAewAKACAAIAAkAG0AIAA9ACAAWwByAGUAZwBlAHgAXQA6ADoATQBhAHQAYwBoACgAJABsACwAIAAnAF4AKABbAF4APQBdACsAKQA9ACgALgAqACkAJAAnACkACgAgACAAaQBmACAAKAAkAG0ALgBTAHUAYwBjAGUAcwBzACAALQBhAG4AZAAgACQAbwB2AC4AQwBvAG4AdABhAGkAbgBzAEsAZQB5ACgAJABtAC4ARwByAG8AdQBwAHMAWwAxAF0ALgBWAGEAbAB1AGUAKQApACAAewAKACAAIAAgACAAJABrACAAPQAgACQAbQAuAEcAcgBvAHUAcABzAFsAMQBdAC4AVgBhAGwAdQBlAAoAIAAgACAAIAAkAG8AdQB0AC4AQQBkAGQAKAAkAGsAIAArACAAJwA9ACcAIAArACAAJABvAHYAWwAkAGsAXQApADsAIAAkAHMAZQBlAG4AWwAkAGsAXQAgAD0AIAAkAHQAcgB1AGUAOwAgAGMAbwBuAHQAaQBuAHUAZQAKACAAIAB9AAoAIAAgACQAbwB1AHQALgBBAGQAZAAoACQAbAApAAoAfQAKAGYAbwByAGUAYQBjAGgAIAAoACQAawAgAGkAbgAgACQAbwB2AC4ASwBlAHkAcwApACAAewAgAGkAZgAgACgALQBuAG8AdAAgACQAcwBlAGUAbgAuAEMAbwBuAHQAYQBpAG4AcwBLAGUAeQAoACQAawApACkAIAB7ACAAJABvAHUAdAAuAEEAZABkACgAJABrACAAKwAgACcAPQAnACAAKwAgACQAbwB2AFsAJABrAF0AKQAgAH0AIAB9AAoAWwBJAE8ALgBGAGkAbABlAF0AOgA6AFcAcgBpAHQAZQBBAGwAbABMAGkAbgBlAHMAKAAkAGQAcwB0ACwAIAAkAG8AdQB0ACkACgA= >nul 2>nul
> ".pack_settings" echo !SVER!
exit /b 0
:fixpacks
rem Включает наши ресурспаки с фиксами: игра видит ресурспак только если он в options.txt.
rem Наш пак дописываем В КОНЕЦ списка - в resourcePacks побеждает последний пак, иначе мод перекрывает фикс.
if not exist "options.txt" exit /b 0
powershell -NoProfile -EncodedCommand JABmACAAPQAgACcAbwBwAHQAaQBvAG4AcwAuAHQAeAB0ACcACgBpAGYAIAAoAFQAZQBzAHQALQBQAGEAdABoACAAJABmACkAIAB7AAoAIAAgACQAdAAgAD0AIABbAEkATwAuAEYAaQBsAGUAXQA6ADoAUgBlAGEAZABBAGwAbABUAGUAeAB0ACgAJABmACkACgAgACAAJABxACAAPQAgAFsAYwBoAGEAcgBdADMANAAKACAAIAAkAGUAdgAgAD0AIABbAFMAeQBzAHQAZQBtAC4AVABlAHgAdAAuAFIAZQBnAHUAbABhAHIARQB4AHAAcgBlAHMAcwBpAG8AbgBzAC4ATQBhAHQAYwBoAEUAdgBhAGwAdQBhAHQAbwByAF0AewAKACAAIAAgACAAcABhAHIAYQBtACgAJABtACkACgAgACAAIAAgACQAcAAgAD0AIABAACgAKQAKACAAIAAgACAAZgBvAHIAZQBhAGMAaAAgACgAJAB4ACAAaQBuACAAJABtAC4ARwByAG8AdQBwAHMAWwAyAF0ALgBWAGEAbAB1AGUALgBTAHAAbABpAHQAKAAnACwAJwApACkAIAB7AAoAIAAgACAAIAAgACAAaQBmACAAKAAkAHgALgBUAHIAaQBtACgAKQAuAEwAZQBuAGcAdABoACAALQBnAHQAIAAwACAALQBhAG4AZAAgACQAeAAgAC0AbgBvAHQAbABpAGsAZQAgACcAKgBtAGMAdwBiAGUAdAB0AGUAcgBzAC0AZgBpAHgALgB6AGkAcAAqACcAKQAgAHsAIAAkAHAAIAArAD0AIAAkAHgALgBUAHIAaQBtACgAKQAgAH0ACgAgACAAIAAgAH0ACgAgACAAIAAgACQAcAAgACsAPQAgACQAcQAgACsAIAAnAGYAaQBsAGUALwBtAGMAdwBiAGUAdAB0AGUAcgBzAC0AZgBpAHgALgB6AGkAcAAnACAAKwAgACQAcQAKACAAIAAgACAAJABtAC4ARwByAG8AdQBwAHMAWwAxAF0ALgBWAGEAbAB1AGUAIAArACAAJwByAGUAcwBvAHUAcgBjAGUAUABhAGMAawBzADoAWwAnACAAKwAgACgAJABwACAALQBqAG8AaQBuACAAJwAsACcAKQAgACsAIAAnAF0AJwAKACAAIAB9AAoAIAAgACQAdAAgAD0AIABbAHIAZQBnAGUAeABdADoAOgBSAGUAcABsAGEAYwBlACgAJAB0ACwAIAAnACgAXgB8AAoAKQByAGUAcwBvAHUAcgBjAGUAUABhAGMAawBzADoAXABbACgAWwBeAFwAXQBdACoAKQBcAF0AJwAsACAAJABlAHYAKQAKACAAIABbAEkATwAuAEYAaQBsAGUAXQA6ADoAVwByAGkAdABlAEEAbABsAFQAZQB4AHQAKAAkAGYALAAgACQAdAAsACAAKABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBUAGUAeAB0AC4AVQBUAEYAOABFAG4AYwBvAGQAaQBuAGcAKAAkAGYAYQBsAHMAZQApACkAKQAKAH0ACgA= >nul 2>nul
exit /b 0

rem ---------------- установка пакета ----------------
:install
set "URL=%~1"
set "TRY=0"
:install_again
set /a TRY+=1
"%JAVA%" -jar packwiz-installer-bootstrap.jar "%URL%"
if %TRY% GEQ %INSTALL_TRIES% exit /b 1
call :reachable "%URL%"
if errorlevel 1 exit /b 1
echo.
echo   !!! Связь оборвалась. Жду %WAIT% секунд и пробую снова (%TRY%/%INSTALL_TRIES%)...
echo.
call :sleep %WAIT%
goto :install_again

rem ---------------- настройки первого запуска ----------------
:seed
set "SBASE=%~1"
if not exist "packwiz-installer-bootstrap.jar" exit /b 0
call :fetch "%SBASE%/starter/manifest.txt" "%STARTER%" "#version="
if errorlevel 1 exit /b 0
set "SVER="
for /f "tokens=1,* delims==" %%A in ('type "%STARTER%" 2^>nul') do (
  if /i "%%~A"=="#version" if not defined SVER set "SVER=%%~B"
)
set "SOLD="
if exist ".pack_starter" for /f "usebackq tokens=* delims=" %%L in (".pack_starter") do if not defined SOLD set "SOLD=%%L"
if defined SVER if "!SVER!"=="!SOLD!" (
  echo Настройки первого запуска: уже применены, не трогаю.
  del "%STARTER%" >nul 2>nul
  exit /b 0
)
echo.
echo Настройки первого запуска (выдаются один раз, только отсутствующие файлы):
set "SEEDED=0"
for /f "usebackq tokens=* delims=" %%L in ("%STARTER%") do (
  set "LINE=%%L"
  if not "!LINE!"=="" if not "!LINE:~0,1!"=="#" call :seed_one "!SBASE!" "!LINE!"
)
echo   выдано файлов: !SEEDED!
if defined SVER echo !SVER!> ".pack_starter"
del "%STARTER%" >nul 2>nul
exit /b 0

:seed_one
set "REL=%~2"
if exist "%REL%" exit /b 0
for %%D in ("%REL%") do if not "%%~dpD"=="" if not exist "%%~dpD" mkdir "%%~dpD" >nul 2>nul
call :fetch "%~1/starter/%REL%" "%REL%" ""
if not errorlevel 1 (
  set /a SEEDED+=1
  echo   + %REL%
) else (
  echo   ! не удалось получить %REL%
)
exit /b 0

rem ---------------- вспомогательные ----------------
:sleep
set /a "SL=%~1"
if %SL% LSS 1 set "SL=1"
ping -n %SL% 127.0.0.1 >nul 2>nul
exit /b 0

:fetch
set "FURL=%~1"
set "FDST=%~2"
set "FMARK=%~3"

set "FMAX=%~4"

if not defined FMAX set "FMAX=%ATTEMPTS%"
set "FTRY=0"
:fetch_again
set /a FTRY+=1
call :direct "%FURL%" "%FDST%"
if not errorlevel 1 (
  call :looks_ok "%FDST%" "%FMARK%"
)
if exist "%FDST%" del "%FDST%" >nul 2>nul
if %FTRY% GEQ %FMAX% exit /b 1
if not "%MODE%"=="quiet" echo     сеть не ответила, повтор %FTRY%/%ATTEMPTS%...
call :sleep 3
goto :fetch_again

:direct
curl.exe -fsS --noproxy "*" -m %TIMEOUT% -o "%~2" "%~1" >nul 2>nul
if exist "%~2" for %%F in ("%~2") do if %%~zF GTR 0 exit /b 0
powershell -NoProfile -Command "try{$w=New-Object Net.WebClient;$w.Proxy=$null;$w.DownloadFile('%~1','%~2')}catch{exit 1}" >nul 2>nul
if exist "%~2" for %%F in ("%~2") do if %%~zF GTR 0 exit /b 0
exit /b 1

:looks_ok
if not exist "%~1" exit /b 1
for %%F in ("%~1") do if %%~zF LSS 1 exit /b 1
if "%~2"=="" exit /b 0
findstr /b /c:"%~2" "%~1" >nul 2>nul
if errorlevel 1 exit /b 1
exit /b 0

:reachable
set "H=%1"
set "HOST="
for /f "tokens=1,2,3 delims=:/" %%a in ("%H%") do set "HOST=%%b"
if not defined HOST exit /b 0
echo %HOST%| findstr /r /c:"^[0-9][0-9]*\.[0-9]" >nul
if errorlevel 1 exit /b 0
ping -n 1 -w 700 %HOST% >nul 2>nul
exit /b %errorlevel%
