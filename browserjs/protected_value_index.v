module browserjs

import os

const disable_protected_value_index = os.getenv('VOX_DISABLE_PROTECTED_VALUE_INDEX') == '1'
const protected_value_index_diagnostics = os.getenv('VOX_PROTECTED_VALUE_INDEX_DIAGNOSTICS') == '1'

// Each protection owns one entry, even when the same JSC handle is retained
// repeatedly. The reverse position lets swap removal update the moved entry
// without scanning its handle's other protections.
fn (mut runtime Runtime) remember_protected_value(value voidptr) {
	if !disable_protected_value_index && !retain_protected_value_array_index {
		runtime.remember_linked_protected_value(value)
		return
	}
	if !disable_protected_value_index {
		mut indices := runtime.protected_value_indices_[value]
		runtime.protected_value_positions_ << indices.len
		indices << runtime.protected_values_.len
		runtime.protected_value_indices_[value] = indices
	}
	runtime.protected_values_ << value
}

fn (mut runtime Runtime) forget_protected_value(value voidptr) bool {
	if disable_protected_value_index {
		for index, retained in runtime.protected_values_ {
			if retained == value {
				runtime.protected_values_.delete(index)
				return true
			}
		}
		return false
	}
	if !retain_protected_value_array_index {
		return runtime.forget_linked_protected_value(value)
	}
	mut indices := runtime.protected_value_indices_[value] or { return false }
	index := indices.pop()
	if indices.len == 0 {
		runtime.protected_value_indices_.delete(value)
	} else {
		runtime.protected_value_indices_[value] = indices
	}
	last := runtime.protected_values_.len - 1
	if index != last {
		moved := runtime.protected_values_[last]
		position := runtime.protected_value_positions_[last]
		runtime.protected_value_indices_[moved][position] = index
		runtime.protected_values_[index] = moved
		runtime.protected_value_positions_[index] = position
	}
	runtime.protected_values_.delete_last()
	runtime.protected_value_positions_.delete_last()
	if protected_value_index_diagnostics && index != last {
		eprintln('Vox protected values: indexed swap removal')
	}
	return true
}
