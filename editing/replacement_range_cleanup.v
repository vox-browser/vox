// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ReplacementRangeCleanup.{h,cpp}.
module editing

import dom
import strings

enum ReplacementTraversalDirection {
	backward
	forward
}

struct TextNodeCoalescer {
	endpoints &ReplacementEndpoints
}

fn (coalescer &TextNodeCoalescer) merge_left_into_right(left &dom.Text, right &dom.Text) {
	left_length := left.length_in_utf16_code_units()
	mut mutable_right := unsafe { &dom.Text(right) }
	mutable_right.insert_data(0, left.data()) or { panic(err) }
	mut endpoints := unsafe { &ReplacementEndpoints(coalescer.endpoints) }
	endpoints.prepare_for_merging_left_text_into_right(left, right, left_length)
	mut mutable_left_node := unsafe { &dom.Node(left.as_node()) }
	mutable_left_node.remove(false)
}

fn (coalescer &TextNodeCoalescer) merge_right_into_left(left &dom.Text, right &dom.Text) {
	left_length := left.length_in_utf16_code_units()
	mut mutable_left := unsafe { &dom.Text(left) }
	mutable_left.insert_data(left_length, right.data()) or { panic(err) }
	mut endpoints := unsafe { &ReplacementEndpoints(coalescer.endpoints) }
	endpoints.prepare_for_merging_right_text_into_left(left, right, left_length)
	mut mutable_right_node := unsafe { &dom.Node(right.as_node()) }
	mutable_right_node.remove(false)
}

fn utf16_character_at(text &dom.Text, offset int) ?rune {
	character := text.substring_data(offset, 1) or { return none }
	characters := character.runes()
	if characters.len == 0 {
		return none
	}
	return characters[0]
}

fn adjacent_text_character(text &dom.Text, offset int, direction ReplacementTraversalDirection) ?rune {
	search_forward := direction == .forward
	if search_forward && offset < text.length_in_utf16_code_units() {
		return utf16_character_at(text, offset)
	}
	if !search_forward && offset > 0 {
		return utf16_character_at(text, offset - 1)
	}

	block := block_node_of_dom_node(text.as_node()) or { return none }
	mut node := if search_forward {
		text.as_node().next_in_pre_order(block)
	} else {
		text.as_node().previous_in_pre_order()
	}
	for node != none {
		current := node or { break }
		if current == block {
			break
		}
		if is_html_break(current) || (if element := current.as_element() {
			element.is_html_element() && element.local_name() == 'img'
		} else {
			false
		}) || (if element := current.as_element() {
			element.is_html_element() && is_prohibited_paragraph_child_name(element.local_name())
		} else {
			false
		}) {
			return none
		}
		if current.is_text() {
			adjacent_text := unsafe { &dom.Text(current) }
			if adjacent_text.data() != '' {
				return if search_forward {
					utf16_character_at(adjacent_text, 0)
				} else {
					utf16_character_at(adjacent_text,
						adjacent_text.length_in_utf16_code_units() - 1)
				}
			}
		}
		node = if search_forward {
			current.next_in_pre_order(block)
		} else {
			current.previous_in_pre_order()
		}
	}
	return none
}

fn is_ascii_space_character(character rune) bool {
	return character in [` `, `\t`, `\n`, `\v`, `\f`, `\r`]
}

fn text_is_protected_whitespace(text &dom.Text) bool {
	characters := text.data().runes()
	return characters.all(is_ascii_space_character(it) || it == `\u00a0`)
}

fn text_has_non_whitespace(text &dom.Text) bool {
	return text.data().runes().any(!is_ascii_space_character(it) && it != `\u00a0`)
}

fn normalize_inserted_nbsp(inserted_content &InsertedContent) []&dom.Text {
	mut normalized_whitespace := []&dom.Text{}
	for text in inserted_content.text_nodes() {
		data := text.data()
		if !data.contains('\u00a0') {
			continue
		}
		mut replacement := strings.new_builder(data.len)
		mut changed := false
		mut utf16_offset := 0
		for character in data.runes() {
			mut replacement_character := character
			if character == `\u00a0` {
				previous := adjacent_text_character(text, utf16_offset, .backward)
				next := adjacent_text_character(text, utf16_offset + 1, .forward)
				if previous_character := previous {
					if next_character := next {
						if !is_ascii_space_character(previous_character)
							&& previous_character != `\u00a0`
							&& !is_ascii_space_character(next_character)
							&& next_character != `\u00a0` {
							replacement_character = ` `
							changed = true
						}
					}
				}
			}
			replacement.write_rune(replacement_character)
			utf16_offset += if character > 0xffff { 2 } else { 1 }
		}
		if changed {
			mut mutable_text := unsafe { &dom.Text(text) }
			mutable_text.set_data(replacement.str())
			if mutable_text.data().runes().all(is_ascii_space_character(it)) {
				normalized_whitespace << text
			}
		}
	}
	return normalized_whitespace
}

fn coalesce_normalized_whitespace_in_integrated_end_paragraph(mut inserted_content InsertedContent, normalized_whitespace []&dom.Text) {
	if !inserted_content.end_paragraph_was_integrated() {
		return
	}
	end_boundary := inserted_content.end_boundary() or { return }
	integrated_end_block := block_node_of_dom_node(end_boundary.node) or { return }
	coalescer := TextNodeCoalescer{
		endpoints: inserted_content.endpoints()
	}
	for text in normalized_whitespace {
		if text.as_node().parent() == none {
			continue
		}
		text_block := block_node_of_dom_node(text.as_node()) or { continue }
		if text_block != integrated_end_block {
			continue
		}
		previous_text := if previous := text.as_node().previous_sibling() {
			if previous.is_text() { unsafe { &dom.Text(previous) } } else { unsafe { &dom.Text(nil) } }
		} else {
			unsafe { &dom.Text(nil) }
		}
		endpoint_follows_noninitial_text_run := inserted_content.endpoints().end().node == text.as_node()
			&& previous_text != unsafe { nil } && previous_text.as_node().previous_sibling() != none
		if endpoint_follows_noninitial_text_run {
			continue
		}
		if previous_text != unsafe { nil } {
			coalescer.merge_right_into_left(previous_text, text)
		} else if next := text.as_node().next_sibling() {
			if next.is_text() {
				coalescer.merge_left_into_right(text, unsafe { &dom.Text(next) })
			}
		}
	}
}

fn editing_ignores_content(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.is_void_element()
}

fn merge_text_nodes_at_start_of_inserted_content(mut inserted_content InsertedContent) {
	start := inserted_content.endpoints().start()
	mut start_text := unsafe { &dom.Text(nil) }
	if start.node.is_text() {
		start_text = unsafe { &dom.Text(start.node) }
	} else if start.offset > 0 {
		if candidate := start.node.child_at_index(start.offset - 1) {
			if candidate.is_text() {
				start_text = unsafe { &dom.Text(candidate) }
			}
		}
	}
	if start_text == unsafe { nil } {
		if candidate := start.node.child_at_index(start.offset) {
			if candidate.is_text() {
				start_text = unsafe { &dom.Text(candidate) }
			}
		}
	}
	if start_text == unsafe { nil } {
		return
	}

	start_is_interior_protected_whitespace := inserted_content.contains(start_text)
		&& !VisiblePosition.create(start.node.document(), start).is_start_of_paragraph()
		&& text_is_protected_whitespace(start_text)
	if !(if previous := start_text.as_node().previous_sibling() {
		previous.is_text()
	} else {
		false
	}) && start_is_interior_protected_whitespace {
		if next := start_text.as_node().next_sibling() {
			if next.is_text() {
				next_text := unsafe { &dom.Text(next) }
				if inserted_content.contains(next_text) && text_has_non_whitespace(next_text) {
					start_text = next_text
				}
			}
		}
	}

	coalescer := TextNodeCoalescer{
		endpoints: inserted_content.endpoints()
	}
	if previous := start_text.as_node().previous_sibling() {
		if previous.is_text() {
			coalescer.merge_left_into_right(unsafe { &dom.Text(previous) }, start_text)
		}
	}
	if next := start_text.as_node().next_sibling() {
		if next.is_text() {
			next_text := unsafe { &dom.Text(next) }
			following_atomic_content := next.next_sibling()
			mut atomic_run_has_following_inserted_text := false
			if atomic_node := following_atomic_content {
				if editing_ignores_content(atomic_node) {
					for text in inserted_content.text_nodes() {
						if atomic_node.is_preceding(text.as_node()) && text_has_non_whitespace(text) {
							atomic_run_has_following_inserted_text = true
							break
						}
					}
				}
			}
			topology_is_inline := if topology := inserted_content.replacement_topology() {
				topology == .inline_
			} else {
				false
			}
			next_is_protected_inserted_whitespace := inserted_content.contains(next_text)
				&& topology_is_inline
				&& text_is_protected_whitespace(next_text) && following_atomic_content != none
				&& editing_ignores_content(following_atomic_content or { next })
				&& !atomic_run_has_following_inserted_text
				&& inserted_content.insertion_was_inside_paragraph()
				&& !inserted_content.insertion_was_after_whitespace()
			if !next_is_protected_inserted_whitespace {
				coalescer.merge_right_into_left(start_text, next_text)
			}
		}
	}
}

fn merge_text_nodes_at_end_of_inserted_content(mut inserted_content InsertedContent) {
	text_nodes := inserted_content.text_nodes()
	if text_nodes.len == 0 {
		return
	}
	last_text := text_nodes.last()
	next := last_text.as_node().next_sibling() or { return }
	if !next.is_text() {
		return
	}
	next_text := unsafe { &dom.Text(next) }
	coalescer := TextNodeCoalescer{
		endpoints: inserted_content.endpoints()
	}
	if previous := last_text.as_node().previous_sibling() {
		if previous.is_text() {
			end_was_in_last_text := inserted_content.endpoints().end().node == last_text.as_node()
			end_offset := inserted_content.endpoints().end().offset
			coalescer.merge_left_into_right(unsafe { &dom.Text(previous) }, last_text)
			if end_was_in_last_text {
				mut endpoints := unsafe { &ReplacementEndpoints(inserted_content.endpoints()) }
				endpoints.set_end(dom.BoundaryPoint{
					node: last_text.as_node()
					offset: end_offset
				})
			}
		}
	}
	coalescer.merge_right_into_left(last_text, next_text)
}

fn collect_empty_modifiable_containers(node &dom.Node, mut containers []&dom.Element) {
	if element := node.as_element() {
		if !node.has_children() && is_dom_modifiable_element(node) {
			containers << element
		}
	}
	for child in node.children_as_vector() {
		collect_empty_modifiable_containers(child, mut containers)
	}
}

fn remove_empty_modifiable_containers(inserted_content &InsertedContent) {
	mut empty_containers := []&dom.Element{}
	for node in inserted_content.nodes() {
		collect_empty_modifiable_containers(node, mut empty_containers)
	}
	for container in empty_containers {
		if container.as_node().parent() != none {
			mut node := unsafe { &dom.Node(container.as_node()) }
			node.remove(false)
		}
	}
}

fn move_end_past_empty_terminal_container(mut inserted_content InsertedContent) {
	caret := inserted_content.endpoints().end()
	end := inserted_content.end_boundary() or { return }
	if caret != end || caret.offset != 0 || caret.node.as_element() == none {
		return
	}
	element := caret.node.as_element() or { return }
	if (element.is_html_element() && element.local_name() == 'li')
		|| is_dom_non_list_single_line_container(caret.node)
		|| has_dom_visible_children(caret.node) {
		return
	}
	position := VisiblePosition.create(caret.node.document(), caret).next() or { return }
	mut endpoints := unsafe { &ReplacementEndpoints(inserted_content.endpoints()) }
	endpoints.set_end(position.deep_equivalent())
}

pub fn finalize_inserted_content(mut inserted_content InsertedContent, end dom.BoundaryPoint) dom.BoundaryPoint {
	inserted_content.begin_completion(end)
	merge_text_nodes_at_start_of_inserted_content(mut inserted_content)
	if inserted_content.should_normalize_end_text_seam() {
		merge_text_nodes_at_end_of_inserted_content(mut inserted_content)
	}
	end_before_whitespace_normalization := inserted_content.endpoints().end()
	normalized_whitespace := normalize_inserted_nbsp(inserted_content)
	mut endpoints := unsafe { &ReplacementEndpoints(inserted_content.endpoints()) }
	endpoints.set_end(end_before_whitespace_normalization)
	coalesce_normalized_whitespace_in_integrated_end_paragraph(mut inserted_content,
		normalized_whitespace)
	remove_empty_modifiable_containers(inserted_content)
	move_end_past_empty_terminal_container(mut inserted_content)
	if atomic_boundary := inserted_content.end_boundary_after_atomic_content() {
		endpoints.set_end(atomic_boundary)
	}
	return endpoints.end()
}
