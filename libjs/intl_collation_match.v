// SPDX-License-Identifier: BSD-2-Clause
module libjs

import vunicode

// Normalize with the existing Unicode tables, charging the VM for canonical
// reorder work as well as input length. A hostile non-starter sequence must
// not bypass the shared instruction budget inside an uninterruptible sort.
fn intl_collation_normalize(mut vm VM, text Utf16String) ![]u32 {
	for index := 0; index < text.data.len; index += 128 { vm.consume_execution_budget()! }
	points := vunicode.decode_utf16(text.data)
	mut output := []u32{cap: points.len}
	for point in points {
		vm.consume_execution_budget()!
		decomposed := if point < 0x80 { [point] } else { vunicode.normalize([point], .nfd) }
		for item in decomposed {
			output << item
			class := vunicode.combining_class(item)
			if class == 0 { continue }
			mut index := output.len - 1
			for index > 0 && vunicode.combining_class(output[index - 1]) > class {
				vm.consume_execution_budget()!
				output[index], output[index - 1] = output[index - 1], output[index]
				index--
			}
		}
	}
	return output
}

// UTS #10 S2.1: find the longest contiguous mapping first, including trie
// prefixes without an element. Then extend that mapping with unblocked
// non-starters. Skipped characters remain in the input for later processing.
fn intl_collation_match(mut vm VM, data IntlCollationData, mut points []u32, start int) !(int, int) {
	mut node := data.child(0, points[start]) or { return -1, start + 1 }
	mut best := if data.node_word(node, 4) > 0 { node } else { -1 }
	mut end := start + 1
	mut cursor := end
	for cursor < points.len {
		vm.consume_execution_budget()!
		next := data.child(node, points[cursor]) or { break }
		node = next; cursor++
		if data.node_word(node, 4) > 0 { best = node; end = cursor }
	}
	if best < 0 { return -1, start + 1 }
	mut blocked := u32(0)
	mut removed := []int{}
	cursor = end
	for cursor < points.len && data.node_word(best, 2) != 0 {
		vm.consume_execution_budget()!
		class := vunicode.combining_class(points[cursor])
		if class == 0 { break }
		mut matched := false
		if class > blocked {
			if next := data.child(best, points[cursor]) {
				if data.node_word(next, 4) > 0 { best = next; removed << cursor; matched = true }
			}
		}
		if !matched { blocked = class }
		cursor++
	}
	for index := removed.len - 1; index >= 0; index-- {
		// Charge for the array's memmove before deleting a discontiguous match.
		for moved := removed[index]; moved < points.len; moved += 128 { vm.consume_execution_budget()! }
		points.delete(removed[index])
	}
	return best, end
}
