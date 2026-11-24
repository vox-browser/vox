module libjs

import os
import platform

// A property instruction remembers the own-property position where it last
// found its key. Own keys are unique, so a matching key at that position is the
// property itself; objects built in the same order (one constructor or literal
// site) share the position. Mismatches, absent keys and exotic objects take
// the ordinary lookup, which refreshes the position.
const no_property_hint = u32(0xffffffff)
// A put_property site whose own lookup missed (it adds the property, or a
// prototype handles it) keeps the complete [[Set]] path without looking the
// key up twice.
const property_hint_adding = u32(0xfffffffe)

// One slot per instruction, owned by the compiled body (closures share it).
@[inline]
fn (executable &Executable) property_hint(pc u32) &u32 {
	if executable.property_hints.len != executable.instructions.len { executable.allocate_property_hints() }
	// run_executable() dispatches only instructions inside the stream.
	return unsafe { &u32(executable.property_hints.data) + pc }
}

fn (executable &Executable) allocate_property_hints() {
	persistent := platform.enter_persistent()
	mut owner := unsafe { &Executable(executable) }
	owner.property_hints = []u32{len: executable.instructions.len, init: no_property_hint}
	platform.leave_persistent(persistent)
}

// Same-binary control: hinted reads only for plain objects' own properties,
// as before String-object, array, key-index and inherited-position hints.
const narrow_property_hints = os.getenv('VOX_LIBJS_NARROW_PROPERTY_HINTS') != ''

@[inline]
fn use_wide_property_hints() bool {
	$if test { if narrow_property_hints_for_test { return false } }
	return !narrow_property_hints
}

// A get_property site whose receiver lacks the key remembers where the
// receiver's direct prototype holds it: this flag plus the position. The own
// lookup still runs first, so the receiver can never shadow a stale holder.
const inherited_property_hint = u32(0x80000000)

// The key's own properties on this object are exactly its ordinary property
// list: no proxy or host provider, and none of the virtual array length,
// array elements or String object characters.
@[inline]
fn (object &Object) reads_key_hinted(key PropertyName) bool {
	if !use_wide_property_hints() {
		return object.proxy_object == none && object.array_object == none
			&& object.indexed_properties == none && object.reads_directly()
	}
	if object.proxy_object != none || !object.reads_key_directly(key) { return false }
	if object.array_object != none { return key.kind != .number_key && !key.is_length_property() }
	return true
}

fn (object &Object) hinted_get(mut vm VM, key PropertyName, receiver Value, hint &u32) !Value {
	if !object.reads_key_hinted(key) {
		return object.internal_get(mut vm, key, receiver)
	}
	position := unsafe { *hint }
	mut index := int(position)
	if position < u32(object.properties.len) && object.properties[position].key.equals(key) {
		$if test { if property_hint_diagnostics { property_hint_hits++ } }
	} else {
		// reads_key_hinted(): no virtual own properties, so none at all here.
		index = if object.properties.len == 0 { -1 } else { object.find_own_property(key) }
		if index < 0 { return object.hinted_get_inherited(mut vm, key, receiver, hint, position) }
		unsafe {
			*hint = u32(index)
		}
	}
	value := object.properties[index].value
	if !value.is_accessor() {
		record_direct_property_read()
		return value
	}
	// Own accessors keep [[Get]]'s complete dispatch and caching.
	return object.internal_get(mut vm, key, receiver)
}

// [[Get]] after the receiver's own lookup missed: the direct prototype's data
// property by its remembered position, else by lookup (remembering it).
// Accessors and deeper holders keep get_inherited(), starting past a
// prototype whose own lookup already missed.
fn (object &Object) hinted_get_inherited(mut vm VM, key PropertyName, receiver Value, hint &u32, position u32) !Value {
	parent := object.prototype or { return js_undefined() }
	if !use_wide_property_hints() || !parent.reads_key_hinted(key) {
		return object.get_inherited(mut vm, key, receiver)
	}
	if position & inherited_property_hint != 0 {
		held := position & ~inherited_property_hint
		if held < u32(parent.properties.len) && parent.properties[held].key.equals(key) {
			value := parent.properties[held].value
			if !value.is_accessor() {
				$if test { if property_hint_diagnostics { inherited_property_hint_hits++ } }
				record_direct_property_read()
				return value
			}
			return object.get_inherited(mut vm, key, receiver)
		}
	}
	found := parent.find_own_property(key)
	if found < 0 {
		if vm.did_reach_stack_space_limit() { return vm.throw_error_type(.internal_error, .call_stack_size_exceeded) }
		return parent.get_inherited(mut vm, key, receiver)
	}
	if found < int(inherited_property_hint) {
		unsafe {
			*hint = inherited_property_hint | u32(found)
		}
	}
	value := parent.properties[found].value
	if !value.is_accessor() {
		record_direct_property_read()
		return value
	}
	return object.get_inherited(mut vm, key, receiver)
}

// [[Set]] for an own writable data property whose receiver is the ordinary
// holder: a direct store, as internal_set()'s direct path performs. Anything
// else, including an absent key, returns false for Reference/[[Set]].
fn (object &Object) hinted_set(key PropertyName, value Value, hint &u32) bool {
	position := unsafe { *hint }
	mut index := int(position)
	if position >= u32(object.properties.len) || !object.properties[position].key.equals(key) {
		if position == property_hint_adding || !object.writes_directly() { return false }
		index = object.find_own_property(key)
		if index < 0 {
			unsafe {
				*hint = property_hint_adding
			}
			return false
		}
		unsafe {
			*hint = u32(index)
		}
	} else if !object.writes_directly() {
		return false
	}
	property := object.properties[index]
	if property.value.is_accessor() || !property.writable { return false }
	$if test { if property_hint_diagnostics { property_hint_hits++ } }
	mut owner := unsafe { &Object(object) }
	owner.properties[index].value = value
	return true
}

// internal_set()'s direct-path holders: no exotic [[Set]] or [[DefineOwnProperty]].
@[inline]
fn (object &Object) writes_directly() bool {
	return object.proxy_object == none && object.array_object == none
		&& object.indexed_properties == none && object.typed_array == none
		&& object.host_properties == none && object.legacy_platform_object == none
		&& object.string_object == none && object.arguments_object == none
		&& use_direct_accessor_dispatch()
}

$if test {
	__global property_hint_diagnostics bool
	__global property_hint_hits u64
	__global inherited_property_hint_hits u64
	__global narrow_property_hints_for_test bool
	pub fn diagnose_property_hints_for_testing(enabled bool) u64 {
		previous := property_hint_hits
		property_hint_hits = 0
		inherited_property_hint_hits = 0
		property_hint_diagnostics = enabled
		return previous
	}
	pub fn inherited_property_hint_hits_for_testing() u64 { return inherited_property_hint_hits }
	pub fn set_wide_property_hints_for_testing(enabled bool) { narrow_property_hints_for_test = !enabled }
}
