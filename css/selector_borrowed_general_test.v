module css

import dom

fn slow_borrow_selector(text string) Selector {
 list := parse_selector_with_parser(text, {'s': true}) or { panic(text) }
 return list.selectors[0]
}

fn slow_borrow_append(parent &dom.Element, child &dom.Element) {
 mut node := parent.as_node()
 node.append_child(child.as_node()) or { panic(err) }
}

fn slow_borrow_expect(selector Selector, element &dom.Element, sheet ?&CSSStyleSheet, expected bool) {
 assert !selector.can_use_fast_matches()
 serialized := selector.serialize()
 mut addresses := []voidptr{}
 for compound in selector.compound_selectors() { addresses << voidptr(compound.simple_selectors.data) }
 mut context := MatchContext{
  subject: unsafe { &dom.Element(element) }
  style_sheet_for_rule: unsafe { sheet }
  collect_per_element_selector_involvement_metadata: true
  has_result_cache: unsafe { nil }
 }
 assert matches(selector, element, none, mut context, none, none, .normal, none) == expected, serialized
 assert voidptr(context.subject or { panic('lost subject') }) == voidptr(element)
 assert context.part_owning_parent == none
 assert !context.for_host_part_matching
 assert selector.serialize() == serialized
 for index,compound in selector.compound_selectors() {
  assert voidptr(compound.simple_selectors.data) == addresses[index]
 }
}

fn test_borrowed_general_selector_records_preserve_components_and_context() {
 for quirks in [false,true] {
  mut document := dom.Document.create(dom.url_about_blank())
  defer { document.finalize() }
  document.set_document_type(.html)
  if quirks { document.set_quirks_mode(.yes) }
  mut parent := document.create_element('section') or { panic(err) }
  mut target := document.create_element('div') or { panic(err) }
  target.set_attribute_value('id','ITEM')
  target.set_attribute_value('class','TARGET other β')
  target.set_attribute_value('data-x','Value two')
  mut document_node := unsafe { &dom.Node(document) }
  document_node.append_child(parent.as_node()) or { panic(err) }
  slow_borrow_append(parent,target)
  for text,expected in {
   'div:is(*)':true,'span:is(*)':false,'*:is(div)':true,
   '#ITEM:is(*)':true,'#missing:is(*)':false,'.TARGET:is(*)':true,
   '.missing:is(*)':false,'.β:is(*)':true,'[data-x]:is(*)':true,
   '[missing]:is(*)':false,'[data-x="Value two"]:is(*)':true,
   '[data-x="value two" i]:is(*)':true,'[data-x~=two]:is(*)':true,
   '[data-x^=Value]:is(*)':true,'[data-x$=two]:is(*)':true,
   '[data-x*=lue]:is(*)':true,':is(.missing,.TARGET)':true,
   ':where(.TARGET)':true,':not(.missing)':true,':not(.TARGET)':false,
   ':is(.TARGET):first-child':true,':is(.TARGET):last-child':true,
  } { slow_borrow_expect(slow_borrow_selector(text),target,none,expected) }
  slow_borrow_expect(slow_borrow_selector('#item.target:is(*)'),target,none,quirks)
 }
}

fn test_borrowed_general_selectors_preserve_backtracking_relations_and_metadata() {
 mut document := dom.Document.create(dom.url_about_blank())
 defer { document.finalize() }
 mut root := document.create_element('section') or { panic(err) }
 root.set_attribute_value('class','group')
 mut first := document.create_element('div') or { panic(err) }
 first.set_attribute_value('class','first')
 mut target := document.create_element('div') or { panic(err) }
 target.set_attribute_value('class','target')
 mut flag := document.create_element('span') or { panic(err) }
 flag.set_attribute_value('class','flag')
 mut document_node := unsafe { &dom.Node(document) }
 document_node.append_child(root.as_node()) or { panic(err) }
 slow_borrow_append(root,first)
 slow_borrow_append(root,target)
 slow_borrow_append(target,flag)
 for text,expected in {
  '.group > .target:is(*)':true,'.group .target:not(.missing)':true,
  '.first + .target':true,'.first ~ .target':true,'.missing + .target':false,
  '.target:has(> .flag)':true,'.target:has(> .missing)':false,
  '.target:not(:has(> .missing))':true,
  '.target:nth-child(2)':true,'.target:nth-child(odd)':false,
  '.target:nth-last-child(1)':true,
  '.target:is(:not(.first)):has(.flag)':true,
 } { slow_borrow_expect(slow_borrow_selector(text),target,none,expected) }
 slow_borrow_expect(slow_borrow_selector('.group:has(> .target .flag)'),root,none,true)
 slow_borrow_expect(slow_borrow_selector('.group:has(> .missing)'),root,none,false)
 slow_borrow_expect(slow_borrow_selector('.target:nth-child(2) > .flag:is(*)'),flag,none,true)
 assert target.affected_by_structural_pseudo_class_in_non_subject_position
}

fn test_borrowed_general_selector_owners_survive_gc_and_live_attribute_changes() {
 mut document := dom.Document.create(dom.url_about_blank())
 defer { document.finalize() }
 mut target := document.create_element('div') or { panic(err) }
 target.set_attribute_value('class','target')
 mut document_node := unsafe { &dom.Node(document) }
 document_node.append_child(target.as_node()) or { panic(err) }
 mut owners := []Selector{}
 for text in ['.target:is([data-v=live])','.target:not([data-v=cold])'] { owners << slow_borrow_selector(text) }
 retained := owners[0]
 owners.clear()
 for _ in 0 .. 4 {
  target.set_attribute_value('data-v','live')
  gc_collect()
  slow_borrow_expect(retained,target,none,true)
  target.set_attribute_value('data-v','cold')
  gc_collect()
  slow_borrow_expect(retained,target,none,false)
  target.remove_attribute('data-v')
  slow_borrow_expect(retained,target,none,false)
 }
}

fn test_borrowed_general_selector_namespace_records_keep_their_sheet_owner() {
 mut document := dom.Document.create(dom.url_about_blank())
 defer { document.finalize() }
 document.set_document_type(.xml)
 mut element := document.create_element_ns('http://www.w3.org/2000/svg','svg') or { panic(err) }
 element.set_attribute_value('data-v','value')
 sheet := parse_css_stylesheet_with_parser('@namespace s "http://www.w3.org/2000/svg";',none)
 selector := slow_borrow_selector('s|svg:is([data-v=value])')
 for _ in 0 .. 3 {
  gc_collect()
  slow_borrow_expect(selector,element,sheet,true)
  slow_borrow_expect(selector,element,none,false)
 }
}
