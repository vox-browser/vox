module browserjs

import dom
import html
import webcrypto
import webidl

fn source_platform_clone_fixture() (&Runtime, &html.EnvironmentSettingsObject) {
	document := html.parse_document_with_url('<!doctype html><body>clone</body>', dom.URL{'https://clone-platform.example/'})
	_ := html.WindowModel.create_top_level(document, none, 'clone-platform') or { panic(err) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	runtime.evaluate_host('globalThis.document={}') or { panic(err) }
	mut font := FontFaceHost.create(document)
	font.install(mut runtime) or { panic(err) }
	mut transform := TransformStreamHost.create(document) or { panic(err) }
	transform.install(mut runtime) or { panic(err) }
	mut strategy := QueuingStrategyHost.create(document) or { panic(err) }
	strategy.install(mut runtime) or { panic(err) }
	mut crypto := CryptoHost.create(document) or { panic(err) }
	crypto.install(mut runtime) or { panic(err) }
	return runtime, settings
}

fn test_native_clone_source_platform_gate_precedes_enumerable_gets_for_actual_wrappers() {
	$if !darwin {
		return
	}
	mut runtime, _ := source_platform_clone_fixture()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	for expression in ['new EventTarget()', 'new Event("event")', 'new AbortController()',
		'new AbortController().signal', 'new ReadableStream()', 'new ReadableStream().getReader()',
		'(()=>{let controller;new ReadableStream({start(value){controller=value}});return controller})()',
		'(()=>{let controller;new ReadableStream({type:"bytes",start(value){controller=value}});return controller})()',
		'new ReadableStream({type:"bytes"}).getReader({mode:"byob"})', 'new WritableStream()',
		'new WritableStream().getWriter()', 'new TransformStream()',
		'(()=>{let controller;new WritableStream({start(value){controller=value}});return controller})()',
		'(()=>{let controller;new TransformStream({start(value){controller=value}});return controller})()',
		'new CountQueuingStrategy({highWaterMark:1})',
		'new ByteLengthQueuingStrategy({highWaterMark:1})',
		'new FontFace("Source Face","url(unfetched.ttf)")', 'document.fonts', 'crypto', 'crypto.subtle'] {
		actual := runtime.evaluate_host_value('globalThis.__platformCloneGetCount=0;globalThis.__platformCloneValue=(' + expression + ');Object.defineProperty(__platformCloneValue,"author",{enumerable:true,get(){++__platformCloneGetCount;throw "wrong source branch"}});__platformCloneValue')!
		for for_storage in [false, true] {
			if _ := bridge.serialize(actual, for_storage) {
				assert false
			} else {
				exception := webidl.exception_value(err).dom_exception_?
				assert exception.name() == 'DataCloneError'
				assert exception.message() == 'Cannot serialize platform objects'
			}
			assert runtime.evaluate_host('__platformCloneGetCount')! == '0'
		}
	}
}

fn test_native_clone_actual_serializable_crypto_key_enters_primary_payload_before_platform_rejection() {
	$if !darwin { return }
	mut runtime, _ := source_platform_clone_fixture()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	key := webcrypto.CryptoKey.create(.secret, true, webcrypto.AesKeyAlgorithm{name: 'AES-GCM', length: 128}, [.encrypt], []u8{len: 16})
	actual := runtime.javascript_crypto_key(key)!
	for for_storage in [false, true] {
		record := bridge.serialize(actual, for_storage)!
		cloned := bridge.deserialize(record)!
		native := runtime.native_crypto_key(cloned)!
		assert cloned != actual
		assert voidptr(native) != voidptr(key)
		assert native.algorithm_name() == 'AES-GCM'
		assert native.internal_usages() == [.encrypt]
		assert native.handle() == key.handle()
	}
}

fn test_native_clone_platform_identity_cannot_be_forged_with_prototypes_or_author_tags() {
	$if !darwin {
		return
	}
	mut runtime, _ := source_platform_clone_fixture()
	bridge := StructuredCloneBridge.create(runtime)!
	for expression in ['Object.create(EventTarget.prototype)', 'Object.create(Event.prototype)',
		'Object.create(FontFace.prototype)', 'Object.create(ReadableStream.prototype)',
		'Object.create(CryptoKey.prototype)', '({[Symbol.toStringTag]:"FontFace",field:7})'] {
		actual := runtime.evaluate_host_value(expression)!
		cloned := bridge.deserialize(bridge.serialize(actual, false)!)!
		// It is an ordinary cloned source object, not a genuine native platform
		// record; own Symbol keys are omitted by the source key list.
		assert runtime.native_stream_wrapper_record(cloned) == unsafe { nil }
	}
	assert runtime.native_clone_font_face_host() != none
	runtime.close()
	assert runtime.native_clone_font_face_host() == none
}
