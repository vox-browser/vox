module main

import browserjs
import dom
import html
import layout
import page

fn test_internals_wheel_dispatches_trusted_cancellable_input_and_obeys_axis_chaining() {
	url := dom.URL{ value: 'https://wheel-input.test/' }
	mut owner := page.Page.create(1)!
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_viewport_rect(dom.Rect{0, 0, 320, 200})
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>body{margin:0}#outer{width:120px;height:120px;overflow:auto}#inner{width:100px;height:100px;overflow:auto}#content{width:300px;height:300px}#after{height:500px}</style><div id="outer"><div id="inner"><div id="content"></div></div><div id="after"></div></div>')
	allocation.finish()
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [], runtime, mut messages)
	_ = layout.run_document_layout(document, 320, 200) or { panic('layout') }
	assert messages == []string{}
	outcome := runtime.evaluate_host(r'
(()=>{try{
const check=(actual,expected)=>{if(actual!==expected)throw new Error(actual+" != "+expected)};
let observed="",trusted=false;inner.addEventListener("wheel",event=>{observed=[event.isTrusted,event.constructor.name,event.deltaY,event instanceof WheelEvent].join("|");trusted=event.isTrusted&&event instanceof WheelEvent&&event.deltaY===50},{once:true});
internals.wheel(20,20,0,50);if(!trusted)throw new Error("wheel observer: "+observed);check(inner.scrollTop,50);check(outer.scrollTop,0);
inner.addEventListener("wheel",event=>event.preventDefault(),{once:true});internals.wheel(20,20,0,50);check(inner.scrollTop,50);
inner.scrollTop=200;inner.style.overscrollBehaviorY="contain";internals.wheel(20,20,0,50);check(inner.scrollTop,200);check(outer.scrollTop,0);
inner.style.overscrollBehaviorY="auto";internals.wheel(20,20,0,50);check(outer.scrollTop,50);
return "passed";
}catch(error){return String(error)+" "+error.stack}})()
')!
	if outcome != 'passed' {
		if event := owner.event_handler.last_wheel_event() {
			eprintln('last native wheel: target=${event.target} dy=${event.delta_y}')
		} else {
			eprintln('no native wheel dispatch')
		}
	}
	assert outcome == 'passed', outcome
}
