module main

import dom
import page

$if vox_ui2 ? {
	import ui2
} $else {
	import math
}

// Keep gesture state per browser tab/document. Coordinates are viewport pixels,
// so page zoom does not change the click tolerance.
struct BrowserPointerClicks {
mut:
	count    int
	last_ms  i64
	last_x   f64
	last_y   f64
	document voidptr = unsafe { nil }
	button   int     = -1
}

fn (mut clicks BrowserPointerClicks) press(document &dom.Document, button int, x f64, y f64,
	now_ms i64) int {
	if clicks.document != voidptr(document) || clicks.button != button || button != 0
		|| now_ms < clicks.last_ms {
		clicks.count = 0
	}
	$if vox_ui2 ? {
		mut counter := ui2.ClickCounter{
			count:   clicks.count
			last_ms: clicks.last_ms
			last_x:  clicks.last_x
			last_y:  clicks.last_y
		}
		clicks.count = counter.press(x, y, now_ms)
	} $else {
		quick := clicks.count > 0 && now_ms - clicks.last_ms <= 500
		near := math.abs(x - clicks.last_x) <= 4 && math.abs(y - clicks.last_y) <= 4
		clicks.count = if quick && near && clicks.count < 3 { clicks.count + 1 } else { 1 }
	}
	clicks.last_ms = now_ms
	clicks.last_x = x
	clicks.last_y = y
	clicks.document = voidptr(document)
	clicks.button = button
	return clicks.count
}

fn browser_text_word_range(text string, offset int) page.SelectionRange {
	$if vox_ui2 ? {
		// UI2 uses rune columns; DOM ranges and native text controls use UTF-16.
		runes := text.runes()
		mut offsets := [0]
		mut column := 0
		for code in runes {
			offsets << offsets.last() + if u32(code) > 0xffff { 2 } else { 1 }
			if offsets.last() <= offset { column++ }
		}
		start, end := ui2.text_word_range(text, column)
		return page.SelectionRange{ start: offsets[start], end: offsets[end] }
	} $else {
		segmenter := dom.Segmenter{ segmented_text: text, granularity: .word }
		boundaries := segmenter.boundaries()
		index := math.max(0, math.min(offset, boundaries.last() - 1))
		for i in 1 .. boundaries.len {
			if boundaries[i] > index {
				return page.SelectionRange{ start: boundaries[i - 1], end: boundaries[i] }
			}
		}
		return page.SelectionRange{}
	}
}
