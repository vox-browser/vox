module layout

import css
import platform

// The first formatted line has its own font cascade. Keep its shaped items
// separate from the ordinary items so a soft or forced break restores the
// normal font without changing DOM text identity or source offsets.
@[heap]
struct FirstLineItems {
mut:
	ordinary []InlineLevelItem
	styled   []InlineLevelItem
	active   bool = true
}

fn inline_item_style_source(item &InlineLevelItem) &Node {
	return item.style_source or { item.node or { panic('text item without a node') } }
}

fn (mut iterator InlineLevelIterator) prepare_first_line_items() ?&Node {
	root := unsafe { &Node(iterator.containing_block) }
	element := (root.dom_node() or { return none }).as_element() or { return none }
	style := css.computed_properties_for_pseudo_element(element, .first_line) or { return none }
	ordinary := root.computed_values()
	// This slice handles text and explicit breaks in the block's own inline
	// context. Descendant inline inheritance, emergency word splitting and
	// transformed source mappings require additional first-line integration.
	if ordinary.writing_mode() != .horizontal_tb || ordinary.hyphens() == .auto_
		|| ordinary.overflow_wrap() != .normal || ordinary.word_break() != .normal
		|| ordinary.text_wrap_style() in [.balance, .pretty]
		|| style.white_space_collapse() != ordinary.white_space_collapse()
		|| style.text_wrap_mode() != ordinary.text_wrap_mode()
		|| style.text_transform() != ordinary.text_transform() {
		return none
	}
	children := root.children()
	if children.len == 0 || children.any(!it.is_text_node() && !it.is_break_node()) {
		return none
	}
	mut styled_root := BlockContainer.new(root.document(), none, style)
	styled_root.set_children_are_inline(true)
	mut originals := map[u64]&Node{}
	for child in children {
		mut clone := unsafe { &Node(nil) }
		if text := child.as_text_node() {
			mut styled_text := if dom_text := text.dom_node() {
				TextNode.new(root.document(), dom_text, text.source_text_)
			} else {
				TextNode.new_generated(root.document(), text.source_text_)
			}
			styled_text.attach_to_dom_node_ = false
			styled_text.source_range_start_ = text.source_range_start_
			styled_text.source_range_length_ = text.source_range_length_
			styled_text.produces_line_box_fragment_when_empty_ = text.produces_line_box_fragment_when_empty_
			clone = unsafe { &Node(styled_text) }
		} else {
			clone = unsafe { &Node(BreakNode.new(root.document(), child.dom_node() or { return none }, style)) }
		}
		styled_root.append_child(clone)
		originals[u64(voidptr(clone))] = child
	}
	mut styled := new_inline_iterator_with_item_storage(mut iterator.state, styled_root,
		iterator.containing_block_used_values, iterator.layout_mode, iterator.available_space,
		iterator.parent_block_context, iterator.item_storage_)
	for index, item in styled.items {
		proxy := item.node or { continue }
		original := originals[u64(voidptr(proxy))] or { return none }
		styled.items[index] = InlineLevelItem{
			...item
			node: original
			style_source: proxy
		}
	}
	iterator.first_line_items = &FirstLineItems{
		ordinary: iterator.items
		styled: styled.items
	}
	iterator.items = styled.items
	return unsafe { &Node(styled_root) }
}

fn (mut iterator InlineLevelIterator) finish_first_line_before_next_item() {
	data := iterator.first_line_items or { return }
	if !data.active || iterator.containing_block_used_values.line_boxes.len < 2
		|| iterator.next_item_index >= iterator.items.len {
		return
	}
	iterator.resume_ordinary_items_at(iterator.items[iterator.next_item_index])
}

// A pending word that caused the first soft break must also be reshaped with
// the ordinary font. It has not yet been appended to the new line.
fn (mut iterator InlineLevelIterator) resume_ordinary_items_after_break(item &InlineLevelItem) bool {
	data := iterator.first_line_items or { return false }
	if !data.active || iterator.containing_block_used_values.line_boxes.len < 2 { return false }
	iterator.resume_ordinary_items_at(item)
	return true
}

fn (mut iterator InlineLevelIterator) resume_ordinary_items_at(anchor &InlineLevelItem) {
	mut data := iterator.first_line_items or { return }
	anchor_node := anchor.node or { return }
	for index, entry in data.ordinary {
		node := entry.node or { continue }
		if !layout_nodes_same(node, anchor_node) || entry.type_ != anchor.type_ { continue }
		if entry.offset_in_node > anchor.offset_in_node { continue }
		if entry.type_ == .text && entry.offset_in_node + entry.length_in_node <= anchor.offset_in_node { continue }
		if entry.type_ != .text && entry.offset_in_node != anchor.offset_in_node { continue }
		if entry.type_ == .text && entry.offset_in_node < anchor.offset_in_node {
			// Fallback font runs may split a word differently between cascades.
			// Resume at the exact rendered UTF-16 boundary already consumed.
			text_node := node.as_text_node() or { return }
			run := entry.glyph_run or { return }
			length := entry.offset_in_node + entry.length_in_node - anchor.offset_in_node
			text := utf16_substring_for_line_box(text_node.text_for_rendering(), anchor.offset_in_node, length)
			shaped := platform.shape_text_with_spacing(0,
				f32(resolved_text_spacing_for_shaping(node, .letter_spacing)),
				f32(resolved_text_spacing_for_shaping(node, .word_spacing)), text,
				run.font(), run.text_type())
			data.ordinary[index] = InlineLevelItem{
				...entry
				offset_in_node: anchor.offset_in_node
				length_in_node: length
				glyph_run: shaped.glyph_run
				width: shaped_inline_width(shaped.glyph_run, 0)
				trailing_whitespace: trailing_whitespace_from_shaped_text(shaped)
			}
		}
		iterator.items = data.ordinary
		iterator.next_item_index = index
		data.active = false
		return
	}
	panic('first-line item lost its ordinary text boundary')
}

fn (mut iterator InlineLevelIterator) release_item_vectors() {
	if iterator.item_storage_ != unsafe { nil } { return }
	if data := iterator.first_line_items {
		unsafe {
			data.ordinary.free()
			data.styled.free()
		}
	} else {
		unsafe { iterator.items.free() }
	}
}

fn (builder &LineBuilder) current_line_style_source() &Node {
	if source := builder.first_line_style_source {
		if builder.containing_block_used_values.line_boxes.len <= 1 { return source }
	}
	return unsafe { &Node(builder.containing_block) }
}
