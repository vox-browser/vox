module browserjs

import dom

fn native_url_runtime() &Runtime {
	mut runtime := Runtime.create()
	address := dom.URL{
		value: 'https://native-url.example.test/'
	}
	document := &dom.Document{
		url:     address
		origin_: address.origin()
	}
	mut query := URLSearchParamsHost.create(document) or { panic(err) }
	query.install(mut runtime) or { panic(err) }
	mut host := URLHost.create(document) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime
}

fn test_native_url_constructor_exposes_actual_source_record() {
	$if !darwin { return }
	mut runtime := native_url_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof URL')! == 'function'
	assert runtime.evaluate_host('globalThis.address=new URL("../target?x=1#part","https://user:pass@native-url.example.test:443/root/page");address.href==="https://user:pass@native-url.example.test/target?x=1#part"&&address.origin==="https://native-url.example.test"&&address.protocol==="https:"&&address.username==="user"&&address.password==="pass"&&address.host==="native-url.example.test"&&address.hostname===address.host&&address.port===""&&address.pathname==="/target"&&address.search==="?x=1"&&address.hash==="#part"')! == 'true'
	actual := runtime.evaluate_host_value('address')!
	mut native := runtime.native_url(actual)!
	assert native.href() == 'https://user:pass@native-url.example.test/target?x=1#part'
	assert runtime.javascript_url(native)! == actual
	native.set_pathname('/typed')
	assert runtime.evaluate_host('address.pathname==="/typed"')! == 'true'
	assert runtime.evaluate_host('address.pathname="/script";address.toString()===address.href&&address.toJSON()===address.href&&JSON.stringify(address)===JSON.stringify(address.href)')! == 'true'
	assert native.pathname() == '/script'
}

fn test_native_url_static_operations_keep_optional_base_and_usv_conversion_order() {
	$if !darwin { return }
	mut runtime := native_url_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{const p=URL.parse("../target","https://example.test/root/page");return p instanceof URL&&p.href==="https://example.test/target"&&URL.parse("not absolute")===null&&!URL.canParse("not absolute")&&URL.canParse("/target","https://example.test/")&&URL.canParse("https://example.test/",undefined)&&!URL.canParse("https://example.test/",null)&&URL.parse.call({},"https://example.test/") instanceof URL})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const lone=String.fromCharCode(0xd800);return new URL("https://example.test/"+lone).pathname==="/%EF%BF%BD"&&URL.parse("/"+lone,"https://example.test/").pathname==="/%EF%BF%BD"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const marker={},calls=[],input={toString(){calls.push("url");return "relative"}},base={toString(){calls.push("base");throw marker}};const failures=[()=>new URL(input,base),()=>URL.parse(input,base),()=>URL.canParse(input,base)];return failures.every(call=>{try{call();return false}catch(reason){return reason===marker}})&&calls.join(",")==="url,base,url,base,url,base"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{return [()=>new URL(),()=>URL.parse(),()=>URL.canParse(),()=>new URL(Symbol()),()=>URL.parse(Symbol()),()=>URL.canParse(Symbol()),()=>new URL("https://example.test/","bad base")].every(call=>{try{call();return false}catch(reason){return reason instanceof TypeError}})})()')! == 'true'
}

fn test_native_url_direct_usv_encoding_preserves_pairs_invalid_runs_and_coercion() {
	$if !darwin { return }
	mut runtime := native_url_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{const units=String.fromCharCode(0xd800,0xd800,0xdc00,0xdc00,0,0xd83d,0xde00),u=new URL("https://example.test/"+units);return u.pathname==="/%EF%BF%BD%F0%90%80%80%EF%BF%BD%00%F0%9F%98%80"&&URL.parse("/"+units,"https://example.test/").href===u.href&&URL.canParse(u.href)})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const units=String.fromCharCode(0xd800,0xd800,0xdc00,0xdc00,0,0xd83d,0xde00),p=new URLSearchParams([[units,units]]);return p.get(units)==="\uFFFD\u{10000}\uFFFD\u0000😀"&&p.toString()==="%EF%BF%BD%F0%90%80%80%EF%BF%BD%00%F0%9F%98%80=%EF%BF%BD%F0%90%80%80%EF%BF%BD%00%F0%9F%98%80"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{let calls=0;const key={toString(){calls++;return "x"}},value={toString(){calls++;return String.fromCharCode(0xd800)}};const p=new URLSearchParams();p.append(key,value);return calls===2&&p.get("x")==="�"})()')! == 'true'
}

fn test_native_url_base_cache_preserves_coercion_reentry_and_fresh_objects() {
	$if !darwin { return }
	mut runtime := native_url_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{let calls=0;const base={toString(){calls++;return "https://base.test/a/"}};const first=new URL("child",base),second=URL.parse("child",base);first.pathname="/changed";return calls===2&&first!==second&&second.href==="https://base.test/a/child"&&URL.canParse("child",base)&&calls===3})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const marker={};let count=0;const base={toString(){if(++count===2)throw marker;return "https://base.test/"}};new URL("one",base);try{new URL("two",base)}catch(e){return e===marker&&count===2}return false})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const base={toString(){new URL("inside","https://inner.test/");return "https://outer.test/"}};return new URL("outside",base).href==="https://outer.test/outside"&&URL.parse("https://absolute.test/","bad base")===null&&!URL.canParse("https://absolute.test/","bad base")})()')! == 'true'
	actual := runtime.evaluate_host_value('new URL("../survivor","https://user:pass@escaped.test:8443/a/")')!
	native := runtime.native_url(actual)!
	runtime.close()
	assert native.href() == 'https://user:pass@escaped.test:8443/survivor'
}

fn test_native_url_input_cache_keeps_coercion_and_query_owners_on_hits_and_close() {
	$if !darwin { return }
	mut runtime := native_url_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{const calls=[],input={toString(){calls.push("input");new URL("inside","https://inner.test/");return "child?x=1"}},base={toString(){calls.push("base");return "https://outer.test/"}};const a=new URL(input,base),b=new URL(input,base);a.searchParams.set("x","changed");return calls.join(",")==="input,base,input,base"&&a!==b&&b.href==="https://outer.test/child?x=1"&&b.searchParams!==a.searchParams})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const marker={},input={toString(){throw marker}};new URL("child","https://outer.test/");try{new URL(input,"https://outer.test/")}catch(e){return e===marker}return false})()')! == 'true'
	value := runtime.evaluate_host_value('new URL("https://survivor.test/a/b?query#fragment")')!
	native := runtime.native_url(value)!
	assert runtime.evaluate_host('for(let i=0;i<2048;i++)new URL("https://eviction.test/"+i);true')! == 'true'
	runtime.close()
	assert native.href() == 'https://survivor.test/a/b?query#fragment'
}

fn test_native_url_same_object_query_and_live_iterator_share_genuine_owners() {
	$if !darwin { return }
	mut runtime := native_url_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host('globalThis.address=new URL("https://example.test/??name=value&b=2");globalThis.query=address.searchParams;globalThis.cursor=query.entries();query===address.searchParams&&query.get("?name")==="value"&&cursor.next().value.join(":")==="?name:value"')! == 'true'
	mut native := runtime.native_url(runtime.evaluate_host_value('address')!)!
	params := runtime.native_url_search_params(runtime.evaluate_host_value('query')!)!
	assert voidptr(native.search_params()) == voidptr(params)
	assert runtime.evaluate_host('address.href="https://example.test/?x=9&y=8";address.searchParams===query&&cursor.next().value.join(":")==="y:8"')! == 'true'
	assert runtime.evaluate_host('query.append("z","a b");address.search==="?x=9&y=8&z=a+b"')! == 'true'
	assert native.search() == '?x=9&y=8&z=a+b'
	native.set_search('??updated=3')
	assert runtime.evaluate_host('address.searchParams===query&&query.get("?updated")==="3"')! == 'true'
}

fn test_native_url_setters_validate_receivers_before_converting_and_keep_original_errors() {
	$if !darwin { return }
	mut runtime := native_url_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{const u=new URL("https://example.test/"),lone=String.fromCharCode(0xd800);u.username="a b";u.password="p@";u.port="8443";u.hostname="other.test";u.pathname="/"+lone;u.search="?name="+lone;u.hash="#"+lone;u.protocol="http:";return u.href==="http://a%20b:p%40@other.test:8443/%EF%BF%BD?name=%EF%BF%BD#%EF%BF%BD"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const marker={},u=new URL("https://example.test/"),setter=Object.getOwnPropertyDescriptor(URL.prototype,"href").set;let calls=0,brand,converted,invalid;const input={toString(){calls++;throw marker}};try{setter.call({},input)}catch(reason){brand=reason}try{setter.call(u,input)}catch(reason){converted=reason}try{u.href="bad url"}catch(reason){invalid=reason}return brand instanceof TypeError&&converted===marker&&calls===1&&invalid instanceof TypeError&&invalid.message==="Invalid URL"&&u.href==="https://example.test/"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const marker={},calls=[],target=new Proxy(function(){},{get(object,key){if(key==="prototype"){calls.push("prototype");throw marker}return object[key]}}),input={toString(){calls.push("url");return "https://example.test/"}};let failure;try{Reflect.construct(URL,[input],target)}catch(reason){failure=reason}return failure===marker&&calls.join()==="prototype"})()')! == 'true'
}

fn test_native_url_metadata_subclass_alias_and_close_ownership() {
	$if !darwin { return }
	mut runtime := native_url_runtime()
	assert runtime.evaluate_host(r'(()=>{const get=Object.getOwnPropertyDescriptor,c=URL,p=c.prototype,g=get(globalThis,"URL"),alias=get(globalThis,"webkitURL"),href=get(p,"href"),params=get(p,"searchParams"),parse=get(c,"parse");return c.name==="URL"&&c.length===1&&g.value===c&&g.writable&&!g.enumerable&&g.configurable&&alias.value===c&&!alias.enumerable&&!get(c,"prototype").writable&&href.get.name==="get href"&&href.get.length===0&&href.set.name==="set href"&&href.set.length===1&&href.enumerable&&href.configurable&&params.set===undefined&&parse.value.length===1&&parse.enumerable&&parse.writable&&parse.configurable&&c.canParse.length===1&&p.toString.length===0&&p.toJSON.length===0&&Function.prototype.toString.call(p.toJSON).includes("[native code]")})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{class Address extends URL{}const u=new Address("https://example.test/");function Target(){}Target.prototype=null;const fallback=Reflect.construct(URL,[u],Target);return u instanceof Address&&u instanceof URL&&u.href===fallback.href&&Object.getPrototypeOf(fallback)===URL.prototype&&Object.prototype.toString.call(u)==="[object URL]"&&(()=>{try{URL("https://example.test/")}catch(reason){return reason instanceof TypeError}return false})()})()')! == 'true'
	actual := runtime.evaluate_host_value('new URL("https://retained.example.test/?x=1")')!
	native := runtime.native_url(actual)!
	runtime.close()
	assert native.href() == 'https://retained.example.test/?x=1'
	if _ := runtime.native_url(actual) { assert false, 'closed runtime retained a URL wrapper'
	 }
}
