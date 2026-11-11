// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct ModularTreeNode {
pub:
	is_leaf    bool
	property   u8
	threshold  i32
	left       u32
	right      u32
	predictor  Predictor
	offset     i32
	multiplier u32
	context    u32
}

pub struct ModularTree {
pub:
	nodes          []ModularTreeNode
	histograms     Histograms
	num_properties int
}

struct TreeValidationFrame {
	node             int
	depth            int
	restore_property int = -1
	restore_low      i32
	restore_high     i32
mut:
	stage int
}

// Range state is stored only for the current path, bounded at 2048 edges.
pub fn validate_modular_tree(nodes []ModularTreeNode, num_properties int) ! {
	if num_properties < 0 || num_properties > 256 {
		return error('Invalid JPEG XL tree property count')
	}
	if nodes.len == 0 { return }
	mut lows := []i32{len: num_properties, init: i32(-2147483648)}
	mut highs := []i32{len: num_properties, init: i32(2147483647)}
	mut stack := [TreeValidationFrame{}]
	for stack.len > 0 {
		mut frame := stack.pop()
		if frame.depth > 2048 || frame.node < 0 || frame.node >= nodes.len {
			return error('Invalid JPEG XL tree depth or child index')
		}
		node := nodes[frame.node]
		if node.is_leaf || frame.stage == 2 {
			if frame.restore_property >= 0 {
				lows[frame.restore_property] = frame.restore_low
				highs[frame.restore_property] = frame.restore_high
			}
			continue
		}
		property := int(node.property)
		if property >= num_properties || lows[property] > node.threshold || highs[property] <= node.threshold {
			return error('JPEG XL tree splits an empty property range')
		}
		left := frame.stage == 0
		frame.stage++
		stack << frame
		stack << TreeValidationFrame{
			node:             int(if left { node.left } else { node.right })
			depth:            frame.depth + 1
			restore_property: property
			restore_low:      lows[property]
			restore_high:     highs[property]
		}
		if left { lows[property] = node.threshold + 1 } else { highs[property] = node.threshold }
	}
}

pub fn (mut reader BitReader) read_modular_tree(size_limit int) !ModularTree {
	// The final entropy map is bounded at 65,536 leaf contexts.
	if size_limit < 0 || size_limit > 131070 {
		return error('Invalid JPEG XL modular tree size limit')
	}
	tree_histograms := reader.read_histograms(6, true)!
	mut symbols := SymbolReader.new(tree_histograms, mut reader, none)!
	mut nodes := []ModularTreeNode{}
	mut pending := 1
	mut leaf_id := u32(0)
	mut max_property := u32(0)
	for pending > 0 {
		// Retain the source's inclusive limit: limit + 1 nodes can finish a tree.
		if nodes.len > size_limit { return error('JPEG XL modular tree exceeds size limit') }
		pending--
		property_code := symbols.read_unsigned(&tree_histograms, 1, mut reader)!
		if property_code > 0 {
			property := property_code - 1
			if property > 255 { return error('Invalid JPEG XL modular tree property') }
			if property > max_property { max_property = property }
			threshold := symbols.read_signed(&tree_histograms, 0, mut reader)!
			left := u32(nodes.len + pending + 1)
			nodes << ModularTreeNode{ property: u8(property), threshold: threshold, left: left, right: left + 1 }
			pending += 2
		} else {
			predictor := predictor_from_id(symbols.read_unsigned(&tree_histograms, 2, mut reader)!)!
			offset := symbols.read_signed(&tree_histograms, 3, mut reader)!
			multiplier_log := symbols.read_unsigned(&tree_histograms, 4, mut reader)!
			if multiplier_log >= 31 {
				return error('JPEG XL tree multiplier exponent is too large')
			}
			multiplier_bits := symbols.read_unsigned(&tree_histograms, 5, mut reader)!
			multiplier := (u64(multiplier_bits) + 1) << multiplier_log
			if multiplier > u64(0xffffffff) { return error('JPEG XL tree multiplier is too large') }
			nodes << ModularTreeNode{ is_leaf: true, predictor: predictor, offset: offset, multiplier: u32(multiplier), context: leaf_id }
			leaf_id++
		}
	}
	symbols.check_final_state(tree_histograms, reader)!
	num_properties := int(max_property) + 1
	validate_modular_tree(nodes, num_properties)!
	histograms := reader.read_histograms((nodes.len + 1) / 2, true)!
	return ModularTree{ nodes: nodes, histograms: histograms, num_properties: num_properties }
}

pub fn (tree ModularTree) walk(properties []i32) !ModularTreeNode {
	mut index := u32(0)
	for _ in 0 .. tree.nodes.len {
		if u64(index) >= u64(tree.nodes.len) { return error('Invalid JPEG XL tree child index') }
		node := tree.nodes[int(index)]
		if node.is_leaf { return node }
		if int(node.property) >= properties.len { return error('Missing JPEG XL tree property') }
		index = if properties[int(node.property)] > node.threshold { node.left } else { node.right }
	}
	return error('Empty or cyclic JPEG XL modular tree')
}

// Follows splits on the properties below `count`, whose values are `fixed`,
// from `start` to the first leaf or other split. The tree must have passed
// validate_modular_tree, which bounds every path.
@[direct_array_access]
fn modular_tree_resolve(nodes []ModularTreeNode, start int, fixed [3]i32, count int) int {
	mut index := start
	for _ in 0 .. nodes.len {
		node := nodes[index]
		if node.is_leaf || int(node.property) >= count { break }
		index = int(if fixed[int(node.property)] > node.threshold { node.left } else { node.right })
	}
	return index
}

// Writes into `out` the tree reachable from the root of a validated tree, with
// every split on a property below `count` (at most 3: channel, stream and row)
// resolved by its `fixed` value. Any pixel whose first `count` properties have
// those values reaches the same leaf in both trees. Returns false, leaving the
// caller to use the original tree, if the copy would be larger than it.
@[direct_array_access]
fn prune_modular_tree_into(nodes []ModularTreeNode, fixed [3]i32, count int, mut out []ModularTreeNode, mut sources []int) bool {
	out.clear()
	sources.clear()
	if nodes.len == 0 { return false }
	root := modular_tree_resolve(nodes, 0, fixed, count)
	out << nodes[root]
	sources << root
	for i := 0; i < out.len; i++ {
		node := nodes[sources[i]]
		if node.is_leaf { continue }
		if out.len + 2 > nodes.len { return false }
		left := modular_tree_resolve(nodes, int(node.left), fixed, count)
		right := modular_tree_resolve(nodes, int(node.right), fixed, count)
		out[i] = ModularTreeNode{ ...node, left: u32(out.len), right: u32(out.len + 1) }
		out << nodes[left]
		sources << left
		out << nodes[right]
		sources << right
	}
	return true
}

