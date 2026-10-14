module browserjs

import dom
import html

@[heap]
struct MediaErrorGetterReplayProbe {
mut:
	reads int
}

fn media_error_getter_fixture(replay ?MediaElementReplayHook) !(&Runtime, &MediaElementHost, &html.HTMLMediaElement) {
	address := dom.URL{
		value: 'https://media-error-getter.example.test/'
	}
	document := html.parse_navigation_document('<video id="video"></video><audio id="audio"></audio>',
		address, address.origin(), none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, replay)!
	host.install(mut runtime)!
	for key, element in host.elements_for_binding() {
		if element.local_name() in ['video', 'audio'] {
			name := element.local_name()
			runtime.evaluate_host('globalThis.${name}={};__ladybirdMediaElementBind(${name},"${key}","${name}")')!
		}
	}
	element := document.get_element_by_id('video') or { return error('missing video') }
	media := html.html_media_element_for_dom_element(element) or {
		return error('missing media owner')
	}
	return runtime, host, media
}

fn test_native_media_error_getter_is_nullable_readonly_and_branded_before_replay() {
	$if !darwin { return }
	probe := &MediaErrorGetterReplayProbe{}
	mut runtime, _, mut media := media_error_getter_fixture(fn [probe] (_ &Runtime) ! {
		mut state := unsafe { &MediaErrorGetterReplayProbe(probe) }
		state.reads++
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"error");
 let traps=0;const proxy=new Proxy(video,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 return d.enumerable&&d.configurable&&d.set===undefined&&d.get.name==="get error"&&d.get.length===0&&Function.prototype.toString.call(d.get).includes("[native code]")&&
 [Object.create(HTMLMediaElement.prototype),proxy,null,undefined,1,{}].every(receiver=>{try{d.get.call(receiver);return false}catch(error){return error instanceof TypeError}})&&traps===0&&!Object.hasOwn(video,"error")&&!Reflect.set(video,"error",{})&&!("code" in video);
})()')! == 'true'
	assert probe.reads == 0
	assert runtime.evaluate_host('video.error===null&&audio.error===null')! == 'true'
	assert probe.reads == 2
	media.set_decoder_error('Decoder \x00 🎬 failed\r\n')
	assert runtime.evaluate_host(r'globalThis.savedMediaError=video.error;savedMediaError instanceof MediaError&&savedMediaError===video.error&&savedMediaError.code===3&&savedMediaError.message==="Decoder \u0000 🎬 failed\r\n"&&audio.error===null')! == 'true'
	assert probe.reads == 5
	actual := media.error() or { panic('missing native decoder error') }
	object := runtime.evaluate_host_value('savedMediaError')!
	assert voidptr(runtime.native_media_error(object)!) == voidptr(actual)
	media.set_decoder_error('ignored duplicate')
	assert runtime.evaluate_host(r'video.error===savedMediaError&&video.error.message==="Decoder \u0000 🎬 failed\r\n"')! == 'true'
}

fn test_native_media_error_interface_metadata_constants_and_exact_actual_records() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_media_error_binding()!
	runtime.install_media_error_binding()!
	assert runtime.evaluate_host(r'(()=>{
 const p=MediaError.prototype,d=Object.getOwnPropertyDescriptor;
 const constants={MEDIA_ERR_ABORTED:1,MEDIA_ERR_NETWORK:2,MEDIA_ERR_DECODE:3,MEDIA_ERR_SRC_NOT_SUPPORTED:4};
 const getters=["code","message"].every(name=>{const a=d(p,name);return a.enumerable&&a.configurable&&a.set===undefined&&a.get.name==="get "+name&&a.get.length===0&&Function.prototype.toString.call(a.get).includes("[native code]")});
 const values=Object.entries(constants).every(([name,value])=>[MediaError,p].every(object=>{const a=d(object,name);return a.value===value&&a.enumerable&&!a.writable&&!a.configurable}));
 const illegal=[()=>MediaError(),()=>new MediaError(),()=>Reflect.construct(MediaError,[])].every(call=>{try{call();return false}catch(error){return error instanceof TypeError&&error.message==="Illegal constructor"}});
 const tag=d(p,Symbol.toStringTag),global=d(globalThis,"MediaError");
 return getters&&values&&illegal&&MediaError.name==="MediaError"&&MediaError.length===0&&Object.getPrototypeOf(MediaError)===Function.prototype&&Object.getPrototypeOf(p)===Object.prototype&&!d(MediaError,"prototype").writable&&tag.value==="MediaError"&&!tag.enumerable&&!tag.writable&&tag.configurable&&global.writable&&!global.enumerable&&global.configurable;
})()')! == 'true'
	for index, code in [html.MediaErrorCode.aborted, .network, .decode, .src_not_supported] {
		message := ['', 'network failure', 'Decode \x00 🎬 failed\r\n', 'unsupported'][index]
		actual := &html.MediaError{
			code:    code
			message: message
		}
		object := runtime.javascript_media_error(actual)!
		assert runtime.javascript_media_error(actual)! == object
		assert voidptr(runtime.native_media_error(object)!) == voidptr(actual)
		runtime.define_value_host_function('actualMediaError', fn [object] (_ voidptr, _ []voidptr) !voidptr {
			return object
		})!
		assert runtime.evaluate_host('globalThis.currentMediaError=actualMediaError();currentMediaError.code===${
			index + 1}&&currentMediaError instanceof MediaError&&Object.getPrototypeOf(currentMediaError)===MediaError.prototype&&Object.prototype.toString.call(currentMediaError)==="[object MediaError]"&&Object.keys(currentMediaError).length===0&&!Object.hasOwn(currentMediaError,"code")&&!Object.hasOwn(currentMediaError,"message")&&!("addEventListener" in currentMediaError)')! == 'true'
		assert runtime.evaluate_host('currentMediaError.message')! == message
		assert runtime.evaluate_host(r'(()=>{
 const p=MediaError.prototype;let traps=0;const proxy=new Proxy(currentMediaError,{get(){traps++;throw "proxy"},getPrototypeOf(){traps++;throw "proxy"}});
 return ["code","message"].every(name=>{const get=Object.getOwnPropertyDescriptor(p,name).get;return [p,Object.create(p),proxy,null,undefined,1,{},new Error()].every(receiver=>{try{get.call(receiver);return false}catch(error){return error instanceof TypeError&&error.message==="Not an object of type MediaError"}})&&!Reflect.set(currentMediaError,name,123)})&&traps===0;
})()')! == 'true'
	}
}

fn test_native_media_error_wrappers_are_runtime_local_and_survive_author_constructor_replacement() {
	$if !darwin { return }
	mut first := Runtime.create()
	defer { first.close() }
	mut second := Runtime.create()
	defer { second.close() }
	first.install_media_error_binding()!
	second.install_media_error_binding()!
	actual := &html.MediaError{
		code:    .network
		message: 'Network \x00 🎬 failed\r\n'
	}
	first_object := first.javascript_media_error(actual)!
	second_object := second.javascript_media_error(actual)!
	assert first_object != second_object
	assert voidptr(first.native_media_error(first_object)!) == voidptr(actual)
	assert voidptr(second.native_media_error(second_object)!) == voidptr(actual)
	if _ := second.native_media_error(first_object) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Not an object of type MediaError'
	}
	first.evaluate_host(r'globalThis.originalMediaError=MediaError;globalThis.originalMediaErrorPrototype=MediaError.prototype;globalThis.authorMediaErrorCalls=0;globalThis.MediaError=function(){authorMediaErrorCalls++;throw "author constructor"};')!
	other := &html.MediaError{
		code:    .network
		message: actual.message()
	}
	other_object := first.javascript_media_error(other)!
	assert other_object != first_object
	first.define_value_host_function('retainedActualMediaError', fn [other_object] (_ voidptr, _ []voidptr) !voidptr {
		return other_object
	})!
	assert first.evaluate_host(r'globalThis.otherMediaError=retainedActualMediaError();otherMediaError instanceof originalMediaError&&Object.getPrototypeOf(otherMediaError)===originalMediaErrorPrototype&&otherMediaError.code===2&&otherMediaError.message==="Network \u0000 🎬 failed\r\n"&&authorMediaErrorCalls===0')! == 'true'
	$if darwin {
		binding := media_error_bindings_[voidptr(first)] or { panic('missing MediaError binding') }
		assert binding.records.len == 2 && binding.by_wrapper.len == 2 && !binding.closed
		first.close()
		assert binding.closed && binding.records.len == 0 && binding.by_wrapper.len == 0
		assert binding.prototype == unsafe { nil } && voidptr(first) !in media_error_bindings_
	}
	first.close()
	assert first.closed && first.context == unsafe { nil } && first.protected_values_.len == 0
	for operation in ['wrap', 'unwrap', 'install'] {
		if operation == 'wrap' {
			if _ := first.javascript_media_error(actual) {
				assert false
			} else {
				assert err.msg() == 'JavaScript runtime is closed'
			}
		} else if operation == 'unwrap' {
			if _ := first.native_media_error(first_object) {
				assert false
			} else {
				assert err.msg() == 'JavaScript runtime is closed'
			}
		} else {
			first.install_media_error_binding() or {
				assert err.msg() == 'JavaScript runtime is closed'
				continue
			}
			assert false
		}
	}
	assert second.javascript_media_error(actual)! == second_object
}

fn test_native_media_error_getter_preserves_the_original_replay_exception() {
	$if !darwin { return }
	mut runtime, _, media := media_error_getter_fixture(fn (runtime &Runtime) ! {
		mut owner := unsafe { &Runtime(runtime) }
		_ = owner.evaluate_host_value('throw mediaErrorReplayReason')!
	})!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'globalThis.mediaErrorReplayReason={};(()=>{try{void video.error;return false}catch(error){return error===mediaErrorReplayReason}})()')! == 'true'
	assert media.error() == none
}
