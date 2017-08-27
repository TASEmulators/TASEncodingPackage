:: feos, 2013-2017 (cheers to Guga, Velitha, nanogyth, Aktan and Dacicus)
:: This global batch is a part of "TAS Encoding Package":
:: http://tasvideos.org/EncodingGuide/PublicationManual.html
:: Asks whether the console is TV based to autoset the SAR parameter (4:3 only so far).
:: Allows to select the encode to make.

@echo off
:: Restore AVS defaults ::
"./programs/replacetext" "encode.avs" "pass = 1" "pass = 0"
"./programs/replacetext" "encode.avs" "pass = 2" "pass = 0"
"./programs/replacetext" "encode.avs" "i444 = true" "i444 = false"
"./programs/replacetext" "encode.avs" "hd = true" "hd = false"
"./programs/replacetext" "encode.avs" "vb = true" "vb = false"

:: Uncomment for a VirtualBoy encode
:: set /a VIRTUALBOY=1

if "%VIRTUALBOY%"=="1" ("./programs/replacetext" "encode.avs" "vb = false" "vb = true")

echo.
echo -----------------------
echo  Hybrid Encoding Batch 
echo -----------------------
echo.

: SAR OPTIONS
echo Is this a TV based console? (y/n)
set /p ANSWER=
if "%ANSWER%"=="y" goto TV sar
if "%ANSWER%"=="n" goto handheld sar
echo I'm not kidding!
goto SAR OPTIONS

: TV sar
"./programs/replacetext" "encode.avs" "handheld = true" "handheld = false"
"./programs/replacetext" "encode.avs" "pass = 0" "pass = 1"
"./programs/avs2pipemod" -info encode.avs > "./temp/info.txt"
for /f "tokens=2" %%G in ('FIND "width" "./temp/info.txt"') do (set width=%%G)
for /f "tokens=2" %%G in ('FIND "height" "./temp/info.txt"') do (set height=%%G)
set /a "SAR_w=4 * %height%"
set /a "SAR_h=3 * %width%"
set VAR=%SAR_w%:%SAR_h%
"./programs/replacetext" "encode.avs" "pass = 1" "pass = 0"
goto ENCODE OPTIONS

: handheld sar
set VAR=1:1
"./programs/replacetext" "encode.avs" "handheld = false" "handheld = true"
goto ENCODE OPTIONS

: ENCODE OPTIONS
echo.
echo What encode do you want to do?
echo.
echo Press 1 for Modern HQ MKV.
echo Press 2 for Compatibility MP4.
echo Press 3 for HD Stream.
echo Press 4 for All of the above.
echo Press 5 for extra HQ encodes.

: Set choice
set /p EncodeChoice=
if "%EncodeChoice%"=="1" goto 10bit444
if "%EncodeChoice%"=="2" goto 512kb
if "%EncodeChoice%"=="3" goto HD
if "%EncodeChoice%"=="4" goto HD
if "%EncodeChoice%"=="5" goto ExtraHQ
echo.
echo You better choose something real!
goto Set choice

: HD
:: Audio ::
"./programs/avs2pipemod" -wav encode.avs | "./programs/venc" -q10 - "./temp/audio_youtube.ogg"
echo.
echo ----------------------------
echo  Encoding YouTube HD stream 
echo ----------------------------
echo.
:: Video ::
"./programs/replacetext" "encode.avs" "hd = false" "hd = true"
"./programs/avs2pipemod" -y4mp encode.avs | "./programs/x264_x64" --qp 5 -b 0 --keyint infinite --output "./temp/video_youtube.mkv" --demuxer y4m -
"./programs/replacetext" "encode.avs" "hd = true" "hd = false"
:: Muxing ::
"./programs/mkvmerge" -o "./output/encode_youtube.mkv" --compression -1:none "./temp/video_youtube.mkv" "./temp/audio_youtube.ogg"
goto Defaults
if "%VIRTUALBOY%"=="1" (set VBPREF="_vb_") else (set VBPREF="_")
if "%VIRTUALBOY%"=="1" ("./programs/ffmpeg" -i "./output/encode_youtube.mkv" -c copy -metadata:s:v:0 stereo_mode=1 "./output/encode%VBPREF%youtube.mkv")

echo.
echo -----------------------------
echo  Uploading YouTube HD stream 
echo -----------------------------
echo.
start https://encoders.tasvideos.org/status.html
start call "./programs\tvcman.exe" "./output/encode%VBPREF%youtube.mkv" todo tasvideos ^< "./programs/ytdesc.txt" ^& exit
if "%EncodeChoice%"=="3" goto Defaults

: 10bit444
:: Audio ::
"./programs/avs2pipemod" -wav encode.avs | "./programs/opusenc" --bitrate 64 - "./temp/audio.opus"
echo.
echo ----------------------
echo  Generating timecodes 
echo ----------------------
echo.
:: Timecodes ::
"./programs/replacetext" "encode.avs" "pass = 0" "pass = 1"
"./programs/avs2pipemod" -benchmark encode.avs
"./programs/replacetext" "encode.avs" "pass = 1" "pass = 2"
echo.
echo --------------------------------
echo  Encoding 10bit444 downloadable 
echo --------------------------------
echo.
:: Video ::
"./programs/replacetext" "encode.avs" "i444 = false" "i444 = true"
"./programs/avs2pipemod" -y4mp encode.avs | "./programs/x264-10_x64" --threads auto --sar "%VAR%" --crf 20 --keyint 600 --ref 16 --no-fast-pskip --bframes 16 --b-adapt 2 --direct auto --me tesa --merange 64 --subme 11 --trellis 2 --partitions all --no-dct-decimate --input-range pc --range pc --tcfile-in "./temp/times.txt" -o "./temp/video.mkv" --colormatrix smpte170m --output-csp i444 --demuxer y4m -
:: Muxing ::
"./programs/mkvmerge" -o "./output/encode.mkv" --timecodes -1:"./temp/times.txt" "./temp/video.mkv" "./temp/audio.opus"
 if "%EncodeChoice%"=="1" goto Defaults

: 512kb
:: Audio ::
"./programs/avs2pipemod" -wav encode.avs | "./programs/sox" -t wav - -t wav - trim 4672s | "./programs/neroAacEnc" -q 0.25 -if - -of "./temp/audio.mp4"
echo -------------------------------
echo  Encoding Archive 512kb stream 
echo -------------------------------
echo.
:: Video ::
"./programs/replacetext" "encode.avs" "pass = 2" "pass = 0"
"./programs/replacetext" "encode.avs" "i444 = true" "i444 = false"
"./programs/avs2pipemod" -y4mp encode.avs | "./programs/x264_x64" --threads auto --crf 20 --keyint 600 --ref 16 --no-fast-pskip --bframes 16 --b-adapt 2 --direct auto --me tesa --merange 64 --subme 11 --trellis 2 --partitions all --no-dct-decimate --range tv --input-range tv --colormatrix smpte170m -o "./temp/video_512kb.h264" --demuxer y4m -
:: Muxing ::
for /f "tokens=2" %%i in ('%~dp0\programs\avs2pipemod -info encode.avs ^|find "fps"') do (set fps=%%i)
for /f %%k in ('%~dp0\programs\div %fps%') do (set double=%%k)
"./programs/mp4box_x64" -hint -add "./temp/video_512kb.h264":fps=%double% -add "./temp/audio.mp4" -new "./output/encode_512kb.mp4"
goto Defaults

: ExtraHQ
:: Extra 10bit444 ::
:: Audio ::
"./programs/avs2pipemod" -wav encode.avs | "./programs/opusenc" --bitrate 64 - "./temp/audio_extra.opus"
echo.
echo ----------------------
echo  Generating timecodes 
echo ----------------------
echo.
:: Timecodes ::
"./programs/replacetext" "encode.avs" "pass = 0" "pass = 1"
"./programs/avs2pipemod" -benchmark encode.avs
"./programs/replacetext" "encode.avs" "pass = 1" "pass = 2"
echo.
echo --------------------------------
echo  Encoding ExtraHQ downloadable 
echo --------------------------------
echo.
:: Video ::
"./programs/replacetext" "encode.avs" "i444 = false" "i444 = true"
"./programs/avs2pipemod" -y4mp encode.avs | "./programs/x264-10_x64" --threads auto --sar "%VAR%" --crf 20 --keyint 600 --preset veryslow --input-range pc --range pc --tcfile-in "./temp/times.txt" -o "./temp/video_extra.mkv" --colormatrix smpte170m --output-csp i444  --demuxer y4m -
:: Muxing ::
"./programs/mkvmerge" -o "./output/encode_extra.mkv" --timecodes -1:"./temp/times.txt" "./temp/video_extra.mkv" "./temp/audio_extra.opus"

:: Extra 512kb ::
:: Audio ::
"./programs/avs2pipemod" -wav encode.avs | "./programs/sox" -t wav - -t wav - trim 4672s | "./programs/neroAacEnc" -q 0.25 -if - -of "./temp/audio_extra.mp4"
echo -------------------------------
echo  Encoding ExtraHQ stream 
echo -------------------------------
echo.
:: Video ::
"./programs/replacetext" "encode.avs" "pass = 2" "pass = 0"
"./programs/replacetext" "encode.avs" "i444 = true" "i444 = false"
"./programs/avs2pipemod" -y4mp encode.avs | "./programs/x264_x64" --threads auto --crf 20 --keyint 600 --preset veryslow --range tv --input-range tv --colormatrix smpte170m -o "./temp/video_512kb_extra.h264" --demuxer y4m -
:: Muxing ::
for /f "tokens=2" %%i in ('%~dp0\programs\avs2pipemod -info encode.avs ^|find "fps"') do (set fps=%%i)
for /f %%k in ('%~dp0\programs\div %fps%') do (set double=%%k)
"./programs/mp4box_x64" -hint -add "./temp/video_512kb_extra.h264":fps=%double% -add "./temp/audio_extra.mp4" -new "./output/encode_512kb_extra.mp4"

: Defaults
"./programs/replacetext" "encode.avs" "pass = 1" "pass = 0"
"./programs/replacetext" "encode.avs" "pass = 2" "pass = 0"
"./programs/replacetext" "encode.avs" "i444 = true" "i444 = false"
"./programs/replacetext" "encode.avs" "hd = true" "hd = false"
"./programs/replacetext" "encode.avs" "vb = true" "vb = false"
