:: feos, 2013-2018
:: Cheers to Guga, Velitha, nanogyth, Aktan, Dacicus, TheCoreyBurton, and Zinfidel
:: This global batch is a part of "TAS Encoding Package":
:: http://tasvideos.org/EncodingGuide/PublicationManual.html
:: Asks for aspect ratio to use
:: Allows to select encode to make
:: Accepts command line arguments

@echo off
setlocal EnableExtensions
setlocal EnableDelayedExpansion

if [%1]==[/?] goto syntax_cmd

:: Restore AVS defaults ::
".\programs\replacetext" "encode.avs" "hd = true" "hd = false"

echo -----------------------
echo  Hybrid Encoding Batch
echo -----------------------
echo.
echo Type /? for command-line arguments.
echo.

if [%1]==[] goto SAR_OPTIONS
if [%1]==[1] goto handHeld_SAR
if [%1]==[2] (
	set ar_w=4
	set ar_h=3
	goto TV_SAR
)
if [%1]==[3] (
	set ar_w=16
	set ar_h=9
	goto TV_SAR
)
set aspect_ratio=%1
goto Parse_AR

: SAR_OPTIONS
echo Aspect ratio options:
echo.
echo Press 1 for  1:1 (no change)
echo Press 2 for  4:3 (CRT TV)
echo Press 3 for 16:9 (LCD TV)
echo Press 4 to enter your own
echo.

title User input expected...

set /p ANSWER=
if "%ANSWER%"=="1" goto handHeld_SAR
if "%ANSWER%"=="2" (
	set ar_w=4
	set ar_h=3
	goto TV_SAR
)
if "%ANSWER%"=="3" (
	set ar_w=16
	set ar_h=9
	goto TV_SAR
)
if "%ANSWER%"=="4" goto Get_AR
if "%ANSWER%"=="/?" goto syntax_cmd

echo I'm not kidding!
goto SAR_OPTIONS

: Get_AR
set ar_w=
set ar_h=
set /p aspect_ratio=Enter aspect ratio in the format width:height 

: Parse_AR
for /f "tokens=1 delims=:" %%g in ('echo %aspect_ratio%') do (set /a "ar_w=%%g")
for /f "tokens=2 delims=:" %%g in ('echo %aspect_ratio%') do (set /a "ar_h=%%g")

if [%ar_w%]==[] goto Get_AR
if [%ar_h%]==[] goto Get_AR
if %ar_w% leq 0 goto Get_AR
if %ar_h% leq 0 goto Get_AR
goto TV_Sar

: TV_SAR
for /f "tokens=2 skip=2 delims== " %%G in ('find "wAspect = " "%~dp0encode.avs"') do (set current_wAspect=%%G)
".\programs\replacetext" "encode.avs" "wAspect = %current_wAspect%" "wAspect = %ar_w%"
for /f "tokens=2 skip=2 delims== " %%G in ('find "hAspect = " "%~dp0encode.avs"') do (set current_hAspect=%%G)
".\programs\replacetext" "encode.avs" "hAspect = %current_hAspect%" "hAspect = %ar_h%"

".\programs\replacetext" "encode.avs" "handHeld = true" "handHeld = false"
".\programs\ffprobe" -hide_banner -v error -select_streams v -of default -show_entries stream=width,height,r_frame_rate encode.avs > ".\temp\info.txt"

for /f "tokens=2 delims==" %%G in ('FINDSTR "width" "%~dp0temp\info.txt"') do (set width=%%G)
for /f "tokens=2 delims==" %%G in ('FINDSTR "height" "%~dp0temp\info.txt"') do (set height=%%G)

set /a "SAR_w=%ar_w% * %height%"
set /a "SAR_h=%ar_h% * %width%"
set VAR=%SAR_w%:%SAR_h%

goto ENCODE_OPTIONS

: handHeld_SAR
set VAR=1:1
".\programs\replacetext" "encode.avs" "handHeld = false" "handHeld = true"
".\programs\ffprobe" -hide_banner -v error -select_streams v -of default -show_entries stream=r_frame_rate encode.avs > ".\temp\info.txt"
goto ENCODE_OPTIONS

: ENCODE_OPTIONS
set EncodeChoice=
set param_2=%2
if [%param_2%]==[] goto get_encode_option
set EncodeChoice=%param_2:~0,1%
goto process_encode_option

: get_encode_option
echo.
echo What encode do you want to do?
echo.
echo Press 1 for Standard Definition MP4.
echo Press 2 for High Definition MKV.
echo Press 3 for Both.
echo.
set /p EncodeChoice=

: process_encode_option
if "%EncodeChoice%"=="1" goto SD
if "%EncodeChoice%"=="2" goto HD
if "%EncodeChoice%"=="3" goto HD

echo.
echo You better choose something real!
goto get_encode_option

: HD

title Processing HD
echo.
echo ----------------------------
echo  Encoding YouTube HD stream
echo ----------------------------
echo.
:: Audio ::
echo Encoding audio...
".\programs\ffmpeg" -y -hide_banner -v error -stats -i encode.avs -vn -c:a flac ".\temp\audio.flac"

:: Video ::
echo Encoding video...
".\programs\replacetext" "encode.avs" "hd = false" "hd = true"
".\programs\x264_x64" --qp 5 -b 0 --keyint infinite --output ".\temp\video.mkv" encode.avs
".\programs\replacetext" "encode.avs" "hd = true" "hd = false"

:: Muxing ::
".\programs\mkvmerge" -o ".\output\encode__youtube.mkv" --compression -1:none ".\temp\video.mkv" ".\temp\audio.flac"

:: kept in case we have scripted uploading again
:: echo.
:: echo -----------------------------
:: echo  Uploading YouTube HD stream
:: echo -----------------------------
:: echo.
:: start "" cmd /c type "%~dp0programs\ytdesc.txt" ^| "%~dp0programs\tvcman.exe" "%~dp0output\encode%VBPREF%youtube.mkv" todo tasvideos

if "%EncodeChoice%"=="2" goto Defaults

: SD

title Processing SD
echo.
echo -------------------------------
echo  Encoding Archive 480p stream
echo -------------------------------
echo.
:: Audio ::
echo Encoding audio...
".\programs\ffmpeg" -y -hide_banner -v error -stats -i encode.avs -vn -af aresample=48000,atrim=start_sample=5060 -c:a libfdk_aac -profile:a aac_he -vbr 2 ".\temp\audio.mp4"

:: Video ::
echo Encoding video...
".\programs\x264_x64" --threads auto --crf 20 --preset veryslow --keyint 600 --merange 64 --range tv --input-range tv --colormatrix smpte170m -o ".\temp\video.h264" encode.avs

:: Muxing ::
for /f "tokens=2 delims==" %%i in ('FINDSTR "r_frame_rate" "%~dp0temp\info.txt"') do (set fps=%%i)
".\programs\mp4box_x64" -hint -add ".\temp\video.h264":fps=%fps% -add ".\temp\audio.mp4" -new ".\output\encode.mp4"
goto Defaults

: Defaults
".\programs\replacetext" "encode.avs" "hd = true" "hd = false"
goto end

:syntax_cmd
echo.
echo Command-line arguments: %0 ^<arc^> ^<enc_opt^>
echo   ^<arc^>       Aspect ratio?      1-3 or width:height
echo                 1 = 1:1
echo                 2 = 4:3
echo                 3 = 16:9
echo   ^<enc_opt^>   Encode option?     1-3
echo                 1 = Standard Definition MP4
echo                 2 = High Definition MKV
echo                 3 = Both
echo.

: end
title ALL DONE!
if "!cmdcmdline!" neq "!cmdcmdline:%~f0=!" (
	pause
)
endlocal
