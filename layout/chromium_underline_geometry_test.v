module layout

import math

// The first 4chan blotter link: 11px Arial at a fractional inline offset. Blink
// fills one full pixel row at baseline + 1 and antialiases only the line ends.
fn test_chromium_auto_underline_snaps_below_the_rounded_ascent() {
	fragment := TextFragment{
		x:                          433.4531
		y:                          19
		width:                      27.5156
		height:                     12
		font_size:                  11
		decoration:                 'underline'
		decoration_skip_ink:        false
		font_metrics_set:           true
		font_ascent:                9.955
		font_descent:               2.33
		chromium_decorations:       true
		text_underline_offset_auto: true
	}
	commands := paint_text_decoration(fragment, 1)
	assert commands.len == 1
	assert commands[0].kind == 'fill_rect' && commands[0].antialiased_rect
	assert commands[0].x == fragment.x && commands[0].y == 30 && commands[0].height == 1
	assert math.abs(commands[0].width - fragment.width) < 1e-9
}

fn test_chromium_underline_offset_and_thickness_follow_blink_rounding() {
	explicit := TextFragment{
		x:                        10
		y:                        4.4
		width:                    20
		height:                   15
		font_size:                13.333333
		decoration:               'underline'
		decoration_skip_ink:      false
		font_metrics_set:         true
		font_ascent:              12.07
		font_descent:             2.83
		decoration_thickness:     2.6
		decoration_thickness_set: true
		text_underline_offset:    1.4
		chromium_decorations:     true
	}
	// An explicit offset has no gap: 4.4 + 12 + 1 snaps to 17, and the 2.6px
	// thickness rounds to a 3px line.
	commands := paint_text_decoration(explicit, 1)
	assert commands.len == 1
	assert [commands[0].x, commands[0].y, commands[0].width, commands[0].height] == [10.0, 17.0,
		20.0, 3.0]
}
