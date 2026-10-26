module browserjs

import css
import dom
import html
import layout
import loader
import platform

fn resize_binding_fixture() !(&Runtime, &dom.Document, &dom.Element) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://resize-binding.test/' }
	mut document := html.parse_navigation_document('<!doctype html><html><body><div id="target" style="width:100px;height:50px;padding:4px 6px;border:2px solid"></div></body></html>', url, url.origin(), none)!
	document.enable_native_storage()
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut navigable := &dom.Navigable{ active_document_: document, is_top_level_traversable_: true }
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	layout.install_document_layout_hook(document)
	document.needs_full_layout_tree_update = true
	document.update_layout(.debugging)
	target := css.query_selector(unsafe { &dom.Node(document) }, '#target') or { return error('Target missing') }
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_resize_observer_binding(none)!
	runtime.bind_event_target(runtime.evaluate_host_value('globalThis.target={}')!, unsafe { &dom.EventTarget(target) })!
	runtime.bind_event_target(runtime.evaluate_host_value('globalThis.document={}')!, unsafe { &dom.EventTarget(document) })!
	return runtime, document, target
}

fn test_resize_binding_delivers_native_geometry_and_retains_entry_snapshots() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut target := resize_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.log=[];globalThis.observer=new ResizeObserver(function(entries,receiver){
  globalThis.entry=entries[0];log.push([this===observer,receiver===observer,entry instanceof ResizeObserverEntry,entry.target===target,entry.contentRect.width]);
 });observer.observe(target);observer.observe(target);
 log.length===0&&ResizeObserver.length===1&&ResizeObserver.prototype.observe.length===1;
 ')! == 'true'
	assert document.registered_resize_observer_count() == 1
	document.gather_active_observations_at_depth(0)
	assert runtime.evaluate_host('log.length')! == '0'
	assert document.has_active_resize_observations()
	document.broadcast_active_resize_observations()
	assert runtime.evaluate_host(r'
 JSON.stringify(log)==="[[true,true,true,true,100]]"&&entry.contentRect instanceof DOMRectReadOnly&&entry.contentRect.x===6&&entry.contentRect.y===4&&entry.contentRect.height===50&&entry.borderBoxSize[0] instanceof ResizeObserverSize&&entry.borderBoxSize[0].inlineSize===116&&entry.borderBoxSize[0].blockSize===62&&entry.contentBoxSize[0].inlineSize===100&&entry.contentBoxSize[0].blockSize===50&&Object.isFrozen(entry.borderBoxSize)&&Object.isFrozen(entry.contentBoxSize)&&Object.isFrozen(entry.devicePixelContentBoxSize)&&Object.prototype.toString.call(entry)==="[object ResizeObserverEntry]"&&Object.prototype.toString.call(entry.contentBoxSize[0])==="[object ResizeObserverSize]";
 ')! == 'true'
	document.gather_active_observations_at_depth(0)
	assert !document.has_active_resize_observations()
	assert runtime.evaluate_host('globalThis.saved=entry;true')! == 'true'
	target.set_attribute_value('style', 'width:140px;height:60px;padding:4px 6px;border:2px solid')
	mut node := target.as_node()
	node.set_needs_layout_tree_update(true, .style_change)
	document.update_layout(.debugging)
	document.gather_active_observations_at_depth(0)
	assert document.has_active_resize_observations()
	document.broadcast_active_resize_observations()
	assert runtime.evaluate_host('log.length===2&&entry!==saved&&entry.contentRect.width===140&&saved.contentRect.width===100&&saved.borderBoxSize[0].inlineSize===116')! == 'true'
	assert runtime.evaluate_host('observer.unobserve(target);true')! == 'true'
	assert document.registered_resize_observer_count() == 0
}

fn test_resize_binding_conversions_brand_checks_and_original_exceptions() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, _ := resize_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 class Derived extends ResizeObserver{};globalThis.observer=new Derived(()=>{});
 let errors=0;for(const run of [()=>ResizeObserver(()=>{}),()=>new ResizeObserver(),()=>new ResizeObserver({handleEvent(){}}),()=>new ResizeObserverEntry(),()=>new ResizeObserverSize(),()=>observer.observe(),()=>observer.unobserve(),()=>observer.observe(document),()=>observer.observe(new Proxy(target,{})),()=>ResizeObserver.prototype.disconnect.call({}),()=>ResizeObserver.prototype.observe.call({},target),()=>observer.observe(target,1),()=>observer.observe(target,{box:"bad"}),()=>observer.observe(target,{box:Symbol()}),()=>Object.getOwnPropertyDescriptor(ResizeObserverEntry.prototype,"target").get.call({}),()=>Object.getOwnPropertyDescriptor(ResizeObserverSize.prototype,"inlineSize").get.call({})])try{run()}catch(e){if(e instanceof TypeError)errors++}
 let reads=0,same=false;const marker={},options={get box(){reads++;throw marker}};
 try{observer.observe(document,options)}catch(e){};const targetBeforeOptions=reads===0;
 try{observer.observe(target,options)}catch(e){same=e===marker}
 let conversions=0;observer.observe(target,{box:{toString(){conversions++;return "border-box"}}});observer.observe(target,null);observer.observe(target);
 errors===16&&same&&reads===1&&targetBeforeOptions&&conversions===1&&observer instanceof Derived&&observer.disconnect()===undefined;
 ')! == 'true'
	assert document.registered_resize_observer_count() == 0
}

fn test_resize_binding_uses_selected_box_and_reports_callback_exceptions() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, mut target := resize_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.contentCalls=0;globalThis.borderCalls=0;
 globalThis.contentObserver=new ResizeObserver(()=>{contentCalls++});contentObserver.observe(target);
 globalThis.borderObserver=new ResizeObserver(()=>{borderCalls++});borderObserver.observe(target,{box:"border-box"});true;
 ')! == 'true'
	document.gather_active_observations_at_depth(0)
	document.broadcast_active_resize_observations()
	target.set_attribute_value('style', 'width:100px;height:50px;padding:8px;border:2px solid')
	mut node := target.as_node()
	node.set_needs_layout_tree_update(true, .style_change)
	document.update_layout(.debugging)
	document.gather_active_observations_at_depth(0)
	document.broadcast_active_resize_observations()
	assert runtime.evaluate_host('contentCalls===1&&borderCalls===2')! == 'true'
	assert runtime.evaluate_host(r'
 contentObserver.disconnect();borderObserver.disconnect();
 globalThis.errors=0;globalThis.broken=new ResizeObserver(function(){errors++;broken.disconnect();throw new Error("resize callback failed")});broken.observe(target);true;
 ')! == 'true'
	document.gather_active_observations_at_depth(0)
	document.broadcast_active_resize_observations()
	assert runtime.evaluate_host('errors===1')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	assert document.registered_resize_observer_count() == 0
}

fn test_resize_binding_survives_caller_scratch_and_unregisters_on_close() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document, _ := resize_binding_fixture()!
	defer { document.finalize() }
	owned_before := runtime.owned_closures_.len
	mut scratch := platform.begin_thread_scratch('resize observer caller')
	source := 'globalThis.calls=0;globalThis.observer=new ResizeObserver(entries=>{calls++;globalThis.savedEntry=entries[0]});observer.observe(target);true'.clone()
	scratch.leave()
	assert runtime.evaluate_host(source)! == 'true'
	scratch.finish()
	gc_collect()
	assert runtime.owned_closures_.len == owned_before + 1
	mut rendering := platform.begin_thread_scratch('resize observer rendering')
	document.gather_active_observations_at_depth(0)
	document.broadcast_active_resize_observations()
	rendering.finish()
	gc_collect()
	assert runtime.evaluate_host('calls===1&&savedEntry.contentRect.width===100&&savedEntry.borderBoxSize[0].inlineSize===116')! == 'true'
	assert document.registered_resize_observer_count() == 1
	runtime.close()
	assert runtime.owned_closures_.len == 0
	assert document.registered_resize_observer_count() == 0
	document.gather_active_observations_at_depth(0)
	assert !document.has_active_resize_observations()
}
