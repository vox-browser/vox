module libjs

// Ordinary own keys are unique. Keep their insertion-ordered storage authoritative
// and cache only successful positions, never values, descriptors or absence.
// Small objects keep the allocation-free linear lookup. Hints are bounded even
// when an object continually deletes and adds unrelated names.
const property_lookup_hint_minimum = 16
// Positions are recorded per key found, so only objects with many accessed
// keys (global objects, prototypes, bundle registries) reach the bound; a
// 64-entry table was cleared on nearly every insertion for them.
const property_lookup_hint_limit = 4096

@[heap]
struct PropertyLookupHints {
mut:
	positions map[u64]int
}

pub struct PropertyLookupActivity {
pub:
	hits   u64
	misses u64
}

$if test {
	__global property_lookup_hints_disabled_for_test bool
	__global property_lookup_hints_diagnostic_for_test bool
	__global property_lookup_hint_hits_for_test u64
	__global property_lookup_hint_misses_for_test u64

	// Same-executable control for focused benchmarks; no production setting or
	// per-lookup environment access. Test processes own their objects/VMs.
	pub fn set_property_lookup_hints_for_testing(enabled bool) {
		property_lookup_hints_disabled_for_test = !enabled
	}

	pub fn diagnose_property_lookup_hints_for_testing(enabled bool) PropertyLookupActivity {
		previous := PropertyLookupActivity{property_lookup_hint_hits_for_test, property_lookup_hint_misses_for_test}
		property_lookup_hints_diagnostic_for_test = enabled
		property_lookup_hint_hits_for_test = 0
		property_lookup_hint_misses_for_test = 0
		return previous
	}
}

fn property_lookup_hash(key PropertyName) u64 {
	match key.kind {
		.number_key { return u64(key.number) * 1099511628211 + 1 }
		.symbol_key { return u64(uint(key.as_symbol())) * 1099511628211 + 2 }
		.string_key {
			mut hash := u64(14695981039346656037)
			for unit in if key.string_value == unsafe { nil } { []u16{} } else { key.string_value.data } {
				hash = (hash ^ u64(unit)) * 1099511628211
			}
			return hash
		}
	}
}

fn (object &Object) find_own_property_with_hints(key PropertyName) int {
	hash := property_lookup_hash(key)
	if hints := object.property_lookup_hints {
		if index := hints.positions[hash] {
			// Deletions, compaction or key replacement can invalidate positions.
			// Hash collisions also take the ordered fallback; no negative cache
			// can hide additions or a property on the prototype chain.
			if index >= 0 && index < object.properties.len
				&& object.properties[index].key.equals(key) {
				$if test {
					if property_lookup_hints_diagnostic_for_test {
						property_lookup_hint_hits_for_test++
					}
				}
				return index
			}
		}
	}
	$if test {
		if property_lookup_hints_diagnostic_for_test { property_lookup_hint_misses_for_test++ }
	}
	index := object.find_own_property_linear(key)
	if index < 0 { return index }
	mut owner := unsafe { &Object(object) }
	mut hints := owner.property_lookup_hints or {
		created := &PropertyLookupHints{}
		owner.property_lookup_hints = created
		created
	}
	if hints.positions.len >= property_lookup_hint_limit { hints.positions.clear() }
	hints.positions[hash] = index
	return index
}
