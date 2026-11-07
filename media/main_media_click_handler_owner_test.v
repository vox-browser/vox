module main

import browserjs
import dom
import page
import time

fn media_click_handler_document(markup string, address string) !(&page.Page, &dom.Document) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn media_click_handler_release(mut owner page.Page, target &dom.Element) {
	input := page.InputTarget.from_node(target.as_node())
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
}

fn media_click_handler_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn test_media_onclick_uses_one_trusted_page_slot_for_parsed_and_created_owners_and_cancels() {
	$if !darwin {
		return
	}
	mut owner, mut document := media_click_handler_document('<video id="video"></video><div id="result">waiting</div>',
		'https://media-click-handler-order.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.clickAudio=document.createElement("audio");clickAudio.id="click-audio";',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'(()=>{const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"onclick");return !!d&&typeof d.get==="function"&&typeof d.set==="function"&&video.onclick===null&&clickAudio.onclick===null})()')! == 'true'
	assert document.get_element_by_id('click-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('clickAudio')!)!
	runtime.evaluate_host(r'
globalThis.clickHandlerOrder=[];globalThis.clickHandlerChecks=[];globalThis.clickHandlerSaved=[];globalThis.cancelClickHandler=false;
for(const [name,player] of [["video",video],["audio",clickAudio]]){
 player.addEventListener("click",function(event){clickHandlerOrder.push(name+":before");clickHandlerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&window.event===event)});
 player.onclick=function(event){clickHandlerOrder.push(name+":handler");clickHandlerSaved.push(event);clickHandlerChecks.push(arguments.length===1&&this===player&&event.target===player&&event.currentTarget===player&&event instanceof Event&&event.isTrusted&&event.bubbles&&event.cancelable&&window.event===event);result.textContent=clickHandlerOrder.join(",");if(cancelClickHandler)return false};
 player.addEventListener("click",function(event){clickHandlerOrder.push(name+":after");clickHandlerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&window.event===event);result.textContent=clickHandlerOrder.join(",")});
}
document.body.appendChild(clickAudio);void clickAudio.paused;
')!
	assert voidptr(document.get_element_by_id('click-audio')?) == voidptr(created_target)
	mut app := media_click_handler_app(owner, document, runtime)
	for index, id in ['video', 'click-audio'] {
		target := document.get_element_by_id(id)?
		media_click_handler_release(mut owner, target)
		assert owner.event_handler.last_click_allowed()
		assert runtime.evaluate_host('clickHandlerOrder.length')! == ((index + 1) * 3).str()
		assert !app.dispatch_javascript_event('click', target)
		assert runtime.evaluate_host('clickHandlerOrder.length')! == ((index + 1) * 3).str()
	}
	assert runtime.evaluate_host(r'clickHandlerOrder.join(",")==="video:before,video:handler,video:after,audio:before,audio:handler,audio:after"&&clickHandlerChecks.length===6&&clickHandlerChecks.every(Boolean)&&clickHandlerSaved.every(event=>event.currentTarget===null&&!event.defaultPrevented)&&window.event===undefined')! == 'true'
	assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('clickHandlerOrder.join(",")')!
	runtime.evaluate_host('cancelClickHandler=true')!
	video := document.get_element_by_id('video')?
	media_click_handler_release(mut owner, video)
	assert !owner.event_handler.last_click_allowed()
	assert runtime.evaluate_host('clickHandlerOrder.length===9&&clickHandlerSaved.length===3&&clickHandlerSaved[2].defaultPrevented&&clickHandlerSaved[2].currentTarget===null&&clickHandlerChecks.every(Boolean)&&window.event===undefined')! == 'true'
	app.poll_javascript_tasks()
	// The browser normally skips replay for the canceled click. Calling its
	// helper explicitly must still leave the actual native delivery single.
	assert !app.dispatch_javascript_event('click', video)
	assert runtime.evaluate_host('clickHandlerOrder.length===9')! == 'true'
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_media_onclick_self_replacement_null_and_noncallable_objects_do_not_replay_retained_raw() {
	$if !darwin {
		return
	}
	raw_source := 'globalThis.staleClickRawRuns++'
	mut owner, mut document := media_click_handler_document('<video id="video" onclick="${raw_source}"></video>',
		'https://media-click-handler-replacement.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.staleClickRawRuns=0;',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'(()=>{const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"onclick");return !!d&&typeof d.get==="function"&&typeof d.set==="function"&&video.onclick===null})()')! == 'true'
	runtime.evaluate_host(r'
globalThis.selfClickOrder=[];globalThis.selfClickChecks=[];globalThis.noncallableClickReads=0;
globalThis.selfClickReplacement=function(event){selfClickOrder.push("replacement");selfClickChecks.push(this===video&&event.isTrusted&&window.event===event);this.onclick=null};
globalThis.selfClickFirst=function(event){selfClickOrder.push("first");selfClickChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event.isTrusted&&window.event===event);this.onclick=selfClickReplacement};video.onclick=selfClickFirst;
')!
	video := document.get_element_by_id('video')?
	mut app := media_click_handler_app(owner, document, runtime)
	media_click_handler_release(mut owner, video)
	assert runtime.evaluate_host('selfClickOrder.join(",")==="first"&&video.onclick===selfClickReplacement')! == 'true'
	assert !app.dispatch_javascript_event('click', video)
	media_click_handler_release(mut owner, video)
	assert runtime.evaluate_host('selfClickOrder.join(",")==="first,replacement"&&video.onclick===null')! == 'true'
	assert !app.dispatch_javascript_event('click', video)
	media_click_handler_release(mut owner, video)
	assert !app.dispatch_javascript_event('click', video)
	runtime.evaluate_host(r'globalThis.noncallableClickHandler=new Proxy({}, {get:function(){noncallableClickReads++;throw new Error("must not read noncallable handler")}});video.onclick=function(event){selfClickOrder.push("object");selfClickChecks.push(this===video&&event.isTrusted&&window.event===event);this.onclick=noncallableClickHandler};0')!
	media_click_handler_release(mut owner, video)
	assert runtime.evaluate_host('video.onclick===noncallableClickHandler&&selfClickOrder.join(",")==="first,replacement,object"')! == 'true'
	assert !app.dispatch_javascript_event('click', video)
	media_click_handler_release(mut owner, video)
	assert !app.dispatch_javascript_event('click', video)
	assert runtime.evaluate_host('noncallableClickReads===0&&staleClickRawRuns===0&&selfClickOrder.length===3&&selfClickChecks.every(Boolean)&&window.event===undefined')! == 'true'
	for expression in ['undefined', 'false', '0', '"text"'] {
		assert runtime.evaluate_host('video.onclick=${expression};video.onclick===null')! == 'true'
		media_click_handler_release(mut owner, video)
		assert !app.dispatch_javascript_event('click', video)
	}
	assert video.get_attribute('onclick')? == raw_source
	assert runtime.evaluate_host('staleClickRawRuns===0&&selfClickOrder.length===3')! == 'true'
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_media_onclick_self_raw_attribute_replacement_waits_for_next_click_and_removal_clears_fallback() {
	$if !darwin {
		return
	}
	old_source := 'globalThis.oldClickRawRuns++'
	new_source := 'globalThis.newClickRawRuns++'
	mut owner, mut document := media_click_handler_document('<video id="video" onclick="${old_source}"></video>',
		'https://media-click-handler-raw-mutation.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.oldClickRawRuns=0;globalThis.newClickRawRuns=0;globalThis.nativeRawReplacementRuns=0;',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'(()=>{const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"onclick");return !!d&&typeof d.get==="function"&&typeof d.set==="function"&&video.onclick===null})()')! == 'true'
	runtime.evaluate_host(r'video.onclick=function(event){nativeRawReplacementRuns++;globalThis.nativeRawReplacementValid=this===video&&event.target===video&&event.currentTarget===video&&event.isTrusted&&window.event===event;this.onclick=null;this.setAttribute("onclick","globalThis.newClickRawRuns++");void this.paused};0')!
	video := document.get_element_by_id('video')?
	native_target := runtime.native_event_target(runtime.evaluate_host_value('video')!)!
	original_handler := native_target.data.event_handler('click') or {
		assert false, 'missing native click handler'
		return
	}
	mut app := media_click_handler_app(owner, document, runtime)
	media_click_handler_release(mut owner, video)
	assert owner.event_handler.last_click_allowed()
	assert runtime.evaluate_host('nativeRawReplacementRuns===1&&nativeRawReplacementValid&&oldClickRawRuns===0&&newClickRawRuns===0&&video.onclick===null&&window.event===undefined')! == 'true'
	raw_handler := native_target.data.event_handler('click') or {
		assert false, 'missing replacement raw click handler'
		return
	}
	assert voidptr(raw_handler) != voidptr(original_handler)
	assert raw_handler.value.kind == .string && raw_handler.value.string_data == new_source
	assert video.get_attribute('onclick')? == new_source
	// The final native map is raw, but this actual click already processed the
	// prior IDL handler. Neither cached nor replacement raw text may run again.
	assert !app.dispatch_javascript_event('click', video)
	assert runtime.evaluate_host('nativeRawReplacementRuns===1&&oldClickRawRuns===0&&newClickRawRuns===0')! == 'true'
	media_click_handler_release(mut owner, video)
	assert runtime.evaluate_host('newClickRawRuns===0')! == 'true'
	assert !app.dispatch_javascript_event('click', video)
	assert runtime.evaluate_host('nativeRawReplacementRuns===1&&oldClickRawRuns===0&&newClickRawRuns===1')! == 'true'
	runtime.evaluate_host('video.removeAttribute("onclick");void video.paused')!
	assert video.get_attribute('onclick') == none
	assert !native_target.data.has_event_handler('click')
	media_click_handler_release(mut owner, video)
	assert !app.dispatch_javascript_event('click', video)
	assert runtime.evaluate_host('nativeRawReplacementRuns===1&&oldClickRawRuns===0&&newClickRawRuns===1')! == 'true'
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_untouched_media_raw_click_fallback_hands_off_to_idl_and_generic_compact_clicks_stay_single() {
	$if !darwin {
		return
	}
	raw_source := 'globalThis.rawMediaClickRuns++'
	markup := '<video id="raw" onclick="${raw_source}"></video><img id="image" onclick="genericRawClicks.push(this.id)"><object id="object" onclick="genericRawClicks.push(this.id)"></object><svg id="vector" onclick="genericRawClicks.push(this.id)"></svg>'
	mut owner, mut document := media_click_handler_document(markup,
		'https://media-click-handler-legacy.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.rawMediaClickRuns=0;globalThis.assignedMediaClickRuns=0;globalThis.genericRawClicks=[];globalThis.genericListenerClicks=[];globalThis.genericClickChecks=[];for(const target of [image,object,vector])target.addEventListener("click",function(event){genericListenerClicks.push(this.id);genericClickChecks.push(this===target&&event.target===target&&event.type==="click")});',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'(()=>{const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"onclick");return !!d&&typeof d.get==="function"&&typeof d.set==="function"&&raw.onclick===null})()')! == 'true'
	raw := document.get_element_by_id('raw')?
	native_target := runtime.native_event_target(runtime.evaluate_host_value('raw')!)!
	raw_handler := native_target.data.event_handler('click') or {
		assert false, 'missing untouched raw click handler'
		return
	}
	assert raw_handler.value.kind == .string
	mut app := media_click_handler_app(owner, document, runtime)
	media_click_handler_release(mut owner, raw)
	assert runtime.evaluate_host('rawMediaClickRuns===0')! == 'true'
	assert !app.dispatch_javascript_event('click', raw)
	assert runtime.evaluate_host('rawMediaClickRuns===1&&raw.onclick===null')! == 'true'
	assert raw_handler.value.kind == .string && raw_handler.value.string_data == raw_source
	owner.set_is_scripting_enabled(false)
	media_click_handler_release(mut owner, raw)
	assert !app.dispatch_javascript_event('click', raw)
	assert runtime.evaluate_host('rawMediaClickRuns===1')! == 'true'
	assert raw_handler.value.kind == .string && raw_handler.value.string_data == raw_source
	owner.set_is_scripting_enabled(true)
	runtime.evaluate_host(r'globalThis.assignedMediaClickHandler=function(event){assignedMediaClickRuns++;globalThis.assignedMediaClickValid=this===raw&&event.target===raw&&event.currentTarget===raw&&event instanceof Event&&event.isTrusted&&window.event===event};raw.onclick=assignedMediaClickHandler;0')!
	assigned_handler := native_target.data.event_handler('click') or {
		assert false, 'missing assigned click handler'
		return
	}
	assert voidptr(assigned_handler) == voidptr(raw_handler)
	assert assigned_handler.value.kind == .object
	media_click_handler_release(mut owner, raw)
	assert !app.dispatch_javascript_event('click', raw)
	assert runtime.evaluate_host('rawMediaClickRuns===1&&assignedMediaClickRuns===1&&assignedMediaClickValid&&raw.onclick===assignedMediaClickHandler&&window.event===undefined')! == 'true'
	assert raw.get_attribute('onclick')? == raw_source
	assert runtime.evaluate_host('raw.onclick=null;raw.onclick===null')! == 'true'
	media_click_handler_release(mut owner, raw)
	assert !app.dispatch_javascript_event('click', raw)
	assert runtime.evaluate_host('rawMediaClickRuns===1&&assignedMediaClickRuns===1')! == 'true'
	for index, id in ['image', 'object', 'vector'] {
		target := document.get_element_by_id(id)?
		media_click_handler_release(mut owner, target)
		assert owner.event_handler.last_click_allowed()
		assert runtime.evaluate_host('genericRawClicks.length')! == index.str()
		assert !app.dispatch_javascript_event('click', target)
		assert runtime.evaluate_host('genericRawClicks.length')! == (index + 1).str()
	}
	assert runtime.evaluate_host('genericRawClicks.join(",")==="image,object,vector"&&genericListenerClicks.join(",")==="image,object,vector"&&genericClickChecks.every(Boolean)&&rawMediaClickRuns===1&&assignedMediaClickRuns===1')! == 'true'
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}
