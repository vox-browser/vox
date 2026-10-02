module browserjs

import css
import dom
import html
import os

fn native_font_event_fixture() (&Runtime, &FontFaceHost, &html.EventLoop) {
	document :=
		html.parse_document_with_url('<!doctype html><body>font events</body>', dom.URL{'https://font-events.example/'})
	_ = html.WindowModel.create_top_level(document, none, 'font-events') or { panic(err) }
	mut runtime := Runtime.create()
	runtime.evaluate_host('globalThis.document={}') or { panic(err) }
	mut host := FontFaceHost.create(document)
	host.install(mut runtime) or { panic(err) }
	mut fonts := host.set
	fonts.set_is_pending_on_the_environment(false)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	owner := settings.responsible_event_loop()
	font_event_host_drain(owner)
	return runtime, host, owner
}

fn font_event_host_drain(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 80 {
		task := queue.take_first_runnable() or { break }
		task.execute()
	}
	mut loop := unsafe { &html.EventLoop(owner) }
	loop.perform_a_microtask_checkpoint()
}

fn test_font_set_load_event_constructor_has_same_native_event_and_frozen_font_wrappers() {
	$if !darwin { return }
	mut runtime, host, _ := native_font_event_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
 const a=new FontFace("A","url(a.ttf)"),b=new FontFace("B","url(b.ttf)");globalThis.constructorFaceA=a;
 const order=[];const marker={};globalThis.nativeFontEvent=new FontFaceSetLoadEvent("fonts",{get fontfaces(){order.push("fontfaces");return new Set([a,b])},get composed(){order.push("composed");return true},get cancelable(){order.push("cancelable");return true},get bubbles(){order.push("bubbles");return true}});
 let throws=0;for(const f of [()=>new FontFaceSetLoadEvent("fonts",{fontfaces:{0:a,length:1}}),()=>new FontFaceSetLoadEvent("fonts",{fontfaces:[{}]}),()=>Object.getOwnPropertyDescriptor(FontFaceSetLoadEvent.prototype,"fontfaces").get.call(new Event("base"))]){try{f()}catch(e){if(e instanceof TypeError)throws++}}
 let original=false;try{new FontFaceSetLoadEvent("fonts",{fontfaces:{get [Symbol.iterator](){throw marker}}})}catch(e){original=e===marker}
 nativeFontEvent instanceof Event&&nativeFontEvent instanceof FontFaceSetLoadEvent&&nativeFontEvent.fontfaces===nativeFontEvent.fontfaces&&Object.isFrozen(nativeFontEvent.fontfaces)&&nativeFontEvent.fontfaces[0]===a&&nativeFontEvent.fontfaces[1]===b&&nativeFontEvent.bubbles&&nativeFontEvent.cancelable&&nativeFontEvent.composed&&!nativeFontEvent.isTrusted&&order.join(",")==="bubbles,cancelable,composed,fontfaces"&&throws===3&&original&&document.fonts instanceof EventTarget;
 ')! == 'true'
	wrapper := runtime.evaluate_host_value('nativeFontEvent')!
	event := runtime.native_event(wrapper)!
	assert event.interface_ == .font_face_set_load_event
	record := host.font_events[wrapper] or { panic('actual native event') }
	assert voidptr(event) == voidptr(record)
	assert record.fontfaces().len == 2
	assert voidptr(record.fontfaces()[0]) == voidptr(host.faces[runtime.evaluate_host_value('constructorFaceA')!] or {
		panic('actual face')
	})
}

fn test_font_loading_callbacks_dispatch_actual_source_events_faces_and_promises() {
	$if !darwin { return }
	mut runtime, host, owner := native_font_event_fixture()
	defer { runtime.close() }
	bytes := os.read_bytes('/System/Library/Fonts/Supplemental/Arial.ttf')!
	runtime.evaluate_host('globalThis.fontEventBytes=new Uint8Array([' +
		bytes.map(it.str()).join(',') + ']);')!
	assert runtime.evaluate_host(r'
 globalThis.fontEventLog=[];globalThis.loadedFace=new FontFace("Good native",fontEventBytes);globalThis.failedFace=new FontFace("Bad native",new Uint8Array([0,1,0,0]));document.fonts.add(loadedFace);document.fonts.add(failedFace);
 const observe=function(event){fontEventLog.push({type:event.type,faces:event.fontfaces.slice(),valid:this===document.fonts&&event.target===document.fonts&&event.currentTarget===document.fonts&&event instanceof FontFaceSetLoadEvent&&event instanceof Event&&event.fontfaces===event.fontfaces&&Object.isFrozen(event.fontfaces)});};
 document.fonts.onloading=observe;document.fonts.onloadingdone=observe;document.fonts.addEventListener("loadingerror",observe);
 globalThis.fontEventReady=document.fonts.ready;globalThis.fontEventReadyValue=null;loadedFace.loaded.then(value=>globalThis.fontEventLoaded=value);failedFace.loaded.catch(value=>globalThis.fontEventFailed=value);
 document.fonts.onloading===observe&&document.fonts.status==="loaded";
 ')! == 'true'
	font_event_host_drain(owner)
	assert runtime.evaluate_host(r'
 document.fonts.ready.then(value=>fontEventReadyValue=value);
 const loading=fontEventLog.filter(event=>event.type==="loading"),done=fontEventLog.filter(event=>event.type==="loadingdone"),error=fontEventLog.filter(event=>event.type==="loadingerror");
 loading.length===1&&loading[0].faces.length===0&&done.length===1&&done[0].faces.length===1&&done[0].faces[0]===loadedFace&&error.length===1&&error[0].faces.length===1&&error[0].faces[0]===failedFace&&fontEventLog.every(event=>event.valid)&&fontEventLoaded===loadedFace&&fontEventFailed instanceof DOMException&&fontEventFailed.name==="SyntaxError"&&document.fonts.status==="loaded";
 ')! == 'true'
	font_event_host_drain(owner)
	assert runtime.evaluate_host('fontEventReadyValue===document.fonts')! == 'true'
	assert host.set.fired_events.last().name == 'loadingerror'
}

fn test_font_set_loading_events_keep_removed_faces_out_and_retain_handler_cancellation_rules() {
	$if !darwin { return }
	mut runtime, host, _ := native_font_event_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
 globalThis.removedFace=new FontFace("Removed","url(removed.ttf)");document.fonts.add(removedFace);globalThis.filteredFaces=null;document.fonts.onloadingdone=function(event){filteredFaces=event.fontfaces;return false;};document.fonts.delete(removedFace);
 ')! == 'true'
	face := host.faces[runtime.evaluate_host_value('removedFace')!] or { panic('native face') }
	mut set := host.set
	set.fire_a_font_load_event('loadingdone', [face])
	assert runtime.evaluate_host('filteredFaces.length===0&&Object.isFrozen(filteredFaces)')! == 'true'
	assert set.fired_events.last().fontfaces.len == 0
	event := css.FontFaceSetLoadEvent.create_for_fonts('native', [face], 12.5)
	assert event.base_event().time_stamp() == 12.5
	assert voidptr(event.base_event()) == voidptr(event)
	assert runtime.javascript_event_handler(unsafe { &dom.EventTarget(set) }, 'loadingdone')! == runtime.evaluate_host_value('document.fonts.onloadingdone')!
}
