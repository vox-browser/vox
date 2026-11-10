// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ReplacementFragment.{h,cpp}.
module editing

import dom

fn replacement_ascii_space(character u8) bool {
	return character in [` `, `\t`, `\n`, `\f`, `\r`]
}

fn remove_formatting_whitespace_between_blocks(mut fragment_node dom.Node) {
	for child in fragment_node.children_as_vector() {
		if is_ascii_whitespace_text(child) {
			mut child_node := unsafe { &dom.Node(child) }
			child_node.remove(false)
		}
	}
}

fn collect_replacement_text_nodes(node &dom.Node, mut text_nodes []&dom.Text) {
	if node.is_text() {
		text_nodes << unsafe { &dom.Text(node) }
	}
	for child in node.children_as_vector() {
		collect_replacement_text_nodes(child, mut text_nodes)
	}
}

fn make_whitespace_round_trippable(document &dom.Document, fragment_node &dom.Node) {
	mut text_nodes := []&dom.Text{}
	collect_replacement_text_nodes(fragment_node, mut text_nodes)
	for text in text_nodes {
		parent := text.as_node().parent() or { continue }
		data := text.data()
		if data == '' || (!replacement_ascii_space(data[0])
			&& !replacement_ascii_space(data[data.len - 1])) {
			continue
		}
		mut parent_node := unsafe { &dom.Node(parent) }
		for token in rebalance_whitespace_for_interchange(data) {
			token_text := if token.type_ == .text { token.text } else { '\u00a0' }
			parent_node.insert_before(document.create_text_node(token_text).as_node(),
				text.as_node(), false)
		}
		mut text_node := unsafe { &dom.Node(text.as_node()) }
		text_node.remove(false)
	}
}

fn collect_interchange_whitespace_spans(node &dom.Node, mut spans []&dom.Element) {
	if element := node.as_element() {
		if element.is_html_element() && element.local_name() == 'span' && !element.has_attributes()
			&& node.child_count() == 1 {
			child := node.first_child() or { return }
			if child.is_text() && (child.text_content() or { '' }) == '\u00a0' {
				spans << element
			}
		}
	}
	for child in node.children_as_vector() {
		collect_interchange_whitespace_spans(child, mut spans)
	}
}

fn unwrap_interchange_whitespace_spans(fragment_node &dom.Node) {
	mut spans := []&dom.Element{}
	collect_interchange_whitespace_spans(fragment_node, mut spans)
	for span in spans {
		parent := span.as_node().parent() or { continue }
		mut parent_node := unsafe { &dom.Node(parent) }
		mut span_node := span.as_node()
		for child in span_node.children_as_vector() {
			parent_node.insert_before(child, span.as_node(), false)
		}
		span_node.remove(false)
	}
}

fn has_renderable_descendant(node &dom.Node) bool {
	if node.is_text() && (node.text_content() or { '' }) != '' {
		return true
	}
	if element := node.as_element() {
		if element.is_void_element() {
			return true
		}
	}
	for child in node.children_as_vector() {
		if has_renderable_descendant(child) {
			return true
		}
	}
	return false
}

fn collect_empty_inline_staging_wrappers(node &dom.Node, mut wrappers []&dom.Element) {
	if element := node.as_element() {
		if !element.is_void_element() && !is_prohibited_paragraph_child(node)
			&& !has_renderable_descendant(node) {
			wrappers << element
		}
	}
	for child in node.children_as_vector() {
		collect_empty_inline_staging_wrappers(child, mut wrappers)
	}
}

fn remove_empty_inline_staging_wrappers(fragment_node &dom.Node) {
	mut wrappers := []&dom.Element{}
	collect_empty_inline_staging_wrappers(fragment_node, mut wrappers)
	for index := wrappers.len; index > 0; index-- {
		mut wrapper_node := wrappers[index - 1].as_node()
		if wrapper_node.parent() != none {
			wrapper_node.remove(false)
		}
	}
}

fn is_interchange_newline_node(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.is_html_element() && element.local_name() == 'br'
		&& element.has_class('Apple-interchange-newline')
}

@[heap]
pub struct ReplacementFragment {
mut:
	fragment_                         &dom.DocumentFragment = unsafe { nil }
	contains_block_content_           bool
	contains_only_text_               bool
	has_interchange_newline_at_start_ bool
	has_interchange_newline_at_end_   bool
}

pub fn ReplacementFragment.new(range &dom.Range, value string) !&ReplacementFragment {
	history := begin_editing_proxy_mutation(range.start_container())
	defer {
		end_editing_proxy_mutation(history)
	}
	fragment := range.create_contextual_fragment(value)!
	return ReplacementFragment.from_fragment(range, fragment)
}

pub fn ReplacementFragment.from_fragment(range &dom.Range, fragment &dom.DocumentFragment) &ReplacementFragment {
	history := begin_editing_proxy_mutation(range.start_container())
	defer { end_editing_proxy_mutation(history) }
	mut fragment_node := fragment.as_node()
	remove_formatting_whitespace_between_blocks(mut fragment_node)

	mut first_leaf := fragment_node.first_child()
	for first_leaf != none {
		current := first_leaf or { break }
		child := current.first_child() or { break }
		first_leaf = child
	}
	mut has_interchange_newline_at_start := false
	if leaf := first_leaf {
		has_interchange_newline_at_start = is_interchange_newline_node(leaf)
	}

	mut has_interchange_newline_at_end := false
	if last_child := fragment_node.last_child() {
		if is_interchange_newline_node(last_child) {
			has_interchange_newline_at_end = true
			mut line_break := unsafe { &dom.Node(last_child) }
			line_break.remove(false)
		}
	}

	unwrap_interchange_whitespace_spans(fragment_node)
	remove_empty_inline_staging_wrappers(fragment_node)
	make_whitespace_round_trippable(range.start_container().document(), fragment_node)

	children := fragment_node.children_as_vector()
	mut contains_only_text := children.len > 0
	mut contains_block_content := false
	for child in children {
		if !child.is_text() {
			contains_only_text = false
		}
		if is_prohibited_paragraph_child(child) {
			contains_block_content = true
		}
	}
	return &ReplacementFragment{
		fragment_: fragment
		contains_block_content_: contains_block_content
		contains_only_text_: contains_only_text
		has_interchange_newline_at_start_: has_interchange_newline_at_start
		has_interchange_newline_at_end_: has_interchange_newline_at_end
	}
}

pub fn (replacement &ReplacementFragment) contains_block_content() bool {
	return replacement.contains_block_content_
}

pub fn (replacement &ReplacementFragment) contains_only_text() bool {
	return replacement.contains_only_text_
}

pub fn (replacement &ReplacementFragment) has_interchange_newline_at_start() bool {
	return replacement.has_interchange_newline_at_start_
}

pub fn (replacement &ReplacementFragment) has_interchange_newline_at_end() bool {
	return replacement.has_interchange_newline_at_end_
}

pub fn (replacement &ReplacementFragment) fragment() &dom.DocumentFragment {
	return replacement.fragment_
}

pub fn (replacement &ReplacementFragment) children() []&dom.Node {
	return replacement.fragment_.as_node().children_as_vector()
}
