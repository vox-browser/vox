module browserjs

import dom
import html

const mln_first = 'urn:loop-first'
const mln_second = 'urn:loop-second'
const mln_prefixed = 'urn:loop-prefixed'

@[heap]
struct MlnProbe {
mut:
	replays int
	mode int
	fetches int
	volume_updates []f64
	element &dom.Element = unsafe { nil }
	inserted &dom.Attr_ = unsafe { nil }
}

fn mln_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document) {
	address := dom.URL{ value: 'https://loop-namespace.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="mln-video-first"></video><video id="mln-video-last"></video><audio id="mln-audio-first"></audio><audio id="mln-audio-last"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	_ = runtime.evaluate_host('globalThis.mlnPlayers={};0')!
	for key, element in host.elements_for_binding() {
		if element.local_name() !in ['audio', 'video'] { continue }
		id := element.get_attribute('id') or { return error('Missing loop namespace ID') }
		_ = runtime.evaluate_host('mlnPlayers["${id}"]={};__ladybirdMediaElementBind(mlnPlayers["${id}"],"${key}","${element.local_name()}");0')!
	}
	return runtime, host, document
}

fn mln_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing loop namespace element ${id}') }
}

fn mln_attr(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'loop') or { return error('Missing loop namespace attribute') }
}

fn mln_foreign_intact(element &dom.Element, first &dom.Attr_, second &dom.Attr_, prefixed &dom.Attr_) ! {
	for index, attribute in [first, second, prefixed] {
		namespace := [mln_first, mln_second, mln_prefixed][index]
		owner := attribute.owner_element() or { return error('Foreign loop attribute lost its owner') }
		actual_namespace := attribute.namespace_uri() or { return error('Foreign loop attribute lost its namespace') }
		assert voidptr(owner) == voidptr(element) && actual_namespace == namespace
		assert voidptr(mln_attr(element, namespace)!) == voidptr(attribute)
		assert attribute.local_name() == 'loop'
	}
	assert first.value() == 'foreign first' && second.value() == 'foreign second'
	assert first.name() == 'loop' && second.name() == 'loop'
	assert first.prefix() == none && second.prefix() == none
	assert prefixed.value() == 'prefixed foreign' && prefixed.name() == 'p:loop'
	prefix := prefixed.prefix() or { return error('Foreign loop attribute lost its prefix') }
	assert prefix == 'p'
}

fn test_native_loop_namespace_slot_preserves_duplicate_attributes_in_both_orders() {
	$if !darwin { return }
	mut runtime, _, mut document := mln_fixture(none)!
	defer { runtime.close(); document.finalize() }
	probe := &MlnProbe{}
	for index, id in ['mln-video-first', 'mln-video-last', 'mln-audio-first', 'mln-audio-last'] {
		mut element := mln_element(document, id)!
		if index % 2 == 0 { element.set_attribute_value('loop', 'initial null') }
		element.set_attribute_ns_for_bindings(mln_first, 'loop', 'foreign first')!
		element.set_attribute_ns_for_bindings(mln_second, 'loop', 'foreign second')!
		element.set_attribute_ns_for_bindings(mln_prefixed, 'p:loop', 'prefixed foreign')!
		if index % 2 == 1 { element.set_attribute_value('loop', 'initial null') }
		first := mln_attr(element, mln_first)!
		second := mln_attr(element, mln_second)!
		prefixed := mln_attr(element, mln_prefixed)!
		original := mln_attr(element, none)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing loop namespace model') }
		media.set_current_time(f64(index) + 3.25)
		media.set_paused(index % 2 == 0)
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MlnProbe(probe) }; observed.fetches++
			return error('loop namespace reflection must not fetch')
		})
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			set_volume: fn [probe] (volume f64) {
				mut observed := unsafe { &MlnProbe(probe) }; observed.volume_updates << volume
			}
		})
		player := 'mlnPlayers["${id}"]'
		assert runtime.evaluate_host('${player}.loop===true')! == 'true'
		assert media.loop() && original.value() == 'initial null'
		assert runtime.evaluate_host('${player}.loop=false;${player}.loop===false')! == 'true'
		assert !media.loop() && !element.has_attribute_ns(none, 'loop') && original.owner_element() == none
		assert element.has_attribute('loop') && element.get_attribute('loop')? == 'foreign first'
		mln_foreign_intact(element, first, second, prefixed)!
		assert runtime.evaluate_host('${player}.loop=false;${player}.loop===false')! == 'true'
		mln_foreign_intact(element, first, second, prefixed)!
		assert runtime.evaluate_host('${player}.loop=true;${player}.loop===true')! == 'true'
		normalized := mln_attr(element, none)!
		assert media.loop() && normalized.value() == '' && normalized.namespace_uri() == none && normalized.prefix() == none
		assert voidptr(normalized) != voidptr(original)
		element.set_attribute_value('loop', 'direct null value')
		assert runtime.evaluate_host('${player}.loop===true')! == 'true'
		assert media.loop() && normalized.value() == 'direct null value'
		assert runtime.evaluate_host('${player}.loop=true;${player}.loop===true')! == 'true'
		assert voidptr(mln_attr(element, none)!) == voidptr(normalized) && normalized.value() == ''
		element.remove_attribute_ns(none, 'loop')
		assert runtime.evaluate_host('${player}.loop===false')! == 'true'
		assert !media.loop() && normalized.owner_element() == none
		mln_foreign_intact(element, first, second, prefixed)!
		assert !media.muted() && media.volume() == 1 && media.current_time() == f64(index) + 3.25
		assert media.paused() == (index % 2 == 0) && media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['volumechange', 'play', 'pause', 'loadstart', 'seeking'] { assert media.event_count(name) == 0 }
	}
	assert probe.fetches == 0 && probe.volume_updates == []
}

fn test_native_loop_namespace_getter_observes_replay_and_replay_failure_preserves_slots() {
	$if !darwin { return }
	probe := &MlnProbe{}
	mut runtime, _, mut document := mln_fixture(fn [probe] (runtime &Runtime) ! {
		mut observed := unsafe { &MlnProbe(probe) }; observed.replays++
		mut element := unsafe { &dom.Element(observed.element) }
		match observed.mode {
			1 { element.set_attribute_ns_for_bindings(mln_first, 'loop', 'foreign first')! }
			2 {
				element.set_attribute_value('loop', 'replayed null')
				observed.inserted = mln_attr(element, none)!
			}
			3 { element.remove_attribute_ns(none, 'loop') }
			4 {
				mut owner := unsafe { &Runtime(runtime) }
				_ = owner.evaluate_host_value('throw mlnReplayReason')!
			}
			else {}
		}
	})!
	defer { runtime.close(); document.finalize() }
	mut observed := unsafe { &MlnProbe(probe) }
	mut element := mln_element(document, 'mln-video-first')!
	observed.element = element
	media := html.html_media_element_for_dom_element(element) or { panic('Missing replay namespace model') }
	_ = runtime.evaluate_host(r'globalThis.mlnVideo=mlnPlayers["mln-video-first"];globalThis.mlnSync=[];globalThis.mlnReplayReason={};globalThis.mlnDescriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"loop");__ladybirdMediaElementSetAttributeSync((receiver,name,present)=>mlnSync.push([receiver,name,present]));0')!
	assert runtime.evaluate_host(r'(()=>{let conversions=0,traps=0;const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};const revoked=Proxy.revocable(mlnVideo,{});revoked.revoke();const proxy=new Proxy(mlnVideo,{get(){traps++;throw "proxy"}});for(const receiver of [proxy,revoked.proxy,Object.create(HTMLMediaElement.prototype)])for(const operation of [()=>mlnDescriptor.get.call(receiver),()=>mlnDescriptor.set.call(receiver,value)]){try{operation();return false}catch(error){if(!(error instanceof TypeError))return false}}return conversions===0&&traps===0})()')! == 'true'
	assert probe.replays == 0
	observed.mode = 1
	assert runtime.evaluate_host('mlnVideo.loop===false')! == 'true'
	assert !media.loop()
	first := mln_attr(element, mln_first)!
	element.set_attribute_ns_for_bindings(mln_second, 'loop', 'foreign second')!
	element.set_attribute_ns_for_bindings(mln_prefixed, 'p:loop', 'prefixed foreign')!
	second := mln_attr(element, mln_second)!
	prefixed := mln_attr(element, mln_prefixed)!
	observed.mode = 2
	assert runtime.evaluate_host('mlnVideo.loop===true')! == 'true'
	original := mln_attr(element, none)!
	assert media.loop() && original.value() == 'replayed null'
	observed.mode = 3
	assert runtime.evaluate_host('mlnVideo.loop===false')! == 'true'
	assert !media.loop() && original.owner_element() == none
	observed.mode = 2
	assert runtime.evaluate_host('mlnDescriptor.set.call(mlnVideo,false)===undefined')! == 'true'
	assert !media.loop() && observed.inserted.owner_element() == none && !element.has_attribute_ns(none, 'loop')
	mln_foreign_intact(element, first, second, prefixed)!
	observed.mode = 1
	assert runtime.evaluate_host('mlnDescriptor.set.call(mlnVideo,{[Symbol.toPrimitive](){throw "conversion"}})===undefined')! == 'true'
	null_attr := mln_attr(element, none)!
	assert media.loop() && null_attr.value() == '' && probe.replays == 5
	observed.mode = 4
	assert runtime.evaluate_host(r'(()=>{for(const operation of [()=>mlnDescriptor.get.call(mlnVideo),()=>mlnDescriptor.set.call(mlnVideo,false)]){try{operation();return false}catch(error){if(error!==mlnReplayReason)return false}}return mlnSync.length===2&&mlnSync[0][0]===mlnVideo&&mlnSync[0][1]==="loop"&&mlnSync[0][2]===false&&mlnSync[1][2]===true})()')! == 'true'
	assert probe.replays == 7 && voidptr(mln_attr(element, none)!) == voidptr(null_attr) && null_attr.value() == ''
	mln_foreign_intact(element, first, second, prefixed)!
	assert media.loop()
	assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
	for name in ['volumechange', 'play', 'pause', 'loadstart'] { assert media.event_count(name) == 0 }
}
