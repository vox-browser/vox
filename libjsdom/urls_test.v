// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand
import platform

fn url_fixture() !(&Host, &libjs.VM) {
	address := dom.URL{value: 'https://libjs-url.test:8443/root?first=one'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	return Host.create(vm, vm.realm(), document, Hooks{})!, vm
}

fn url_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-url.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 200000}) or { return error(exception_message(err)) }
}

fn test_url_static_parsing_uses_real_parser_for_absolute_relative_and_opaque_urls() {
	mut host, mut vm := url_fixture()!
	defer { host.close() }
	assert url_eval(mut vm, 'URL.canParse("https://example.com/")&&!URL.canParse("/relative")&&URL.canParse("../item","https://example.com/a/")&&!URL.canParse("https://example.com/","bad base")&&!URL.canParse("https://[invalid]/")&&URL.canParse("urn:typebox:root")&&!URL.canParse("item","urn:typebox:root")&&URL.parse("bad URL")===null&&URL.parse("../item","https://example.com/a/").href==="https://example.com/item"&&URL.parse("urn:typebox:root").href==="urn:typebox:root"')!.as_bool()
}

fn test_url_required_arguments_usv_strings_and_abrupt_conversion_order() {
	mut host, mut vm := url_fixture()!
	defer { host.close() }
	assert url_eval(mut vm, 'var errors=0;for(var run of [()=>URL(),()=>new URL(),()=>URL.canParse(),()=>URL.parse(),()=>URL.canParse(Symbol()),()=>URL.parse(Symbol()),()=>new URL(Symbol())])try{run()}catch(e){if(e instanceof TypeError)errors++}errors===7&&URL.canParse(undefined,"https://example.com/")&&new URL(undefined,"https://example.com/").pathname==="/undefined"&&URL.parse("https://example.com/\\ud800").pathname==="/%EF%BF%BD"')!.as_bool()
	assert url_eval(mut vm, 'var seen="",marker={},caught=false;try{URL.canParse({toString(){seen+="i";return "not a URL"}},{toString(){seen+="b";throw marker}})}catch(e){caught=e===marker}caught&&seen==="ib"&&(function(){var same=false;try{URL.parse({toString(){throw marker}})}catch(e){same=e===marker}return same})()')!.as_bool()
}

fn test_url_new_target_prototype_is_read_after_conversion_before_parser_failure() {
	mut host, mut vm := url_fixture()!
	defer { host.close() }
	assert url_eval(mut vm, 'var seen="",N=new Proxy(function(){},{get(t,k,r){if(k==="prototype"){seen+="p";return URL.prototype}return Reflect.get(t,k,r)}}),failed=false;try{Reflect.construct(URL,[{toString(){seen+="i";return "https://example.com/"}},{toString(){seen+="b";return "bad base"}}],N)}catch(e){failed=e instanceof TypeError}failed&&seen==="ibp"&&(function(){class U extends URL{answer=42}var u=new U("/item","https://example.com/");return u instanceof U&&u instanceof URL&&u.answer===42&&u.href==="https://example.com/item"})()')!.as_bool()
}

fn test_url_components_getters_setters_and_json_share_the_native_record() {
	mut host, mut vm := url_fixture()!
	defer { host.close() }
	assert url_eval(mut vm, 'var u=new URL("https://user:pass@example.com:8443/a?x=1#old");u.protocol==="https:"&&u.username==="user"&&u.password==="pass"&&u.host==="example.com:8443"&&u.hostname==="example.com"&&u.port==="8443"&&u.pathname==="/a"&&u.search==="?x=1"&&u.hash==="#old"&&u.origin==="https://example.com:8443"')!.as_bool()
	assert url_eval(mut vm, 'u.protocol="http:";u.username="a b";u.password="p:q";u.hostname="other.test";u.port="8080";u.pathname="/a b";u.search="?x=hello world";u.hash="new value";u.href==="http://a%20b:p%3Aq@other.test:8080/a%20b?x=hello%20world#new%20value"&&u.toString()===u.href&&u.toJSON()===u.href&&JSON.stringify(u)===JSON.stringify(u.href)')!.as_bool()
	actual := vm.global_object().get(mut vm, libjs.PropertyName.from_str('u'))!
	mut native := host.urls[voidptr(actual.as_object())] or { panic('Missing native URL') }
	native.set_pathname('/native')
	assert url_eval(mut vm, 'u.pathname==="/native"')!.as_bool()
}

fn test_url_search_params_are_lazy_same_object_and_live_after_href_replacement() {
	mut host, mut vm := url_fixture()!
	defer { host.close() }
	url_eval(mut vm, 'var u=new URL("https://example.com/?a=1")')!
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('u'))!
	native := host.urls[voidptr(value.as_object())] or { panic('Missing native URL') }
	assert native.query_object == none
	assert url_eval(mut vm, 'var p=u.searchParams;p===u.searchParams&&p.get("a")==="1"&&(p.append("b","a b"),u.search==="?a=1&b=a+b")&&(u.href="https://other.test/?new=2",p===u.searchParams&&p.get("new")==="2"&&!p.has("a"))&&(u.search="?last=3",p.get("last")==="3")')!.as_bool()
}

fn test_url_prototype_metadata_and_brand_checks_precede_setter_conversion() {
	mut host, mut vm := url_fixture()!
	defer { host.close() }
	assert url_eval(mut vm, 'var p=URL.prototype,g=Object.getOwnPropertyDescriptor(p,"href"),u=new URL("https://example.com/");Object.keys(u).length===0&&Object.prototype.toString.call(u)==="[object URL]"&&g.enumerable&&g.configurable&&g.get.length===0&&g.set.length===1&&URL.length===1&&URL.canParse.length===1&&URL.parse.length===1&&p.toJSON.length===0&&p.toString.length===0&&!Object.getOwnPropertyDescriptor(URL,"prototype").writable&&Object.getOwnPropertyDescriptor(URL,"canParse").enumerable')!.as_bool()
	assert url_eval(mut vm, 'var reads=0,errors=0,g=Object.getOwnPropertyDescriptor(URL.prototype,"href");for(var run of [()=>g.get.call({}),()=>g.set.call({},{toString(){reads++;return "https://example.com/"}}),()=>URL.prototype.toString.call({}),()=>URL.prototype.toJSON.call({}),()=>g.get.call(new Proxy(u,{})),()=>g.get.call(Object.create(u))])try{run()}catch(e){if(e instanceof TypeError)errors++}errors===6&&reads===0')!.as_bool()
}

fn test_url_wrappers_use_fixed_prototype_callbacks_and_location_stays_separate() {
	mut host, mut vm := url_fixture()!
	defer { host.close() }
	before := host.closures.len
	queries := host.queries.len
	assert url_eval(mut vm, 'for(var i=0;i<100;i++)new URL("/"+i,"https://example.com/");location.protocol==="https:"&&location.host==="libjs-url.test:8443"&&location.hostname==="libjs-url.test"&&location.port==="8443"&&location.pathname==="/root"&&!(location instanceof URL)')!.as_bool()
	assert host.closures.len == before && host.queries.len == queries
}

fn test_url_records_and_lazy_queries_survive_temporary_arena_reset() {
	mut host, mut vm := url_fixture()!
	defer { host.close() }
	mut arena := platform.new_arena('native URL and lazy searchParams')
	entry := arena.enter()
	url_eval(mut vm, 'var u=URL.parse("/temporary?x=1","https://example.com/"),params=u.searchParams;u.hash="kept"')!
	arena.leave(entry)
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('u'))!
	native := host.urls[voidptr(value.as_object())] or { panic('Missing native URL') }
	assert !arena.contains(value.as_object()) && !arena.contains(native) && !arena.contains(native.query_object?)
	arena.reset(); arena.release()
	assert url_eval(mut vm, 'u.href==="https://example.com/temporary?x=1#kept"&&params.get("x")==="1"&&(params.set("x","2"),u.search==="?x=2")')!.as_bool()
}

fn test_cached_url_schema_parsing_revisit_disables_compiler_and_close_releases_roots() {
	directory := os.join_path(os.temp_dir(), 'vox-native-url-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := url_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert url_eval(mut vm, 'function schemaURL(input,base){return URL.canParse(input,base)?new URL(input,base).href:null}schemaURL("child","https://example.com/a/")==="https://example.com/a/child"&&schemaURL("bad","bad")===null')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
		assert host.urls.len == 0 && host.url_wrappers.len == 0
	}
}
