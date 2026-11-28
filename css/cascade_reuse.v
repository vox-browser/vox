module css

import dom
import os
import platform

// The cascade ran again for every element: about 16% of the style pass on the
// archived github.com/vlang/v page, where 87% of elements match exactly the
// rules of an earlier element in the same custom property environment. The
// cascade reads only the matched rules (with their shadow roots and layers),
// the presentational hints, the inline style, a position-try override, the
// logical alias context, the pseudo-element and, through var() substitution,
// the custom property environment. Hint values for equal SVG attributes and
// var() results per environment are shared within a style batch, so equal
// inputs mean equal value objects. Within one batch the complete cascaded
// structure (every property's entry chain, its order and the presence bits)
// is kept by those inputs and replayed for later elements. Elements with an
// inline style or a position-try override, and cascades that substitute
// attr(), if(), inherit() or custom functions, are cascaded every time.
const disable_cascade_reuse = os.getenv('VOX_DISABLE_CASCADE_REUSE') != ''
const cascade_reuse_limit = 4096

struct CascadeReuseChain {
	id      PropertyID
	entries []CascadedPropertiesEntry // newest first
}

@[heap]
struct CascadeReuseEntry {
	key      []u64
	chains   []CascadeReuseChain
	present  []u16
	uses_var bool
}

@[heap]
struct CascadeReuseCache {
mut:
	entries   map[u64]&CascadeReuseEntry
	recording bool
	blocked   bool
	uses_var  bool
}

fn cascade_reuse_push_rules(mut key []u64, rules []ScopedMatchingRule) {
	key << u64(rules.len)
	for scoped in rules {
		key << u64(voidptr(scoped.rule))
		key << if root := scoped.shadow_root { u64(voidptr(root)) } else { u64(0) }
	}
}

fn cascade_reuse_hash(key []u64) u64 {
	mut hash := u64(0xcbf29ce484222325)
	for part in key {
		hash = (hash ^ part) * u64(0x100000001b3)
	}
	return hash
}

fn (s &StyleComputer) cascade_reuse_key(abstract_element dom.AbstractElement, did_match_any_pseudo_element_rules bool, mode ComputeStyleMode, matching_rule_set MatchingRuleSet, logical_alias_mapping_context ?LogicalAliasMappingContext, hints []StyleProperty) ?[]u64 {
	if disable_cascade_reuse || s.computed_property_page_batch_depth_ == 0 { return none }
	pseudo := abstract_element.pseudo_element()
	if pseudo == none && inline_style_for_abstract_element(abstract_element) != none { return none }
	if override := s.position_try_override_ {
		if voidptr(override.target.element()) == voidptr(abstract_element.element()) { return none }
	}
	mut key := []u64{cap: 64}
	key << u64(mode)
	key << if did_match_any_pseudo_element_rules { u64(1) } else { u64(0) }
	key << if p := pseudo { u64(p) + 1 } else { u64(0) }
	key << if context := logical_alias_mapping_context {
		(u64(1) << 32) | (u64(context.writing_mode) << 8) | u64(context.direction)
	} else {
		u64(0)
	}
	key << if data := abstract_element.custom_property_data() { u64(voidptr(data)) } else { u64(0) }
	cascade_reuse_push_rules(mut key, matching_rule_set.user_agent_rules)
	cascade_reuse_push_rules(mut key, matching_rule_set.user_rules)
	key << u64(matching_rule_set.author_rules.len)
	for layer in matching_rule_set.author_rules {
		key << u64(layer.qualified_layer_name.hash())
		key << u64(layer.qualified_layer_name.len)
		cascade_reuse_push_rules(mut key, layer.rules)
	}
	key << u64(hints.len)
	for hint in hints {
		key << u64(hint.property_id)
		key << u64(voidptr(hint.value))
		key << u64(hint.important)
	}
	return key
}

// The cascade of compute_style_impl(), replayed from an earlier element with
// the same inputs within the style batch when possible.
fn (s &StyleComputer) compute_cascaded_values_reusing(mut cascaded_properties CascadedProperties, abstract_element dom.AbstractElement, did_match_any_pseudo_element_rules bool, mode ComputeStyleMode, matching_rule_set MatchingRuleSet, logical_alias_mapping_context ?LogicalAliasMappingContext) {
	hints := if abstract_element.pseudo_element() == none {
		s.cascade_presentational_hints(abstract_element, []PropertyID{})
	} else {
		[]StyleProperty{}
	}
	key := s.cascade_reuse_key(abstract_element, did_match_any_pseudo_element_rules, mode,
		matching_rule_set, logical_alias_mapping_context, hints) or {
		s.compute_cascaded_values_with_hints(mut cascaded_properties, abstract_element, did_match_any_pseudo_element_rules, mode, matching_rule_set, logical_alias_mapping_context, []PropertyID{}, hints)
		return
	}
	hash := cascade_reuse_hash(key)
	mut owner := unsafe { &StyleComputer(s) }
	if owner.cascade_reuse_ != unsafe { nil } {
		if entry := owner.cascade_reuse_.entries[hash] {
			if entry.key == key {
				replay_cascade(mut cascaded_properties, entry)
				if entry.uses_var {
					mut element := unsafe { &dom.Element(abstract_element.element()) }
					element.set_style_uses_var_css_function()
				}
				return
			}
		}
	}
	if owner.cascade_reuse_ == unsafe { nil } {
		owner.cascade_reuse_ = &CascadeReuseCache{}
	}
	mut cache := owner.cascade_reuse_
	// A nested style computation records its own cascade; keep this one's state.
	was_recording, was_blocked, did_use_var := cache.recording, cache.blocked, cache.uses_var
	cache.recording = true
	cache.blocked = false
	cache.uses_var = false
	s.compute_cascaded_values_with_hints(mut cascaded_properties, abstract_element, did_match_any_pseudo_element_rules, mode, matching_rule_set, logical_alias_mapping_context, []PropertyID{}, hints)
	blocked, uses_var := cache.blocked, cache.uses_var
	cache.recording, cache.blocked, cache.uses_var = was_recording, was_blocked || blocked, did_use_var || uses_var
	if blocked || cache.entries.len >= cascade_reuse_limit { return }
	mut index_arena := s.computed_property_page_index_arena()
	allocation := index_arena.enter()
	defer { index_arena.leave(allocation) }
	cache.entries[hash] = snapshot_cascade(cascaded_properties, key, uses_var)
}

// Called by resolve_cascade_declaration_value() for each substitution.
fn note_cascade_substitution(abstract_element dom.AbstractElement, unresolved UnresolvedStyleValue) {
	computer := batch_style_computer_for(abstract_element.element()) or { return }
	mut cache := computer.cascade_reuse_
	if cache == unsafe { nil } || !cache.recording { return }
	if !environment_substitution_applies(unresolved) { cache.blocked = true }
	if unresolved.includes_var_function() { cache.uses_var = true }
}

fn snapshot_cascade(cascaded &CascadedProperties, key []u64, uses_var bool) &CascadeReuseEntry {
	mut chains := []CascadeReuseChain{cap: cascaded.entry_heads_.active.len}
	for id in cascaded.entry_heads_.active {
		mut entries := []CascadedPropertiesEntry{}
		mut index := cascaded.entry_heads_.get(id)
		for index >= 0 {
			node := cascaded.entry_node(index)
			entries << node.entry
			index = node.previous
		}
		chains << CascadeReuseChain{id: id, entries: entries}
	}
	mut present := []u16{}
	for index, bit in cascaded.contained_properties_cache_ {
		if bit != 0 { present << u16(index) }
	}
	return &CascadeReuseEntry{key: key.clone(), chains: chains, present: present, uses_var: uses_var}
}

// Rebuilds the snapshot in an empty scratch cascade: the same chains, in the
// same active order, and the same presence bits.
fn replay_cascade(mut cascaded CascadedProperties, entry &CascadeReuseEntry) {
	mut arena_entry := platform.ArenaEntry{}
	entered := cascaded.scratch_arena_ != unsafe { nil }
	if entered { arena_entry = cascaded.scratch_arena_.enter() }
	defer { if entered { cascaded.scratch_arena_.leave(arena_entry) } }
	for index in entry.present {
		cascaded.contained_properties_cache_[int(index)] = 1
	}
	for chain in entry.chains {
		mut previous := -1
		for position := chain.entries.len - 1; position >= 0; position-- {
			previous = cascaded.allocate_entry(chain.entries[position], previous)
		}
		cascaded.entry_heads_.set(chain.id, previous)
	}
}
