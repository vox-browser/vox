module css

import dom
import os

const retain_parent_longhand_hashing = os.getenv('VOX_RETAIN_PARENT_LONGHAND_HASHING') != ''
const longhand_parent_hash_diagnostics = os.getenv('VOX_LONGHAND_PARENT_HASH_DIAGNOSTICS') != ''

__global longhand_parent_hash_reported_document dom.UniqueNodeID

struct ComputedLonghandParentHashHint {
	parent &ComputedProperties
	token &ComputedPropertyGraphMutationToken
	revision u64
	hash u64
}

fn inherited_longhand_hash(parent &ComputedProperties) ?u64 {
	mut hash := u64(0x9e3779b97f4a7c15)
	ensure_computed_interpolation_inherited_cache()
	for index in 0 .. number_of_longhand_properties {
		if computed_interpolation_inherited_cache[index] == 0 { continue }
		value := parent.raw_property_at_index(index)
		mut value_hash := u64(0)
		if value != unsafe { nil } {
			if value.css_value_handle == unsafe { nil } { return none }
			value_hash = computed_longhand_reuse_value_hash(value) or { u64(voidptr(value.css_value_handle)) }
		}
		hash = (hash ^ value_hash) * u64(0x100000001b3)
	}
	return hash
}

// Cache only a bucket hint for this synchronous outer batch. Every restore
// still checks current parent values and the retained original payloads.
// Direct mutable-box writes can make the hint stale without changing an epoch;
// that creates a collision/miss, never permission to restore a stale style.
fn (s &StyleComputer) inherited_longhand_hash_hint(parent &ComputedProperties,
	element dom.AbstractElement) ?u64 {
	if retain_parent_longhand_hashing { return inherited_longhand_hash(parent) }
	key := u64(voidptr(parent))
	if s.longhand_reuse_cache_ != unsafe { nil } {
		if previous := s.longhand_reuse_cache_.parent_hashes[key] {
			if voidptr(previous.parent) == voidptr(parent)
				&& voidptr(previous.token) == voidptr(parent.computed_property_graph_token_)
				&& previous.revision != 0 && previous.revision == parent.mutation_revision() {
				report_longhand_parent_hash_hint(element)
				return previous.hash
			}
		}
	}
	hash := inherited_longhand_hash(parent) or { return none }
	revision := parent.mutation_revision()
	if revision == 0 { return hash }
	mut arena := s.computed_property_page_index_arena()
	allocation := arena.enter()
	defer { arena.leave(allocation) }
	mut owner := unsafe { &StyleComputer(s) }
	if owner.longhand_reuse_cache_ == unsafe { nil } {
		owner.longhand_reuse_cache_ = &ComputedLonghandReuseCache{}
	}
	// The cache and its parent references retire with the outer batch.
	if key in owner.longhand_reuse_cache_.parent_hashes
		|| owner.longhand_reuse_cache_.parent_hashes.len < 1024 {
		owner.longhand_reuse_cache_.parent_hashes[key] = ComputedLonghandParentHashHint{
			parent:parent
			token:parent.computed_property_graph_token_
			revision:revision
			hash:hash
		}
	}
	return hash
}

fn report_longhand_parent_hash_hint(element dom.AbstractElement) {
	if !longhand_parent_hash_diagnostics { return }
	document := element.element().document()
	identity := document.as_node().unique_id()
	if longhand_parent_hash_reported_document != identity {
		longhand_parent_hash_reported_document = identity
		eprintln('Vox inherited longhands: reused parent hash hint with exact restore guards; document=${document.url.serialize()}')
	}
}
