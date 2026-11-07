module main

import browserjs
import html
import layout

fn test_compact_scroll_into_view_scrolls_the_nearest_scroller() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:100px;height:50px;overflow:hidden}#before{height:200px}#target{height:20px}#after{height:200px}</style><div id="scroller"><div id="before"></div><div id="target"></div><div id="after"></div></div>')
	_ = html.WindowModel.create_top_level(document, none, 'compact-scroll-into-view')!
	_ = layout.layout_document_typed_in_viewport(document, 320, 240)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
if(typeof target.scrollIntoView!=="function")fail("scrollIntoView missing");
target.scrollIntoView();
if(scroller.scrollTop!==200)fail("start alignment "+scroller.scrollTop);
target.scrollIntoView(false);
if(scroller.scrollTop!==170)fail("end alignment "+scroller.scrollTop);
target.scrollIntoView({block:"center",behavior:"instant"});
if(scroller.scrollTop!==185)fail("center alignment "+scroller.scrollTop);
const rejected=target.scrollIntoView({block:"middle"});
if(!(rejected instanceof Promise))fail("invalid options promise");
console.log("scrollIntoView passed");
'], runtime, mut messages)
	assert messages == ['scrollIntoView passed']
}
