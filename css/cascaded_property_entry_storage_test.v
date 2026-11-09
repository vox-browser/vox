module css

import dom

// Exact previous vector-backed implementation for differential cascade checks.
@[heap]
struct LegacyCascadedPropertyEntries {
mut:
 properties_ map[PropertyID][]CascadedPropertiesEntry
 contained_properties_cache_ []u8
}
fn LegacyCascadedPropertyEntries.new() &LegacyCascadedPropertyEntries {
	return &LegacyCascadedPropertyEntries{
		properties_: map[PropertyID][]CascadedPropertiesEntry{}
		// Upstream's PropertyID places shorthands before its contiguous
		// longhands, so FixedBitmap<last_longhand + 1> also covers unresolved
		// shorthand entries. V groups longhands first for dense computed-value
		// storage and puts shorthands afterwards; size this cache by the complete
		// PropertyID range to preserve the LegacyCascadedPropertyEntries contract.
		contained_properties_cache_: []u8{len: int(PropertyID.container) + 1}
	}
}


fn (mut c LegacyCascadedPropertyEntries) revert_property(property_id PropertyID, important Important, cascade_origin CascadeOrigin) {
	if property_id !in c.properties_ {
		return
	}
	mut entries := c.properties_[property_id] or { return }
	mut filtered := []CascadedPropertiesEntry{}
	for entry in entries {
		// Presentational hints cascade independently, but `revert` at the
		// author origin also rolls them back as part of the author origin.
		origin_matches := cascade_origin == entry.origin
			|| (cascade_origin == .author && entry.origin == .author_presentational_hint)
		if entry.property.property_id == property_id && entry.property.important == important
			&& origin_matches {
			continue
		}
		filtered << entry
	}
	if filtered.len == 0 {
		c.contained_properties_cache_[cascaded_property_index(property_id)] = 0
		c.properties_.delete(property_id)
		return
	}
	c.properties_[property_id] = filtered
}


fn (mut c LegacyCascadedPropertyEntries) revert_layer_property(property_id PropertyID, important Important, layer_name ?string) {
	if property_id !in c.properties_ {
		return
	}
	mut entries := c.properties_[property_id] or { return }
	mut filtered := []CascadedPropertiesEntry{}
	for entry in entries {
		if entry.property.property_id == property_id && entry.property.important == important && option_string_equal(entry.layer_name, layer_name) {
			continue
		}
		filtered << entry
	}
	if filtered.len == 0 {
		c.contained_properties_cache_[cascaded_property_index(property_id)] = 0
		c.properties_.delete(property_id)
		return
	}
	c.properties_[property_id] = filtered
}


fn (mut c LegacyCascadedPropertyEntries) set_property(property_id PropertyID, value &dom.StyleValue, important Important, origin CascadeOrigin, layer_name ?string, source voidptr, source_shadow_root ?&dom.ShadowRoot) {
	c.contained_properties_cache_[cascaded_property_index(property_id)] = 1

	mut entries := c.properties_[property_id]
	for index := entries.len - 1; index >= 0; index-- {
		mut entry := entries[index]
		if entry.origin == origin && option_string_equal(entry.layer_name, layer_name) {
			if entry.property.important == .yes && important == .no {
				return
			}
			entry.property = StyleProperty{
				important: important
				property_id: property_id
				value: unsafe { value }
			}
			entry.source = source
			entry.source_shadow_root = source_shadow_root
			entries[index] = entry
			c.properties_[property_id] = entries
			return
		}
	}

	entries << CascadedPropertiesEntry{
		property: StyleProperty{
			important: important
			property_id: property_id
			value: unsafe { value }
		}
		origin: origin
		layer_name: layer_name
		source: source
		source_shadow_root: source_shadow_root
	}
	c.properties_[property_id] = entries
}


fn (c &LegacyCascadedPropertyEntries) property(property_id PropertyID) ?&dom.StyleValue {
	if c.contained_properties_cache_[cascaded_property_index(property_id)] == 0 {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].property.value
}


fn (c &LegacyCascadedPropertyEntries) property_source(property_id PropertyID) voidptr {
	if c.contained_properties_cache_[cascaded_property_index(property_id)] == 0 {
		return unsafe { nil }
	}
	entries := c.properties_[property_id] or { return unsafe { nil } }
	if entries.len == 0 {
		return unsafe { nil }
	}
	return entries[entries.len - 1].source
}


fn (c &LegacyCascadedPropertyEntries) property_source_shadow_root(property_id PropertyID) ?&dom.ShadowRoot {
	if c.contained_properties_cache_[cascaded_property_index(property_id)] == 0 {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].source_shadow_root
}


fn (c &LegacyCascadedPropertyEntries) style_property(property_id PropertyID) ?StyleProperty {
	if c.contained_properties_cache_[cascaded_property_index(property_id)] == 0 {
		return none
	}
	entries := c.properties_[property_id] or { return none }
	if entries.len == 0 {
		return none
	}
	return entries[entries.len - 1].property
}


fn entry_storage_snapshot(cascaded &CascadedProperties, id PropertyID) []CascadedPropertiesEntry {
 mut entries := []CascadedPropertiesEntry{}
 mut index := cascaded.entry_heads_.get(id)
 for index >= 0 {
  node := cascaded.entry_node(index)
  entries << node.entry
  index = node.previous
 }
 entries.reverse_in_place()
 return entries
}

fn chain_probe_assert_equivalent(left &LegacyCascadedPropertyEntries,right &CascadedProperties) {
 assert left.properties_.len == right.entry_heads_.active.len
 assert left.contained_properties_cache_ == right.contained_properties_cache_
 for id,entries in left.properties_ {
  actual:=entry_storage_snapshot(right,id)
  assert entries.len==actual.len
  for index,expected in entries {
   entry:=actual[index]
   assert expected.property.property_id==entry.property.property_id
   assert expected.property.value==entry.property.value
   assert expected.property.important==entry.property.important
   assert expected.origin==entry.origin
   assert option_string_equal(expected.layer_name,entry.layer_name)
   assert expected.source==entry.source
   assert expected.source_shadow_root==entry.source_shadow_root
  }
  assert (left.property(id) or {panic('missing baseline property')}) == (right.property(id) or {panic('missing chain property')})
  assert left.property_source(id) == right.property_source(id)
  assert left.property_source_shadow_root(id) == right.property_source_shadow_root(id)
  expected_property := left.style_property(id) or {panic('missing baseline style property')}
  actual_property := right.style_property(id) or {panic('missing chain style property')}
  assert expected_property.property_id == actual_property.property_id
  assert expected_property.important == actual_property.important
  assert expected_property.value == actual_property.value
 }
}

fn test_entry_chain_multiple_layers_keep_neighbor_values_and_previous_order() {
 first:=&dom.StyleValue{css_text:'first'}
 second:=&dom.StyleValue{css_text:'second'}
 mut baseline:=LegacyCascadedPropertyEntries.new()
 mut chain:=CascadedProperties.new()
 for id in [PropertyID.width,.height,.color,.opacity,.display,.margin_left,.padding_right,.font_size,.font_weight] {
  baseline.set_property(id,first,.no,.user_agent,none,voidptr(second),none)
  chain.set_property(id,first,.no,.user_agent,none,voidptr(second),none)
 }
 for layer in ['first','second','third','fourth','fifth'] {
  baseline.set_property(.width,second,.yes,.author,layer,voidptr(first),none)
  chain.set_property(.width,second,.yes,.author,layer,voidptr(first),none)
 }
 gc_collect()
 chain_probe_assert_equivalent(baseline,chain)
 assert chain.entry_chunks_.len==(chain.allocated_entry_count_+cascaded_property_entry_chunk_size-1)/cascaded_property_entry_chunk_size
 assert entry_storage_snapshot(chain,.width).len==6
 assert chain.property(.height)?==first
 assert chain.entry_node(chain.winning_entry_index(.width)).entry.layer_name?=='fifth'
}

fn chain_probe_return_cascade() &CascadedProperties {
 mut chain:=CascadedProperties.new()
 for index in 1..40 {
  id:=unsafe{PropertyID(index)}
  value:=&dom.StyleValue{css_text:'retained-${index}'}
  chain.set_property(id,value,.no,.author,'layer-${index}',voidptr(value),none)
 }
 return chain
}

fn test_entry_chain_returned_scanned_chunks_retain_values_layer_names_and_sources() {
 chain:=chain_probe_return_cascade()
 mut pressure:=[]string{}
 for index in 0..2048 {pressure << 'pressure-${index}'}
 for _ in 0..3 {gc_collect()}
 for index in 1..40 {
  id:=unsafe{PropertyID(index)}
  assert chain.property(id)?.css_text=='retained-${index}'
  entry:=chain.entry_node(chain.winning_entry_index(id)).entry
  assert entry.layer_name?=='layer-${index}'
  assert entry.source==voidptr(entry.property.value)
 }
 assert pressure.len==2048
}

fn test_entry_chain_reverts_preserve_important_origin_layer_and_shadow_source() {
 document:=dom.Document.create(dom.url_about_blank())
 mut host:=document.create_element_ns(dom.namespace_html_uri,'div')!
 shadow:=host.attach_shadow(dom.ShadowRootInit{mode:.open})!
 first:=&dom.StyleValue{css_text:'first'}
 second:=&dom.StyleValue{css_text:'second'}
 mut baseline:=LegacyCascadedPropertyEntries.new()
 mut chain:=CascadedProperties.new()
 for origin in [CascadeOrigin.user_agent,.author_presentational_hint,.author,.user] {
  for layer in ['a','b'] {
   baseline.set_property(.width,first,.no,origin,layer,voidptr(second),shadow)
   chain.set_property(.width,first,.no,origin,layer,voidptr(second),shadow)
  }
 }
 baseline.set_property(.width,second,.yes,.author,'b',voidptr(first),none)
 chain.set_property(.width,second,.yes,.author,'b',voidptr(first),none)
 baseline.set_property(.width,first,.no,.author,'b',voidptr(second),shadow)
 chain.set_property(.width,first,.no,.author,'b',voidptr(second),shadow)
 chain_probe_assert_equivalent(baseline,chain)
 baseline.revert_layer_property(.width,.no,'a')
 chain.revert_layer_property(.width,.no,'a')
 chain_probe_assert_equivalent(baseline,chain)
 baseline.revert_property(.width,.no,.author)
 chain.revert_property(.width,.no,.author)
 chain_probe_assert_equivalent(baseline,chain)
 gc_collect()
 assert chain.property(.width)?==first
 assert entry_storage_snapshot(chain,.width).last().source_shadow_root?==shadow
}

fn test_entry_chain_recycles_removed_slots_without_retaining_values_or_mutating_snapshots() {
 value:=&dom.StyleValue{css_text:'value'}
 mut chain:=CascadedProperties.new()
 chain.set_property(.color,value,.no,.author,'retained',voidptr(value),none)
 snapshot:=entry_storage_snapshot(chain,.color)
 for _ in 0..2048 {
  chain.revert_property(.color,.no,.author)
  assert chain.property(.color)==none
  assert chain.entry_heads_.active.len==0
  assert chain.entry_node(0).entry.property.value==unsafe{nil}
  assert chain.entry_node(0).entry.source==unsafe{nil}
  chain.set_property(.color,value,.no,.author,none,unsafe{nil},none)
 }
 assert chain.allocated_entry_count_==1
 assert chain.entry_chunks_.len==1
 gc_collect()
 assert chain.property(.color)?==value
 assert snapshot[0].layer_name?=='retained'
 assert snapshot[0].source==voidptr(value)
 assert snapshot[0].property.value==value
}

fn test_entry_chain_differential_mixed_cascade_edits_keep_priority_and_source_metadata() {
 first:=&dom.StyleValue{css_text:'first'}
 second:=&dom.StyleValue{css_text:'second'}
 mut baseline:=LegacyCascadedPropertyEntries.new()
 mut chain:=CascadedProperties.new()
 for index in 0..768 {
  id:=unsafe{PropertyID(1+(index*7)%23)}
  layer:=if index%3==0 {'layer-a'} else {'layer-b'}
  value:=if index%2==0 {first} else {second}
  origin:=if index%5==0 {CascadeOrigin.user_agent} else {CascadeOrigin.author}
  important:=if index%7==0 {Important.yes} else {Important.no}
  match index%6 {
   3 {baseline.revert_layer_property(id,important,layer);chain.revert_layer_property(id,important,layer)}
   5 {baseline.revert_property(id,important,origin);chain.revert_property(id,important,origin)}
   else {
    baseline.set_property(id,value,important,origin,layer,voidptr(value),none)
    chain.set_property(id,value,important,origin,layer,voidptr(value),none)
   }
  }
  chain_probe_assert_equivalent(baseline,chain)
  if index%64==0 {gc_collect()}
 }
}

fn test_entry_chain_empty_and_deleted_heads_keep_every_getter_consistent() {
 first := &dom.StyleValue{css_text: 'first'}
 second := &dom.StyleValue{css_text: 'second'}
 mut properties := CascadedProperties.new()
 properties.entry_heads_.set(.height, -1)
 properties.contained_properties_cache_[int(PropertyID.height)] = 1
 assert properties.property(.height) == none
 assert properties.property_source(.height) == unsafe {nil}
 assert properties.property_source_shadow_root(.height) == none
 assert properties.style_property(.height) == none
 properties.set_property(.height, first, .no, .author, none, voidptr(first), none)
 assert properties.property(.height)? == first
 properties.entry_heads_.delete(PropertyID.height)
 assert properties.contained_properties_cache_[int(PropertyID.height)] == 1
 assert properties.property(.height) == none
 assert properties.property_source(.height) == unsafe {nil}
 assert properties.property_source_shadow_root(.height) == none
 assert properties.style_property(.height) == none
 properties.set_property(.height, second, .yes, .author, none, voidptr(second), none)
 gc_collect()
 assert properties.property(.height)? == second
 assert properties.property_source(.height) == voidptr(second)
 assert properties.style_property(.height)?.important == .yes
}

fn test_entry_chain_absent_and_empty_reverts_preserve_public_presence_semantics() {
	mut properties := CascadedProperties.new()
	properties.contained_properties_cache_[int(PropertyID.width)] = 1
	properties.revert_property(.width, .no, .author)
	assert properties.contained_properties_cache_[int(PropertyID.width)] == 1
	assert properties.property(.width) == none
	properties.entry_heads_.set(.width, -1)
	properties.revert_property(.width, .no, .author)
	assert properties.contained_properties_cache_[int(PropertyID.width)] == 0
	assert properties.property(.width) == none

	first := &dom.StyleValue{css_text: 'first'}
	second := &dom.StyleValue{css_text: 'second'}
	properties.set_property(.width, first, .no, .author, none, voidptr(first), none)
	properties.contained_properties_cache_[int(PropertyID.width)] = 0
	assert properties.property(.width) == none
	assert properties.property_source(.width) == unsafe { nil }
	assert properties.style_property(.width) == none
	assert entry_storage_snapshot(properties, .width).len == 1
	properties.contained_properties_cache_[int(PropertyID.width)] = 1
	assert voidptr(properties.property(.width)?) == voidptr(first)
	properties.contained_properties_cache_[int(PropertyID.width)] = 0
	properties.set_property(.width, second, .yes, .author, none, voidptr(second), none)
	assert properties.contained_properties_cache_[int(PropertyID.width)] == 1
	assert voidptr(properties.property(.width)?) == voidptr(second)
	assert properties.property_source(.width) == voidptr(second)
	assert entry_storage_snapshot(properties, .width).len == 1
}

fn test_entry_chain_all_generated_ids_match_independent_cascade_after_revert_and_readd() {
	first := &dom.StyleValue{css_text: 'first'}
	second := &dom.StyleValue{css_text: 'second'}
	mut baseline := LegacyCascadedPropertyEntries.new()
	mut chain := CascadedProperties.new()
	for index in 0 .. int(PropertyID.container) + 1 {
		id := unsafe { PropertyID(index) }
		baseline.set_property(id, first, .no, .author_presentational_hint, none, voidptr(first), none)
		chain.set_property(id, first, .no, .author_presentational_hint, none, voidptr(first), none)
		baseline.set_property(id, second, .yes, .author, 'layer', voidptr(second), none)
		chain.set_property(id, second, .yes, .author, 'layer', voidptr(second), none)
	}
	chain_probe_assert_equivalent(baseline, chain)
	for index in 0 .. int(PropertyID.container) + 1 {
		id := unsafe { PropertyID(index) }
		baseline.revert_layer_property(id, .yes, 'layer')
		chain.revert_layer_property(id, .yes, 'layer')
		baseline.revert_property(id, .no, .author)
		chain.revert_property(id, .no, .author)
		assert chain.property(id) == none
		baseline.set_property(id, second, .no, .user, none, voidptr(second), none)
		chain.set_property(id, second, .no, .user, none, voidptr(second), none)
	}
	chain_probe_assert_equivalent(baseline, chain)
	assert chain.allocated_entry_count_ == 2 * (int(PropertyID.container) + 1)
}
