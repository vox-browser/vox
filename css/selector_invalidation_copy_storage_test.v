module css

import platform

fn test_invalidation_copy_retires_memo_storage_while_preserving_cycles_and_shared_nodes() {
	mut source_storage := platform.new_arena('invalidation copy source')
	source_entry := source_storage.enter()
	mut nodes := []&InvalidationPlan{cap: 256}
	for index in 0 .. 256 {
		nodes << &InvalidationPlan{invalidate_self: index == 123}
	}
	for index in 0 .. nodes.len {
		mut node := nodes[index]
		node.descendant_rules << DescendantInvalidationRule{payload: nodes[(index + 1) % nodes.len]}
		node.sibling_rules << SiblingInvalidationRule{payload: nodes[123]}
	}
	root := nodes[0]
	source_storage.leave(source_entry)
	mut destination := platform.new_arena('invalidation copy result')
	destination_entry := destination.enter()
	mut scratch := platform.begin_thread_scratch('invalidation copy memo')
	mut copy := InvalidationGraphCopy{}
	copy.prepare(root)
	scratch.leave()
	owned := copy.plan(root)
	scratch.finish()
	destination.leave(destination_entry)
	source_storage.release()
	// A memo table and its slots must not become retained result payload.
	$if prealloc {
		payload := i64(sizeof(InvalidationPlan) + sizeof(DescendantInvalidationRule)
			+ sizeof(SiblingInvalidationRule)) * 256
		// Both edge vectors also need managed-array headers and alignment (up
		// to 64 bytes each). Memo tables and boxed loop records exceed this.
		assert destination.usage().used < payload + 256 * 128 + 4096
	}
	shared := owned.sibling_rules[0].payload
	assert shared.invalidate_self
	mut cursor := owned
	for index in 0 .. 256 {
		assert cursor.invalidate_self == (index == 123)
		assert voidptr(cursor.sibling_rules[0].payload) == voidptr(shared)
		cursor = cursor.descendant_rules[0].payload
	}
	assert voidptr(cursor) == voidptr(owned)
	destination.release()
}
