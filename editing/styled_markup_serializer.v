// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/StyledMarkupSerializer.{h,cpp}.
module editing

import dom
import strings

fn is_inter_block_formatting_whitespace(node &dom.Node) bool {
	if !is_ascii_whitespace_text(node) {
		return false
	}

	// Formatting whitespace between block containers participates in the DOM range, but not in either rendered
	// paragraph. Using the surrounding structure also identifies it before layout has been updated for the copy.
	previous := node.previous_sibling() or { return false }
	next := node.next_sibling() or { return false }
	return is_prohibited_paragraph_child(previous) && is_prohibited_paragraph_child(next)
}

fn is_empty_paragraph(node &dom.Node) bool {
	if !is_prohibited_paragraph_child(node) || node.child_count() != 1 {
		return false
	}
	first_child := node.first_child() or { return false }
	return first_child.is_html_br_element()
}

fn has_renderable_content_in_subtree(node &dom.Node) bool {
	for descendant in node.children_as_vector() {
		if descendant.is_text() && unsafe { &dom.Text(descendant) }.data() != '' {
			return true
		}
		if element := descendant.as_element() {
			if element.is_void_element() && !descendant.is_html_br_element() {
				return true
			}
		}
		if has_renderable_content_in_subtree(descendant) {
			return true
		}
	}
	return false
}

fn is_empty_or_clipped_paragraph(node &dom.Node) bool {
	if !is_prohibited_paragraph_child(node) {
		return false
	}

	// INTEROP: Range cloning can leave empty text nodes or inline ancestors in a clipped list item. Blink treats the
	//          item as an interchange paragraph boundary unless a descendant can produce rendered content.
	return !has_renderable_content_in_subtree(node)
}

fn create_interchange_newline(document &dom.Document) &dom.Node {
	mut line_break := document.create_element('br') or { panic(err) }
	line_break.set_attribute_value('class', 'Apple-interchange-newline')
	return line_break.as_node()
}

fn remove_serialized_node(node &dom.Node) {
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.remove(false)
}

fn insert_serialized_node_before(parent &dom.Node, node &dom.Node, child ?&dom.Node) {
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.insert_before(node, child, false)
}

fn append_serialized_node(parent &dom.Node, node &dom.Node) {
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(node) or { panic(err) }
}

fn replace_with_interchange_newline(document &dom.Document, node &dom.Node) {
	line_break := create_interchange_newline(document)
	parent := node.parent() or { return }
	insert_serialized_node_before(parent, line_break, node)
	remove_serialized_node(node)
}

fn is_html_font_node(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.is_html_element() && element.local_name() == 'font'
}

fn normalize_content_after_interchange_newline(range_ &dom.Range, fragment &dom.DocumentFragment) {
	mut descendants := []&dom.Node{}
	collect_subtree_descendants(fragment.as_node(), mut descendants)
	fonts := descendants.filter(is_html_font_node(it))
	mut selected_font := ?&dom.Node(none)
	for font in fonts {
		if font.descendant_text_content() != '' {
			selected_font = font
		} else {
			remove_serialized_node(font)
		}
	}
	font := selected_font or { return }

	mut source_node := range_.end_container()
	if range_.end_offset() == 0 {
		for source_node != range_.common_ancestor_container() && source_node.previous_sibling() == none {
			source_node = source_node.parent() or { break }
		}
		if previous_sibling := source_node.previous_sibling() {
			source_node = previous_sibling
			for source_node.last_child() != none {
				source_node = source_node.last_child() or { break }
			}
		}
	}
	color := resolved_value(source_node, 'color') or { return }

	document := range_.start_container().document()
	mut span := document.create_element('span') or { panic(err) }
	style := 'color: ${color};'
	span.set_attribute_value('style', style)
	span_node := span.as_node()
	parent := font.parent() or { return }
	insert_serialized_node_before(parent, span_node, font)
	for font.first_child() != none {
		child := font.first_child() or { break }
		append_serialized_node(span_node, child)
	}
	remove_serialized_node(font)

	last_child := span_node.last_child() or { return }
	if !last_child.is_text() {
		return
	}
	trailing_text := unsafe { &dom.Text(last_child) }
	trailing_data := trailing_text.data()
	if trailing_data == '' || !is_ascii_space_character(trailing_data.runes().last()) {
		return
	}

	mut mutable_trailing_text := unsafe { &dom.Text(trailing_text) }
	mutable_trailing_text.delete_data(trailing_text.length_in_utf16_code_units() - 1, 1) or {
		panic(err)
	}
	mut whitespace_span := document.create_element('span') or { panic(err) }
	whitespace_span.set_attribute_value('style', style)
	append_serialized_node(whitespace_span.as_node(), document.create_text_node(' ').as_node())
	insert_serialized_node_before(parent, whitespace_span.as_node(), span_node.next_sibling())
}

fn optional_list_item(node ?&dom.Node) ?&dom.Node {
	found := node or { return none }
	if !found.is_html_li_element() {
		return none
	}
	return found
}

struct SkippedUnrenderedText {
	leading  bool
	trailing bool
}

fn next_non_whitespace_sibling(node ?&dom.Node) ?&dom.Node {
	mut current := node
	for {
		candidate := current or { return none }
		if !is_ascii_whitespace_text(candidate) {
			return candidate
		}
		current = candidate.next_sibling()
	}
	return none
}

fn annotate_interchange_newlines(selection &StyledMarkupSelection, fragment &dom.DocumentFragment, skipped_unrendered_text SkippedUnrenderedText) {
	range_ := selection.serialization_range()
	document := range_.start_container().document()
	fragment_node := fragment.as_node()
	// INTEROP: Blink and WebKit encode a selected rendered paragraph boundary as this private break marker. Their
	//          replacement commands consume it as structure instead of inserting a literal br. Formatting whitespace
	//          in source markup is otherwise omitted from the clipboard representation.
	// INTEROP: A selected empty paragraph before block content is represented at the start of the first content block.
	//          Blink and WebKit descend through its leading formatting wrappers, or into the first item of a list, so
	//          the receiving replacement command preserves the boundary while still recognizing the block fragment.
	mut leading_paragraph := fragment_node.first_child()
	mut placed_leading_marker := false
	mut skipped_fragment_edge_whitespace := skipped_unrendered_text.leading
	for {
		candidate := leading_paragraph or { break }
		if !is_ascii_whitespace_text(candidate) {
			break
		}
		skipped_fragment_edge_whitespace = true
		leading_paragraph = candidate.next_sibling()
	}
	if paragraph := leading_paragraph {
		if is_empty_or_clipped_paragraph(paragraph) {
			content := next_non_whitespace_sibling(paragraph.next_sibling())
			mut marker_parent := content
			mut following_content := ?&dom.Node(none)
			if found_content := content {
				following_content = next_non_whitespace_sibling(found_content.next_sibling())
			}
			if skipped_fragment_edge_whitespace && following_content == none {
				// INTEROP: When a range starts in source formatting whitespace and ends inside the first content block,
				//          Blink emits a top-level boundary followed by inline content. Leave that case to the range-edge
				//          handling below instead of moving the boundary into a partially selected block wrapper.
				marker_parent = none
			} else if found_content := content {
				if found_content.is_html_ulist_element() || found_content.is_html_olist_element() {
					marker_parent = optional_list_item(found_content.first_child())
				} else if !is_prohibited_paragraph_child(found_content) {
					marker_parent = none
				}
			} else {
				marker_parent = none
			}

			if found_marker_parent := marker_parent {
				mut descend := unsafe { found_marker_parent }
				for {
					first_child := descend.first_child() or { break }
					if !is_inline_node(first_child) || !first_child.is_element()
						|| !first_child.has_children() {
						break
					}
					descend = first_child
				}
				marker := create_interchange_newline(document)
				insert_serialized_node_before(descend, marker, descend.first_child())
				placed_leading_marker = true
				for !editing_same_node(fragment_node.first_child(), content) {
					first_child := fragment_node.first_child() or { break }
					remove_serialized_node(first_child)
				}
			}
		}
	}

	previous_sibling := range_.start_container().previous_sibling()
	starts_after_empty_paragraph := range_.start_offset() != 0 && if sibling := previous_sibling {
		is_empty_paragraph(sibling)
	} else {
		false
	}
	if !placed_leading_marker && !starts_after_empty_paragraph
		&& selection.has_leading_interchange_newline() {
		if first_child := fragment_node.first_child() {
			mut inserted_marker := false
			if first_child.is_text() {
				replace_with_interchange_newline(document, first_child)
				inserted_marker = true
			} else if skipped_unrendered_text.leading {
				marker := create_interchange_newline(document)
				insert_serialized_node_before(fragment_node, marker, first_child)
				inserted_marker = true
			}
			if inserted_marker {
				if new_first_child := fragment_node.first_child() {
					if next := new_first_child.next_sibling() {
						if is_empty_paragraph(next) {
							remove_serialized_node(next)
						}
					}
				}
				normalize_content_after_interchange_newline(range_, fragment)
			}
		}
	}

	if selection.has_trailing_interchange_newline() && fragment_node.last_child() != none {
		last_child := fragment_node.last_child() or { return }
		if last_child.is_text() {
			replace_with_interchange_newline(document, last_child)
		} else if skipped_unrendered_text.trailing {
			// INTEROP: Blink and WebKit append the trailing marker from the rendered selection after traversal. It
			//          must not depend on skipped source indentation surviving as a text node at the fragment edge.
			append_serialized_node(fragment_node, create_interchange_newline(document))
		}
	} else if !range_.end_container().is_text() && range_.end_offset() > 0 {
		if source_before_end := range_.end_container().child_at_index(range_.end_offset() - 1) {
			fragment_ends_in_text := if last_child := fragment_node.last_child() {
				last_child.is_text()
			} else {
				false
			}
			if is_inter_block_formatting_whitespace(source_before_end) && fragment_ends_in_text {
				replace_with_interchange_newline(document, fragment_node.last_child() or { return })
			} else if is_empty_paragraph(source_before_end) {
				append_serialized_node(fragment_node, create_interchange_newline(document))
			}
		}
	}
}

fn restore_leading_interchange_newline_ancestry(fragment &dom.DocumentFragment) {
	mut leading_node := fragment.as_node().first_child()
	for {
		candidate := leading_node or { break }
		if candidate.is_html_br_element() {
			break
		}
		leading_node = candidate.first_child()
	}
	marker := leading_node or { return }
	if !is_interchange_newline(marker) {
		return
	}

	// INTEROP: Blink's traversal serializer wraps a leading paragraph boundary in the inline ancestors of the first
	//          selected content. Range cloning leaves the synthesized marker beside those wrappers. Reconstruct that
	//          ancestry without depending on the particular formatting element used by the source document. Detached
	//          fragments have no computed display, so classify wrappers by whether they may contain paragraph text.
	for {
		following_element := marker.next_sibling() or { break }
		if !following_element.is_element() {
			break
		}
		if is_prohibited_paragraph_child(following_element) || !following_element.has_children() {
			break
		}
		remove_serialized_node(marker)
		insert_serialized_node_before(following_element, marker, following_element.first_child())
	}
}

fn wrap_cloned_list_items(range_ &dom.Range, fragment &dom.DocumentFragment) {
	fragment_node := fragment.as_node()
	if !fragment_node.has_children() {
		return
	}
	for child in fragment_node.children_as_vector() {
		if !child.is_html_li_element() {
			return
		}
	}

	mut source_list := ?&dom.Node(range_.common_ancestor_container())
	for source_list != none {
		current := source_list or { break }
		if current.is_html_ulist_element() || current.is_html_olist_element() {
			break
		}
		source_list = current.parent()
	}
	found_source_list := source_list or { return }

	// INTEROP: Range cloning omits the common ancestor itself. Blink and WebKit restore an enclosing list around
	//          cloned list-item siblings so the clipboard fragment retains their shared list structure.
	list_wrapper := found_source_list.clone_node(none, false, none) or { panic(err) }
	for fragment_node.first_child() != none {
		child := fragment_node.first_child() or { break }
		append_serialized_node(list_wrapper, child)
	}
	append_serialized_node(fragment_node, list_wrapper)
}

fn encode_empty_list_item_boundaries(range_ &dom.Range, fragment &dom.DocumentFragment) {
	document := range_.start_container().document()
	fragment_node := fragment.as_node()
	lists := fragment_node.children_as_vector().filter(it.is_html_ulist_element()
		|| it.is_html_olist_element())

	for list in lists {
		first_item := optional_list_item(list.first_child())
		mut following_item := ?&dom.Node(none)
		if item := first_item {
			following_item = optional_list_item(item.next_sibling())
		}
		if item := first_item {
			if following := following_item {
				if is_empty_or_clipped_paragraph(item) {
					// INTEROP: A selected leading list-item boundary is carried inside the following item. Keeping it within
					//          the list lets replacement distinguish a new rendered paragraph from an empty list item.
					insert_serialized_node_before(following, create_interchange_newline(document),
						following.first_child())
					remove_serialized_node(item)
				}
			}
		}

		last_item := list.last_child() or { continue }
		if !last_item.is_html_li_element() || !is_empty_or_clipped_paragraph(last_item) {
			continue
		}

		// INTEROP: A selected trailing list-item boundary is serialized after the list. The empty item itself is
		//          transport structure, including when it is the list's only selected child.
		insert_serialized_node_before(fragment_node, create_interchange_newline(document),
			list.next_sibling())
		remove_serialized_node(last_item)
	}
}

fn classify_cloned_text_for_interchange(accumulator &StyledMarkupAccumulator, mut text_with_preserved_breaks []&dom.Text, mut unrendered_text []&dom.Text) {
	for text in accumulator.serialized_text() {
		white_space_collapse := resolved_keyword(text.source.as_node(), 'white-space-collapse')
		if keyword := white_space_collapse {
			if keyword != 'collapse' {
				text_with_preserved_breaks << text.serialized
				continue
			}
		}
		if dom.collect_visual_lines(text.source).len == 0 {
			unrendered_text << text.serialized
		}
	}
}

fn remove_unrendered_text(unrendered_text []&dom.Text) {
	for text in unrendered_text {
		if text.as_node().parent() != none {
			remove_serialized_node(text.as_node())
		}
	}
}

fn protect_collapsible_whitespace_for_interchange(fragment &dom.DocumentFragment, text_with_preserved_breaks []&dom.Text) {
	mut descendants := []&dom.Node{}
	collect_subtree_descendants(fragment.as_node(), mut descendants)
	text_nodes := descendants.filter(it.is_text())
	document := fragment.as_node().document()

	for text_node in text_nodes {
		parent := text_node.parent() or { continue }
		text := unsafe { &dom.Text(text_node) }
		if text_with_preserved_breaks.any(voidptr(it) == voidptr(text))
			|| is_inter_block_formatting_whitespace(text_node) {
			continue
		}
		data := text.data()
		if data == '' {
			continue
		}

		for token in rebalance_whitespace_for_interchange(data) {
			if token.type_ == .text {
				insert_serialized_node_before(parent, document.create_text_node(token.text).as_node(),
					text_node)
			} else {
				span := document.create_element('span') or { panic(err) }
				append_serialized_node(span.as_node(), document.create_text_node(' ').as_node())
				insert_serialized_node_before(parent, span.as_node(), text_node)
			}
		}
		remove_serialized_node(text_node)
	}
}

// Serialize the rendered selection for rich clipboard interchange. Unlike DOM fragment serialization, this preserves
// visual paragraph boundaries, collapsible whitespace, list structure, and formatting inherited from outside a range.
pub fn serialize_styled_markup_for_clipboard(range_ &dom.Range) string {
	if range_.collapsed() {
		return ''
	}

	mut document := unsafe { &dom.Document(range_.start_container().document()) }
	document.update_layout_if_needed_for_node(range_.common_ancestor_container(), .navigable_selected_text)
	selection := StyledMarkupSelection.new(range_)
	// INTEROP: Blink and WebKit represent a selection containing exactly one rendered paragraph boundary with a
	//          standalone interchange marker. Let replacement interpret that marker instead of cloning either block.
	if selection.contains_only_interchange_newline() {
		return '<br class="Apple-interchange-newline">'
	}
	accumulator := StyledMarkupAccumulator.new(&selection)
	fragment := accumulator.fragment()
	fragment_node := fragment.as_node()
	mut text_with_preserved_breaks := []&dom.Text{}
	mut unrendered_text := []&dom.Text{}
	classify_cloned_text_for_interchange(accumulator, mut text_with_preserved_breaks, mut
		unrendered_text)
	// INTEROP: A range ending at offset zero has not entered its final text run. Blink keeps a selected leading
	//          paragraph boundary at the fragment edge in that case, while ranges containing final-run text move the
	//          boundary into the selected structure. Preserve that distinction after removing unrendered edge text.
	skipped_unrendered_text := SkippedUnrenderedText{
		leading: unrendered_text.any(editing_same_node(fragment_node.first_child(), it.as_node())
			&& it.data() != '' && range_.end_container().is_character_data()
			&& range_.end_offset() == 0)
		trailing: unrendered_text.any(editing_same_node(fragment_node.last_child(), it.as_node()))
	}
	// INTEROP: Blink and WebKit skip text without rendered content during traversal. Remove it before structural
	//          wrapping and interchange-marker placement so source indentation cannot become fragment topology.
	remove_unrendered_text(unrendered_text)
	wrap_cloned_list_items(range_, fragment)
	encode_empty_list_item_boundaries(range_, fragment)
	annotate_interchange_newlines(&selection, fragment, skipped_unrendered_text)
	restore_leading_interchange_newline_ancestry(fragment)
	accumulator.remove_partial_block_transport_wrapper()

	// INTEROP: Chromium represents a partial text-node selection with the computed inline styles that distinguish it
	//          from its editing host. The DOM Range cloning algorithm cannot preserve these styles because the common
	//          ancestor is the text node itself, so provide the missing formatting context explicitly.
	start_container := range_.start_container()
	if start_container == range_.end_container() && start_container.is_text()
		&& (range_.start_offset() != 0 || range_.end_offset() != start_container.length()) {
		if editing_host := start_container.editing_host() {
			mut style := strings.new_builder(0)
			for property_name in ['color', 'background-color', 'font-family', 'font-size', 'font-style',
				'font-weight', 'text-decoration-line'] {
				selected_value := resolved_value(start_container, property_name) or { continue }
				host_value := resolved_value(editing_host, property_name) or { continue }
				if selected_value == host_value {
					continue
				}
				style.write_string('${property_name}: ${selected_value};')
			}

			if style.len > 0 {
				mut span := document.create_element('span') or { panic(err) }
				span.set_attribute_value('style', style.str())
				for fragment_node.has_children() {
					child := fragment_node.first_child() or { break }
					append_serialized_node(span.as_node(), child)
				}
				append_serialized_node(fragment_node, span.as_node())
			}
		}
	}

	// INTEROP: Blink and WebKit serialize collapsible whitespace through span-wrapped non-breaking spaces. The wrapper
	//          preserves both the rendered space and its text-node seam until rich replacement performs its ordered
	//          whitespace cleanup. Text whose CSS preserves line breaks is serialized verbatim.
	protect_collapsible_whitespace_for_interchange(fragment, text_with_preserved_breaks)
	serialized_text := accumulator.serialized_text()
	if serialized_text.len > 0 {
		materialize_single_run_legacy_font_style_from_rendered_source(fragment_node, serialized_text[0].source.as_node())
	}

	return fragment_node.serialize_fragment(.no, .inner) or { panic(err) }
}
