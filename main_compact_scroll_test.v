module main

import browserjs
import dom
import html
import layout
import platform
import time

fn test_compact_scroll_metrics_and_writes_use_live_native_css_pixel_geometry() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{overflow:auto;width:100px;height:50px}#inside{width:300px;height:200px;background:red}</style><div id="scroller"><div id="inside"></div></div><svg id="vector"></svg>')
	document.set_viewport_rect(dom.Rect{ width: 320, height: 240 })
	document.set_layout_coordinate_scale(2)
	_ = layout.run_document_layout(document, 320, 240) or { panic('missing initial layout') }
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
if(scroller.scrollWidth!==300||scroller.scrollHeight!==200||scroller.scrollTop!==0||scroller.scrollLeft!==0)throw new Error("native scroll metrics");
for(const element of [document.documentElement,document.body,vector,document.createElement("div")]){
 for(const name of ["scrollTop","scrollLeft","scrollWidth","scrollHeight"])if(!Number.isFinite(element[name]))throw new Error("missing Element scroll metric");
}
const rect=scroller.getBoundingClientRect(),x=rect.left+(document.documentElement.scrollLeft||document.body.scrollLeft)+rect.width/2,y=rect.top+(document.documentElement.scrollTop||document.body.scrollTop)+rect.height/2;
if(!Number.isFinite(x)||!Number.isFinite(y)||!scroller.contains(document.elementFromPoint(x,y)))throw new Error("popup target coordinates");
scroller.scrollLeft="25.5";scroller.scrollTop={valueOf(){return 30.25;}};
if(scroller.scrollLeft!==25.5||scroller.scrollTop!==30.25||inside.getBoundingClientRect().x!==-25.5||inside.getBoundingClientRect().y!==-30.25)throw new Error("native scroll position");
scroller.scrollLeft=10000;scroller.scrollTop=10000;
if(scroller.scrollLeft!==200||scroller.scrollTop!==150)throw new Error("scroll bounds");
scroller.scrollLeft=-1;scroller.scrollTop=-1;
if(scroller.scrollLeft!==0||scroller.scrollTop!==0)throw new Error("negative bounds");
inside.style.width="350px";inside.style.height="250px";
if(scroller.scrollWidth!==350||scroller.scrollHeight!==250)throw new Error("pending style extent");
scroller.scrollTop=10000;if(scroller.scrollTop!==200)throw new Error("pending style scroll clamp");
for(const value of [NaN,Infinity,-Infinity,undefined,null]){
 scroller.scrollLeft=10;scroller.scrollTop=10;scroller.scrollLeft=value;scroller.scrollTop=value;
 if(scroller.scrollLeft!==0||scroller.scrollTop!==0)throw new Error("nonfinite normalization");
}
console.log("scroll metrics passed");
'], runtime, mut messages)
	assert messages == ['scroll metrics passed']
	mut scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	scroller.set_scroll_top(27)
	assert runtime.evaluate_host('scroller.scrollTop')! == '27'
}

fn test_compact_scroll_accessors_validate_element_brand_before_numeric_conversion() {
	mut document := html.parse_document('<!doctype html><div id="scroller" style="overflow:auto;width:100px;height:50px"><div style="width:300px;height:200px"></div></div>')
	document.set_viewport_rect(dom.Rect{ width: 320, height: 240 })
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
function typeError(callback){let threw=false;try{callback()}catch(error){threw=error instanceof TypeError}if(!threw)throw new Error("expected TypeError");}
let conversions=0,traps=0;
const number={valueOf(){conversions++;return 12;}},proxy=new Proxy(scroller,{get(){traps++;throw new Error("proxy get")},getPrototypeOf(){traps++;throw new Error("proxy prototype")}});
for(const name of ["scrollTop","scrollLeft","scrollWidth","scrollHeight"]){
 const descriptor=Object.getOwnPropertyDescriptor(scroller,name);
 if(!descriptor.enumerable||!descriptor.configurable||typeof descriptor.get!=="function")throw new Error("scroll descriptor");
 for(const receiver of [undefined,null,{},Object.create(scroller),proxy]){
  typeError(()=>descriptor.get.call(receiver));
  if(descriptor.set)typeError(()=>descriptor.set.call(receiver,number));
 }
 if(name==="scrollWidth"||name==="scrollHeight"){
  if(descriptor.set!==undefined)throw new Error("read-only extent");
 }else{
  if(typeof descriptor.set!=="function")throw new Error("missing setter");
  typeError(()=>descriptor.set.call(scroller,Symbol()));typeError(()=>descriptor.set.call(scroller,1n));
 }
}
if(conversions||traps)throw new Error("brand precedes conversion");
scroller.scrollTop=number;if(conversions!==1||scroller.scrollTop!==12)throw new Error("numeric conversion");
console.log("scroll conversion passed");
'], runtime, mut messages)
	assert messages == ['scroll conversion passed']
}

fn test_compact_scroll_timer_updates_native_paint_without_replaying_an_expando() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{overflow:auto;width:100px;height:50px}#inside{width:300px;height:200px;background:red}</style><div id="scroller"><div id="inside"></div></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	mut app := &BrowserApp{ document: document, js_runtime: runtime }
	app.relayout(320, 312)
	runtime.take_document_state_dirty()
	runtime.take_document_replay_effects()
	assert runtime.evaluate_host('scroller.scrollTop')! == '0'
	assert !runtime.take_document_state_dirty()
	assert !runtime.take_document_replay_effects()
	paint := app.paint_display_list
	runtime.evaluate_host('globalThis.scrollTimerDone=false;setTimeout(()=>{scroller.scrollTop=30;scroller.scrollLeft=25;scrollTimerDone=true;},1)')!
	deadline := time.sys_mono_now() + 2_000_000_000
	for runtime.evaluate_host('scrollTimerDone')! != 'true' && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.005)
	}
	assert runtime.evaluate_host('scrollTimerDone')! == 'true'
	app.poll_javascript_tasks()
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	assert scroller.el_scroll_offset() == dom.CSSPixelPoint_{25, 30}
	inside := document.get_element_by_id('inside') or { panic('missing inside') }
	assert inside.get_bounding_client_rect().x == -25
	assert inside.get_bounding_client_rect().y == -30
	assert voidptr(app.paint_display_list) != voidptr(paint)
}
