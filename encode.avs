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

trimFrame = 654321	# manual, discards logo lengh automatically
ARCorrection = false	# aspect ratio correction. auto, but set it for preview
hd = false			# auto, but set it for preview
halfFPS = false		# for games that "lag" every other frame
threads = 8			# manual, how many threads avisynth should use.

#	if the script guessed wrong, force the right factor by setting to non-zero
#	for Dolphin footage, force 1
prescaleOverride = 0 

#	Resizer (for hd upscaling and multisegment import)
resizer = hd ? "Point" : "Lanczos"
#	force Lanczos for 3D footage with increased internal resolution 
# resizer = "Lanczos"

#	Subtitles contents
game = "Game Name"
branch = "branch"	# lowercase for usual words, capital for in-game capital words. when blank, leave ""
author = "author"
time = "00:00.0"
rerecords = "0"

#	Subtitles timing and placement
subFF = 2689 		# first subtitles frame, set manually!
subAlign = 8		# subtitles horizontal alignment (7/8/9)
subYpc = 1			# subtitles vertical position in percents of video height
subXpc = 1			# subtitles horizontal position in percents of video width (can be negative)
subEntry = 4		# sets the number of sub entries (2/3/4)
subFF2delay = 0		# extra delay in frames between subtitle entries 1 and 2
subFF3delay = 0		# extra delay in frames between subtitle entries 2 and 3
subFF4delay = 0		# extra delay in frames between subtitle entries 3 and 4
subLengthMul = 5	# entry length in seconds (fractions work)
subSizepc = 5		# subtitles font size in percents of smaller video side

#	Multisegment import (upscales hires segments straight to HD when needed)
#	requires normally importing a sample whose attributes it will use for all segments
ms = false			# enable multisegment import
msLetterbox = false	# import segments with letterboxing instead of resizing
					# (initally imported clip is discarded)
msBase = "movie_"	# common string for all segment names
msStart = 0			# number of the first segment
msEnd = 15			# number of the last segment
msFormat = "%1.0f"	# string format: http://avisynth.nl/index.php/Internal_functions#String
msAudioFile = ""	# path to external audio file. not used when empty

#	Aspect ratio correction
wAspect = 4
hAspect = 3

#	Subtitles text
subString1	= game + "\n" \
			+ (branch == "" ? "" : """"""" + branch + """"\n""") \
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

if (msLetterbox) {
	AppendSegmentLetterbox(msBase, msStart, msEnd, msFormat, pixelType)
	
	if (msAudioFile != "") {
		AudioDub(last, WavSource(msAudioFile))
	}
}

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
file = hd ? "hdlogo.png" : "logo.png"
# file = hd ? "hdlogo34.png" : "logo34.png"

#	Prescale lowres by 4, mid res by 2, and the rest ignore
magicNumerator = 768

if (prescaleOverride > 0) {
	prescaleFactor = prescaleOverride
} else {
	prescaleFactor = int(magicNumerator / last.height)
}

# 3 is banned due to chroma subsampling, use 2 instead
prescaleFactor = prescaleFactor.ForceModulo(2, false)

if (prescaleFactor > 1 && !hd) {
	PointResize(last.width * prescaleFactor, last.height * prescaleFactor)
}

#	Aspect ratio correction for SD encodes
#	if dimensions are not multiples of 4, codecs freak out, so we enforce mod 4
mod		= 4
height	= last.height.ForceModulo(mod, true)
width	= (ARCorrection \
		? height * wAspect / hAspect \
		: last.width) \
		.ForceModulo(mod, true)

#	Actually go HD if we need
if (hd) {
	vertical        = width < height
	
	normalAspect	= ARCorrection ? float(wAspect) / hAspect \
		: float(last.width) / last.height
	reverseAspect	= ARCorrection ? float(hAspect) / wAspect \
		: float(last.height) / last.width
	
	if (vertical) {
		temp		= normalAspect
		normalAspect	= reverseAspect
		reverseAspect	= temp
	}
	
	smallerSideCap  = 2160
	biggerSideCap   = 3840
	
	smallerSideHD	= smallerSideCap
	biggerSideHD	= int(smallerSideHD * normalAspect).ForceModulo(mod, true)
	
	if (biggerSideHD > biggerSideCap) {
		biggerSideHD	= biggerSideCap
		smallerSideHD	= int(biggerSideHD * reverseAspect).ForceModulo(mod, true)
	}
	
	width	= vertical ? smallerSideHD : biggerSideHD
	height	= vertical ? biggerSideHD  : smallerSideHD
}

#	Rescaling
#	hd: resize to 4K, then just subsample with lanczos in the end
#	handheld: do nothing
#	480p: do ARC with lanczos
resized = hd || ARCorrection \
	? Eval((hd ? resizer : "Lanczos4") + "Resize(width, height)") \
	: last

#	If ms enabled, we use parameters of "resized" to apply to all segments
if (ms && !msLetterbox) {
	resized = resized \
		.AppendSegment(msBase, msStart, msEnd, msFormat, resizer, hd, pixelType) \
		.ConvertToRGB32()
	
	if (msAudioFile != "") {
		resized = AudioDub(resized, WavSource(msAudioFile))
	}
}

#	Logo
logoVideo = ImageSource(file=file, start=0, end=int((resized.FrameRate * 2) - 1), fps=resized.FrameRate) \
	.ConvertToRGB32().AssumeFPS(resized)
logoAudio = BlankClip(logoVideo, audio_rate=resized.AudioRate, channels=resized.AudioChannels)
logo = AudioDub(logoVideo, logoAudio).Lanczos4Resize(resized.width, resized.height)
last = logo ++ resized

#	Subtitles variables
subXpos = float(last.width) / 100 * subXpc

if (subAlign == 9 || subAlign == 6 || subAlign == 3) {
	subXpos = last.width - subXpos
} else if (subAlign == 8 || subAlign == 5 || subAlign == 2) {
	subXpos = last.width / 2 + subXpos
}

subYpos		= float(last.height) / 100 * subYpc
smallerSide = min(last.height, last.width)
subSize 	= float(smallerSide) / 100 * subSizepc
subHaloSize = floor(subSize / 7)
subLength	= int(last.FrameRate * subLengthMul)
subFF2		= subFF  + subLength + 1 + subFF2delay
subFF3		= subFF2 + subLength + 1 + subFF3delay
subFF4		= subFF3 + subLength + 1 + subFF4delay
subColor	= $00FFFFFF
subRadius	= hd ? 0 : subHaloSize

if (subEntry == 2) {
	subString1 = subString1 + "\n" + SubString2
	SubString2 = subString3 + "\n" + subString4
} else if (subEntry == 3) {
	subString3 = subString3 + "\n" + subString4
}

#	Subtitles functions
ng_bighalo(subString1, x=subXpos, y=subYpos, align=subAlign, \
	first_frame=subFF, last_frame=subFF+subLength, size=subSize, \
	text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius)

ng_bighalo(SubString2, x=subXpos, y=subYpos, align=subAlign, \
	first_frame=subff2, last_frame=subff2+subLength, size=subSize, \
	text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius)

if (subEntry == 3 || subEntry == 4) {
	ng_bighalo(subString3, x=subXpos, y=subYpos, align=subAlign, \
		first_frame=subFF3, last_frame=subFF3+subLength, size=subSize, \
		text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius)
}

if (subEntry == 4) {
	ng_bighalo(subString4, x=subXpos, y=subYpos, align=subAlign, \
		first_frame=subFF4, last_frame=subFF4+subLength, size=subSize, \
		text_color=subColor, halo_color=$00000000, lsp=2, halo_radius=subRadius)
}

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
