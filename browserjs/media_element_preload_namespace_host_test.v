module browserjs

import dom
import html

const mpln_first = 'urn:preload-first'
const mpln_second = 'urn:preload-second'
const mpln_prefixed = 'urn:preload-prefixed'

@[heap]
struct MplnProbe {
mut:
	replays int
	mode int
	fetches int
	volume_updates []f64
	element &dom.Element = unsafe { nil }
}

fn mpln_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &dom.Document) {
	address := dom.URL{ value: 'https://preload-namespace.example.test/' }
	mut document := html.parse_navigation_document('<!doctype html><video id="mpln-video-first"></video><video id="mpln-video-last"></video><audio id="mpln-audio-first"></audio><audio id="mpln-audio-last"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	_ = runtime.evaluate_host('globalThis.mplnPlayers={};0')!
	for key, element in host.elements_for_binding() {
		if element.local_name() !in ['audio', 'video'] { continue }
		id := element.get_attribute('id') or { return error('Missing preload namespace ID') }
		_ = runtime.evaluate_host('mplnPlayers["${id}"]={};__ladybirdMediaElementBind(mplnPlayers["${id}"],"${key}","${element.local_name()}");0')!
	}
	return runtime, host, document
}

fn mpln_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing preload namespace element ${id}') }
}

fn mpln_attr(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'preload') or { return error('Missing preload namespace attribute') }
}

fn mpln_foreign_intact(element &dom.Element, first &dom.Attr_, second &dom.Attr_, prefixed &dom.Attr_) ! {
	for index, attribute in [first, second, prefixed] {
		namespace := [mpln_first, mpln_second, mpln_prefixed][index]
		owner := attribute.owner_element() or { return error('Foreign preload attribute lost its owner') }
		actual_namespace := attribute.namespace_uri() or { return error('Foreign preload attribute lost its namespace') }
		assert voidptr(owner) == voidptr(element) && actual_namespace == namespace
		assert voidptr(mpln_attr(element, namespace)!) == voidptr(attribute) && attribute.local_name() == 'preload'
	}
	assert first.value() == 'none' && second.value() == 'auto'
	assert first.name() == 'preload' && second.name() == 'preload'
	assert first.prefix() == none && second.prefix() == none
	assert prefixed.value() == 'metadata' && prefixed.name() == 'p:preload'
	prefix := prefixed.prefix() or { return error('Foreign preload attribute lost its prefix') }
	assert prefix == 'p'
}

fn test_native_preload_namespace_reads_canonical_null_slot_and_preserves_raw_writes_and_foreign_identity() {
	$if !darwin { return }
	mut runtime, _, mut document := mpln_fixture(none)!
	defer { runtime.close(); document.finalize() }
	probe := &MplnProbe{}
	for index, id in ['mpln-video-first', 'mpln-video-last', 'mpln-audio-first', 'mpln-audio-last'] {
		mut element := mpln_element(document, id)!
		if index % 2 == 0 { element.set_attribute_value('preload', 'AuTo') }
		element.set_attribute_ns_for_bindings(mpln_first, 'preload', 'none')!
		element.set_attribute_ns_for_bindings(mpln_second, 'preload', 'auto')!
		element.set_attribute_ns_for_bindings(mpln_prefixed, 'p:preload', 'metadata')!
		if index % 2 == 1 { element.set_attribute_value('preload', 'AuTo') }
		first := mpln_attr(element, mpln_first)!
		second := mpln_attr(element, mpln_second)!
		prefixed := mpln_attr(element, mpln_prefixed)!
		original := mpln_attr(element, none)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing preload namespace model') }
		media.set_current_time(f64(index) + 3.25)
		media.set_paused(index % 2 == 0)
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !html.MediaResourceResponse {
			mut observed := unsafe { &MplnProbe(probe) }; observed.fetches++
			return error('source-less preload namespace reflection must not fetch')
		})
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			set_volume: fn [probe] (volume f64) {
				mut observed := unsafe { &MplnProbe(probe) }; observed.volume_updates << volume
			}
		})
		player := 'mplnPlayers["${id}"]'
		assert runtime.evaluate_host('${player}.preload==="auto"')! == 'true'
		assert media.preload() == 'auto' && original.value() == 'AuTo'
		for raw in ['nOnE', 'MeTaDaTa', '', 'invalid', ' none ', 'AUTO'] {
			canonical := if raw == 'nOnE' { 'none' } else if raw == 'AUTO' { 'auto' } else { 'metadata' }
			assert runtime.evaluate_host('${player}.preload="${raw}";${player}.preload==="${canonical}"')! == 'true'
			assert media.preload() == canonical && original.value() == raw
			assert voidptr(mpln_attr(element, none)!) == voidptr(original)
			mpln_foreign_intact(element, first, second, prefixed)!
		}
		element.set_attribute_value('preload', 'nOnE')
		assert runtime.evaluate_host('${player}.preload==="none"')! == 'true'
		assert media.preload() == 'none' && original.value() == 'nOnE'
		element.remove_attribute_ns(none, 'preload')
		assert runtime.evaluate_host('${player}.preload==="metadata"')! == 'true'
		assert media.preload() == 'metadata' && original.owner_element() == none
		assert element.has_attribute('preload') && element.get_attribute('preload')? == 'none'
		media.set_preload(none)
		assert !element.has_attribute_ns(none, 'preload') && media.preload() == 'metadata'
		mpln_foreign_intact(element, first, second, prefixed)!
		assert !media.muted() && media.volume() == 1 && media.current_time() == f64(index) + 3.25
		assert media.paused() == (index % 2 == 0) && media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['volumechange', 'play', 'playing', 'pause', 'loadstart', 'seeking'] { assert media.event_count(name) == 0 }
	}
	assert probe.fetches == 0 && probe.volume_updates == []
}

fn test_native_preload_namespace_orders_conversion_replay_and_preserves_slots_after_abrupt_completion() {
	$if !darwin { return }
	probe := &MplnProbe{}
	mut runtime, _, mut document := mpln_fixture(fn [probe] (runtime &Runtime) ! {
		mut observed := unsafe { &MplnProbe(probe) }; observed.replays++
		_ = runtime.evaluate_host('mplnOrder.push("replay");0')!
		mut element := unsafe { &dom.Element(observed.element) }
		match observed.mode {
			1 { element.set_attribute_ns_for_bindings(mpln_first, 'preload', 'none')! }
			2 { element.set_attribute_value('preload', 'nOnE') }
			3 { element.remove_attribute_ns(none, 'preload') }
			4 {
				mut owner := unsafe { &Runtime(runtime) }
				_ = owner.evaluate_host_value('throw mplnReplayReason')!
			}
			else {}
		}
	})!
	defer { runtime.close(); document.finalize() }
	mut observed := unsafe { &MplnProbe(probe) }
	mut element := mpln_element(document, 'mpln-video-first')!
	observed.element = element
	media := html.html_media_element_for_dom_element(element) or { panic('Missing preload replay model') }
	_ = runtime.evaluate_host(r'globalThis.mplnVideo=mplnPlayers["mpln-video-first"];globalThis.mplnSync=[];globalThis.mplnOrder=[];globalThis.mplnConversions=0;globalThis.mplnReplayReason={};globalThis.mplnConversionReason={};globalThis.mplnDescriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"preload");__ladybirdMediaElementSetAttributeSync((receiver,name,value)=>{mplnOrder.push("sync");mplnSync.push([receiver,name,value])});0')!
	assert runtime.evaluate_host(r'(()=>{let conversions=0,traps=0;const value={[Symbol.toPrimitive](){conversions++;throw "conversion"}};const revoked=Proxy.revocable(mplnVideo,{});revoked.revoke();const proxy=new Proxy(mplnVideo,{get(){traps++;throw "proxy"}});for(const receiver of [proxy,revoked.proxy,Object.create(HTMLMediaElement.prototype)])for(const operation of [()=>mplnDescriptor.get.call(receiver),()=>mplnDescriptor.set.call(receiver,value)]){try{operation();return false}catch(error){if(!(error instanceof TypeError))return false}}return conversions===0&&traps===0})()')! == 'true'
	assert probe.replays == 0
	observed.mode = 1
	assert runtime.evaluate_host('mplnVideo.preload==="metadata"')! == 'true'
	assert media.preload() == 'metadata'
	first := mpln_attr(element, mpln_first)!
	element.set_attribute_ns_for_bindings(mpln_second, 'preload', 'auto')!
	element.set_attribute_ns_for_bindings(mpln_prefixed, 'p:preload', 'metadata')!
	second := mpln_attr(element, mpln_second)!
	prefixed := mpln_attr(element, mpln_prefixed)!
	observed.mode = 2
	assert runtime.evaluate_host('mplnVideo.preload==="none"')! == 'true'
	original := mpln_attr(element, none)!
	assert media.preload() == 'none' && original.value() == 'nOnE'
	observed.mode = 3
	assert runtime.evaluate_host('mplnVideo.preload==="metadata"')! == 'true'
	assert original.owner_element() == none && media.preload() == 'metadata'
	observed.mode = 1
	assert runtime.evaluate_host(r'(()=>{mplnOrder.length=0;const value={[Symbol.toPrimitive](hint){mplnConversions++;mplnOrder.push("convert:"+hint);return "AuTo"}};if(mplnDescriptor.set.call(mplnVideo,value)!==undefined||mplnOrder.join(",")!=="convert:string,replay,sync")return false;return mplnConversions===1&&mplnVideo.preload==="auto"})()')! == 'true'
	null_attr := mpln_attr(element, none)!
	assert null_attr.value() == 'AuTo' && media.preload() == 'auto' && probe.replays == 5
	observed.mode = 4
	assert runtime.evaluate_host(r'(()=>{try{mplnDescriptor.set.call(mplnVideo,{[Symbol.toPrimitive](){throw mplnConversionReason}});return false}catch(error){if(error!==mplnConversionReason)return false}try{mplnDescriptor.set.call(mplnVideo,Symbol());return false}catch(error){if(!(error instanceof TypeError))return false}mplnOrder.length=0;for(const operation of [()=>mplnDescriptor.get.call(mplnVideo),()=>mplnDescriptor.set.call(mplnVideo,{[Symbol.toPrimitive](hint){mplnOrder.push("convert:"+hint);return "none"}})]){try{operation();return false}catch(error){if(error!==mplnReplayReason)return false}}return mplnOrder.join(",")==="replay,convert:string,replay"&&mplnSync.length===1&&mplnSync[0][0]===mplnVideo&&mplnSync[0][1]==="preload"&&mplnSync[0][2]==="AuTo"})()')! == 'true'
	assert probe.replays == 7 && voidptr(mpln_attr(element, none)!) == voidptr(null_attr)
	assert null_attr.value() == 'AuTo' && media.preload() == 'auto'
	mpln_foreign_intact(element, first, second, prefixed)!
	assert !media.muted() && media.volume() == 1 && media.paused() && media.current_time() == 0
	for name in ['volumechange', 'play', 'playing', 'pause', 'loadstart'] { assert media.event_count(name) == 0 }
}
