module layout

import platform
import css

fn retained_text_node_chunks(text &TextNode, wrap bool, respect_breaks bool,
	direction TextDirectionMode) []TextNodeChunk {
	$if prealloc {
		// Materialize the retained rendered-text cache in the caller's owner.
		_ = text.text_for_rendering()
		mut buffers := acquire_inline_item_buffers(text.Node.document())
		if buffers.arena == unsafe { nil } {
			return collect_text_node_chunks(text, wrap, respect_breaks, direction, false)
		}
		mut storage := buffers.arena
		entry := storage.enter()
		temporary := collect_text_node_chunks(text, wrap, respect_breaks, direction, true)
		storage.leave(entry)
		mut result := []TextNodeChunk{cap: temporary.len}
		for chunk in temporary {
			result << TextNodeChunk{ ...chunk, view: chunk.view.clone() }
		}
		buffers.finish()
		return result
	}
	return collect_text_node_chunks(text, wrap, respect_breaks, direction, false)
}

fn collect_text_node_chunks(text &TextNode, wrap bool, respect_breaks bool,
	direction TextDirectionMode, retain_fonts bool) []TextNodeChunk {
	mut iterator := TextNodeChunkIterator.new_with_direction(text, wrap, respect_breaks, direction)
	iterator.retain_selected_fonts_ = retain_fonts
	mut chunks := []TextNodeChunk{}
	for {
		chunk := iterator.next() or { break }
		chunks << chunk
	}
	if chunks.len == 0 && text.text_for_rendering().len == 0
		&& (text.retains_empty_generated_fragment_ || text.produces_line_box_fragment_when_empty_) {
		chunks << iterator.create_empty_chunk()
	}
	return chunks
}

// Font computation and URL-backed face resolution can publish cache entries
// or queue completion tasks. Their retained state must stay outside the chunk
// iterator's workspace, while its local cascade vectors remain temporary.
fn chunk_iterator_rendering_fonts(text &TextNode) (&css.FontCascadeList, &platform.Font) {
	transient := platform.transient_arena_entered()
	use_document := transient && cache_uses_entered_document_storage(text.Node.document())
	mut retained := if use_document {
		platform.enter_retained_allocations()
	} else {
		platform.RetainedAllocationScope{}
	}
	persistent := platform.enter_persistent_if(transient && !use_document)
	defer {
		platform.leave_persistent(persistent)
		retained.finish()
	}
	return text.Node.font_list(), text.font_for_rendering()
}

fn (iterator &TextNodeChunkIterator) fallback_visibility_for_code_point(code_point u32, index int) bool {
	if !iterator.retain_selected_fonts_ || iterator.font_cascade_list.pending_faces.len == 0 {
		return iterator.font_cascade_list.fallback_is_invisible_for_code_point_through(code_point, index)
	}
	use_document := cache_uses_entered_document_storage(iterator.text_node.Node.document())
	mut retained := if use_document {
		platform.enter_retained_allocations()
	} else {
		platform.RetainedAllocationScope{}
	}
	persistent := platform.enter_persistent_if(!use_document)
	defer {
		platform.leave_persistent(persistent)
		retained.finish()
	}
	return iterator.font_cascade_list.fallback_is_invisible_for_code_point_through(code_point, index)
}
