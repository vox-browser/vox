module css

import dom
import os
import time

// VOX_STYLE_PASS_DIAGNOSTICS=1: one line per document style pass with the
// elements it visited and why each one was computed again.
const style_pass_diagnostics = os.getenv('VOX_STYLE_PASS_DIAGNOSTICS') != ''

// 0 full update, 1 own flag, 2 parent display, 3 ancestor descendant
// recompute, 4 custom properties, 5 if()/media, 6 font inputs refreshed,
// 7 font inputs recomputed, 8 inherited values only, 9 elements visited.
__global style_pass_counts [10]u64

@[inline]
fn note_style_pass(index int) {
	if style_pass_diagnostics { style_pass_counts[index]++ }
}

fn style_pass_clock() u64 {
	return if style_pass_diagnostics { time.sys_mono_now() } else { u64(0) }
}

fn report_style_pass(document &dom.Document, started u64) {
	if !style_pass_diagnostics { return }
	c := style_pass_counts
	if c[9] > 0 {
		eprintln('VOX_STYLE_PASS us=${(time.sys_mono_now() - started) / 1000} visited=${c[9]} full=${c[0]} own=${c[1]} parent_display=${c[2]} ancestor=${c[3]} custom=${c[4]} conditional=${c[5]} font_refresh=${c[6]} font_recompute=${c[7]} inherited=${c[8]} url=${document.url.serialize().limit(60)}')
	}
	style_pass_counts = [10]u64{}
}
