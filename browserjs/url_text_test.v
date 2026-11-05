module browserjs

import platform

fn native_url_text_runtime() &Runtime {
	mut runtime := native_url_runtime()
	if retain_href_url_objects {
		getter := runtime.evaluate_host_value('Object.getOwnPropertyDescriptor(URL.prototype,"href").get') or { panic(err) }
		runtime.install_url_text_binding(getter) or { panic(err) }
		runtime.release_javascript_value(getter)
	}
	return runtime
}

fn test_url_text_matches_native_constructor_and_keeps_url_owner_maps_unchanged() {
	$if !darwin && !linux { return }
	mut runtime := native_url_text_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
const cases=["","../a?b=c#d","https://user:pass@EXAMPLE.test:443/a/../b","//example.test/x","data:text/plain,a","https://é.example/😀","http://[::1]/a","x%20y","http://[broken",String.fromCharCode(0xd800,0,0xd83d,0xde00)];
cases.every(value=>{let expected;try{expected=new URL(value,"https://base.test/a/b").href;}catch(error){expected=null;}return __ladybirdSerializeURLText(value,"https://base.test/a/b")===expected;})
')! == 'true'
	host := url_bindings_[voidptr(runtime)] or { panic('host') }
	owners := host.records.len
	wrappers := host.by_wrapper.len
	assert runtime.evaluate_host(r'
for(let i=0;i<2048;i++){const input=i%2?"child?x=1":"../other#part";if(__ladybirdSerializeURLText(input,"https://base.test/a/")!==(i%2?"https://base.test/a/child?x=1":"https://base.test/other#part"))throw new Error("text");}true
')! == 'true'
	assert host.records.len == owners && host.by_wrapper.len == wrappers
}

fn test_url_text_does_not_coerce_non_strings_and_keeps_original_constructor_tokens() {
	$if !darwin && !linux { return }
	mut runtime := native_url_text_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
const marker={},bad={toString(){throw marker;},[Symbol.toPrimitive](){throw marker;}};
__ladybirdSerializeURLText.nativeConstructor===URL&&__ladybirdSerializeURLText.nativePrototype===URL.prototype&&__ladybirdSerializeURLText.nativeHrefGetter===Object.getOwnPropertyDescriptor(URL.prototype,"href").get&&[undefined,null,1,Symbol(),bad,new String("x")].every(value=>__ladybirdSerializeURLText(value,"https://base.test/")===null&&__ladybirdSerializeURLText("x",value)===null)&&__ladybirdSerializeURLText()===null&&__ladybirdSerializeURLText("x","https://base.test/",1)===null&&__ladybirdSerializeURLText("https://absolute.test/","bad base")===null
')! == 'true'
}

fn test_url_text_retired_inputs_eviction_and_separate_runtime_close_keep_live_urls() {
	$if !darwin && !linux { return }
	mut runtime := native_url_text_runtime()
	mut second := native_url_text_runtime()
	defer { runtime.close(); second.close() }
	_ = runtime.evaluate_host('globalThis.keptURL=new URL("https://kept.test/a?x=1");globalThis.keptText=__ladybirdSerializeURLText("../survivor","https://base.test/a/b")')!
	for _ in 0 .. 8 {
		work := platform.begin_thread_scratch('URL text input caller')
		assert runtime.evaluate_host(r'for(let i=0;i<512;i++){const base="https://base"+i+".test/a/";if(__ladybirdSerializeURLText("../"+i,base)!=="https://base"+i+".test/"+i)throw new Error("rotating");}true')! == 'true'
		work.finish()
		churn := platform.begin_thread_scratch('URL text input overwrite')
		_ = []u8{len:256 * 1024, init:u8(0xa5)}
		churn.finish()
	}
	assert runtime.evaluate_host('keptText==="https://base.test/survivor"&&keptURL.href==="https://kept.test/a?x=1"&&__ladybirdSerializeURLText("child","https://base511.test/a/")==="https://base511.test/a/child"')! == 'true'
	runtime.close()
	assert second.evaluate_host('__ladybirdSerializeURLText("/still-live","https://second.test/")==="https://second.test/still-live"')! == 'true'
	if _ := runtime.install_url_text_binding(unsafe { nil }) {
		assert false
	} else { assert err.msg().contains('closed') }
}
