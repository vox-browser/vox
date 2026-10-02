module browserjs

import css
import dom
import html
import os
import platform

fn font_host_fixture() (&Runtime, &FontFaceHost, &html.EventLoop) {
	document := html.parse_document_with_url('<!doctype html><body>fonts</body>', dom.URL{
		value: 'https://font-binding.example/'
	})
	window := html.WindowModel.create_top_level(document, none, 'font-binding') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(window.associated_document().relevant_settings_object()) }
	owner := settings.responsible_event_loop()
	mut runtime := Runtime.create()
	runtime.evaluate_host('globalThis.document={}') or { panic(err) }
	mut host := FontFaceHost.create(document)
	host.install(mut runtime) or { panic(err) }
	return runtime, host, owner
}

fn font_host_drain(owner &html.EventLoop) {
	mut queue := owner.task_queue()
	for _ in 0 .. 50 {
		task := queue.take_first_runnable() or { break }
		task.execute()
	}
	mut mutable_owner := unsafe { &html.EventLoop(owner) }
	mutable_owner.perform_a_microtask_checkpoint()
}

fn test_font_host_brands_descriptors_and_native_rejection_keep_actual_values() {
	$if !darwin { return }
	mut runtime, _, owner := font_host_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
 const face=new FontFace("Native Face","url(font.ttf)",{weight:"700",display:"swap"});
 const initial=face.loaded;const same=initial===face.loaded;
 const marker={};let thrown=false;try{new FontFace({toString(){throw marker}},"");}catch(e){thrown=e===marker;}
 let brands=0;for(const f of [()=>FontFace("A",""),()=>new FontFace(),()=>Object.getOwnPropertyDescriptor(FontFace.prototype,"family").get.call({}),()=>new FontFace("A","",1)]){try{f()}catch(e){if(e instanceof TypeError)brands++}}
 let setter=false;try{face.weight="invalid"}catch(e){setter=e instanceof DOMException&&e.name==="SyntaxError"}
 const broken=new FontFace("Broken",new Uint8Array([0,1,0,0]));globalThis.fontFailure=null;broken.loaded.catch(e=>fontFailure=e);
 same&&thrown&&brands===4&&setter&&face.weight==="700"&&face.display==="swap"&&FontFace.length===2&&FontFaceSet.prototype.load.length===1&&document.fonts===document.fonts&&document.fonts instanceof FontFaceSet;
 ')! == 'true'
	font_host_drain(owner)
	assert runtime.evaluate_host('fontFailure instanceof DOMException&&fontFailure.name==="SyntaxError"&&fontFailure.code===12')! == 'true'
}

fn test_font_host_buffer_source_copy_and_real_promise_return_original_wrapper() {
	$if !darwin { return }
	mut runtime, host, owner := font_host_fixture()
	defer { runtime.close() }
	bytes := os.read_bytes('/System/Library/Fonts/Supplemental/Arial.ttf')!
	// Pass actual typed-array views to the native source copy boundary.
	runtime.evaluate_host('globalThis.fontBytes=new Uint8Array([' + bytes.map(it.str()).join(',') +
		']);globalThis.fontBuffer=new Uint8Array(fontBytes.length+8);fontBuffer.set(fontBytes,4);globalThis.nativeFace=new FontFace("Arial native",new DataView(fontBuffer.buffer,4,fontBytes.length));globalThis.originalFontPromise=nativeFace.loaded;globalThis.fontLoadedValue=null;originalFontPromise.then(value=>fontLoadedValue=value);fontBuffer.fill(0);document.fonts.add(nativeFace);')!
	assert runtime.evaluate_host('nativeFace.status==="unloaded"&&nativeFace.loaded===originalFontPromise&&nativeFace.load()===originalFontPromise&&document.fonts.has(nativeFace)&&document.fonts.size===1&&document.fonts.add(nativeFace)===document.fonts')! == 'true'
	assert host.set.set_entries().len == 1
	font_host_drain(owner)
	assert runtime.evaluate_host('nativeFace.status==="loaded"&&fontLoadedValue===nativeFace&&nativeFace.loaded===originalFontPromise&&originalFontPromise instanceof Promise')! == 'true'
}

fn test_setlike_cache_iterators_follow_live_native_membership_and_source_order() {
	$if !darwin { return }
	mut runtime, host, _ := font_host_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
 const a=new FontFace("A","url(a.ttf)"),b=new FontFace("B","url(b.ttf)"),c=new FontFace("C","url(c.ttf)");
 document.fonts.add(a);document.fonts.add(b);const iterator=document.fonts.values();const first=iterator.next().value;
 document.fonts.add(c);document.fonts.delete(b);const second=iterator.next().value;
 let correct=false;document.fonts.forEach(function(value,key,set){correct=value===key&&set===document.fonts});
 globalThis.nativeCacheA=a;globalThis.nativeCacheC=c;
 first===a&&second===c&&iterator.next().done&&correct&&[...document.fonts].length===2;
 ')! == 'true'
	assert host.set.set_entries().len == 2
	mut set := host.set
	set.delete_(set.set_entries()[0])
	assert runtime.evaluate_host('[...document.fonts].length===1&&[...document.fonts][0]===nativeCacheC')! == 'true'
	set.clear()
	assert runtime.evaluate_host('document.fonts.size===0&&[...document.fonts].length===0')! == 'true'
}

fn test_font_set_load_actual_engine_promise_adopts_native_font_wrapper_array() {
	$if !darwin { return }
	mut runtime, host, mut owner := font_host_fixture()
	defer { runtime.close() }
	mut set := host.set
	set.set_is_pending_on_the_environment(false)
	runtime.evaluate_host('globalThis.emptyFonts=null;globalThis.emptyLoad=document.fonts.load("16px Missing");emptyLoad.then(value=>emptyFonts=value);')!
	assert runtime.evaluate_host('emptyFonts===null&&emptyLoad instanceof Promise')! == 'true'
	mut plugin := platform.EventLoopPlugin.the()
	assert plugin.run_one_deferred()
	font_host_drain(owner)
	assert runtime.evaluate_host('Array.isArray(emptyFonts)&&emptyFonts.length===0')! == 'true'
	assert runtime.evaluate_host('globalThis.fontReadyValue=null;const ready=document.fonts.ready;ready.then(value=>fontReadyValue=value);ready===document.fonts.ready')! == 'true'
	owner.perform_a_microtask_checkpoint()
	assert runtime.evaluate_host('fontReadyValue===document.fonts')! == 'true'
}

fn test_promise_returning_font_operations_reject_original_conversion_exception() {
	$if !darwin { return }
	mut runtime, _, _ := font_host_fixture()
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.argumentMarker={};globalThis.fontArgumentReason=null;globalThis.fontBrandReason=null;document.fonts.load({toString(){throw argumentMarker}}).catch(reason=>fontArgumentReason=reason);FontFace.prototype.load.call({}).catch(reason=>fontBrandReason=reason);')!
	assert runtime.evaluate_host('fontArgumentReason===argumentMarker&&fontBrandReason instanceof TypeError')! == 'true'
}
