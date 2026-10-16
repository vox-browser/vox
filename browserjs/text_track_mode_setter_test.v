module browserjs

import dom
import html

fn text_mode_fixture() !(&Runtime,&MediaElementHost,&dom.Document,&html.TextTrack) {
	url := dom.URL{value:'https://text-mode.example/'}
	document := html.parse_navigation_document('<!doctype html>',url,url.origin(),none)!
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document,none)!
	host.install(mut runtime)!
	track := html.TextTrack.create()
	wrapper := host.wrap_text_track(track)!
	runtime.define_value_host_function('__modeTrack',fn [wrapper] (_ voidptr,_ []voidptr) !voidptr { return wrapper })!
	runtime.evaluate_host('globalThis.nmode=__modeTrack();globalThis.nModeSet=Object.getOwnPropertyDescriptor(TextTrack.prototype,"mode").set;0')!
	return runtime,host,document,track
}

fn text_mode_balanced(runtime &Runtime,document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0 && runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_text_track_mode_enum_setter_ignores_invalid_and_omitted_values_without_mutation() {
	$if !darwin { return }
	mut runtime,_,mut document,track := text_mode_fixture()!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 const d=Object.getOwnPropertyDescriptor(TextTrack.prototype,"mode");
 if(nmode.mode!=="disabled"||d.set!==nModeSet||d.set.name!=="set mode"||d.set.length!==1||!d.enumerable||!d.configurable||Object.hasOwn(nmode,"mode")||!Function.prototype.toString.call(d.set).includes("[native code]"))return false;
 nmode.mode="showing";
 const invalid=[undefined,null,false,true,0,-0,NaN,Infinity,1n,Symbol(),"","Hidden"," showing","showing ","showing\0","showing\ud800",[],{},Object.create(null)];
 for(const value of invalid){if(nModeSet.call(nmode,value)!==undefined||nmode.mode!=="showing")return false;if(!Reflect.set(nmode,"mode",value)||nmode.mode!=="showing")return false;}
 if(nModeSet.call(nmode)!==undefined||nmode.mode!=="showing")return false;
 const supplied={toString(){return "invalid"}};if((nmode.mode=supplied)!==supplied)return false;
 return nmode.mode==="showing";
})()')! == 'true'
	assert track.mode() == .showing
	text_mode_balanced(runtime,document)
}

fn test_text_track_mode_enum_string_conversion_is_once_and_preserves_reentrant_effects() {
	$if !darwin { return }
	mut runtime,_,mut document,track := text_mode_fixture()!
	defer { runtime.close();document.finalize() }
	assert runtime.evaluate_host(r'(()=>{
 let log=[];
 for(const word of ["disabled","hidden","showing"]){const value={[Symbol.toPrimitive](hint){log.push(hint);return word},toString(){throw "fallback conversion"}};if(nModeSet.call(nmode,value)!==undefined||nmode.mode!==word)return false;}
 if(log.join(",")!=="string,string,string")return false;
 const fallback={toString(){log.push("toString");return {}},valueOf(){log.push("valueOf");return "hidden"}};
 nmode.mode=fallback;if(nmode.mode!=="hidden"||log.slice(-2).join(",")!=="toString,valueOf")return false;
 nmode.mode=new String("showing");if(nmode.mode!=="showing")return false;
 let calls=0;nmode.mode={toString(){calls++;nmode.mode="disabled";return "hidden"}};if(nmode.mode!=="hidden"||calls!==1)return false;
 nmode.mode={toString(){calls++;nmode.mode="showing";return "invalid"}};if(nmode.mode!=="showing"||calls!==2)return false;
 const reason={};nmode.mode={[Symbol.toPrimitive](hint){calls++;nmode.mode="disabled";throw reason}};
 return nmode.mode==="disabled"&&calls===3;
})()')! == 'true'
	assert track.mode() == .disabled
	text_mode_balanced(runtime,document)
}

fn test_text_track_mode_enum_setter_brands_before_conversion_and_keeps_interfaces_distinct() {
	$if !darwin { return }
	mut runtime,host,mut document,track := text_mode_fixture()!
	defer { runtime.close();document.finalize() }
	mut second := MediaElementHost.create(document,none)!
	second.install(mut runtime)!
	other := second.wrap_text_track(html.TextTrack.create())!
	runtime.define_value_host_function('__otherModeTrack',fn [other] (_ voidptr,_ []voidptr) !voidptr { return other })!
	assert runtime.evaluate_host(r'(()=>{
 let reads=0;const value={toString(){reads++;throw "conversion"}},proxy=new Proxy(nmode,{get(){reads++;throw "proxy get"},getPrototypeOf(){reads++;throw "proxy prototype"}}),revoked=Proxy.revocable(nmode,{});revoked.revoke();
 for(const receiver of [null,undefined,1,{},Object.create(nmode),TextTrack.prototype,new EventTarget(),proxy,revoked.proxy,__otherModeTrack()])try{nModeSet.call(receiver,value);return false}catch(e){if(!(e instanceof TypeError)||e.message!=="Not an object of type TextTrack")return false;}
 return reads===0&&nmode.mode==="disabled"&&nModeSet.call(nmode,"hidden")===undefined&&nmode.mode==="hidden";
})()')! == 'true'
	assert track.mode() == .hidden && host.text_tracks.len == 1
	text_mode_balanced(runtime,document)
}

fn test_text_track_mode_enum_ignored_coercion_exceptions_do_not_accumulate_engine_roots() {
	$if !darwin { return }
	mut runtime,_,mut document,track := text_mode_fixture()!
	defer { runtime.close();document.finalize() }
	runtime.evaluate_host(r'globalThis.modeReason={};globalThis.modeThrows=[Symbol(),{get [Symbol.toPrimitive](){throw modeReason}},{[Symbol.toPrimitive](){throw modeReason}},{toString(){throw modeReason}},{[Symbol.toPrimitive]:0},{[Symbol.toPrimitive](){return {}}},new Proxy({},{get(){throw modeReason}})];nmode.mode="hidden";0')!
	protected := runtime.protected_values_.len
	assert runtime.evaluate_host(r'(()=>{for(let i=0;i<20;i++)for(const value of modeThrows)if(nModeSet.call(nmode,value)!==undefined||nmode.mode!=="hidden")return false;return true})()')! == 'true'
	assert runtime.protected_values_.len == protected
	assert track.mode() == .hidden
	text_mode_balanced(runtime,document)
	runtime.close()
	assert runtime.protected_values_.len == 0
}
