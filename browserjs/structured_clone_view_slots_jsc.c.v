// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
@[has_globals]
module browserjs


// Original immutable view slots from source deserialization's actual native
// constructor calls. Buffer/view pointer identity and one real engine root
// prevent stale entries being applied to a reclaimed/reused object address.
struct NativeCloneViewSlots {
	buffer voidptr
	constructor_name string
	byte_length ?u32
	byte_offset u32
	array_length ?u32
}

@[heap]
struct NativeCloneViewSlotsOwner {
mut:
	by_actual map[voidptr]NativeCloneViewSlots
}

__global native_clone_view_slot_owners_ = map[voidptr]&NativeCloneViewSlotsOwner{}

fn (runtime &Runtime) native_clone_view_slots(value voidptr) ?NativeCloneViewSlots {
	owner := native_clone_view_slot_owners_[voidptr(runtime)] or { return none }
	return owner.by_actual[value] or { return none }
}

fn (mut runtime Runtime) retain_native_clone_view_slots(value voidptr, slots NativeCloneViewSlots) ! {
	runtime.require_javascript_value_context()!
	identity := voidptr(&runtime)
	mut owner := native_clone_view_slot_owners_[identity] or {
		mut record := &NativeCloneViewSlotsOwner{}
		register_runtime_binding(mut native_clone_view_slot_owners_, identity, record)
		runtime.add_close_handler(fn [identity, mut record] () {
			record.by_actual.clear()
			unregister_runtime_binding(mut native_clone_view_slot_owners_, identity)
		})
		record
	}
	if _ := owner.by_actual[value] { return }
	runtime.retain_javascript_value(value)!
	owner.by_actual[value] = slots
}
