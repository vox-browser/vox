module css

import dom

fn entry_array_test_entries(cascaded &CascadedProperties, id PropertyID) []CascadedPropertiesEntry {
 mut entries := []CascadedPropertiesEntry{}
 assert cascaded.entry_heads_.contains(id)
 mut index := cascaded.entry_heads_.get(id)
 for index >= 0 {
  node := cascaded.entry_node(index)
  entries << node.entry
  index = node.previous
 }
 entries.reverse_in_place()
 return entries
}

fn test_cascade_entry_arrays_default_on_every_generated_key_and_replace() {
 initial := &dom.StyleValue{css_text:'initial'}
 unset := &dom.StyleValue{css_text:'unset'}
 source := &dom.StyleValue{css_text:'source'}
 mut cascaded := CascadedProperties.new()
 for index in 1 .. int(PropertyID.container)+1 {
  id := unsafe { PropertyID(index) }
  cascaded.set_property(id,initial,.no,.author,none,voidptr(source),none)
  assert entry_array_test_entries(cascaded,id).len == 1
  assert cascaded.property(id)? == initial
  assert cascaded.property_source(id) == voidptr(source)
 }
 assert cascaded.entry_heads_.active.len == int(PropertyID.container)
 for index in 1 .. int(PropertyID.container)+1 {
  id := unsafe { PropertyID(index) }
  cascaded.set_property(id,unset,.no,.author,none,unsafe{nil},none)
  assert entry_array_test_entries(cascaded,id).len == 1
  assert cascaded.property(id)? == unset
  assert cascaded.property_source(id) == unsafe{nil}
 }
 gc_collect()
 assert cascaded.property(.color)?.css_text == 'unset'
 assert cascaded.property(.container)?.css_text == 'unset'
}
fn test_cascade_entry_arrays_preserve_priority_layers_origins_and_shadow_source() {
 document := dom.Document.create(dom.url_about_blank())
 mut host := document.create_element_ns('http://www.w3.org/1999/xhtml','div') or {panic(err)}
 shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open}) or {panic(err)}
 first := &dom.StyleValue{css_text:'10px'}
 second := &dom.StyleValue{css_text:'20px'}
 source := &dom.StyleValue{css_text:'source'}
 mut cascaded := CascadedProperties.new()
 cascaded.set_property(.width,first,.yes,.author,'base',voidptr(source),shadow)
 cascaded.set_property(.width,second,.no,.author,'base',unsafe{nil},none)
 assert cascaded.property(.width)? == first
 assert cascaded.property_source(.width) == voidptr(source)
 assert cascaded.property_source_shadow_root(.width)? == shadow
 cascaded.set_property(.width,second,.yes,.author,'base',unsafe{nil},none)
 assert entry_array_test_entries(cascaded,PropertyID.width).len == 1
 assert cascaded.property(.width)? == second
 assert cascaded.property_source(.width) == unsafe{nil}
 assert cascaded.property_source_shadow_root(.width) == none
 cascaded.set_property(.width,first,.no,.user,'base',voidptr(source),shadow)
 cascaded.set_property(.width,second,.no,.author,'other',unsafe{nil},none)
 assert entry_array_test_entries(cascaded,PropertyID.width).len == 3
 for _ in 0 .. 3 {
  gc_collect()
  entries := entry_array_test_entries(cascaded,PropertyID.width)
  assert entries[0].origin == .author && entries[0].property.important == .yes
  assert entries[1].origin == .user && entries[1].source == voidptr(source)
  assert entries[1].source_shadow_root? == shadow
  assert entries[2].layer_name? == 'other'
 }
}
fn test_cascade_entry_arrays_handle_stored_empty_arrays_and_stale_presence_byte() {
 value := &dom.StyleValue{css_text:'10px'}
 next := &dom.StyleValue{css_text:'20px'}
 mut cascaded := CascadedProperties.new()
 cascaded.entry_heads_.set(.height, -1) // An explicitly empty stored history.
 cascaded.set_property(.height,value,.no,.author,none,unsafe{nil},none)
 assert cascaded.property(.height)? == value
 cascaded.entry_heads_.delete(PropertyID.height)
 assert cascaded.contained_properties_cache_[int(PropertyID.height)] == 1
 cascaded.set_property(.height,next,.no,.author,none,unsafe{nil},none)
 assert entry_array_test_entries(cascaded,PropertyID.height).len == 1
 assert cascaded.property(.height)? == next
 for index in 1 .. int(PropertyID.container)+1 {
  id := unsafe { PropertyID(index) }
  if id != .height { cascaded.set_property(id,value,.no,.author,none,unsafe{nil},none) }
 }
 gc_collect()
 assert cascaded.property(.height)? == next
 assert entry_array_test_entries(cascaded,PropertyID.height).len == 1
 assert cascaded.property(.height)?.css_text == '20px'
}
