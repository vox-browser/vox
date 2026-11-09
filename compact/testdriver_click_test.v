module main

import browserjs
import dom
import html
import page
import platform

fn check_native_testdriver_click(source string) ! {
	url := dom.URL{ value: 'https://native-testdriver.test/' }
	mut owner := page.Page.create(1)!
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>body{margin:0}input{margin:20px;width:40px;height:40px}</style><input id="field" type="checkbox">')
	allocation.finish()
	owner.set_local_root_navigable(document.navigable() or { return error('missing navigable') })!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [], runtime, mut messages)
	mut app := BrowserApp{ document: document, page_model: owner, js_runtime: runtime, viewport_width: 320, viewport_height: 200 }
	app.relayout(320, 284)
	assert messages == []string{}
	if !wpt_testdriver_enabled {
		assert runtime.evaluate_host('typeof internals.testDriverClick')! == 'undefined'
		return
	}
	assert runtime.evaluate_host(source)! == 'passed'
}

fn test_native_testdriver_click_is_opt_in_and_uses_platform_pointer_dispatch() {
	check_native_testdriver_click(r'
const target=document.getElementById("field"),events=[];
const rect=target.getBoundingClientRect(),x=rect.left+rect.width/2,y=rect.top+rect.height/2;
if(document.elementFromPoint(x,y)!==target)throw new Error("fixture hit "+JSON.stringify(rect.toJSON()));
for(const name of ["pointerdown","mousedown","pointerup","mouseup","click","input","change"])target.addEventListener(name,event=>{
 if(!event.isTrusted||event.target!==target)throw new Error("untrusted or wrong target");events.push(name);
});
HTMLElement.prototype.click=function(){throw new Error("DOM click shortcut")};
EventTarget.prototype.dispatchEvent=function(){throw new Error("DOM dispatch shortcut")};
internals.testDriverClick(target,x,y);
if(events.join(",")!=="pointerdown,mousedown,pointerup,mouseup,click,input,change"||target.checked!==true)throw new Error("native event order or activation "+events+":"+target.checked);
let rejected=false;try{internals.testDriverClick(target,300,180)}catch(error){rejected=true}
if(!rejected||!target.checked)throw new Error("intercepted click accepted");
for(const args of [[{},30,30],[target,NaN,30],[target,30,Infinity]]){let bad=false;try{internals.testDriverClick(...args)}catch(error){bad=error instanceof TypeError}if(!bad)throw new Error("invalid click accepted")}
"passed"
')!
}

fn test_native_testdriver_vendor_backend_preserves_cancellation_and_returns_a_promise() {
	vendor := platform.embedded_text($embed_file('@VMODROOT/tools/wpt_testdriver_vendor.js'))
	check_native_testdriver_click('globalThis.test_driver_internal={in_automation:false};' + vendor + r'
const target=document.getElementById("field");let clicks=0;
const rect=target.getBoundingClientRect(),x=rect.left+rect.width/2,y=rect.top+rect.height/2;
target.addEventListener("click",event=>{if(!event.isTrusted)throw new Error("untrusted backend");clicks++;event.preventDefault()});
const result=test_driver_internal.click(target,{x,y});
if(!(result instanceof Promise)||!test_driver_internal.in_automation||clicks!==1||target.checked)throw new Error("vendor promise or cancelled activation");
"passed"
')!
}
