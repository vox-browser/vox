module layout

import css
import processmetrics

// A retained TextNode reads its inline parent's current computed style. The
// document's font environment generation does not change for an ordinary CSS
// font-size/family change, so it cannot by itself validate chunks holding fonts.
fn refresh_inline_chunk_font_owner(text &TextNode) {
	current := text.Node.font_list()
	style := text.Node.computed_values()
	generation := css.css_style_computer_for(text.Node.document()).font_computer().environment_generation()
	mut mutable_text := unsafe { &TextNode(text) }
	if previous := text.cached_inline_font_owner_ {
		if text.cached_inline_font_style_ == voidptr(style)
			&& text.cached_inline_font_style_revision_ == style.mutation_revision()
			&& ((voidptr(previous) == voidptr(current)
				&& text.cached_font_environment_generation_ == generation)
				|| previous.equals(current)) {
			if text.cached_font_environment_generation_ != generation && processmetrics.instructions_enabled() {
				eprintln('Vox retained text font generation: ${text.cached_font_environment_generation_} -> ${generation}')
			}
			mutable_text.cached_inline_font_owner_ = current
			mutable_text.cached_font_environment_generation_ = generation
			return
		}
	}
	mutable_text.cached_inline_font_owner_ = current
	mutable_text.cached_inline_font_style_ = voidptr(style)
	mutable_text.cached_inline_font_style_revision_ = style.mutation_revision()
	mutable_text.cached_inline_chunks_ = none
	mutable_text.cached_intrinsic_text_shapes_.clear()
}
