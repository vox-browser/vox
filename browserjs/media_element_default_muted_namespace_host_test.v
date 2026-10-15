module browserjs

import dom
import html

const mdmn_first = 'urn:default-muted-first'
const mdmn_second = 'urn:default-muted-second'
const mdmn_prefixed = 'urn:default-muted-prefixed'

@[heap]
struct MdmnProbe {
mut:
	replays int
	mode int
	fetches int
	volume_updates []f64
	element &dom.Element = unsafe { nil }
	inserted &dom.Attr_ = unsafe { nil }
}

fn mdmn_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document) {
	address := dom.URL{ value: 'https://default-muted-namespace.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="mdmn-video-first"></video><video id="mdmn-video-last"></video><audio id="mdmn-audio-first"></audio><audio id="mdmn-audio-last"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	_ = runtime.evaluate_host('globalThis.mdmnPlayers={};0')!
	for key, element in host.elements_for_binding() {
		if element.local_name() !in ['audio', 'video'] { continue }
		id := element.get_attribute('id') or { return error('Missing defaultMuted namespace ID') }
		_ = runtime.evaluate_host('mdmnPlayers["${id}"]={};__ladybirdMediaElementBind(mdmnPlayers["${id}"],"${key}","${element.local_name()}");0')!
	}
	return runtime, host, document
}

fn mdmn_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing defaultMuted namespace element ${id}') }
}

fn mdmn_attr(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'muted') or { return error('Missing defaultMuted namespace attribute') }
}

fn mdmn_foreign_intact(element &dom.Element, first &dom.Attr_, second &dom.Attr_, prefixed &dom.Attr_) ! {
	for index, attribute in [first, second, prefixed] {
		namespace := [mdmn_first, mdmn_second, mdmn_prefixed][index]
		owner := attribute.owner_element() or { return error('Foreign muted attribute lost its owner') }
		actual_namespace := attribute.namespace_uri() or { return error('Foreign muted attribute lost its namespace') }
		assert voidptr(owner) == voidptr(element) && actual_namespace == namespace
		assert voidptr(mdmn_attr(element, namespace)!) == voidptr(attribute)
		assert attribute.local_name() == 'muted'
	}
	assert first.value() == 'foreign first' && second.value() == 'foreign second'
	assert first.name() == 'muted' && second.name() == 'muted'
	assert first.prefix() == none && second.prefix() == none
	assert prefixed.value() == 'prefixed foreign' && prefixed.name() == 'p:muted'
	prefix := prefixed.prefix() or { return error('Foreign muted attribute lost its prefix') }
	assert prefix == 'p'
}

fn test_native_default_muted_namespace_slot_preserves_duplicate_attributes_in_both_orders() {
	$if !darwin { return }
	mut runtime, _, mut document := mdmn_fixture(none)!
	defer { runtime.close(); document.finalize() }
	probe := &MdmnProbe{}
	for index, id in ['mdmn-video-first', 'mdmn-video-last', 'mdmn-audio-first', 'mdmn-audio-last'] {
		mut element := mdmn_element(document, id)!
		if index % 2 == 0 { element.set_attribute_value('muted', 'initial null') }
		element.set_attribute_ns_for_bindings(mdmn_first, 'muted', 'foreign first')!
		element.set_attribute_ns_for_bindings(mdmn_second, 'muted', 'foreign second')!
		element.set_attribute_ns_for_bindings(mdmn_prefixed, 'p:muted', 'prefixed foreign')!
		if index % 2 == 1 { element.set_attribute_value('muted', 'initial null') }
		first := mdmn_attr(element, mdmn_first)!
		second := mdmn_attr(element, mdmn_second)!
		prefixed := mdmn_attr(element, mdmn_prefixed)!
		original := mdmn_attr(element, none)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing defaultMuted namespace model') }
		media.set_current_time(f64(index) + 3.25)
		media.set_paused(index % 2 == 0)
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MdmnProbe(probe) }; observed.fetches++
			return error('defaultMuted namespace reflection must not fetch')
		})
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			set_volume: fn [probe] (volume f64) {
				mut observed := unsafe { &MdmnProbe(probe) }; observed.volume_updates << volume
			}
		})
		player := 'mdmnPlayers["${id}"]'
		assert runtime.evaluate_host('${player}.defaultMuted===true')! == 'true'
		assert original.value() == 'initial null'
		assert runtime.evaluate_host('${player}.defaultMuted=false;${player}.defaultMuted===false')! == 'true'
		assert !element.has_attribute_ns(none, 'muted') && original.owner_element() == none
		assert element.has_attribute('muted') && element.get_attribute('muted')? == 'foreign first'
		mdmn_foreign_intact(element, first, second, prefixed)!
		assert runtime.evaluate_host('${player}.defaultMuted=false;${player}.defaultMuted===false')! == 'true'
		mdmn_foreign_intact(element, first, second, prefixed)!
		assert runtime.evaluate_host('${player}.defaultMuted=true;${player}.defaultMuted===true')! == 'true'
		normalized := mdmn_attr(element, none)!
		assert normalized.value() == '' && normalized.namespace_uri() == none && normalized.prefix() == none
		assert voidptr(normalized) != voidptr(original)
		element.set_attribute_value('muted', 'direct null value')
		assert runtime.evaluate_host('${player}.defaultMuted===true')! == 'true'
		assert normalized.value() == 'direct null value'
		assert runtime.evaluate_host('${player}.defaultMuted=true;${player}.defaultMuted===true')! == 'true'
		assert voidptr(mdmn_attr(element, none)!) == voidptr(normalized) && normalized.value() == ''
		element.remove_attribute_ns(none, 'muted')
		assert runtime.evaluate_host('${player}.defaultMuted===false')! == 'true'
		assert normalized.owner_element() == none
		mdmn_foreign_intact(element, first, second, prefixed)!
		assert !media.muted() && media.volume() == 1 && media.current_time() == f64(index) + 3.25
		assert media.paused() == (index % 2 == 0) && media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['volumechange', 'play', 'pause', 'loadstart', 'seeking'] { assert media.event_count(name) == 0 }
	}
	assert probe.fetches == 0 && probe.volume_updates == []
}

fn test_native_default_muted_namespace_getter_observes_replay_and_replay_failure_preserves_slots() {
	$if !darwin { return }
	probe := &MdmnProbe{}
	mut runtime, _, mut document := mdmn_fixture(fn [probe] (runtime &Runtime) ! {
		mut observed := unsafe { &MdmnProbe(probe) }; observed.replays++
		mut element := unsafe { &dom.Element(observed.element) }
		match observed.mode {
			1 { element.set_attribute_ns_for_bindings(mdmn_first, 'muted', 'foreign first')! }
			2 {
				element.set_attribute_value('muted', 'replayed null')
				observed.inserted = mdmn_attr(element, none)!
			}
			3 { element.remove_attribute_ns(none, 'muted') }
			4 {
				mut owner := unsafe { &Runtime(runtime) }
				_ = owner.evaluate_host_value('throw mdmnReplayReason')!
			}
			else {}
		}
	})!
	defer { runtime.close(); document.finalize() }
	mut observed := unsafe { &MdmnProbe(probe) }
	mut element := mdmn_element(document, 'mdmn-video-first')!
	observed.element = element
	_ = runtime.evaluate_host(r'globalThis.mdmnVideo=mdmnPlayers["mdmn-video-first"];globalThis.mdmnSync=[];globalThis.mdmnReplayReason={};globalThis.mdmnDescriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"defaultMuted");__ladybirdMediaElementSetAttributeSync((receiver,name,present)=>mdmnSync.push([receiver,name,present]));0')!
	assert runtime.evaluate_host(r'(()=>{let conversions=0,traps=0;const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};const revoked=Proxy.revocable(mdmnVideo,{});revoked.revoke();const proxy=new Proxy(mdmnVideo,{get(){traps++;throw "proxy"}});for(const receiver of [proxy,revoked.proxy,Object.create(HTMLMediaElement.prototype)])for(const operation of [()=>mdmnDescriptor.get.call(receiver),()=>mdmnDescriptor.set.call(receiver,value)]){try{operation();return false}catch(error){if(!(error instanceof TypeError))return false}}return conversions===0&&traps===0})()')! == 'true'
	assert probe.replays == 0
	observed.mode = 1
	assert runtime.evaluate_host('mdmnVideo.defaultMuted===false')! == 'true'
	first := mdmn_attr(element, mdmn_first)!
	element.set_attribute_ns_for_bindings(mdmn_second, 'muted', 'foreign second')!
	element.set_attribute_ns_for_bindings(mdmn_prefixed, 'p:muted', 'prefixed foreign')!
	second := mdmn_attr(element, mdmn_second)!
	prefixed := mdmn_attr(element, mdmn_prefixed)!
	observed.mode = 2
	assert runtime.evaluate_host('mdmnVideo.defaultMuted===true')! == 'true'
	original := mdmn_attr(element, none)!
	assert original.value() == 'replayed null'
	observed.mode = 3
	assert runtime.evaluate_host('mdmnVideo.defaultMuted===false')! == 'true'
	assert original.owner_element() == none
	observed.mode = 2
	assert runtime.evaluate_host('mdmnDescriptor.set.call(mdmnVideo,false)===undefined')! == 'true'
	assert observed.inserted.owner_element() == none && !element.has_attribute_ns(none, 'muted')
	mdmn_foreign_intact(element, first, second, prefixed)!
	observed.mode = 1
	assert runtime.evaluate_host('mdmnDescriptor.set.call(mdmnVideo,{[Symbol.toPrimitive](){throw "conversion"}})===undefined')! == 'true'
	null_attr := mdmn_attr(element, none)!
	assert null_attr.value() == '' && probe.replays == 5
	observed.mode = 4
	assert runtime.evaluate_host(r'(()=>{for(const operation of [()=>mdmnDescriptor.get.call(mdmnVideo),()=>mdmnDescriptor.set.call(mdmnVideo,false)]){try{operation();return false}catch(error){if(error!==mdmnReplayReason)return false}}return mdmnSync.length===2&&mdmnSync[0][0]===mdmnVideo&&mdmnSync[0][1]==="muted"&&mdmnSync[0][2]===false&&mdmnSync[1][2]===true})()')! == 'true'
	assert probe.replays == 7 && voidptr(mdmn_attr(element, none)!) == voidptr(null_attr) && null_attr.value() == ''
	mdmn_foreign_intact(element, first, second, prefixed)!
	media := html.html_media_element_for_dom_element(element) or { panic('Missing replay namespace model') }
	assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
	for name in ['volumechange', 'play', 'pause', 'loadstart'] { assert media.event_count(name) == 0 }
}
