module main

import browserjs
import dom
import html
import page
import time

fn media_auxiliary_handler_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn media_auxiliary_handler_release(mut owner page.Page, target &dom.Element, button u32, click_count int) {
	input := page.InputTarget.from_node(target.as_node())
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, button,
		browser_pointer_button_mask(int(button)), 0, click_count) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, button, 0, 0) == .handled
}

fn media_auxiliary_handler_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn media_auxiliary_handler_guard(runtime &browserjs.Runtime) !bool {
	// The parent compiles this fixture but fails here before assigning an own
	// property could conceal a missing native descriptor.
	return runtime.evaluate_host(r'["onauxclick","ondblclick"].every(name=>{const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);return !!d&&typeof d.get==="function"&&typeof d.set==="function"&&[video,auxiliaryAudio].every(player=>player[name]===null&&!Object.hasOwn(player,name))})')! == 'true'
}

fn test_media_double_click_follows_cancelled_primary_click_and_uses_primary_activation_result() {
	$if !darwin { return }
	mut owner, mut document :=
		media_auxiliary_handler_document('https://media-double-click-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.auxiliaryAudio=document.createElement("audio");auxiliaryAudio.id="auxiliary-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_auxiliary_handler_guard(runtime)!
	assert document.get_element_by_id('auxiliary-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('auxiliaryAudio')!)!
	runtime.evaluate_host(r'
globalThis.doubleOwnerOrder=[];globalThis.doubleOwnerChecks=[];globalThis.doubleOwnerSaved=[];globalThis.cancelPrimary=false;globalThis.cancelDouble=true;
for(const [name,player] of [["video",video],["audio",auxiliaryAudio]]){
 player.onclick=function(event){doubleOwnerOrder.push(name+":click");doubleOwnerSaved.push(event);doubleOwnerChecks.push(arguments.length===1&&this===player&&event.type==="click"&&event instanceof Event&&event.isTrusted&&event.bubbles&&event.cancelable&&event.target===player&&event.currentTarget===player&&window.event===event);if(cancelPrimary)return false};
 player.addEventListener("dblclick",function(event){doubleOwnerOrder.push(name+":before");doubleOwnerChecks.push(this===player&&event.isTrusted&&event.target===player&&event.currentTarget===player&&window.event===event&&!event.defaultPrevented)});
 player.ondblclick=function(){doubleOwnerOrder.push("obsolete")};
 player.addEventListener("dblclick",function(event){doubleOwnerOrder.push(name+":after");doubleOwnerChecks.push(this===player&&event.isTrusted&&event.target===player&&event.currentTarget===player&&event.defaultPrevented===cancelDouble&&window.event===event);result.textContent=doubleOwnerOrder.join(",")});
 const replacement=function(event){doubleOwnerOrder.push(name+":double");doubleOwnerSaved.push(event);doubleOwnerChecks.push(arguments.length===1&&this===player&&event.type==="dblclick"&&event instanceof Event&&event.isTrusted&&event.bubbles&&event.cancelable&&event.target===player&&event.currentTarget===player&&window.event===event);if(cancelDouble)return false};player.ondblclick=replacement;doubleOwnerChecks.push(player.ondblclick===replacement&&!Object.hasOwn(player,"ondblclick"));
}
document.body.appendChild(auxiliaryAudio);void auxiliaryAudio.paused;
')!
	assert voidptr(document.get_element_by_id('auxiliary-audio')?) == voidptr(created_target)
	mut app := media_auxiliary_handler_app(owner, document, runtime)
	for name, id in {
		'video': 'video'
		'audio': 'auxiliary-audio'
	} {
		target := document.get_element_by_id(id)?
		runtime.evaluate_host('doubleOwnerOrder=[];doubleOwnerSaved=[];cancelPrimary=false;cancelDouble=true;0')!
		media_auxiliary_handler_release(mut owner, target, 0, 2)
		assert owner.event_handler.last_click_allowed()
		assert runtime.evaluate_host('doubleOwnerOrder.join(",")==="${name}:click,${name}:before,${name}:double,${name}:after"&&doubleOwnerSaved.length===2&&!doubleOwnerSaved[0].defaultPrevented&&doubleOwnerSaved[1].defaultPrevented')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('doubleOwnerOrder.join(",")')!
		assert !app.dispatch_javascript_event('click', target)
		assert owner.event_handler.take_last_click_event() == none
		assert runtime.evaluate_host('doubleOwnerOrder.length===4')! == 'true'
		runtime.evaluate_host('cancelPrimary=true;cancelDouble=false;0')!
		media_auxiliary_handler_release(mut owner, target, 0, 2)
		assert !owner.event_handler.last_click_allowed()
		assert runtime.evaluate_host('doubleOwnerOrder.join(",")==="${name}:click,${name}:before,${name}:double,${name}:after,${name}:click,${name}:before,${name}:double,${name}:after"&&doubleOwnerSaved.length===4&&doubleOwnerSaved[2].defaultPrevented&&!doubleOwnerSaved[3].defaultPrevented&&doubleOwnerSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&doubleOwnerChecks.every(Boolean)&&window.event===undefined')! == 'true'
		app.poll_javascript_tasks()
		assert !app.dispatch_javascript_event('click', target)
		assert owner.event_handler.take_last_click_event() == none
		assert runtime.evaluate_host('doubleOwnerOrder.length===8')! == 'true'
	}
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_media_nonprimary_release_uses_auxclick_exact_false_and_clears_primary_replay_receipt() {
	$if !darwin { return }
	mut owner, mut document :=
		media_auxiliary_handler_document('https://media-aux-click-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.auxiliaryAudio=document.createElement("audio");auxiliaryAudio.id="auxiliary-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_auxiliary_handler_guard(runtime)!
	runtime.evaluate_host(r'
globalThis.auxOwnerOrder=[];globalThis.auxOwnerChecks=[];globalThis.auxOwnerSaved=[];globalThis.primaryOwnerCalls=0;globalThis.doubleOwnerCalls=0;globalThis.cancelAux=false;
for(const [name,player] of [["video",video],["audio",auxiliaryAudio]]){
 player.onclick=function(event){primaryOwnerCalls++;auxOwnerChecks.push(this===player&&event.type==="click"&&event.isTrusted&&window.event===event)};
 player.ondblclick=function(){doubleOwnerCalls++};
 player.addEventListener("auxclick",function(event){auxOwnerOrder.push(name+":before");auxOwnerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.defaultPrevented&&window.event===event)});
 const callback=function(event){auxOwnerOrder.push(name+":aux");auxOwnerSaved.push(event);auxOwnerChecks.push(arguments.length===1&&this===player&&event.type==="auxclick"&&event instanceof Event&&event.isTrusted&&event.bubbles&&event.cancelable&&event.target===player&&event.currentTarget===player&&window.event===event);return cancelAux?false:0};player.onauxclick=callback;
 player.addEventListener("auxclick",function(event){auxOwnerOrder.push(name+":after");auxOwnerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&event.defaultPrevented===cancelAux&&window.event===event);result.textContent=auxOwnerOrder.join(",")});auxOwnerChecks.push(player.onauxclick===callback&&!Object.hasOwn(player,"onauxclick"));
}
document.body.appendChild(auxiliaryAudio);void auxiliaryAudio.paused;
')!
	mut app := media_auxiliary_handler_app(owner, document, runtime)
	for index, id in ['video', 'auxiliary-audio'] {
		target := document.get_element_by_id(id)?
		media_auxiliary_handler_release(mut owner, target, 0, 1)
		assert owner.event_handler.last_click_allowed()
		assert runtime.evaluate_host('primaryOwnerCalls')! == (index + 1).str()
		// Retain the primary receipt deliberately: the next nonprimary release
		// must clear it without asking compact JavaScript to replay a click.
		for button in [u32(1), u32(2)] {
			runtime.evaluate_host('cancelAux=false;0')!
			media_auxiliary_handler_release(mut owner, target, button, 2)
			assert owner.event_handler.last_click_allowed()
			assert owner.event_handler.take_last_click_event() == none
			assert runtime.evaluate_host('auxOwnerSaved[auxOwnerSaved.length-1].defaultPrevented===false&&primaryOwnerCalls===${
				index + 1}&&doubleOwnerCalls===0')! == 'true'
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('auxOwnerOrder.join(",")')!
			calls := runtime.evaluate_host('auxOwnerOrder.length')!
			assert !app.dispatch_javascript_event('auxclick', target)
			assert runtime.evaluate_host('auxOwnerOrder.length')! == calls
			runtime.evaluate_host('cancelAux=true;0')!
			media_auxiliary_handler_release(mut owner, target, button, 2)
			assert !owner.event_handler.last_click_allowed()
			assert owner.event_handler.take_last_click_event() == none
			assert runtime.evaluate_host('auxOwnerSaved[auxOwnerSaved.length-1].defaultPrevented&&primaryOwnerCalls===${
				index + 1}&&doubleOwnerCalls===0')! == 'true'
			app.poll_javascript_tasks()
		}
	}
	assert runtime.evaluate_host('auxOwnerOrder.length===24&&auxOwnerSaved.length===8&&auxOwnerSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&auxOwnerChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_media_auxiliary_self_replacement_and_throwing_double_handler_keep_live_dom_and_click_receipt() {
	$if !darwin { return }
	mut owner, mut document :=
		media_auxiliary_handler_document('https://media-auxiliary-mutation.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.auxiliaryAudio=document.createElement("audio");auxiliaryAudio.id="auxiliary-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_auxiliary_handler_guard(runtime)!
	runtime.evaluate_host(r'
globalThis.selfAuxOrder=[];globalThis.selfAuxChecks=[];
auxiliaryAudio.addEventListener("auxclick",function(event){selfAuxOrder.push("before");selfAuxChecks.push(this===auxiliaryAudio&&event.isTrusted&&window.event===event)});
globalThis.nextAuxHandler=function(event){selfAuxOrder.push("replacement");selfAuxChecks.push(this===auxiliaryAudio&&event.target===auxiliaryAudio&&event.currentTarget===auxiliaryAudio&&event.isTrusted&&window.event===event);this.onauxclick=null};
auxiliaryAudio.onauxclick=function(event){selfAuxOrder.push("first");selfAuxChecks.push(this===auxiliaryAudio&&event.isTrusted&&window.event===event);this.onauxclick=nextAuxHandler};
auxiliaryAudio.addEventListener("auxclick",function(event){selfAuxOrder.push("after");selfAuxChecks.push(this===auxiliaryAudio&&event.isTrusted&&window.event===event);result.textContent=selfAuxOrder.join(",")});
document.body.appendChild(auxiliaryAudio);void auxiliaryAudio.paused;
')!
	mut app := media_auxiliary_handler_app(owner, document, runtime)
	audio := document.get_element_by_id('auxiliary-audio')?
	for _ in 0 .. 3 {
		media_auxiliary_handler_release(mut owner, audio, 1, 1)
		assert owner.event_handler.last_click_allowed()
		assert owner.event_handler.take_last_click_event() == none
		app.poll_javascript_tasks()
	}
	assert runtime.evaluate_host('selfAuxOrder.join(",")==="before,first,after,before,replacement,after,before,after"&&auxiliaryAudio.onauxclick===null')! == 'true'
	runtime.evaluate_host(r'globalThis.reactivatedAux=function(event){selfAuxOrder.push("reactivated");selfAuxChecks.push(this===auxiliaryAudio&&event.target===auxiliaryAudio&&event.currentTarget===auxiliaryAudio&&event.isTrusted&&window.event===event);result.textContent=selfAuxOrder.join(",")};auxiliaryAudio.onauxclick=reactivatedAux;0')!
	media_auxiliary_handler_release(mut owner, audio, 1, 1)
	app.poll_javascript_tasks()
	assert runtime.evaluate_host('selfAuxOrder.join(",")==="before,first,after,before,replacement,after,before,after,before,after,reactivated"&&auxiliaryAudio.onauxclick===reactivatedAux&&selfAuxChecks.every(Boolean)')! == 'true'
	assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('selfAuxOrder.join(",")')!
	runtime.evaluate_host(r'
globalThis.throwingDoubleReason={original:true};globalThis.throwingDoubleOrder=[];globalThis.throwingDoubleChecks=[];globalThis.futurePrimaryRaw=0;
video.onclick=function(event){throwingDoubleOrder.push("click");throwingDoubleChecks.push(this===video&&event.type==="click"&&event.isTrusted&&window.event===event)};
video.ondblclick=function(event){throwingDoubleOrder.push("double");throwingDoubleChecks.push(this===video&&event.type==="dblclick"&&event.target===video&&event.currentTarget===video&&event.isTrusted&&window.event===event);this.onclick=null;this.setAttribute("onclick","globalThis.futurePrimaryRaw++");result.textContent="double before throw";throw throwingDoubleReason};
video.addEventListener("dblclick",function(event){throwingDoubleOrder.push("later");throwingDoubleChecks.push(this===video&&event.isTrusted&&!event.defaultPrevented&&window.event===event);result.textContent="later double listener"});0
')!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	before_exceptions := settings.realm().reported_exceptions.len
	video := document.get_element_by_id('video')?
	media_auxiliary_handler_release(mut owner, video, 0, 2)
	assert owner.event_handler.last_click_allowed()
	assert runtime.evaluate_host('throwingDoubleOrder.join(",")==="click,double,later"&&throwingDoubleChecks.every(Boolean)&&futurePrimaryRaw===0&&video.onclick===null&&window.event===undefined')! == 'true'
	assert settings.realm().reported_exceptions.len == before_exceptions + 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[before_exceptions].value.as_webidl_value()!)! == runtime.evaluate_host_value('throwingDoubleReason')!
	app.poll_javascript_tasks()
	assert video.get_attribute('onclick')? == 'globalThis.futurePrimaryRaw++'
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'later double listener'
	// The receipt is the outer primary click. A later throwing dblclick handler
	// cannot authorize its newly installed raw onclick for the same release.
	assert !app.dispatch_javascript_event('click', video)
	assert owner.event_handler.take_last_click_event() == none
	assert runtime.evaluate_host('futurePrimaryRaw===0&&throwingDoubleOrder.length===3')! == 'true'
	media_auxiliary_handler_release(mut owner, video, 0, 1)
	assert owner.event_handler.last_click_allowed()
	assert !app.dispatch_javascript_event('click', video)
	assert runtime.evaluate_host('futurePrimaryRaw===1&&throwingDoubleOrder.length===3&&window.event===undefined')! == 'true'
	assert settings.realm().reported_exceptions.len == before_exceptions + 1
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}
