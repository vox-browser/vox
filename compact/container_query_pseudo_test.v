module main

import browserjs
import dom

fn test_boxless_pseudo_custom_properties_follow_scroll_state_queries() {
 mut document := parse_browser_navigation_document('<!doctype html><style>#scroller{container-type:scroll-state;overflow:auto;width:100px;height:100px}#target{width:10px;height:10px;--match:no}#target.large{width:200px;height:200px}@container scroll-state(scrollable){#target::after{--match:yes}}</style><div id="scroller"><div id="target"></div></div>',dom.URL{value:'https://pseudo-query.test/'},none)
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,document.url.serialize(),[r'globalThis.readMatch=()=>getComputedStyle(document.getElementById("target"),"::after").getPropertyValue("--match");'],runtime,mut messages)
 assert messages == []string{},messages.str()
 assert runtime.evaluate_host('readMatch()')! == 'no'
 mut target := document.get_element_by_id('target') or { panic('target') }
 target.set_attribute_value('class','large')
 document.update_layout(.debugging)
 _ = document.snapshot_scroll_state_queries(false)
 document.update_layout(.debugging)
 assert runtime.evaluate_host('readMatch()')! == 'yes'
}
