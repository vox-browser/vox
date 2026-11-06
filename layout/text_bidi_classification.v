module layout

import dom
import os

const retain_text_bidi_scans = os.getenv('VOX_RETAIN_TEXT_BIDI_SCANS') != ''
const text_bidi_cache_diagnostics = os.getenv('VOX_TEXT_BIDI_CACHE_DIAGNOSTICS') != ''

__global text_bidi_cache_reported bool

// Classification depends only on the rendered code points. Paragraph direction
// and inline unicode-bidi styles are still checked by the iterator on each run.
// Text rendering invalidation clears this scalar with the other text caches.
fn text_may_require_bidi_processing(text_node &TextNode) bool {
	text := text_node.text_for_rendering()
	if retain_text_bidi_scans { return uncached_text_may_require_bidi_processing(text) }
	if cached := text_node.cached_inline_bidi_processing_ {
		if text_bidi_cache_diagnostics && !text_bidi_cache_reported
			&& !text_node.rendered_text_is_ascii_ {
			text_bidi_cache_reported = true
			eprintln('Vox bidi classification: reused rendered non-ASCII text')
		}
		return cached
	}
	result := !text_node.rendered_text_is_ascii_
		&& uncached_text_may_require_bidi_processing(text)
	mut mutable_text := unsafe { &TextNode(text_node) }
	mutable_text.cached_inline_bidi_processing_ = result
	return result
}

fn uncached_text_may_require_bidi_processing(text string) bool {
	if text.is_ascii() { return false }
	for code_point in text.runes() {
		bidi_class := dom.unicode_bidirectional_class(u32(code_point))
		if bidi_class in [
			.right_to_left,
			.right_to_left_arabic,
			.right_to_left_embedding,
			.right_to_left_isolate,
			.right_to_left_override,
			.left_to_right_embedding,
			.left_to_right_isolate,
			.left_to_right_override,
			.first_strong_isolate,
			.pop_directional_format,
			.pop_directional_isolate,
		] { return true }
	}
	return false
}
