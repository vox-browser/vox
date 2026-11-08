module adblock

#include "@DIR/enabled_snapshot_test.h"

fn C.vox_adblock_test_mutex_errorcheck(int) int

fn test_enabled_snapshot_remains_readable_while_filtering_owns_the_engine() {
	before := is_enabled()
	assert C.vox_adblock_test_mutex_errorcheck(1) == 0
	defer { assert C.vox_adblock_test_mutex_errorcheck(0) == 0 }
	C.vox_adblock_lock()
	// A frame's cached-image policy check must not wait for this mutex.
	assert is_enabled() == before
	assert C.vox_adblock_try_lock() == 0
	C.vox_adblock_set_enabled(int(!before))
	assert is_enabled() == !before
	C.vox_adblock_set_enabled(int(before))
	C.vox_adblock_unlock()
	set_enabled(!before)
	assert is_enabled() == !before
	set_enabled(before)
	assert is_enabled() == before
}
