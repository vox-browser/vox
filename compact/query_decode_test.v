module main

import platform

fn test_compact_query_metadata_survives_document_storage_release() {
	mut old_owner := platform.new_retained_arena('initial compact query document')
	mut old_scope := old_owner.enter_nested()
	first := compact_decode_query[CompactInlineStyleQuery]('{"op":"value","name":"color"}')!
	assert first.op == 'value' && first.name == 'color'
	old_scope.finish()
	old_owner.release()
	assert old_owner.arena.usage().used == 0
	mut replacement := platform.new_retained_arena('replacement compact query document')
	mut scope := replacement.enter_nested()
	// Reuse released storage before consulting the process-wide typed decoder.
	churn := []u8{len: 256 * 1024, init: u8(0xa5)}
	assert churn[0] == 0xa5
	query := compact_decode_query[CompactInlineStyleQuery]('{"op":"set","name":"color","value":"green"}')!
	assert query.op == 'set' && query.name == 'color' && query.value == 'green'
	scope.finish()
	replacement.release()
}

fn test_compact_query_strings_keep_the_callers_retained_owner() {
	mut owner := platform.new_retained_arena('compact query payload ownership')
	mut scope := owner.enter_nested()
	for _ in 0 .. 16 {
		query := compact_decode_query[CompactCharacterDataQuery](r'{"op":"replaceData","data":"left\nright"}')!
		assert query.op == 'replaceData' && query.data == 'left\nright'
		$if prealloc { assert owner.arena.contains(query.data.str) }
	}
	scope.finish()
	owner.release()
}

fn test_compact_query_syntax_failure_restores_the_callers_allocation_scope() {
	mut owner := platform.new_retained_arena('invalid compact query ownership')
	mut scope := owner.enter_nested()
	mut rejected := false
	compact_decode_query[CompactElementScrollQuery]('{broken') or { rejected = true }
	assert rejected
	query := compact_decode_query[CompactElementScrollQuery]('{"name":"scrollTop","value":42}')!
	assert query.name == 'scrollTop' && query.value == 42
	text := query.name.repeat(257)
	$if prealloc { assert owner.arena.contains(text.str) }
	scope.finish()
	owner.release()
}
