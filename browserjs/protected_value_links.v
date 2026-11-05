module browserjs

import os

const retain_protected_value_array_index = os.getenv('VOX_RETAIN_PROTECTED_VALUE_ARRAY_INDEX') == '1'

struct ProtectedValueLink {
mut:
	previous int = -1
	next     int = -1
}

// Duplicate protections form a chain in the dense root array. A handle maps
// directly to its newest protection, without allocating a separate index array.
fn (mut runtime Runtime) remember_linked_protected_value(value voidptr) {
	index := runtime.protected_values_.len
	previous := runtime.protected_value_tails_[value] or { -1 }
	runtime.protected_value_links_ << ProtectedValueLink{ previous: previous }
	if previous >= 0 {
		runtime.protected_value_links_[previous].next = index
	}
	runtime.protected_value_tails_[value] = index
	runtime.protected_values_ << value
	if protected_value_index_diagnostics && !runtime.protected_value_links_reported_ {
		runtime.protected_value_links_reported_ = true
		eprintln('Vox protected values: linked root index')
	}
}

fn (mut runtime Runtime) forget_linked_protected_value(value voidptr) bool {
	index := runtime.protected_value_tails_[value] or { return false }
	previous := runtime.protected_value_links_[index].previous
	if previous < 0 {
		runtime.protected_value_tails_.delete(value)
	} else {
		runtime.protected_value_tails_[value] = previous
		runtime.protected_value_links_[previous].next = -1
	}
	last := runtime.protected_values_.len - 1
	if index != last {
		moved := runtime.protected_values_[last]
		// Read after unlinking: the moved root can be an older protection of
		// the same handle, whose next link or tail just changed above.
		link := runtime.protected_value_links_[last]
		if link.previous >= 0 {
			runtime.protected_value_links_[link.previous].next = index
		}
		if link.next >= 0 {
			runtime.protected_value_links_[link.next].previous = index
		} else {
			runtime.protected_value_tails_[moved] = index
		}
		runtime.protected_values_[index] = moved
		runtime.protected_value_links_[index] = link
	}
	runtime.protected_values_.delete_last()
	runtime.protected_value_links_.delete_last()
	return true
}
