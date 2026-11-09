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

fn test_unconditional_pseudo_container_units_recompute_the_origin_after_layout() {
 mut document := parse_browser_navigation_document('<!doctype html><style>#outer{width:400px;container-type:inline-size}#target{width:200px;container-type:inline-size}#target::before{content:"Text";font-size:10cqw}#target::after{font-size:10cqw}#plain::before{content:normal}</style><div id="outer"><div id="target"></div><div id="plain"></div></div>',dom.URL{value:'https://pseudo-units.test/'},none)
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,document.url.serialize(),[r'for(const name of ["::before","::after"]){const value=getComputedStyle(target,name).fontSize;if(value!=="20px")throw new Error(name+" "+value);}if(getComputedStyle(plain,"::before").content!=="none")throw new Error("content normal");target.style.width="300px";if(getComputedStyle(target,"::before").fontSize!=="30px")throw new Error("resize");globalThis.pseudoUnitsPassed=true;'],runtime,mut messages)
 assert messages == []string{},messages.str()
 assert runtime.evaluate_host('pseudoUnitsPassed')! == 'true'
}

fn test_pseudo_content_tracks_query_creation_and_removal() {
 mut document := parse_browser_navigation_document('<!doctype html><style>#container{container-type:size;width:200px;height:40px}@container(min-width:300px){#target::before{content:"before"}#target::after{content:"after"}}</style><main id="container"><div id="target">test</div></main>',dom.URL{value:'https://pseudo-content.test/'},none)
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,document.url.serialize(),[r'for(const width of ["200px","300px","200px"]){container.style.width=width;for(const name of ["before","after"]){const value=getComputedStyle(target,"::"+name).content,expected=width==="300px"?JSON.stringify(name):"none";if(value!==expected)throw new Error(width+" "+name+" got "+JSON.stringify(value));}}globalThis.pseudoContentPassed=true;'],runtime,mut messages)
 assert messages == []string{},messages.str()
 assert runtime.evaluate_host('pseudoContentPassed')! == 'true'
}

fn test_pseudo_container_units_survive_sibling_pseudo_queries_and_closed_dialog() {
 mut document := parse_browser_navigation_document('<!doctype html><style>.container{container-type:inline-size}#target{display:list-item}#target::before{content:"PASS";font-size:10cqw}#target::after{font-size:10cqw}#target::marker{font-size:10cqw}#target::first-line{font-size:10cqw}#target::first-letter{font-size:10cqw}dialog::backdrop{font-size:10cqw}</style><div style="width:400px" class="container"><div style="width:300px" class="container"><div id="target" class="container" style="width:200px">First-line</div><dialog id="dialog" class="container" style="width:100px"></dialog></div></div>',dom.URL{value:'https://pseudo-siblings.test/'},none)
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,document.url.serialize(),[r'for(const name of ["::before","::after","::marker","::first-line","::first-letter"]){const value=getComputedStyle(target,name).fontSize;if(value!=="20px")throw new Error(name+" "+value);}if(getComputedStyle(dialog,"::backdrop").fontSize!=="30px")throw new Error("closed backdrop "+getComputedStyle(dialog,"::backdrop").fontSize);dialog.showModal();if(getComputedStyle(dialog,"::backdrop").fontSize!=="10px")throw new Error("modal backdrop");globalThis.pseudoSiblingsPassed=true;'],runtime,mut messages)
 assert messages == []string{},messages.str()
 assert runtime.evaluate_host('pseudoSiblingsPassed')! == 'true'
}
