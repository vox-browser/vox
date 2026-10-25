module main

import browserjs
import css
import html
import platform
import time

fn test_compact_inline_style_preserves_replacements_and_uses_native_css_parsing() {
	mut document := html.parse_document('<!doctype html><div id="host" style="width:10px;color:red"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const style=host.style;
if(style!==host.style||style.width!=="10px")throw new Error("style identity");
if(!("transform" in style)||!("width" in style)||"voxUnsupported" in style||style.voxUnsupported!==undefined)throw new Error("CSS feature detection");
style.voxUnsupported=42;if(style.voxUnsupported!==42||style.getPropertyValue("vox-unsupported")!=="")throw new Error("CSS expando");
style.cssText="position:absolute;left:50px;width:20px;height:30px;background-image:url(\"data:image/svg+xml;a;b\");--Theme:one;--theme:two";
style.pointerEvents="none";
if(style.position!=="absolute"||style.left!=="50px"||style.width!=="20px"||style.height!=="30px"||style.color!=="")throw new Error("cssText replacement lost declarations");
if(!style.backgroundImage.includes(";a;b")||style.getPropertyValue("--Theme")!=="one"||style.getPropertyValue("--theme")!=="two")throw new Error("CSS tokenization or custom property case");
host.setAttribute("style","width:80px;height:40px");style.color="blue";
if(style.width!=="80px"||style.height!=="40px"||style.pointerEvents!==""||!host.getAttribute("style").includes("color: blue"))throw new Error("live style attribute replacement");
style.setProperty("width","90px","IMPORTANT");
if(style.width!=="90px"||style.getPropertyPriority("width")!=="important")throw new Error("priority");
style.setProperty("width","100px","invalid");style.setProperty("height","99px",null);
if(style.height!=="99px"||style.getPropertyPriority("height")!=="")throw new Error("null priority is empty");
style.height="invalid";style.setProperty("height",undefined);style.height=undefined;
if(style.width!=="90px"||style.height!=="99px")throw new Error("invalid and undefined values must preserve declarations");
if(style.removeProperty("width")!=="90px"||style.width!==""||style.getPropertyPriority("width")!=="")throw new Error("remove property");
style.setProperty("color",null);if(style.color!=="")throw new Error("null removes property");
style.cssFloat="left";if(style.getPropertyValue("float")!=="left")throw new Error("cssFloat");
const names=Array.from(style);
if(names.length!==style.length||style[0]!==style.item(0)||style.item(9999)!==""||style[9999]!==undefined||!names.includes("height"))throw new Error("indexed declarations");
host.removeAttribute("style");if(style.cssText!==""||style.length!==0)throw new Error("style attribute removal");
const detached=document.createElement("div");detached.style.cssText="width:17px;height:19px";detached.style.top="2px";document.body.appendChild(detached);
if(detached.style.width!=="17px"||detached.style.height!=="19px")throw new Error("detached declaration");
console.log("inline style passed");
'], runtime, mut messages)
	assert messages == ['inline style passed']
	host := document.get_element_by_id('host') or { panic('missing style owner') }
	assert !host.has_attribute('style')
}

fn test_compact_inline_style_reads_native_changes_and_validates_method_receivers() {
	mut document := html.parse_document('<!doctype html><div id="host" style="width:10px"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.savedStyle=host.style;
function typeError(callback){let threw=false;try{callback()}catch(error){threw=error instanceof TypeError}if(!threw)throw new Error("expected TypeError");}
let conversions=0,traps=0;
const value={toString(){conversions++;return "width";}},proxy=new Proxy(savedStyle,{get(){traps++;throw new Error("proxy trap")}});
for(const method of [savedStyle.getPropertyValue,savedStyle.getPropertyPriority,savedStyle.removeProperty,savedStyle.item,savedStyle.setProperty]){
 for(const receiver of [undefined,null,{},Object.create(savedStyle),proxy])typeError(()=>method.call(receiver,value,value));
 typeError(()=>method.call(savedStyle));
}

if(conversions||traps)throw new Error("receiver or arity precedes conversion");
for(const method of [savedStyle.getPropertyValue,savedStyle.getPropertyPriority,savedStyle.removeProperty,savedStyle.item])typeError(()=>method.call(savedStyle,Symbol()));
typeError(()=>savedStyle.setProperty("width",Symbol()));typeError(()=>{savedStyle.cssText=Symbol();});
const order=[];
savedStyle.setProperty({toString(){order.push("name");return "height";}},{toString(){order.push("value");return "23px";}},{toString(){order.push("priority");return "important";}});
if(order.join()!=="name,value,priority"||savedStyle.height!=="23px")throw new Error("conversion order");
console.log("inline conversion passed");
'], runtime, mut messages)
	assert messages == ['inline conversion passed']
	mut host := document.get_element_by_id('host') or { panic('missing style owner') }
	host.set_attribute_value('style', 'width:81px;height:32px')
	assert runtime.evaluate_host('savedStyle.width')! == '81px'
	assert runtime.evaluate_host('savedStyle.height')! == '32px'
	assert runtime.evaluate_host('host.getAttribute("style")')! == 'width:81px;height:32px'
}

fn test_compact_inline_style_retains_native_declarations_after_request_scratch_is_retired() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	document.enable_native_storage()
	defer {
		document.finalize()
		document.release_native_storage()
	}
	host := document.get_element_by_id('host') or { panic('missing style owner') }
	input := platform.begin_thread_scratch('inline style request')
	source := '{"op":"replace","value":"width:37px;--Theme:retained; background-image:url(\\\"data:image/svg+xml;a;b\\\")"}'.clone()
	response := compact_inline_style_query(host.as_node(), source, unsafe { nil })!
	$if prealloc {
		assert !document.native_storage().arena.contains(voidptr(response.str))
	}
	assert response.contains('37px')
	input.finish()
	declaration := css.element_style(host)
	$if prealloc {
		assert document.native_storage().arena.contains(voidptr(declaration))
	}
	assert declaration.get_property_value('width') == '37px'
	assert declaration.get_property_value('--Theme') == 'retained'
	assert declaration.get_property_value('background-image').contains(';a;b')
}

fn test_compact_inline_style_query_flushed_timer_changes_reach_final_paint() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><div id="target" style="width:30px;height:20px;background:green"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	assert messages == []string{}
	runtime.evaluate_host('globalThis.inlineStyleRefreshes=0;globalThis.__voxAdblockApplyProcedural=()=>{inlineStyleRefreshes++;return ""};')!
	mut app := &BrowserApp{ document: document, js_runtime: runtime }
	app.relayout(320, 232)
	runtime.evaluate_host('inlineStyleRefreshes=0')!
	runtime.take_document_state_dirty()
	runtime.take_document_replay_effects()
	paint := app.paint_display_list
	// Reading the native declaration must not schedule a cosmetic refresh.
	assert runtime.evaluate_host('target.style.width')! == '30px'
	assert !runtime.take_document_state_dirty()
	assert !runtime.take_document_replay_effects()
	runtime.evaluate_host('globalThis.inlineStyleTimerDone=false;setTimeout(()=>{target.style.cssText="width:70px;height:20px;background:rgb(71 72 73)";target.style.height="24px";getComputedStyle(target).getPropertyValue("width");inlineStyleTimerDone=true;},1)')!
	deadline := time.sys_mono_now() + 2_000_000_000
	for runtime.evaluate_host('inlineStyleTimerDone')! != 'true' && time.sys_mono_now() < deadline {
		platform.pump_native_events(0.005)
	}
	assert runtime.evaluate_host('inlineStyleTimerDone')! == 'true'
	app.poll_javascript_tasks()
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_bounding_client_rect().width == 70
	assert target.get_bounding_client_rect().height == 24
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
	assert voidptr(app.paint_display_list) != voidptr(paint)
	assert runtime.evaluate_host('inlineStyleRefreshes')! == '1'
}
