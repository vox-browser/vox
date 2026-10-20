module platform

#include "@DIR/retained_arena_mapping_test.h"
fn C.vox_retained_test_page_mapped(address voidptr) i32
fn C.vox_retained_test_mapping_probe_works() i32

fn test_nested_thread_scratch_keeps_every_grown_document_block_in_its_owner_chain() {
	$if prealloc {
		assert C.vox_retained_test_mapping_probe_works() == 1
		mut owner := new_retained_arena('document parent link growth')
		mut document := owner.enter()
		first := 'a'.repeat(6 * 1024 * 1024)
		mut outer := begin_thread_scratch('outer raw scope around document growth')
		_ = 'x'.repeat(1024 * 1024)
		mut inner := begin_thread_scratch('inner raw scope around document growth')
		_ = 'y'.repeat(1024 * 1024)
		mut retained := enter_retained_allocations()
		second := 'b'.repeat(6 * 1024 * 1024)
		retained.finish()
		inner.finish()
		mut another := enter_retained_allocations()
		third := 'c'.repeat(6 * 1024 * 1024)
		another.finish()
		outer.finish()
		// Keep the original pointers: placing these strings in an array can
		// itself copy them and hide the lost original blocks from this check.
		assert first[0] == `a` && second[0] == `b` && third[0] == `c`
		assert owner.arena.usage().used >= first.len + second.len + third.len
		first_page := voidptr(first.str)
		second_page := voidptr(second.str)
		third_page := voidptr(third.str)
		document.finish()
		owner.release()
		if !arenas_poisoned() {
			// These six-MiB blocks exceed V's recycler size classes. Teardown
			// must unmap every original block, including the redirected growth.
			assert C.vox_retained_test_page_mapped(first_page) == 0
			assert C.vox_retained_test_page_mapped(second_page) == 0
			assert C.vox_retained_test_page_mapped(third_page) == 0
		}
	}
}
