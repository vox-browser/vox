// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn query_fixture() !(&Host, &libjs.VM) {
	address := dom.URL{value: 'https://libjs-query.test/?original=1'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	return Host.create(vm, vm.realm(), document, Hooks{})!, vm
}

fn query_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-query.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_query_params_constructors_native_records_and_usv_conversion() {
	mut host, mut vm := query_fixture()!
	defer { host.close() }
	assert query_eval(mut vm, 'var p=new URLSearchParams("?%EF%BB%BFname=%EF%BB%BFvalue&a=1&a=2&bad=%FF");p.size===4&&p.get("missing")===null&&p.get("\\uFEFFname")==="\\uFEFFvalue"&&p.getAll("a").join(",")==="1,2"&&p.toString()==="%EF%BB%BFname=%EF%BB%BFvalue&a=1&a=2&bad=%EF%BF%BD"')!.as_bool()
	actual := vm.global_object().get(mut vm, libjs.PropertyName.from_str('p'))!
	mut native := host.queries[voidptr(actual.as_object())] or { panic('Missing native URLSearchParams') }
	native.append('actual', 'a b')
	assert query_eval(mut vm, 'p.get("actual")==="a b"&&p.toString().endsWith("actual=a+b")&&new URLSearchParams(p).toString()===p.toString()&&new URLSearchParams(null).toString()==="null="&&new URLSearchParams(undefined).size===0')!.as_bool()
	assert query_eval(mut vm, 'var record={};record["\\ud800"]="first";record.middle="middle";record["\\udc00"]="last";var q=new URLSearchParams(record);q.toString()==="%EF%BF%BD=last&middle=middle"&&new URLSearchParams([["\\ud800\\ud800\\udc00\\udc00\\u0000😀","\\ud800"]]).toString()==="%EF%BF%BD%F0%90%80%80%EF%BF%BD%00%F0%9F%98%80=%EF%BF%BD"')!.as_bool()
}

fn test_query_params_methods_use_live_native_owner_and_optional_values() {
	mut host, mut vm := query_fixture()!
	defer { host.close() }
	assert query_eval(mut vm, 'var p=new URLSearchParams("a=1&a=2&z=3");p.delete("a","1");p.append("a","4");p.set("z","5");p.sort();p.getAll("a").join(",")==="2,4"&&p.has("a")&&p.has("a","4")&&!p.has("a",null)&&p.has("a",undefined)&&p.toString()==="a=2&a=4&z=5"')!.as_bool()
	assert query_eval(mut vm, 'p.delete("a",undefined);p.set("z","6");p.append("z",undefined);p.delete("z",null);p.toString()==="z=6&z=undefined"&&p.size===2')!.as_bool()
	assert query_eval(mut vm, 'var u=new URL("https://example.test/?a=1&a=2"),q=u.searchParams;q instanceof URLSearchParams&&q===u.searchParams&&q.getAll("a").join(",")==="1,2"')!.as_bool()
	assert query_eval(mut vm, 'q.delete("a","1");q.append("space","a b");var ok=u.href==="https://example.test/?a=2&space=a+b";u.search="?next=3";ok=ok&&q===u.searchParams&&q.toString()==="next=3";u.href="https://other.test/?x=4";q.set("x","5");ok&&q===u.searchParams&&u.href==="https://other.test/?x=5"&&q.get("next")===null')!.as_bool()
}

fn test_query_params_iterators_and_foreach_remain_live_and_share_prototypes() {
	mut host, mut vm := query_fixture()!
	defer { host.close() }
	assert query_eval(mut vm, 'var p=new URLSearchParams("a=1&b=2&c=3"),seen=[],receiver={};p.forEach(function(value,key,owner){if(this!==receiver||owner!==p)throw 1;seen.push(key+value);if(key==="a"){p.delete("b");p.append("d","4")}return {get then(){throw 2}}},receiver);seen.join(",")==="a1,c3,d4"')!.as_bool()
	assert query_eval(mut vm, 'var keys=p.keys(),values=p.values(),entries=p.entries();p.delete("a");p.append("e","5");var ok=keys[Symbol.iterator]()===keys&&keys.next().value==="c"&&values.next().value==="3"&&entries.next().value.join(":")==="c:3";for(var v of keys)seen.push(v);p.append("f","6");ok&&keys.next().done&&Object.getPrototypeOf(values)===Object.getPrototypeOf(entries)&&Object.prototype.toString.call(keys)==="[object URLSearchParams Iterator]"&&p[Symbol.iterator]===p.entries')!.as_bool()
	assert query_eval(mut vm, 'var p=new URLSearchParams([["\\uE000","b"],["😀","a"],["😀","c"]]);p.sort();var result=[];for(var value of p.values())result.push(value);result.join(",")==="a,c,b"')!.as_bool()
}

fn test_query_params_conversion_order_original_throws_and_native_pair_validation() {
	mut host, mut vm := query_fixture()!
	defer { host.close() }
	assert query_eval(mut vm, 'var reads=0,nextReads=0,init={get [Symbol.iterator](){reads++;return function(){var i=0;return {get next(){nextReads++;return function(){return i++?{done:true}:{done:false,value:["x","1"]}}}}}}};new URLSearchParams(init).get("x")==="1"&&reads===1&&nextReads===1')!.as_bool()
	assert query_eval(mut vm, 'var marker={},calls="",failure;try{new URLSearchParams([["wrong"],[{toString(){calls+="late";throw marker}},"value"]])}catch(e){failure=e}failure===marker&&calls==="late"')!.as_bool()
	assert query_eval(mut vm, 'var closed=0,marker={},source={[Symbol.iterator](){return {next(){return {done:false,value:[{toString(){throw marker}},"v"]}},return(){closed++;return {}}}}},same=false;try{new URLSearchParams(source)}catch(e){same=e===marker}same&&closed===0')!.as_bool()
	assert query_eval(mut vm, 'var calls="",init={get a(){calls+="a";return 1},get b(){calls+="b";return 2}};Object.defineProperty(init,Symbol.iterator,{get(){calls+="i";return null}});new URLSearchParams(init).toString()==="a=1&b=2"&&calls==="iab"')!.as_bool()
}

fn test_query_params_metadata_subclasses_branding_required_arguments_and_budget() {
	mut host, mut vm := query_fixture()!
	defer { host.close() }
	assert query_eval(mut vm, 'class Query extends URLSearchParams{answer=42}var q=new Query("a=1"),get=Object.getOwnPropertyDescriptor,p=URLSearchParams.prototype,d=get(p,"size"),iter=get(p,Symbol.iterator);q instanceof Query&&q instanceof URLSearchParams&&q.answer===42&&q.get("a")==="1"&&Object.prototype.toString.call(q)==="[object URLSearchParams]"&&URLSearchParams.length===0&&!get(URLSearchParams,"prototype").writable&&d.enumerable&&d.configurable&&d.get.length===0&&p.append.length===2&&p.delete.length===1&&p.entries.length===0&&p.forEach.length===1&&iter.writable&&iter.configurable&&!iter.enumerable')!.as_bool()
	assert query_eval(mut vm, 'var count=0,coerced=0,marker={},same=false;for(var run of [()=>URLSearchParams(),()=>new URLSearchParams(Symbol()),()=>new URLSearchParams([[1]]),()=>new URLSearchParams({[Symbol("x")]:1}),()=>q.append("x"),()=>q.get(),()=>q.getAll(),()=>q.delete(),()=>q.has(),()=>q.set("x"),()=>q.forEach(),()=>q.get.call({},{toString(){coerced++;return "x"}}),()=>q.entries().next.call({}),()=>Object.getOwnPropertyDescriptor(URLSearchParams.prototype,"size").get.call({})])try{run()}catch(e){if(e instanceof TypeError)count++}try{q.append("x",{toString(){throw marker}})}catch(e){same=e===marker}count===14&&coerced===0&&same&&q.size===1')!.as_bool()
	query_eval(mut vm, 'var p=new URLSearchParams("a=1");p.forEach(()=>p.append("a","1"))') or { assert err.msg().contains('budget'); return }
	assert false
}

fn test_cached_query_params_callbacks_reopen_without_compiler_and_close_releases_wrappers() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-query-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := query_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert query_eval(mut vm, 'var p=new URLSearchParams("a=1&b=2"),sum=0;p.forEach(function(value){sum+=+value});sum===3')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('p'))!
		mut native := host.queries[voidptr(value.as_object())] or { panic('Missing native query') }
		host.close()
		native.append('remaining', '3')
		assert (native.get('remaining') or { '' }) == '3'
		assert host.queries.len == 0 && host.query_wrappers.len == 0 && host.query_iterators.len == 0
	}
}
