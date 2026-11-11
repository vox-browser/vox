module platform

@[noinline]
fn nested_owner_runtime_string(value string, count int) string {
	return value.repeat(count)
}

fn test_embedded_owner_restores_host_workspace_and_retained_allocation_target() {
	mut host := new_retained_arena('nested host')
	mut child := new_retained_arena('nested child')
	mut scope := host.enter()
	parent_before := nested_owner_runtime_string('a', 1024)
	mut work := new_arena('host frame around child')
	entry := work.enter()
	mut nested := child.enter_nested()
	child_before := 'b'.repeat(3 * 1024 * 1024)
	$if prealloc { assert voidptr(current_retained_arena()) == voidptr(child) }
	mut temporary := begin_thread_scratch('child geometry')
	_ = 'discard'.repeat(1024)
	mut retained := enter_retained_allocations()
	child_after := 'c'.repeat(3 * 1024 * 1024)
	retained.finish()
	temporary.finish()
	nested.finish()
	$if prealloc { assert voidptr(current_retained_arena()) == voidptr(host) }
	_ = 'temporary frame data'.repeat(1024)
	work.leave(entry)
	work.release()
	parent_after := 'd'.repeat(3 * 1024 * 1024)
	$if prealloc {
		assert host.arena.contains(parent_before.str) && host.arena.contains(parent_after.str)
		assert child.arena.contains(child_before.str) && child.arena.contains(child_after.str)
	}
	scope.finish()
	host.release()
	assert child_before[0] == `b` && child_after[child_after.len - 1] == `c`
	child.release()
}

fn test_embedded_owner_can_reenter_from_its_persistent_cache_section() {
	mut owner := new_retained_arena('persistent nested owner')
	mut scope := owner.enter()
	persistent := enter_persistent()
	base_before := 'e'.repeat(20 * 1024 * 1024)
	mut nested := owner.enter_nested()
	owned := 'f'.repeat(3 * 1024 * 1024)
	nested.finish()
	base_after := 'g'.repeat(20 * 1024 * 1024)
	leave_persistent(persistent)
	$if prealloc { assert owner.arena.contains(owned.str) }
	scope.finish()
	owner.release()
	assert base_before[0] == `e` && base_after[base_after.len - 1] == `g`
}

fn test_child_can_query_an_entered_parent_and_restore_its_workspace() {
	$if !prealloc { return }
	mut parent := new_retained_arena('queried parent')
	mut child := new_retained_arena('querying child')
	mut parent_scope := parent.enter()
	parent_before := nested_owner_runtime_string('p', 1024)
	mut child_scope := child.enter_nested()
	child_before := nested_owner_runtime_string('c', 1024)
	mut workspace := new_arena('child query workspace')
	entry := workspace.enter()

	mut query_scope := parent.enter_nested()
	assert voidptr(current_retained_arena()) == voidptr(parent)
	parent_during := nested_owner_runtime_string('q', 3 * 1024 * 1024)
	assert parent.arena.contains(parent_during.str)
	query_scope.finish()
	assert voidptr(current_retained_arena()) == voidptr(child)
	query_scope.finish()
	assert voidptr(current_retained_arena()) == voidptr(child)
	workspace_after := nested_owner_runtime_string('w', 1024)
	assert workspace.contains(workspace_after.str)
	workspace.leave(entry)
	workspace.release()

	child_after := nested_owner_runtime_string('d', 3 * 1024 * 1024)
	assert child.arena.contains(child_before.str) && child.arena.contains(child_after.str)
	child_scope.finish()
	assert voidptr(current_retained_arena()) == voidptr(parent)
	parent_after := nested_owner_runtime_string('r', 3 * 1024 * 1024)
	assert parent.arena.contains(parent_before.str) && parent.arena.contains(parent_after.str)
	assert parent_before[0] == `p` && parent_during[parent_during.len - 1] == `q`
	parent_scope.finish()
	parent.release()
	assert parent.arena.usage().used == 0
	assert child_before[0] == `c` && child_after[child_after.len - 1] == `d`
	child.release()
	assert child.arena.usage().used == 0
}
