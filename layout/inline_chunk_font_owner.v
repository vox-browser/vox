module layout

import css
import os

const disable_live_pending_text_reuse = os.getenv('VOX_DISABLE_LIVE_PENDING_TEXT_REUSE') != ''
const live_pending_text_reuse_diagnostics = os.getenv('VOX_LIVE_PENDING_TEXT_REUSE_DIAGNOSTICS') != ''

__global live_pending_text_reuse_reported bool

fn inline_chunk_font_owner_matches(text &TextNode, current &css.FontCascadeList,
	style &css.ComputedProperties, generation u64) bool {
	previous := text.cached_inline_font_owner_ or { return false }
	return text.cached_inline_font_style_ == voidptr(style)
		&& text.cached_inline_font_style_revision_ == style.mutation_revision()
		&& ((voidptr(previous) == voidptr(current)
			&& text.cached_font_environment_generation_ == generation)
			|| original_pending_text_cascade_is_current(text, previous, current, style)
			|| previous.equals(current))
}

// Reading a newer computed cascade does not update already shaped chunks.
// A layout snapshot must certify the fonts that produced its geometry too.
// Keep this check read-only: missing or expired computed inputs require layout.
fn retained_text_font_owner_is_current(text &TextNode) bool {
	if text.cached_inline_chunks_ == none { return true }
	style := text.Node.computed_values()
	current := style.cached_computed_font_list() or { return false }
	computer := css.css_style_computer_for(text.Node.document()).font_computer()
	generation := computer.environment_generation()
	return style.cached_font_inputs_are_unchanged_since(computer, generation)
		&& inline_chunk_font_owner_matches(text, current, style, generation)
}

fn original_pending_text_cascade_is_current(text &TextNode, previous &css.FontCascadeList,
	current &css.FontCascadeList, style &css.ComputedProperties) bool {
	if disable_live_pending_text_reuse || current.pending_faces.len == 0
		|| voidptr(previous) != voidptr(current) { return false }
	computer := css.css_style_computer_for(text.Node.document()).font_computer()
	if !style.cached_font_inputs_are_unchanged_since(computer, text.cached_font_environment_generation_) { return false }
	if live_pending_text_reuse_diagnostics && !live_pending_text_reuse_reported {
		live_pending_text_reuse_reported = true
		eprintln('Vox pending text reuse: retained chunks and intrinsic shapes')
	}
	return true
}

// A retained TextNode reads its inline parent's current computed style. The
// document's font environment generation does not change for an ordinary CSS
// font-size/family change, so it cannot by itself validate chunks holding fonts.
fn refresh_inline_chunk_font_owner(text &TextNode) {
	current := text.Node.font_list()
	style := text.Node.computed_values()
	generation := css.css_style_computer_for(text.Node.document()).font_computer().environment_generation()
	mut mutable_text := unsafe { &TextNode(text) }
	if inline_chunk_font_owner_matches(text, current, style, generation) {
		if text.cached_font_environment_generation_ != generation && retained_font_generation_diagnostics {
			eprintln('Vox retained text font generation: ${text.cached_font_environment_generation_} -> ${generation}')
		}
		mutable_text.cached_inline_font_owner_ = current
		mutable_text.cached_font_environment_generation_ = generation
		return
	}
	mutable_text.cached_inline_font_owner_ = current
	mutable_text.cached_inline_font_style_ = voidptr(style)
	mutable_text.cached_inline_font_style_revision_ = style.mutation_revision()
	mutable_text.cached_inline_chunks_ = none
	mutable_text.cached_intrinsic_text_shapes_.clear()
}
