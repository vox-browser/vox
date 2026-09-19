// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/InsertedNodes.{h,cpp}.
module editing

import dom

pub enum LeadingContentKind {
	other
	text_node
	unwrapped_paragraph_text
}

fn collect_inserted_text_nodes(node &dom.Node, mut text_nodes []&dom.Text) {
	if node.is_text() {
		text_nodes << unsafe { &dom.Text(node) }
	}
	for child in node.children_as_vector() {
		collect_inserted_text_nodes(child, mut text_nodes)
	}
}

@[heap]
pub struct InsertedNodes {
	nodes_                []&dom.Node
mut:
	text_nodes_           []&dom.Text
	first_node_           ?&dom.Node
	last_node_            ?&dom.Node
	last_atomic_node_     ?&dom.Node
	leading_content_kind_ LeadingContentKind
}

pub fn InsertedNodes.new(nodes []&dom.Node) &InsertedNodes {
	mut inserted := &InsertedNodes{
		nodes_: nodes.clone()
	}
	if nodes.len > 0 {
		inserted.first_node_ = nodes[0]
		inserted.last_node_ = nodes[nodes.len - 1]
		if nodes[0].is_text() {
			inserted.leading_content_kind_ = .text_node
		} else if first_child := nodes[0].first_child() {
			if first_child.is_text() {
				inserted.leading_content_kind_ = .unwrapped_paragraph_text
			}
		}

		mut last_leaf := nodes[nodes.len - 1]
		for last_leaf.last_child() != none {
			last_leaf = last_leaf.last_child() or { break }
		}
		if element := last_leaf.as_element() {
			if element.is_void_element()
				&& !(element.is_html_element() && element.local_name() == 'br') {
				inserted.last_atomic_node_ = last_leaf
			}
		}
	}
	for node in nodes {
		collect_inserted_text_nodes(node, mut inserted.text_nodes_)
	}
	return inserted
}

pub fn (inserted &InsertedNodes) is_empty() bool {
	return inserted.nodes_.len == 0
}

pub fn (inserted &InsertedNodes) connected_nodes() []&dom.Node {
	return inserted.nodes_.filter(it.parent() != none)
}

pub fn (inserted &InsertedNodes) first_node() ?&dom.Node {
	return inserted.first_node_
}

pub fn (inserted &InsertedNodes) last_node() ?&dom.Node {
	return inserted.last_node_
}

pub fn (inserted &InsertedNodes) last_atomic_node() ?&dom.Node {
	return inserted.last_atomic_node_
}

pub fn (inserted &InsertedNodes) connected_text_nodes() []&dom.Text {
	return inserted.text_nodes_.filter(it.as_node().parent() != none)
}

pub fn (inserted &InsertedNodes) contains(candidate &dom.Text) bool {
	for text in inserted.text_nodes_ {
		if text == candidate && text.as_node().parent() != none {
			return true
		}
	}
	return false
}

pub fn (inserted &InsertedNodes) leading_content_kind() LeadingContentKind {
	return inserted.leading_content_kind_
}

pub fn (mut inserted InsertedNodes) did_replace_node(node &dom.Node, replacement &dom.Node) {
	inserted.did_replace_node_range(node, replacement, replacement)
}

pub fn (mut inserted InsertedNodes) did_replace_node_range(node &dom.Node, first_replacement &dom.Node, last_replacement &dom.Node) {
	if first := inserted.first_node_ {
		if first == node {
			inserted.first_node_ = first_replacement
		}
	}
	if last := inserted.last_node_ {
		if last == node {
			inserted.last_node_ = last_replacement
		}
	}
}
