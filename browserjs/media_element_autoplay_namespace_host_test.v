module browserjs

import dom
import html

const mapn_first = 'urn:autoplay-first'
const mapn_second = 'urn:autoplay-second'
const mapn_prefixed = 'urn:autoplay-prefixed'

@[heap]
struct MapnProbe {
mut:
	replays int
	mode int
	fetches int
	volume_updates []f64
	element &dom.Element = unsafe { nil }
	inserted &dom.Attr_ = unsafe { nil }
}

fn mapn_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document) {
	address := dom.URL{ value: 'https://autoplay-namespace.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="mapn-video-first"></video><video id="mapn-video-last"></video><audio id="mapn-audio-first"></audio><audio id="mapn-audio-last"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	_ = runtime.evaluate_host('globalThis.mapnPlayers={};0')!
	for key, element in host.elements_for_binding() {
		if element.local_name() !in ['audio', 'video'] { continue }
		id := element.get_attribute('id') or { return error('Missing autoplay namespace ID') }
		_ = runtime.evaluate_host('mapnPlayers["${id}"]={};__ladybirdMediaElementBind(mapnPlayers["${id}"],"${key}","${element.local_name()}");0')!
	}
	return runtime, host, document
}

fn mapn_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing autoplay namespace element ${id}') }
}

fn mapn_attr(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'autoplay') or { return error('Missing autoplay namespace attribute') }
}

fn mapn_foreign_intact(element &dom.Element, first &dom.Attr_, second &dom.Attr_, prefixed &dom.Attr_) ! {
	for index, attribute in [first, second, prefixed] {
		namespace := [mapn_first, mapn_second, mapn_prefixed][index]
		owner := attribute.owner_element() or { return error('Foreign autoplay attribute lost its owner') }
		actual_namespace := attribute.namespace_uri() or { return error('Foreign autoplay attribute lost its namespace') }
		assert voidptr(owner) == voidptr(element) && actual_namespace == namespace
		assert voidptr(mapn_attr(element, namespace)!) == voidptr(attribute)
		assert attribute.local_name() == 'autoplay'
	}
	assert first.value() == 'foreign first' && second.value() == 'foreign second'
	assert first.name() == 'autoplay' && second.name() == 'autoplay'
	assert first.prefix() == none && second.prefix() == none
	assert prefixed.value() == 'prefixed foreign' && prefixed.name() == 'p:autoplay'
	prefix := prefixed.prefix() or { return error('Foreign autoplay attribute lost its prefix') }
	assert prefix == 'p'
}

fn test_native_autoplay_namespace_slot_preserves_duplicate_attributes_in_both_orders() {
	$if !darwin { return }
	mut runtime, _, mut document := mapn_fixture(none)!
	defer { runtime.close(); document.finalize() }
	probe := &MapnProbe{}
	for index, id in ['mapn-video-first', 'mapn-video-last', 'mapn-audio-first', 'mapn-audio-last'] {
		mut element := mapn_element(document, id)!
		if index % 2 == 0 { element.set_attribute_value('autoplay', 'initial null') }
		element.set_attribute_ns_for_bindings(mapn_first, 'autoplay', 'foreign first')!
		element.set_attribute_ns_for_bindings(mapn_second, 'autoplay', 'foreign second')!
		element.set_attribute_ns_for_bindings(mapn_prefixed, 'p:autoplay', 'prefixed foreign')!
		if index % 2 == 1 { element.set_attribute_value('autoplay', 'initial null') }
		first := mapn_attr(element, mapn_first)!
		second := mapn_attr(element, mapn_second)!
		prefixed := mapn_attr(element, mapn_prefixed)!
		original := mapn_attr(element, none)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing autoplay namespace model') }
		media.set_current_time(f64(index) + 3.25)
		media.set_paused(index % 2 == 0)
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MapnProbe(probe) }; observed.fetches++
			return error('autoplay namespace reflection must not fetch')
		})
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			set_volume: fn [probe] (volume f64) {
				mut observed := unsafe { &MapnProbe(probe) }; observed.volume_updates << volume
			}
		})
		player := 'mapnPlayers["${id}"]'
		assert runtime.evaluate_host('${player}.autoplay===true')! == 'true'
		assert media.autoplay() && original.value() == 'initial null'
		assert runtime.evaluate_host('${player}.autoplay=false;${player}.autoplay===false')! == 'true'
		assert !media.autoplay() && !element.has_attribute_ns(none, 'autoplay') && original.owner_element() == none
		assert element.has_attribute('autoplay') && element.get_attribute('autoplay')? == 'foreign first'
		mapn_foreign_intact(element, first, second, prefixed)!
		assert runtime.evaluate_host('${player}.autoplay=false;${player}.autoplay===false')! == 'true'
		mapn_foreign_intact(element, first, second, prefixed)!
		assert runtime.evaluate_host('${player}.autoplay=true;${player}.autoplay===true')! == 'true'
		normalized := mapn_attr(element, none)!
		assert media.autoplay() && normalized.value() == '' && normalized.namespace_uri() == none && normalized.prefix() == none
		assert voidptr(normalized) != voidptr(original)
		element.set_attribute_value('autoplay', 'direct null value')
		assert runtime.evaluate_host('${player}.autoplay===true')! == 'true'
		assert media.autoplay() && normalized.value() == 'direct null value'
		assert runtime.evaluate_host('${player}.autoplay=true;${player}.autoplay===true')! == 'true'
		assert voidptr(mapn_attr(element, none)!) == voidptr(normalized) && normalized.value() == ''
		element.remove_attribute_ns(none, 'autoplay')
		assert runtime.evaluate_host('${player}.autoplay===false')! == 'true'
		assert !media.autoplay() && normalized.owner_element() == none
		mapn_foreign_intact(element, first, second, prefixed)!
		assert !media.muted() && media.volume() == 1 && media.current_time() == f64(index) + 3.25
		assert media.paused() == (index % 2 == 0) && media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['volumechange', 'play', 'playing', 'pause', 'loadstart', 'seeking'] { assert media.event_count(name) == 0 }
	}
	assert probe.fetches == 0 && probe.volume_updates == []
}

fn test_native_autoplay_namespace_getter_observes_replay_and_replay_failure_preserves_slots() {
	$if !darwin { return }
	probe := &MapnProbe{}
	mut runtime, _, mut document := mapn_fixture(fn [probe] (runtime &Runtime) ! {
		mut observed := unsafe { &MapnProbe(probe) }; observed.replays++
		mut element := unsafe { &dom.Element(observed.element) }
		match observed.mode {
			1 { element.set_attribute_ns_for_bindings(mapn_first, 'autoplay', 'foreign first')! }
			2 {
				element.set_attribute_value('autoplay', 'replayed null')
				observed.inserted = mapn_attr(element, none)!
			}
			3 { element.remove_attribute_ns(none, 'autoplay') }
			4 {
				mut owner := unsafe { &Runtime(runtime) }
				_ = owner.evaluate_host_value('throw mapnReplayReason')!
			}
			else {}
		}
	})!
	defer { runtime.close(); document.finalize() }
	mut observed := unsafe { &MapnProbe(probe) }
	mut element := mapn_element(document, 'mapn-video-first')!
	observed.element = element
	media := html.html_media_element_for_dom_element(element) or { panic('Missing replay namespace model') }
	_ = runtime.evaluate_host(r'globalThis.mapnVideo=mapnPlayers["mapn-video-first"];globalThis.mapnSync=[];globalThis.mapnReplayReason={};globalThis.mapnDescriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"autoplay");__ladybirdMediaElementSetAttributeSync((receiver,name,present)=>mapnSync.push([receiver,name,present]));0')!
	assert runtime.evaluate_host(r'(()=>{let conversions=0,traps=0;const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};const revoked=Proxy.revocable(mapnVideo,{});revoked.revoke();const proxy=new Proxy(mapnVideo,{get(){traps++;throw "proxy"}});for(const receiver of [proxy,revoked.proxy,Object.create(HTMLMediaElement.prototype)])for(const operation of [()=>mapnDescriptor.get.call(receiver),()=>mapnDescriptor.set.call(receiver,value)]){try{operation();return false}catch(error){if(!(error instanceof TypeError))return false}}return conversions===0&&traps===0})()')! == 'true'
	assert probe.replays == 0
	observed.mode = 1
	assert runtime.evaluate_host('mapnVideo.autoplay===false')! == 'true'
	assert !media.autoplay()
	first := mapn_attr(element, mapn_first)!
	element.set_attribute_ns_for_bindings(mapn_second, 'autoplay', 'foreign second')!
	element.set_attribute_ns_for_bindings(mapn_prefixed, 'p:autoplay', 'prefixed foreign')!
	second := mapn_attr(element, mapn_second)!
	prefixed := mapn_attr(element, mapn_prefixed)!
	observed.mode = 2
	assert runtime.evaluate_host('mapnVideo.autoplay===true')! == 'true'
	original := mapn_attr(element, none)!
	assert media.autoplay() && original.value() == 'replayed null'
	observed.mode = 3
	assert runtime.evaluate_host('mapnVideo.autoplay===false')! == 'true'
	assert !media.autoplay() && original.owner_element() == none
	observed.mode = 2
	assert runtime.evaluate_host('mapnDescriptor.set.call(mapnVideo,false)===undefined')! == 'true'
	assert !media.autoplay() && observed.inserted.owner_element() == none && !element.has_attribute_ns(none, 'autoplay')
	mapn_foreign_intact(element, first, second, prefixed)!
	observed.mode = 1
	assert runtime.evaluate_host('mapnDescriptor.set.call(mapnVideo,{[Symbol.toPrimitive](){throw "conversion"}})===undefined')! == 'true'
	null_attr := mapn_attr(element, none)!
	assert media.autoplay() && null_attr.value() == '' && probe.replays == 5
	observed.mode = 4
	assert runtime.evaluate_host(r'(()=>{for(const operation of [()=>mapnDescriptor.get.call(mapnVideo),()=>mapnDescriptor.set.call(mapnVideo,false)]){try{operation();return false}catch(error){if(error!==mapnReplayReason)return false}}return mapnSync.length===2&&mapnSync[0][0]===mapnVideo&&mapnSync[0][1]==="autoplay"&&mapnSync[0][2]===false&&mapnSync[1][2]===true})()')! == 'true'
	assert probe.replays == 7 && voidptr(mapn_attr(element, none)!) == voidptr(null_attr) && null_attr.value() == ''
	mapn_foreign_intact(element, first, second, prefixed)!
	assert media.autoplay()
	assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
	for name in ['volumechange', 'play', 'playing', 'pause', 'loadstart'] { assert media.event_count(name) == 0 }
}
