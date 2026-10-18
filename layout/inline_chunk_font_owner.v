module layout

// A retained TextNode reads its inline parent's current computed style. The
// document's font environment generation does not change for an ordinary CSS
// font-size/family change, so it cannot by itself validate chunks holding fonts.
fn refresh_inline_chunk_font_owner(text &TextNode) {
	current := text.Node.font_list()
	if text.cached_inline_font_owner_ == voidptr(current) { return }
	mut mutable_text := unsafe { &TextNode(text) }
	mutable_text.cached_inline_font_owner_ = voidptr(current)
	mutable_text.cached_inline_chunks_ = none
	mutable_text.cached_intrinsic_text_shapes_.clear()
}
