# Multisegment AVI import via resizing
function AppendSegment(
\   clip sample,
\ string base,
\    int first_val,
\    int last_val,
\ string format,
\ string resizer,
\	bool hd,
\ string pix_type
\){
	for (i = first_val, last_val) {
		filename = base + string(i, format) + ".avi"
		AviSource(filename, pixel_type=pix_type)
		
		if (hd) {
			Eval(resizer + """Resize(sample.width, sample.height)""")
		} else {
			scaler = int(float(sample.height) / float(last.height))
			scaler = scaler < 1 ? 1 : scaler
			PointResize(last.width * scaler, last.height * scaler)
			Lanczos4Resize(sample.width, sample.height)
		}
		
		if (i == first_val) {
			result = last
		} else {
			result = result + last
		}
	}
	
	return result
}

# Multisegment AVI import via letterboxing
function AppendSegmentLetterbox(
\ string base,
\    int first_val,
\    int last_val,
\ string format,
\ string pix_type
\){
	biggest_width  = 0
	biggest_height = 0
	
	for (i = first_val, last_val) {
		filename = base + string(i, format) + ".avi"
		AviSource(filename, pixel_type=pix_type)
		biggest_width  = biggest_width  < last.width  ? last.width  : biggest_width
		biggest_height = biggest_height < last.height ? last.height : biggest_height
	}
	
	for (i = first_val, last_val) {
		filename = base + string(i, format) + ".avi"
		AviSource(filename, pixel_type=pix_type)
		
		xside = int(biggest_width  - last.width)  / 2
		yside = int(biggest_height - last.height) / 2
		AddBorders(xside, yside, xside, yside)
		
		if (i == first_val) {
			result = last
		} else {
			result = result + last
		}
	}
	
	return result
}

# rounds an integer up or down to the nearest multiple of mod
function ForceModulo(
\    int number,
\    int mod,
\   bool up
\){
	return (up \
		? (int(number + mod - 1) / mod) * mod \
		:  int(number            / mod) * mod)
}

function Remove(
\   clip c,
\    int start,
\    int end
\){
	c
	Trim(0, -start) + Trim(end, 0)
}

function Replace(
\   clip dest,
\    int start,
\    int end,
\   clip src
\){
    Assert(start >= 0, "Replace: parameter 'start' is negative")
    Assert(  end >= 0, "Replace: parameter 'end' is negative")
    p1 = dest.Trim(0, -start)
    p2 =  src.Trim(start, end)
    p3 = dest.Trim(end + 1, 0)
    p1 = (start == 0) ? dest.Trim(0, -1).DeleteFrame(0) : p1
    p3 = (  end == 0) ? dest.Trim(0, -1).DeleteFrame(0) : p3
    p1 + p2 + p3
    return (dest.HasAudio) ? last.AudioDub(dest) : last
}

# HD encodes need big subtitle fonts, but AviSynth can't enlarge the halo.
# Here's the custom subtitle function by nanogyth
# It's slow, but we have subtitles for a limited time only
function ng_bighalo(
\   clip clp,
\ string text,
\  float "x",
\  float "y",
\    int "first_frame",
\    int "last_frame",
\ string "font",
\  float "size",
\    int "text_color",
\    int "halo_color",
\    int "align",
\    int "spc",
\    int "lsp",
\  float "font_width",
\  float "font_angle",
\    int "halo_radius",
\ string "mode",
\ string "halo",
\ string "shadow"
\){

#Version 16-17 2012/12/1
# - added circle_12 as default
# - reworked math to avoid bitwise functions that are only
#   availible in experimental builds
#Version 15 2012/12/1
# - drop shadow added
# - halo_radius still works, but calculating the points of 
#   a hollow circle for halo is much faster
# - mode is depricated since memo-ing isn't as needed

    first_frame = default(first_frame, 0)
    last_frame  = default( last_frame, first_frame + 299)
    font        = default(       font, "Arial")
    size        = default(       size, 112)
    x           = default(          x, -1)
    y           = default(          y, -1)
    text_color  = default( text_color, $00DDDDDD)
    halo_color  = default( halo_color, $80000000)
    align       = default(      align, 5)
    spc         = default(        spc, 0)
    lsp         = default(        lsp, 0)
    font_width  = default( font_width, 0)
    font_angle  = default( font_angle, 0)
    shadow      = default(     shadow, "")
    w           = clp.width
    h           = clp.height
###
   ###
      ##
        #
         #
          #
          #
           #
           #
           #
            #
            #
#           #
circle_12="0 0 "+\
"12 0 0 12 -12 0 0 -12 "+\
"1 12 2 12 3 11 4 11 5 11 6 10 7 10 8 9 "+\
"12 1 12 2 11 3 11 4 11 5 10 6 10 7 9 8 "+\
"-1 12 -2 12 -3 11 -4 11 -5 11 -6 10 -7 10 -8 9 "+\
"-12 1 -12 2 -11 3 -11 4 -11 5 -10 6 -10 7 -9 8 "+\
"-1 -12 -2 -12 -3 -11 -4 -11 -5 -11 -6 -10 -7 -10 -8 -9 "+\
"-12 -1 -12 -2 -11 -3 -11 -4 -11 -5 -10 -6 -10 -7 -9 -8 "+\
"1 -12  2 -12 3 -11 4 -11 5 -11 6 -10 7 -10 8 -9 "+\
"12 -1  12 -2 11 -3 11 -4 11 -5 10 -6 10 -7 9 -8 "
    halo = (defined(halo_radius) && halo_radius != 0) ? mt_circle(halo_radius) : circle_12

    invis = BlankClip(1, w, h, pixel_type="YV12")
    tm = Subtitle(invis, text, x, y, 0, 0, font, size, $00FFFFFF,\
        0, align, spc, lsp, font_width, font_angle, utf8=true)
    text_mask = tm.mt_expand(mode="0 0 "+shadow, chroma="-128")
    halo_mask = text_mask.mt_expand(mode=halo, chroma="-128")
    
    h0      = halo_color%$01000000
    h_color = (h0>=0) ? h0 : $01000000+h0
    t0      = text_color%$01000000
    t_color = (t0>=0) ? t0 : $01000000+t0
    h_alpha = (halo_color>=0) ? 255-(halo_color/$01000000) : (-halo_color-1)/$01000000
    t_alpha = (text_color>=0) ? 255-(text_color/$01000000) : (-text_color-1)/$01000000
    lut_str = string(h_alpha)+ " x * 255 / " +string(t_alpha)+\
              " " +string(h_alpha)+ " - y * 255 / +"

    alpha_mask = mt_lutxy(halo_mask, text_mask, lut_str)

    hc = BlankClip(1, w, h, color=h_color)
    tc = Subtitle(hc, text, x, y, 0, 0, font, size, t_color,\
        0, align, spc, lsp, font_width, font_angle, utf8=true)
    overlay = tc.Mask(alpha_mask.ConvertToRGB32())
    
    clp.ApplyRange(first_frame, last_frame, "Layer", overlay)
}