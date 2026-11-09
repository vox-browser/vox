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

fn test_pseudo_font_container_units_follow_the_originating_container() {
 mut document := parse_browser_navigation_document('<!doctype html><style>#outer{width:400px;container-type:inline-size}#target{width:200px;container-type:inline-size}@container (max-width:200px){#target::before{content:"Text";font-size:10cqw}#target::after{font-size:10cqw}}</style><div id="outer"><div id="target"></div></div>',dom.URL{value:'https://pseudo-font.test/'},none)
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,document.url.serialize(),[r'for(const name of ["::before","::after"]){const value=getComputedStyle(target,name).fontSize;if(value!=="20px")throw new Error(name+" "+value);}globalThis.pseudoFontPassed=true;'],runtime,mut messages)
 assert messages == []string{},messages.str()
 assert runtime.evaluate_host('pseudoFontPassed')! == 'true'
}
