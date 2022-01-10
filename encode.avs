#	The downloadable/HD encoding script
#	https://tasvideos.org/EncodingGuide/PublicationManual.html

SetFilterMTMode("DEFAULT_MT_MODE", MT_MULTI_INSTANCE)
AddAutoloadDir("MAINSCRIPTDIR/programs/plugins")
Import(ScriptDir() + "programs/functions.avsi")

#	"RGB24" for FFV1, "AUTO" for the rest
pixelType = "RGB24"

AviSource("movie.avi", pixel_type=pixelType)

#	Dolphin (with FFMPEG). Use FFV1 patch for dumping:
#	https://github.com/vadosnaprimer/dolphin/releases
# AviSource("movie.avi", pixel_type="RGB24")
# AudioDub(last, wavsource("dspdump.wav"))

threads = 8			# manual, how many threads avisynth should use.
trimFrame = 654321	# manual, discards logo lengh automatically
handHeld = false 	# auto, but set it for preview
hd = false			# auto, but set it for preview
halfFPS = false		# for games that "lag" every other frame
prescaleFactor = 2	# set back to 1 if source is already 480p or 480i

#	Resizer (for hd upscaling and multisegment import)
resizer = hd ? "Point" : "Lanczos"
#	force Lanczos for 3D footage with increased internal resolution 
# resizer = "Lanczos"

#	Subtitles contents
game = "Game Name"
branch = "'branch'"	# lowercase for usual words, capital for in-game capital words. when blank, leave "''"
author = "author"
time = "00:00.0"
rerecords = "0"

#	Subtitles timing and placement
subFF = 2689 		# first subtitles frame, set manually!
subAlign = 8		# subtitles horizontal alignment (7/8/9)
subEntry = 3		# sets the number of sub entries (2/3/4)
subYpc = 1			# subtitles vertical position in percents of video height
subXpc = 1			# subtitles horizontal position in percents of video width (can be negative)
subSizepc = 5		# subtitles font size in percents of smaller video side
subLengthMul = 5	# entry length in seconds (fractions work)
subFF2delay = 0		# extra delay in frames between subtitle entries 1 and 2
subFF2delay2 = 0	# extra delay in frames between subtitle entries 2 and 3
subFF2delay3 = 0	# extra delay in frames between subtitle entries 3 and 4

#	Multisegment import (upscales hires segments straight to HD when needed)
#	requires normally importing a sample whose attributes it will use for all segments
ms = false			# enable multisegment import
ms_base = "movie_"	# common string for all segment names
ms_start = 0		# number of the first segment
ms_end = 15			# number of the last segment
ms_format = "%1.0f"	# string format: http://avisynth.nl/index.php/Internal_functions#String

#	Aspect ratio correction
wAspect = 4
hAspect = 3

#	Subtitles text
subString1	= game + "\n" \
			+ (branch == "''" ? "" : branch + "\n") \
			+ "Played by " + author
subString2	= "Playing time: " + time \
			+ "\nRerecord count: " + rerecords	
subString3	= "This is a tool-assisted recording." \
subString4	= "For details, visit https://TASVideos.org/"

#	Fix progressing (not floating) audio/video desync
avDesyncFixer = false

################
# LEGACY STUFF #
################

#	Famtasia
# ConvertAudioTo16bit()

#	Mupen64
# ResampleAudio(last, 44100)
# Crop(0,0,-0,-20)	# when old Glide64 is used

#	PSXjin
# audio = WavSource("movie_000.wav")
# AudioDub(audio, last)

#	Old Dolphin (remove /* and */ to uncomment)
#	get values at https://tasvideos.org/forum/viewtopic.php?p=373299#373299
/*
M = 486000000
F = 60
k = 1
N = 525
b = 0
D = (k * N + b) * floor(floor(M / F) / N) # don't edit this formula
video = last.TimecodeFPS("timecodes.txt", fpsnum=M, fpsden=D)
audio = \
	WavSource("dspdump0.wav") + \
	WavSource("dspdump1.wav").ResampleAudio(32000) + \
	WavSource("dspdump.wav")
*/

######################
# AUTOMATED SETTINGS #
######################

ConvertToRGB32()

#	Add 1 scanline if height is uneven (ntsc sms, pal c64)
last.height % 2 > 0 ? StackVertical(last, Crop(0, Height-1, 0, 0)) : 0

#	Make too dark scenes brighter
# AutoLevels(filterRadius=1000, sceneChgThresh=200, gamma=1.1)

#	Fix progressing (not floating) audio/video desync
num = last.AudioLengthF * last.FrameRateNumerator
denom = last.FrameCount * last.FrameRateDenominator
avDesyncFixer ? AssumeSampleRate(Round(num / denom)).ResampleAudio(48000) : 0
#	Alternative method that tweaks framerate instead (not recommended)
# avDesyncFixer ? AssumeFPS(last.FrameCount / last.AudioLengthF * last.AudioRate) : 0

#	Pick logo file
file = hd \
	? "hdlogo.png" \
	: "logo.png"
# file = !hd ? "logo34.png" : "hdlogo34.png"

prescaleFactor > 1 ? \
	PointResize(last.width * prescaleFactor, last.height * prescaleFactor) : 0

#	Aspect ratio correction for SD encodes
height	= last.height
width	= handHeld \
		? last.width \
		: height * wAspect / hAspect
width	= width  % 4 == 1 ? width  + 3 \
		: width  % 4 == 2 ? width  + 2 \
		: width  % 4 == 3 ? width  + 1 : width
height	= height % 4 == 1 ? height + 3 \
		: height % 4 == 2 ? height + 2 \
		: height % 4 == 3 ? height + 1 : height
#	Remember SD frame size for subYpos HD tweaks
wARC	= width
hARC	= height
#	Actually go HD if we need
height	= hd ? 2160 : height
width	= handHeld \
		? height * last.width / last.height \
		: height * wAspect / hAspect
width	= width  % 4 == 1 ? width  + 3 : \
		  width  % 4 == 2 ? width  + 2 : \
		  width  % 4 == 3 ? width  + 1 : width
hStretch = height / last.height

#	Rescaling
#	hd: resize to 4K, then just subsample with lanczos in the end
#	handheld: do nothing
#	480p: do ARC with lanczos
resized = hd \
		? eval(resizer+"Resize(width, height)") \
		: handHeld \
			? last \
			: Lanczos4Resize(width, height)

#	If ms enabled, we use parameters of "resized" to apply to all segments
resized = ms ? resized.AppendSegment(ms_base, ms_start, ms_end, ms_format, resizer, pixelType).ConvertToRGB32() : resized

#	Logo
logoVideo = ImageSource(file=file, start=0, end=int((resized.FrameRate * 2) - 1), fps=resized.FrameRate) \
	.ConvertToRGB32().AssumeFPS(resized)
logoAudio = BlankClip(logoVideo, audio_rate=resized.AudioRate, channels=resized.AudioChannels)
logo = AudioDub(logoVideo, logoAudio).Lanczos4Resize(resized.width, resized.height)
last = logo ++ resized

#	Subtitles variables
subXpos		= float(last.width) / 100 * subXpc
subXpos 	= subAlign == 7 || subAlign == 4 || subAlign == 1 \
			? subXpos \
			: subAlign == 8 || subAlign == 5 || subAlign == 2 \
			? last.width / 2 + subXpos \
			: last.width - subXpos
subYpos		= float(last.height) / 100 * subYpc
smallerSide = last.height < last.width ? last.height : last.width
subSize 	= float(smallerSide) / 100 * subSizepc
subHaloSize = floor(subSize / 7)
subLength	= int(last.FrameRate * subLengthMul)
subFF2		= SubFF  + subLength + 1 + subFF2delay
subFF3		= SubFF2 + subLength + 1 + subFF2delay2
subFF4		= SubFF3 + subLength + 1 + subFF2delay3
subColor	= $00FFFFFF
subRadius	= hd ? 0 : subHaloSize

#	Subtitles functions
subEntry == 2 ? ng_bighalo(subString1 + "\n" + SubString2, \
	x=subXpos, y=subYpos, align=subAlign, first_frame=subFF, \
	last_frame=subFF+subLength, size=subSize, \
	text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius) : 0
	
subEntry == 2 ? ng_bighalo(subString3 + "\n" + subString4, \
	x=subXpos, y=subYpos, align=subAlign, first_frame=subff2, \
	last_frame=subff2+subLength, size=subSize, \
	text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius) : 0
	
subEntry == 3 || subEntry == 4 ? ng_bighalo(subString1, \
	x=subXpos, y=subYpos, align=subAlign, first_frame=subFF, \
	last_frame=subFF+subLength, size=subSize, \
	text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius) : 0
	
subEntry == 3 || subEntry == 4 ? ng_bighalo(subString2, \
	x=subXpos, y=subYpos, align=subAlign, first_frame=subff2, \
	last_frame=subff2+subLength, size=subSize, \
	text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius) : 0
	
subEntry == 3 ? ng_bighalo(subString3 + "\n" + subString4,  \
	x=subXpos, y=subYpos, align=subAlign, first_frame=subFF3, \
	last_frame=subFF3+subLength, size=subSize, \
	text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius) : 0
	
subEntry == 4 ? ng_bighalo(subString3,  \
	x=subXpos, y=subYpos, align=subAlign, first_frame=subFF3, \
	last_frame=subFF3+subLength, size=subSize, \
	text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius) : 0

subEntry == 4 ? ng_bighalo(subString4,  \
	x=subXpos, y=subYpos, align=subAlign, first_frame=subFF4, \
	last_frame=subFF4+subLength, size=subSize, \
	text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius) : 0

Trim(0, trimFrame)

halfFPS ? SelectOdd : 0

#	Youtube can't handle fps above 60
hd && last.FrameRate > 60 ? ChangeFPS(60) : 0

#	YV12 reduces chroma, so we use "lanczos" even for HD
#	https://tasvideos.org/forum/viewtopic.php?t=19426
ConvertToYV12(chromaresample="lanczos", matrix=(hd \
	? "Rec709" \
	: "Rec601"))

Prefetch(threads)
