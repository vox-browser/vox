module layout

import css
import os
import platform

const disable_inline_context_slice_reuse = os.getenv('VOX_DISABLE_INLINE_CONTEXT_SLICE_REUSE') != ''
const inline_context_slice_diagnostics = os.getenv('VOX_INLINE_CONTEXT_SLICE_DIAGNOSTICS') != ''

__global inline_context_slice_reported bool

struct InlineContextSlice {
	shape ?platform.ShapedText
}

@[heap]
struct InlineContextSlices {
	chunks []TextNodeChunk
	style &css.ComputedProperties
	style_revision u64
	font_generation u64
	paragraph_ltr bool
	letter_spacing f64
	word_spacing f64
	slices []InlineContextSlice
}

// Each chunk's context geometry is independent of available width. Keep the
// exact local-pen rounding from the ordinary slicer, then fork its immutable
// glyph storage for each layout consumer. Tabs and rejected cluster boundaries
// retain their existing per-item fallback.
fn (iterator &InlineLevelIterator) retained_inline_context_slices(text &TextNode,
	chunks []TextNodeChunk) ?&InlineContextSlices {
	if disable_inline_context_slice_reuse || text.Node.document().font_rendering_policy() != .chromium
		|| chunks.len < 2 || chunks.len > 128 || text.rendered_utf16_length_ > 4096 {
		return none
	}
	style := text.Node.computed_values()
	generation := css.css_style_computer_for(text.Node.document()).font_computer().environment_generation()
	letter_spacing := resolved_text_spacing_for_shaping(unsafe { &Node(text) }, .letter_spacing)
	word_spacing := resolved_text_spacing_for_shaping(unsafe { &Node(text) }, .word_spacing)
	if cached := text.cached_inline_context_slices_ {
		if cached.chunks.data == chunks.data && cached.chunks.len == chunks.len
			&& voidptr(cached.style) == voidptr(style) && cached.style_revision == style.mutation_revision()
			&& cached.font_generation == generation
			&& cached.paragraph_ltr == iterator.is_unidirectional_left_to_right
			&& cached.letter_spacing == letter_spacing && cached.word_spacing == word_spacing {
			if inline_context_slice_diagnostics && !inline_context_slice_reported
				&& cached.slices.any(it.shape != none) {
				inline_context_slice_reported = true
				eprintln('Vox inline context slices: reused owned shaped chunks')
			}
			return cached
		}
	}
	use_document := cache_uses_entered_document_storage(text.Node.document())
	mut retained := if use_document { platform.enter_retained_allocations() } else { platform.RetainedAllocationScope{} }
	persistent := platform.enter_persistent_if(!use_document)
	defer { platform.leave_persistent(persistent); retained.finish() }
	run := iterator.chromium_single_script_context_run(text, chunks)
	segments := if run == none { iterator.chromium_segmented_context_runs(text, chunks) }
		else { []ChromiumTextContextRun{} }
	mut cursor := ChromiumContextSliceCursor{}
	mut slices := []InlineContextSlice{cap: chunks.len}
	for chunk in chunks {
		shape := if source := run {
			chromium_context_slice_with_cursor(source, chunk, mut cursor)
		} else {
			chromium_segmented_context_slice_with_cursor(segments, chunk, mut cursor)
		}
		slices << InlineContextSlice{shape}
	}
	cached := &InlineContextSlices{
		chunks: chunks
		style: style
		style_revision: style.mutation_revision()
		font_generation: generation
		paragraph_ltr: iterator.is_unidirectional_left_to_right
		letter_spacing: letter_spacing
		word_spacing: word_spacing
		slices: slices
	}
	mut mutable_text := unsafe { &TextNode(text) }
	mutable_text.cached_inline_context_slices_ = cached
	return cached
}

fn (cache &InlineContextSlices) fork_slice(index int) ?platform.ShapedText {
	shape := cache.slices[index].shape or { return none }
	return platform.ShapedText{
		glyph_run: shape.glyph_run.fork_for_layout()
		trailing_whitespace: shape.trailing_whitespace
	}
}
