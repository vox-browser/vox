module libjs

import platform

// Opt-in ordinary storage, retaining the authoritative insertion-ordered
// property vector. Owners must use the object mutation methods after opting
// in; direct key edits/reordering of the public vector are not supported.
// Unindexed objects retain the existing externally mutable storage behavior.
@[heap]
struct IndexedProperties {
mut:
	positions PositionTable
	count     int
	data      voidptr
	revision  u64
}

pub struct IndexedPropertyActivity {
pub:
	hits   u64
	misses u64
}

$if test {
	__global indexed_properties_disabled bool
	__global indexed_properties_diagnostics bool
	__global indexed_property_hits u64
	__global indexed_property_misses u64
	pub fn set_indexed_properties_for_testing(enabled bool) {
		indexed_properties_disabled = !enabled
	}
	pub fn diagnose_indexed_properties_for_testing(enabled bool) IndexedPropertyActivity {
		previous := IndexedPropertyActivity{indexed_property_hits, indexed_property_misses}
		indexed_property_hits = 0
		indexed_property_misses = 0
		indexed_properties_diagnostics = enabled
		return previous
	}
}

fn use_indexed_properties() bool {
	$if test {
		if indexed_properties_disabled { return false }
	}
	return true
}

// Native DOM binding owners use this before publishing methods/accessors.
// Script-visible additions, updates and deletions keep the index coherent.
pub fn (mut object Object) enable_indexed_properties() bool {
	if !use_indexed_properties() || object.proxy_object != none || object.array_object != none
		|| object.typed_array != none || object.arguments_object != none
		|| object.string_object != none || object.legacy_platform_object != none {
		return false
	}
	if object.indexed_properties != none { return true }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut index := &IndexedProperties{}
	index.rebuild(object)
	object.indexed_properties = index
	object.property_lookup_hints = none
	return true
}

fn (mut index IndexedProperties) insert(object &Object, position int) {
	key := object.properties[position].key
	mut hash := property_lookup_hash(key)
	for {
		if previous := index.positions.get(hash) {
			if object.properties[previous].key.equals(key) { return }
			hash++
			continue
		}
		index.positions.set(hash, position)
		return
	}
}

fn (mut index IndexedProperties) rebuild(object &Object) {
	index.revision++
	index.positions.clear()
	for position in 0 .. object.properties.len { index.insert(object, position) }
	index.count = object.properties.len
	index.data = object.properties.data
}

fn (object &Object) find_indexed_property(key PropertyName) int {
	owner := object.indexed_properties or { return object.find_own_property_linear(key) }
	mut index := unsafe { &IndexedProperties(owner) }
	// Detect whole-vector replacement or growth by an embedding caller too.
	if index.count != object.properties.len || index.data != object.properties.data {
		persistent := platform.enter_persistent()
		index.rebuild(object)
		platform.leave_persistent(persistent)
	}
	mut hash := property_lookup_hash(key)
	for {
		position := index.positions.get(hash) or {
			$if test {
				if indexed_properties_diagnostics { indexed_property_misses++ }
			}
			return -1
		}
		if position >= 0 && position < object.properties.len && object.properties[position].key.equals(key) {
			$if test {
				if indexed_properties_diagnostics { indexed_property_hits++ }
			}
			return position
		}
		hash++
	}
	return -1
}

fn (object &Object) index_appended_property() {
	owner := object.indexed_properties or { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut index := unsafe { &IndexedProperties(owner) }
	index.insert(object, object.properties.len - 1)
	index.revision++
	index.count = object.properties.len
	index.data = object.properties.data
}

fn (object &Object) reindex_deleted_property() {
	owner := object.indexed_properties or { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut index := unsafe { &IndexedProperties(owner) }
	index.rebuild(object)
}
