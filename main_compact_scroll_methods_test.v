module main

import browserjs
import html
import layout
import platform
import time

fn test_compact_scroll_methods_share_native_window_and_element_scrolling() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}body{width:700px;height:700px}#scroller{width:100px;height:50px;overflow:hidden}#inside{width:300px;height:200px}</style><div id="scroller"><div id="inside"></div></div>')
	mut window := html.WindowModel.create_top_level(document, none, 'compact-scroll-methods')!
	_ = layout.layout_document_typed_in_viewport(document, 320, 240)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
window.scrollTo({left:20,top:30,behavior:"instant"});if(scrollX!==20||scrollY!==30)throw new Error("window scrollTo");
window.scrollBy(5,7);if(scrollX!==25||scrollY!==37)throw new Error("relative window scroll");
window.scroll({top:40});if(scrollX!==25||scrollY!==40)throw new Error("omitted horizontal position");
scroller.scrollTo(25,30);if(scroller.scrollLeft!==25||scroller.scrollTop!==30)throw new Error("element scrollTo");
scroller.scrollBy({left:5,top:7});if(scroller.scrollLeft!==30||scroller.scrollTop!==37)throw new Error("relative element scroll");
scroller.scroll({top:40});if(scroller.scrollLeft!==30||scroller.scrollTop!==40)throw new Error("omitted element position");
inside.style.width="400px";scroller.scrollTo({left:10000});if(scroller.scrollLeft!==300)throw new Error("scroll flushes pending styles");
scroller.scrollTo(NaN,Infinity);if(scroller.scrollLeft!==0||scroller.scrollTop!==0)throw new Error("nonfinite scroll normalization");
document.documentElement.style.scrollBehavior="smooth";document.documentElement.scrollTo({left:40,top:50,behavior:"instant"});if(scrollX!==40||scrollY!==50)throw new Error("root explicit instant behavior");
console.log("native scroll methods passed");
'], runtime, mut messages)
	assert messages == ['native scroll methods passed']
	assert window.scroll_x() == 40 && window.scroll_y() == 50
}

fn test_compact_scroll_methods_validate_brands_and_order_dictionary_conversion() {
	document := html.parse_document('<!doctype html><div id="scroller"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.scrollExpectedRejections=0;globalThis.scrollObservedRejections=0;globalThis.scrollPromiseFailures=[];
function typeError(fn){const promise=fn();if(!(promise instanceof Promise))throw new Error("expected rejected Promise");scrollExpectedRejections++;promise.then(()=>scrollPromiseFailures.push("unexpected fulfillment"),error=>{scrollObservedRejections++;if(!(error instanceof TypeError))scrollPromiseFailures.push("wrong rejection")})}
let calls=0;const value={get behavior(){calls++;return "instant"}},proxy=new Proxy(scroller,{get(){throw new Error("proxy trap")},getPrototypeOf(){throw new Error("prototype trap")}});
for(const target of [window,scroller])for(const name of ["scroll","scrollTo","scrollBy"]){
 const method=target[name];if(method.name!==name||method.length!==0)throw new Error("scroll function metadata");
 for(const receiver of [{},Object.create(target),proxy])typeError(()=>method.call(receiver,value));
 for(const bad of [1,"options",false,Symbol(),1n])typeError(()=>method.call(target,bad));
 typeError(()=>method.call(target,{behavior:"invalid"}));typeError(()=>method.call(target,{behavior:Symbol()}));typeError(()=>method.call(target,Symbol(),0));typeError(()=>method.call(target,0,1n));
 const promises=[method.call(target),method.call(target,null),method.call(target,undefined)];for(const promise of promises)if(!(promise instanceof Promise))throw new Error("scroll returns Promise");if(new Set(promises).size!==3)throw new Error("fresh operation promises");
}
if(calls)throw new Error("receiver checks precede dictionary conversion");
const order=[];scroller.scrollTo({get behavior(){order.push("behavior");return "instant"},get left(){order.push("left");return {valueOf(){order.push("left number");return 1}}},get top(){order.push("top");return {valueOf(){order.push("top number");return 2}}}});
if(order.join()!=="behavior,left,left number,top,top number")throw new Error("dictionary member conversion order");
globalThis.scrollOriginalReason={reason:"getter"};globalThis.scrollReasonPreserved=false;scroller.scrollTo({get top(){throw scrollOriginalReason}}).catch(error=>scrollReasonPreserved=error===scrollOriginalReason);
console.log("scroll method conversions passed");
'], runtime, mut messages)
	assert messages == ['scroll method conversions passed']
	html.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('scrollObservedRejections===scrollExpectedRejections&&scrollPromiseFailures.length===0&&scrollReasonPreserved')! == 'true'
}

fn test_compact_smooth_scroll_promise_settles_after_the_native_operation() {
	document := html.parse_document('<!doctype html><style>#scroller{width:100px;height:50px;overflow:hidden}#inside{height:300px}</style><div id="scroller"><div id="inside"></div></div>')
	window := html.WindowModel.create_top_level(document, none, 'scroll-promise')!
	_ = layout.layout_document_typed_in_viewport(document, 320, 240)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'globalThis.scrollSettled=false;globalThis.scrollRejection="";globalThis.scrollCompletion=scroller.scrollTo({top:120,behavior:"smooth"});scrollCompletion.then(value=>{if(!value||value.interrupted!==false)throw new Error("scroll fulfillment value");scrollSettled=true;},error=>scrollRejection=String(error));'], runtime, mut messages)
	assert messages == []string{}
	html.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('scrollCompletion instanceof Promise&&!scrollSettled')! == 'true'
	mut model := window.navigable_model()
	deadline := time.sys_mono_now() + 3_000_000_000
	for runtime.evaluate_host('scrollSettled')! != 'true' && time.sys_mono_now() < deadline {
		model.process_main_thread_smooth_scrolls()
		html.perform_a_microtask_checkpoint()
		platform.pump_native_events(0.005)
	}
	state := runtime.evaluate_host('JSON.stringify({settled:scrollSettled,top:scroller.scrollTop})')!
	assert state == '{"settled":true,"top":120}', state + ' reason=' + runtime.evaluate_host('scrollRejection')!
}

fn test_compact_scroll_replacement_reports_interrupted_completion() {
	document := html.parse_document('<!doctype html><style>#scroller{width:100px;height:50px;overflow:hidden}#inside{height:300px}</style><div id="scroller"><div id="inside"></div></div>')
	_ = html.WindowModel.create_top_level(document, none, 'scroll-interruption')!
	_ = layout.layout_document_typed_in_viewport(document, 320, 240)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'globalThis.scrollResults=[];scroller.scrollTo({top:120,behavior:"smooth"}).then(result=>scrollResults.push(["old",result.interrupted]));scroller.scrollTo({top:30,behavior:"instant"}).then(result=>scrollResults.push(["new",result.interrupted]));'], runtime, mut messages)
	assert messages == []string{}
	html.perform_a_microtask_checkpoint()
	result := runtime.evaluate_host('JSON.stringify(scrollResults)')!
	assert runtime.evaluate_host('scrollResults.length===2&&scrollResults.some(x=>x[0]==="old"&&x[1]===true)&&scrollResults.some(x=>x[0]==="new"&&x[1]===false)')! == 'true', result
}
