// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XPath/XPathResult.{h,cpp,idl}.
module xpath

import dom

pub enum ResultType as u16 {
	any                     = 0
	number                  = 1
	string                  = 2
	boolean                 = 3
	unordered_node_iterator = 4
	ordered_node_iterator   = 5
	unordered_node_snapshot = 6
	ordered_node_snapshot   = 7
	any_unordered_node      = 8
	first_ordered_node      = 9
}

@[heap]
pub struct XPathResult {
pub mut:
	result_type            ResultType
	number_value           f64
	string_value           string
	boolean_value          bool
	invalid_iterator_state bool
	nodes                  []&dom.Node
mut:
	iterator_index int
}

pub fn (result &XPathResult) single_node_value() ?&dom.Node {
	if result.nodes.len == 0 {
		return none
	}
	return result.nodes[0]
}

pub fn (result &XPathResult) snapshot_length() u32 {
	return u32(result.nodes.len)
}

pub fn (mut result XPathResult) iterate_next() ?&dom.Node {
	if result.iterator_index >= result.nodes.len {
		return none
	}
	node := result.nodes[result.iterator_index]
	result.iterator_index++
	return node
}

pub fn (result &XPathResult) snapshot_item(index int) ?&dom.Node {
	if index < 0 || index >= result.nodes.len {
		return none
	}
	return result.nodes[index]
}

fn (mut result XPathResult) set_nodes(nodes []&dom.Node, requested ResultType) {
	result.nodes = nodes
	result.iterator_index = 0
	result.result_type = if int(requested) >= int(ResultType.unordered_node_iterator)
		&& int(requested) <= int(ResultType.first_ordered_node) {
		requested
	} else {
		.unordered_node_iterator
	}
}
