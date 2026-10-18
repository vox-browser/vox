module css

import dom

fn independent_query_append(parent &dom.Node, child &dom.Node) {
 mut mutable_parent := unsafe { &dom.Node(parent) }
 mutable_parent.append_child(child) or { panic(err) }
}

fn independent_query_compare(root &dom.Node, text string) {
 selectors := parse_query_selector_list(text) or { panic(text) }
 mut expected := []&dom.Element{}
 query_selector_all_in(root, selectors, mut expected)
 actual := query_selector_all(root, text)
 assert actual.len == expected.len, text
 for index, element in expected { assert voidptr(actual[index]) == voidptr(element), text }
 old_first := query_selector_first_in(root, selectors)
 new_first := query_selector(root, text)
 if first := old_first {
  assert voidptr(new_first or { panic('missing first: '+text) }) == voidptr(first), text
 } else { assert new_first == none, text }
}

fn test_independent_queries_preserve_namespace_case_attributes_and_group_order() {
 for html_document in [false, true] {
  for quirks in [false, true] {
   mut document := dom.Document.create(dom.url_about_blank())
   defer { document.finalize() }
   document.set_document_type(if html_document { dom.DocumentType_.html } else { dom.DocumentType_.xml })
   if quirks { document.set_quirks_mode(.yes) }
   mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
   independent_query_append(document.as_node(),root.as_node())
   for namespace in ['http://www.w3.org/1999/xhtml','http://www.w3.org/2000/svg',''] {
    mut element := document.create_element_ns(namespace, 'linearGradient')!
    element.set_attribute_value('id','TARGET')
    element.set_attribute_value('class','ITEM beta')
    element.set_attribute_value('data-label','Value two')
    element.set_attribute_value_ns('token', 'Name', 'q', 'urn:query')
    independent_query_append(root.as_node(),element.as_node())
   }
   for text in ['*','*|*','|*','linearGradient','lineargradient','*|linearGradient','|linearGradient','#TARGET','#target','.ITEM','.item','[id], [class]','[data-label="Value two"]','[data-label="value two" i]','[data-label~=two]','[data-label^=Value]','[data-label$=two]','[data-label*=lue]','[*|token]','[|token]','linearGradient.ITEM[data-label], #TARGET, *'] {
    selectors := (parse_query_selector_list(text) or { panic(text) })
    assert independent_query_compounds(selectors) != none, text
    independent_query_compare(root.as_node(),text)
   }
  }
 }
}

fn test_independent_queries_observe_live_mutations_and_exclude_shadow_descendants() {
 mut document := dom.Document.create(dom.url_about_blank())
 defer { document.finalize() }
 document.set_document_type(.html)
 mut root := document.create_element('main')!
 independent_query_append(document.as_node(),root.as_node())
 mut host := document.create_element('section')!
 host.set_attribute_value('class','target')
 independent_query_append(root.as_node(),host.as_node())
 shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open})!
 hidden := document.create_element('div')!
 independent_query_append(unsafe { &dom.Node(shadow) },hidden.as_node())
 mut visible := document.create_element('span')!
 independent_query_append(host.as_node(),visible.as_node())
 for _ in 0..3 {
  gc_collect()
  for text in ['*','.target','[data-x], .target','span, section'] { independent_query_compare(root.as_node(),text) }
  assert query_selector_all(root.as_node(),'*').len == 2
  visible.set_attribute_value('class','target')
  visible.set_attribute_value('data-x','present')
 }
 mut host_node := host.as_node()
 host_node.remove_child(visible.as_node())!
 independent_query_compare(root.as_node(),'.target, [data-x]')
 assert query_selector_all(root.as_node(),'*').len == 1
 independent_query_compare(unsafe { &dom.Node(shadow) },'div')
 assert query_selector_all(unsafe { &dom.Node(shadow) },'div').len == 1
}

fn test_independent_queries_leave_relations_and_pseudo_classes_to_full_matcher() {
 mut document := dom.Document.create(dom.url_about_blank())
 defer { document.finalize() }
 root := document.create_element('div')!
 independent_query_append(document.as_node(),root.as_node())
 first := document.create_element('span')!
 second := document.create_element('span')!
 independent_query_append(root.as_node(),first.as_node())
 independent_query_append(root.as_node(),second.as_node())
 for text in ['div > span','span + span','span ~ span',':scope > span','span:first-child','span:not(.missing)','span:is(.missing, span)','span, :last-child','div:has(span)'] {
  assert independent_query_compounds((parse_query_selector_list(text) or { panic(text) })) == none, text
  independent_query_compare(root.as_node(),text)
 }
}
