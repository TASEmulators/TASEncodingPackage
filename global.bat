:: feos, 2013-2018
:: Cheers to Guga, Velitha, nanogyth, Aktan, Dacicus, and TheCoreyBurton
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
".\programs\replacetext" "encode.avs" "pass = 1" "pass = 0"
".\programs\replacetext" "encode.avs" "pass = 2" "pass = 0"
".\programs\replacetext" "encode.avs" "i444 = true" "i444 = false"
".\programs\replacetext" "encode.avs" "hd = true" "hd = false"
".\programs\replacetext" "encode.avs" "hq = true" "hq = false"
".\programs\replacetext" "encode.avs" "vb = true" "vb = false"

:: Uncomment for a VirtualBoy encode
:: set /a VIRTUALBOY=1

if "%VIRTUALBOY%"=="1" (".\programs\replacetext" "encode.avs" "vb = false" "vb = true")

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
".\programs\replacetext" "encode.avs" "pass = 0" "pass = 1"
".\programs\ffprobe" -hide_banner -v error -select_streams v -of default -show_entries stream=width,height,r_frame_rate encode.avs > ".\temp\info.txt"

for /f "tokens=2 delims==" %%G in ('FINDSTR "width" "%~dp0temp\info.txt"') do (set width=%%G)
for /f "tokens=2 delims==" %%G in ('FINDSTR "height" "%~dp0temp\info.txt"') do (set height=%%G)

set /a "SAR_w=%ar_w% * %height%"
set /a "SAR_h=%ar_h% * %width%"
set VAR=%SAR_w%:%SAR_h%

".\programs\replacetext" "encode.avs" "pass = 1" "pass = 0"
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
echo Press 1 for Modern HQ MKV.
echo Press 2 for Compatibility MP4.
echo Press 3 for HD Stream.
echo Press 4 for All of the above.
echo Press 5 for Extra HQ encodes.
echo.
set /p EncodeChoice=

: process_encode_option
if "%EncodeChoice%"=="1" goto 10bit444
if "%EncodeChoice%"=="2" goto 512kb
if "%EncodeChoice%"=="3" goto HD
if "%EncodeChoice%"=="4" goto HD
if "%EncodeChoice%"=="5" goto ExtraHQ_scale

echo.
echo You better choose something real!
goto get_encode_option

: ExtraHQ_scale
".\programs\replacetext" "encode.avs" "hq = false" "hq = true"

set ExtraScaleFactors=
if [%3]==[] goto get_extrahq_scale
set ExtraScaleFactors=%3
goto remove_starting_slash

: get_extrahq_scale
echo.
echo What scale factor do you want to use? (2-16, separate multiple with /)
echo.
set /p ExtraScaleFactors=

: remove_starting_slash
if [%ExtraScaleFactors%]==[] goto get_extrahq_scale
if [%ExtraScaleFactors:~0,1%]==[/] (
 set ExtraScaleFactors=%ExtraScaleFactors:~1%
 goto remove_starting_slash
)

set ExtraScale=
for /f "tokens=1 delims=/" %%G in ('echo %ExtraScaleFactors%') do (set ExtraScale=%%G)
if [%ExtraScale%]==[] goto get_extrahq_scale

: verify_extrahq_scale
if %ExtraScale% GTR 1 (if %ExtraScale% LSS 17 goto ExtraHQ_type)
echo.
echo Uhhh... Seriously?
goto get_extrahq_scale

: ExtraHQ_type
for /f "tokens=3 skip=2" %%G in ('find "hq_scale = " "%~dp0encode.avs"') do (set current_scale=%%G)
".\programs\replacetext" "encode.avs" "hq_scale = %current_scale%" "hq_scale = %ExtraScale%"

set ExtraType=
if [%param_2%]==[] goto get_extrahq_type
if [%param_2:~1,1%]==[] goto get_extrahq_type
set ExtraType=%param_2:~1,1%
goto process_extrahq_type

: get_extrahq_type
echo.
echo Which ExtraHQ encode type do you want to do using scale %ExtraScale%?
echo.
echo Press 1 for Modern HQ MKV.
echo Press 2 for Compatibility MP4.
echo Press 3 both.
echo.
set /p ExtraType=

: process_extrahq_type
if "%ExtraType%"=="1" goto ExtraHQ_10bit444
if "%ExtraType%"=="2" goto ExtraHQ_512kb
if "%ExtraType%"=="3" goto ExtraHQ_10bit444
echo.
echo C'mon! Let's finish this already!
goto get_extrahq_type

: HD
title Processing YouTube
echo.
echo ----------------------------
echo  Encoding YouTube HD stream
echo ----------------------------
echo.
:: Audio ::
echo Encoding audio...
".\programs\ffmpeg" -y -hide_banner -v error -stats -i encode.avs -vn -c:a libvorbis -q 10 ".\temp\audio_youtube.ogg"

:: Video ::
echo Encoding video...
".\programs\replacetext" "encode.avs" "hd = false" "hd = true"
".\programs\x264_x64" --qp 5 -b 0 --keyint infinite --output ".\temp\video_youtube.mkv" encode.avs
".\programs\replacetext" "encode.avs" "hd = true" "hd = false"

:: Muxing ::
".\programs\mkvmerge" -o ".\output\encode_youtube.mkv" --compression -1:none ".\temp\video_youtube.mkv" ".\temp\audio_youtube.ogg"

if "%VIRTUALBOY%"=="1" (set VBPREF="_vb_") else (set VBPREF="_")
if "%VIRTUALBOY%"=="1" (".\programs\mkvmerge.exe" -o ".\output\encode%VBPREF%youtube.mkv" --compression -1:none --stereo-mode 0:1 ".\temp\video_youtube.mkv" ".\temp\audio_youtube.ogg")

echo.
echo -----------------------------
echo  Uploading YouTube HD stream
echo -----------------------------
echo.
start "" cmd /c type "%~dp0programs\ytdesc.txt" ^| "%~dp0programs\tvcman.exe" "%~dp0output\encode%VBPREF%youtube.mkv" todo tasvideos
rem start "" cmd /c echo todo ^| "%~dp0programs\tvcman.exe" "%~dp0output\encode%VBPREF%youtube.mkv" todo tasvideos
if "%EncodeChoice%"=="3" goto Defaults

: 10bit444
title Processing Modern
echo.
echo --------------------------------
echo  Encoding 10bit444 downloadable
echo --------------------------------
echo.
:: Audio ::
echo Encoding audio...
".\programs\ffmpeg" -y -hide_banner -v error -stats -i encode.avs -vn -c:a libopus -b:a 64K ".\temp\audio.opus"

:: Timecodes ::
echo Generating timecodes...
".\programs\replacetext" "encode.avs" "i444 = false" "i444 = true"
".\programs\replacetext" "encode.avs" "pass = 0" "pass = 1"
".\programs\ffmpeg" -hide_banner -v error -stats -i encode.avs -an -f null -
".\programs\replacetext" "encode.avs" "pass = 1" "pass = 2"

:: Video ::
echo Encoding video...
".\programs\x264_x64" --threads auto --sar "%VAR%" --crf 20 --keyint 600 --ref 16 --no-fast-pskip --bframes 16 --b-adapt 2 --direct auto --me tesa --merange 64 --subme 11 --trellis 2 --partitions all --no-dct-decimate --input-range pc --range pc --tcfile-in ".\temp\times.txt" -o ".\temp\video.mkv" --colormatrix smpte170m --output-csp i444 --profile high444 --output-depth 10 encode.avs

:: Muxing ::
".\programs\mkvmerge" -o ".\output\encode.mkv" --timecodes -1:".\temp\times.txt" ".\temp\video.mkv" ".\temp\audio.opus"
 if "%EncodeChoice%"=="1" goto Defaults

: 512kb
title Processing Compatability
echo.
echo -------------------------------
echo  Encoding Archive 512kb stream
echo -------------------------------
echo.
:: Audio ::
echo Encoding audio...
".\programs\ffmpeg" -y -hide_banner -v error -stats -i encode.avs -vn -af atrim=start_sample=7107 -c:a libfdk_aac -profile:a aac_he -vbr 2 ".\temp\audio.mp4"

:: Video ::
echo Encoding video...
".\programs\replacetext" "encode.avs" "pass = 2" "pass = 0"
".\programs\replacetext" "encode.avs" "i444 = true" "i444 = false"
".\programs\x264_x64" --threads auto --crf 20 --keyint 600 --ref 16 --no-fast-pskip --bframes 16 --b-adapt 2 --direct auto --me tesa --merange 64 --subme 11 --trellis 2 --partitions all --no-dct-decimate --range tv --input-range tv --colormatrix smpte170m -o ".\temp\video_512kb.h264" encode.avs

:: Muxing ::
for /f "tokens=2 delims==" %%i in ('FINDSTR "r_frame_rate" "%~dp0temp\info.txt"') do (set fps=%%i)
".\programs\mp4box_x64" -hint -add ".\temp\video_512kb.h264":fps=%fps% -add ".\temp\audio.mp4" -new ".\output\encode_512kb.mp4"
goto Defaults

: ExtraHQ_10bit444
title Processing ExtraHQ Modern
echo.
echo ----------------------------------------
echo  Encoding ExtraHQ 10bit444 downloadable
echo ----------------------------------------
echo.
:: Audio ::
echo Encoding audio...
".\programs\ffmpeg" -y -hide_banner -v error -stats -i encode.avs -vn -c:a libopus -b:a 128K ".\temp\audio_extra.opus"

:: Timecodes ::
echo Generating timecodes...
".\programs\replacetext" "encode.avs" "pass = 0" "pass = 1"
".\programs\ffmpeg" -hide_banner -v error -stats -i encode.avs -an -f null -
".\programs\replacetext" "encode.avs" "pass = 1" "pass = 2"

:: Video ::
echo Encoding video...
".\programs\replacetext" "encode.avs" "i444 = false" "i444 = true"
".\programs\x264_x64" --threads auto --sar "%VAR%" --crf 20 --keyint 600 --preset veryslow --input-range pc --range pc --tcfile-in ".\temp\times.txt" -o ".\temp\video_%ExtraScale%x.mkv" --colormatrix smpte170m --output-csp i444 --profile high444 --output-depth 10 encode.avs

:: Muxing ::
".\programs\mkvmerge" -o ".\output\encode_%ExtraScale%x.mkv" --timecodes -1:".\temp\times.txt" ".\temp\video_%ExtraScale%x.mkv" ".\temp\audio_extra.opus"
if "%ExtraType%" NEQ "3" goto check_more_hqfactors

: ExtraHQ_512kb
title Processing ExtraHQ Compatability
echo.
echo ---------------------------------------
echo  Encoding ExtraHQ Archive 512kb stream
echo ---------------------------------------
echo.
:: Audio ::
echo Encoding audio...
".\programs\ffmpeg" -y -hide_banner -v error -stats -i encode.avs -vn -af atrim=start_sample=7107 -c:a libfdk_aac -profile:a aac_he -vbr 5 ".\temp\audio_extra.mp4"

:: Video ::
echo Encoding video...
".\programs\replacetext" "encode.avs" "pass = 2" "pass = 0"
".\programs\replacetext" "encode.avs" "i444 = true" "i444 = false"
".\programs\x264_x64" --threads auto --crf 20 --keyint 600 --preset veryslow --range tv --input-range tv --colormatrix smpte170m -o ".\temp\video_%ExtraScale%x_512kb.h264" encode.avs

:: Muxing ::
for /f "tokens=2 delims==" %%i in ('FINDSTR "r_frame_rate" "%~dp0temp\info.txt"') do (set fps=%%i)
".\programs\mp4box_x64" -hint -add ".\temp\video_%ExtraScale%x_512kb.h264":fps=%fps% -add ".\temp\audio_extra.mp4" -new ".\output\encode_%ExtraScale%x_512kb.mp4"
goto check_more_hqfactors

:check_more_hqfactors
set _scalestringlength=0

:calculate_length
call set _dummy=%%ExtraScale:~%_scalestringlength%%%
if not defined _dummy (
  goto updateExtraScaleFactors
)
set /a _scalestringlength=%_scalestringlength%+1
goto calculate_length

:updateExtraScaleFactors
call set ExtraScaleFactors=%%ExtraScaleFactors:~%_scalestringlength%%%
if [%ExtraScaleFactors%]==[] goto Defaults
if [%ExtraScaleFactors:/=%]==[] goto Defaults

set ExtraScaleFactors=%ExtraScaleFactors:~1%

if [%ExtraScaleFactors%]==[] goto Defaults
if [%ExtraScaleFactors:/=%]==[] goto Defaults
goto remove_starting_slash

: Defaults
".\programs\replacetext" "encode.avs" "pass = 1" "pass = 0"
".\programs\replacetext" "encode.avs" "pass = 2" "pass = 0"
".\programs\replacetext" "encode.avs" "i444 = true" "i444 = false"
".\programs\replacetext" "encode.avs" "hd = true" "hd = false"
".\programs\replacetext" "encode.avs" "hq = true" "hq = false"
".\programs\replacetext" "encode.avs" "vb = true" "vb = false"
goto end

:syntax_cmd
echo.
echo Command-line arguments: %0 ^<arc^> ^<enc_opt^>^<hq_opt^> ^<hq_scale^>
echo   ^<arc^>       Aspect ratio?      1-3 or width:height
echo                 1 = 1:1
echo                 2 = 4:3
echo                 3 = 16:9
echo   ^<enc_opt^>   Encode option?     1-5
echo                 1 = Modern HQ MKV
echo                 2 = Compatibility MP4
echo                 3 = HD Stream
echo                 4 = All of the above
echo                 5 = Extra HQ encodes
echo   ^<hq_opt^>    Extra HQ option?   1-3
echo                 1 = Modern HQ MKV
echo                 2 = Compatibility MP4
echo                 3 = Both of the above
echo   ^<hq_scale^>  Extra HQ scale?    2-16, separate multiple with /
echo.
echo   NOTE: hq_opt and hq_scale are used only when enc_opt is 5.
echo   NOTE: Do not put spaces between enc_opt and hq_opt.  For example, enter 52 to
echo         indicate encode option 5 and extra HQ option 2.
echo.

: end
title ALL DONE!
if "!cmdcmdline!" neq "!cmdcmdline:%~f0=!" (
	pause
)
endlocal