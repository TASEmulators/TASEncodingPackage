# Multisegment AVI import
function AppendSegment(
\   clip sample,
\ string base,
\    int first_val,
\    int last_val,
\ string format,
\ string resizer
\){
	filename = base + string(first_val, format) + ".avi"
	result = AviSource(filename).Eval(resizer + """Resize(sample.width, sample.height)""")
	return (first_val < last_val) \
		? result + sample.AppendSegment(base, first_val+1, last_val, format, resizer) \
		: result
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

function TASBlend(
\   clip c,
\  float "ratio"
\){
    # reduces framerate to 1/2 but leaves flicker effects partly visible
    # blends frame pairs with alternating opacity
    # The default for this is 2/3+1/3;1/3+2/3)
    # optional "ratio" is the opacity of the first frame out of the four
    ratio    = default(ratio, 2.0 / 3)
    opacity1 = round((1 - ratio) * 257)
    opacity2 = round((ratio) * 257)
    c
    Interleave( \
        Layer(SelectEvery(4, 0), SelectEvery(4, 1), level=opacity1), \
        Layer(SelectEvery(4, 2), SelectEvery(4, 3), level=opacity2) \
    )
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
        0, align, spc, lsp, font_width, font_angle)
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
        0, align, spc, lsp, font_width, font_angle)
    overlay = tc.Mask(alpha_mask.ConvertToRGB32())
    
    clp.ApplyRange(first_frame, last_frame, "Layer", overlay)
}

# nanogyth's deblink.
function ng_deblink(
\   clip clp,
\  float "ratio",
\    int "level",
\   clip "blinkmask"
\){
#Version 10 2012.04.22

    blink = default(blinkmask, clp.ng_blinkmask())

    ratio = default(ratio, 2.0 /3)
    assert(ratio >= 0.0 && 1.0 >= ratio,
    \      "[ng_deblink] 1.0 >= ratio >= 0.0, it was " + string(ratio))

    level = default(level, round(ratio * 257))
    assert(level >= 0 && 257 >= level,
    \      "[ng_deblink] 257 >= level >= 0, it was " + string(level))

    m01=mt_logic(blink.SelectEvery(4,0),
\                blink.SelectEvery(4,1),
\                mode="or").ConvertToRGB32()
    m23=mt_logic(blink.SelectEvery(4,2),
\                blink.SelectEvery(4,3),
\                mode="or").ConvertToRGB32()

    f0=Layer(clp.SelectEvery(4,0),
\            clp.SelectEvery(4,1).Mask(m01),
\            level=level)
    f1=Layer(clp.SelectEvery(4,1),
\            clp.SelectEvery(4,0).Mask(m01),
\            level=level)
    f2=Layer(clp.SelectEvery(4,2),
\            clp.SelectEvery(4,3).Mask(m23),
\            level=(257-level) )
    f3=Layer(clp.SelectEvery(4,3),
\            clp.SelectEvery(4,2).Mask(m23),
\            level=(257-level) )

    Interleave(f0,f1,f2,f3)
}

function ng_blinkmask(clip clp,
\   bool "TEST",
\   bool "STABILIZE",
\   bool "SHARP",
\   bool "HYSTER",
\    int "inpand",
\    int "expand",
\    int "ml"
\){
#Version 10 2012.04.22

#BLINK
# Blinking is a block that alternates on/off each frame
# SelectEven would only see either the on or the off

#FLASH
# Flashing is a block that is only on for a single frame
# SelectEven might miss the flash

#SHAKE
# Shaking is a block that moves back/forth each frame
# SelectEven would only see one position

# The goal of this function is to make a blink mask for use with
# ng_deblink. For overly complicated scenes where a clean blinkmask
# can't be found, just use TASBlend. Uniform softness looks better
# than sharp artifacts.

# This function calculates flash and shake info for the test script,
# but those effects should be handled in different ways.
# Flash - choose frames to make sure the flash is in your final clip.
# Shake - SelectEvery(4,0,2,1,3) or SelectEvery(4,1,0,2,3)
# SelectEvery doesn't generally work because it messes with the fluidity
# of motion. But that won't be noticable on a shaking screen.
# Be careful if 2 frame blinking is present, as the selectevery can turn
# it into 1 frame blinking.

    TEST      = default(     TEST, false)
    STABILIZE = default(STABILIZE, true)
    SHARP     = default(    SHARP, true)
    HYSTER    = default(   HYSTER, false)
    inpand    = default(   inpand, 1)
    expand    = default(   expand, 1)
    ml        = default(       ml, 128)

# The functions used to make the masks work in the YV12 colorspace. Once
# the masks are created they can be used in the RGB32 colorspace direcly
    src=clp.ConvertToYV12()

# Blinking is located by looking for blocks that don't exist in
# consecutive frames. The motion vector will match blocks that exist in
# both frames. The blocks that aren't in both will end up with huge
# values that are picked out by the motion mask.
    super = MSuper(src, pel=1)
    fvec  = MAnalyse(super, isb=false, blksize=4)
    bvec  = MAnalyse(super, isb=true , blksize=4)
    fmask = Mmask(src, fvec, kind=1, ml=ml).mt_binarize()
    bmask = Mmask(src, bvec, kind=1, ml=ml).mt_binarize()
    blink = mt_logic(fmask, bmask, mode="and")

# Blinking usually occurs against a stable background. This is found
# by looking at blocks 2 frames apart. This distinguishes a blink from
# blocks that are just changing every frame.
    ee_src   = src.SelectEven()
    ee_super = MSuper(ee_src, pel=1)
    ee_fvec  = MAnalyse(ee_super, isb=false, blksize=4)
    ee_bvec  = MAnalyse(ee_super, isb=true , blksize=4)
    ee_fmask = Mmask(ee_src, ee_fvec, kind=1, ml=ml).mt_binarize()
    ee_bmask = Mmask(ee_src, ee_bvec, kind=1, ml=ml).mt_binarize()

    oo_src   = src.SelectOdd()
    oo_super = MSuper(oo_src, pel=1)
    oo_fvec  = MAnalyse(oo_super, isb=false, blksize=4)
    oo_bvec  = MAnalyse(oo_super, isb=true , blksize=4)
    oo_fmask = Mmask(oo_src, oo_fvec, kind=1, ml=ml).mt_binarize()
    oo_bmask = Mmask(oo_src, oo_bvec, kind=1, ml=ml).mt_binarize()

    fmask_2   = Interleave(ee_fmask, oo_fmask)
    bmask_2   = Interleave(ee_bmask, oo_bmask)
    background = mt_logic(fmask_2.SelectEvery(1,1),
\                         bmask_2.SelectEvery(1,-1),
\                         mode="or")
    stable_blink = mt_hysteresis(background.mt_invert, blink)
    blink2 = (STABILIZE) ? stable_blink : blink

# Shrinking the blink mask can get rid of noise,
# too much will lose signal as well.
    blink3 = blink2.mt_inpand(mode=mt_diamond(inpand))
    
# Using just pixels that changed helps sharpen the mask
    diff   = ng_diff(clp.SelectEvery(1,-1), clp)
    diff_2 = mt_logic(diff, diff.SelectEvery(1,1), mode="and")

#Hysteresis
# Matches continuous blocks of pixels.
# Use with care, will match the whole screen on fades.
    hyster_blink = mt_hysteresis(blink3, diff_2)

# Expand the mask to make up for shrinking it (or just use hysteresis)
    blink4 = blink3.mt_expand(mode=mt_circle(expand))
    sharp_blink = mt_logic(blink4, diff_2, mode="and")

    blink5 = (HYSTER) ? hyster_blink :
\            (SHARP)  ? sharp_blink  : blink4

    
# A flash won't match blocks 1 or 2 frames away.
    sub_flash = mt_logic(fmask_2, bmask_2, mode="and")
    flash     = mt_logic(blink, sub_flash, mode="and")
    
# A shake changes in one frame and changes back in the next.
# This isn't detected by the motion vectors because the blocks exist in
# both frames, they are just shifting around.
    same   = ng_same(clp.SelectEvery(1,-1), clp.SelectEvery(1,1))
    shake  = mt_logic(same, diff_2, mode="and")

    (TEST) ? stackhorizontal(clp, mergeRGB(blink5, flash, shake))
\          : blink5.GreyScale()
}

function ng_diff(clip A, clip B, int "thr"){
    thr=default(thr,0)
    TAD=ng_TAD(A,B)
    return mt_binarize(TAD, threshold=thr)
}

function ng_same(clip A, clip B, int "thr"){
    thr=default(thr,0)
    TAD=ng_TAD(A,B)
    return mt_binarize(TAD, threshold=thr, upper=true)
}

function ng_TAD(clip A, clip B){
    R=ng_AD(A  .showRed("YV12"),B  .showRed("YV12"))
    G=ng_AD(A.showGreen("YV12"),B.showGreen("YV12"))
    B=ng_AD(A .showBlue("YV12"),B .showBlue("YV12"))
    return ng_plus(R, ng_plus(G, B))
}

function ng_AD(clip A, clip B){
    return mt_lutxy(A,B,"x y - abs")
}

function ng_plus(clip A, clip B){
    return mt_lutxy(A,B,"x y +")
}