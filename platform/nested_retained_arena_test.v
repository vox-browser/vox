module platform

fn test_embedded_owner_restores_host_workspace_and_retained_allocation_target() {
	mut host := new_retained_arena('nested host')
	mut child := new_retained_arena('nested child')
	mut scope := host.enter()
	parent_before := 'a'.repeat(1024)
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
