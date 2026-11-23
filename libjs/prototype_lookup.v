module libjs

import platform

const indexed_prototype_cache_size = 128
const indexed_prototype_chain_limit = 8

struct IndexedPrototypeState {
	object   &Object            = unsafe { nil }
	index    &IndexedProperties = unsafe { nil }
	revision u64
}

struct IndexedPrototypeEntry {
mut:
	states   [8]IndexedPrototypeState
	count    int
	position int
}

@[heap]
struct IndexedPrototypeCache {
mut:
	slots []IndexedPrototypeEntry
}

struct IndexedPrototypeProperty {
	holder &Object
	// Nonnegative: live own cell. -1: resume ordinary lookup here. -2:
	// this uncached walk reached a null prototype without finding the key.
	position int
}

$if test {
	__global indexed_prototype_lookups_disabled bool
	pub fn set_indexed_prototype_lookups_for_testing(enabled bool) {
		indexed_prototype_lookups_disabled = !enabled
	}
}

fn use_indexed_prototype_lookups() bool {
	$if test {
		if indexed_prototype_lookups_disabled { return false }
	}
	return use_indexed_properties()
}

fn indexed_prototype_storage(object &Object) ?&IndexedProperties {
	if object.proxy_object != none || object.host_properties != none || object.array_object != none
		|| object.typed_array != none || object.string_object != none || object.arguments_object != none
		|| object.legacy_platform_object != none {
		return none
	}
	return object.indexed_properties
}

fn (entry &IndexedPrototypeEntry) lookup(start &Object, key PropertyName) ?IndexedPrototypeProperty {
	if entry.count == 0 || voidptr(entry.states[0].object) != voidptr(start) { return none }
	for position in 0 .. entry.count {
		state := &entry.states[position]
		index := indexed_prototype_storage(state.object) or { return none }
		if voidptr(index) != voidptr(state.index) || index.revision != state.revision
			|| index.count != state.object.properties.len || index.data != state.object.properties.data {
			return none
		}
		if position + 1 < entry.count {
			parent := state.object.prototype or { return none }
			if voidptr(parent) != voidptr(entry.states[position + 1].object) { return none }
		}
	}
	holder := entry.states[entry.count - 1].object
	if entry.position < 0 || entry.position >= holder.properties.len
		|| !holder.properties[entry.position].key.equals(key) {
		return none
	}
	return IndexedPrototypeProperty{holder, entry.position}
}

// Only owners of explicitly indexed ordinary storage qualify. Every skipped
// absence is protected by that storage's revision and every prototype link is
// checked live. The selected data/accessor cell itself is never cached.
fn (mut vm VM) indexed_prototype_property(start &Object, key PropertyName) ?IndexedPrototypeProperty {
	if !use_indexed_prototype_lookups() || start.indexed_properties == none { return none }
	if vm.stack_info_.size_free() < 64 * 1024 { return none }
	if _ := indexed_prototype_storage(start) {} else { return none }
	mut cache := vm.indexed_prototype_cache or {
		persistent := platform.enter_persistent()
		created := &IndexedPrototypeCache{ slots: []IndexedPrototypeEntry{len: indexed_prototype_cache_size} }
		platform.leave_persistent(persistent)
		vm.indexed_prototype_cache = created
		created
	}
	slot := int((u64(uint(start) >> 4) ^ property_lookup_hash(key)) & u64(indexed_prototype_cache_size - 1))
	if found := cache.slots[slot].lookup(start, key) {
		if mut tier := vm.native_tier {
			if tier.diagnostics { tier.activity.indexed_prototype_lookup_hits++ }
		}
		return found
	}
	mut entry := IndexedPrototypeEntry{}
	mut current := start
	for entry.count < indexed_prototype_chain_limit {
		if _ := indexed_prototype_storage(current) {
		} else {
			return IndexedPrototypeProperty{current, -1}
		}
		position := current.find_own_property(key)
		index := current.indexed_properties or { return none }
		entry.states[entry.count] = IndexedPrototypeState{current, index, index.revision}
		entry.count++
		if position >= 0 {
			entry.position = position
			cache.slots[slot] = entry
			return IndexedPrototypeProperty{current, position}
		}
		current = current.prototype or { return IndexedPrototypeProperty{current, -2} }
	}
	return IndexedPrototypeProperty{current, -1}
}
