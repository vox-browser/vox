module libjs

const native_entry_cache_slots = 256

struct NativeEntryCacheSlot {
	executable &Executable = unsafe { nil }
	entry NativeEntry = unsafe { nil }
}

$if test {
	__global native_entry_cache_disabled bool
	pub fn set_native_entry_cache_for_testing(enabled bool) { native_entry_cache_disabled = !enabled }
}

fn use_native_entry_cache() bool {
	$if test { if native_entry_cache_disabled { return false } }
	return true
}

fn native_entry_cache_slot(executable &Executable) int {
	address := u64(uint(executable))
	return int(((address >> 4) ^ (address >> 16)) & (native_entry_cache_slots - 1))
}

fn (mut tier NativeTier) remember_native_entry(executable &Executable, entry NativeEntry) {
	// Keep an already-populated table coherent even when a test disables reads.
	if tier.entry_cache.len == 0 {
		if !use_native_entry_cache() { return }
		tier.entry_cache = []NativeEntryCacheSlot{len: native_entry_cache_slots}
	}
	tier.entry_cache[native_entry_cache_slot(executable)] = NativeEntryCacheSlot{executable: executable, entry: entry}
}

fn (mut tier NativeTier) set_native_entry(executable &Executable, entry NativeEntry) {
	tier.entries[voidptr(executable)] = entry
	tier.remember_native_entry(executable, entry)
}

// The tier owns both table and library handles. Exact executable identity guards
// collisions; misses are never cached. Every mapping write updates this table,
// bulk replacement clears it, and closing the tier discards it with the handles.
fn (mut tier NativeTier) entry_for_execution(executable &Executable) ?NativeEntry {
	if tier.enabled && use_native_entry_cache() && tier.entry_cache.len != 0 {
		slot := &tier.entry_cache[native_entry_cache_slot(executable)]
		if voidptr(slot.executable) == voidptr(executable) {
			if tier.profiling { tier.observe(executable) }
			if tier.diagnostics { tier.activity.entry_cache_hits++ }
			return slot.entry
		}
	}
	if tier.persistent != none { tier.prepare_cached_entry(executable) }
	if tier.profiling { tier.observe(executable) }
	if !tier.enabled { return none }
	if entry := tier.entries[voidptr(executable)] {
		tier.remember_native_entry(executable, entry)
		return entry
	}
	return none
}

// The interpreter's entry: the same lookup as entry_for_execution, with the
// persisted lookup index consulted before an executable's first record lookup.
fn (mut vm VM) native_entry_for_execution(mut tier NativeTier, executable &Executable) ?NativeEntry {
	if tier.enabled && use_native_entry_cache() && tier.entry_cache.len != 0 {
		slot := &tier.entry_cache[native_entry_cache_slot(executable)]
		if voidptr(slot.executable) == voidptr(executable) {
			if tier.profiling { tier.observe(executable) }
			if tier.diagnostics { tier.activity.entry_cache_hits++ }
			return slot.entry
		}
	}
	if mut cache := tier.persistent {
		match vm.native_lookup_entry(mut tier, mut cache, executable) {
			.hit {}
			.missed {
				tier.prepare_cached_entry(executable)
				vm.learn_native_lookup_entry(tier, executable)
			}
			.skipped { tier.prepare_cached_entry(executable) }
		}
	}
	if tier.profiling { tier.observe(executable) }
	if !tier.enabled { return none }
	if entry := tier.entries[voidptr(executable)] {
		tier.remember_native_entry(executable, entry)
		return entry
	}
	return none
}
