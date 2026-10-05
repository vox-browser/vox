module browserjs

import dom
import domurl

fn native_url_search_params_runtime() &Runtime {
	mut runtime := Runtime.create()
	url := dom.URL{
		value: 'https://native-query.example.test/'
	}
	document := &dom.Document{
		url:     url
		origin_: url.origin()
	}
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blob := BlobHost.create(document) or { panic(err) }
	blob.install(mut runtime) or { panic(err) }
	blob.install_constructor() or { panic(err) }
	mut host := URLSearchParamsHost.create(document) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	return runtime
}

fn test_native_url_search_params_exposes_its_constructor() {
	$if !darwin { return }
	mut runtime := native_url_search_params_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host('typeof URLSearchParams')! == 'function'
	assert runtime.evaluate_host('globalThis.query=new URLSearchParams("?%EF%BB%BFname=%EF%BB%BFvalue&a=1&a=2&bad=%FF");query.size===4&&query.get("missing")===null&&query.get("\\uFEFFname")==="\\uFEFFvalue"&&query.getAll("a").join(",")==="1,2"&&query.toString()==="%EF%BB%BFname=%EF%BB%BFvalue&a=1&a=2&bad=%EF%BF%BD"')! == 'true'
	actual := runtime.evaluate_host_value('query')!
	mut native := runtime.native_url_search_params(actual)!
	assert native.params()[0] == domurl.QueryParam{
		name:  '\ufeffname'
		value: '\ufeffvalue'
	}
	assert runtime.javascript_url_search_params(native)! == actual
	native.append('native', 'a b')
	assert runtime.evaluate_host('query.get("native")==="a b"&&query.size===5')! == 'true'
	assert runtime.evaluate_host('query.set("a",3);query.delete("a",undefined);query.append("a",undefined);query.has("a","undefined")&&query.has("a",undefined)&&query.size===4')! == 'true'
	assert native.get('a') or { panic('native record missed script mutation') } == 'undefined'
}

fn test_native_url_search_params_converts_usv_union_and_ordered_records() {
	$if !darwin { return }
	mut runtime := native_url_search_params_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{const lone=String.fromCharCode(0xd800),low=String.fromCharCode(0xdc00),record={};record[lone]="first";record.middle="middle";record[low]="last";const p=new URLSearchParams(record);return [...p].map(pair=>pair.join(":" )).join("|")==="�:last|middle:middle"&&new URLSearchParams([[lone,low]]).toString()==="%EF%BF%BD=%EF%BF%BD"&&new URLSearchParams(null).toString()==="null="&&new URLSearchParams(undefined).size===0})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{let reads=0,nextReads=0;const init={get [Symbol.iterator](){reads++;return function(){let i=0;return {get next(){nextReads++;return function(){return i++?{done:true}:{done:false,value:["x","1"]}}}}}}};return new URLSearchParams(init).get("x")==="1"&&reads===1&&nextReads===1})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const calls=[],record=new Proxy({a:{toString(){calls.push("value");return "1"}}},{get(object,key){if(key===Symbol.iterator){calls.push("iterator");return null}calls.push("get:"+key);return object[key]},ownKeys(){calls.push("keys");return ["a"]},getOwnPropertyDescriptor(){calls.push("descriptor");return {enumerable:true,configurable:true}}});const p=new URLSearchParams(record);return p.toString()==="a=1"&&calls.join(",")==="iterator,keys,descriptor,get:a,value"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const p=new URLSearchParams([["a",1],["a",2]]);return new URLSearchParams(p).toString()==="a=1&a=2"&&(()=>{try{new URLSearchParams({[Symbol("x")]:1});return false}catch(reason){return reason instanceof TypeError}})()})()')! == 'true'
}

fn test_native_url_search_params_preserves_conversion_order_and_actual_exceptions() {
	$if !darwin { return }
	mut runtime := native_url_search_params_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{const marker={},calls=[];let failure;try{new URLSearchParams([["wrong"],[{toString(){calls.push("late");throw marker}},"value"]])}catch(reason){failure=reason}return failure===marker&&calls.join()==="late"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{let closed=0;const marker={},init={ [Symbol.iterator](){return {next(){return {done:false,value:[{toString(){throw marker}},"v"]}},return(){closed++;return {done:true}}}}};let failure;try{new URLSearchParams(init)}catch(reason){failure=reason}return failure===marker&&closed===0})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const marker={},failures=[()=>new URLSearchParams(new Proxy({},{get(){throw marker}})),()=>new URLSearchParams({[Symbol.iterator](){return {next(){throw marker}}}}),()=>new URLSearchParams({get a(){throw marker}}),()=>Reflect.construct(URLSearchParams,[],new Proxy(function(){},{get(){throw marker}}))];return failures.every(call=>{try{call();return false}catch(reason){return reason===marker}})})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const calls=[],init={get x(){calls.push("value");return "1"}};Object.defineProperty(init,Symbol.iterator,{get(){calls.push("iterator");return undefined}});const target=new Proxy(function(){},{get(object,key){if(key==="prototype"){calls.push("prototype");return null}return object[key]}});const p=Reflect.construct(URLSearchParams,[init],target);return calls.join(",")==="prototype,iterator,value"&&Object.getPrototypeOf(p)===URLSearchParams.prototype})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const marker={},p=new URLSearchParams();let converted=0;const value={toString(){converted++;throw marker}};let brand,missing,convert;try{p.append.call({},value,value)}catch(reason){brand=reason}try{p.append(value)}catch(reason){missing=reason}try{p.append("x",value)}catch(reason){convert=reason}return brand instanceof TypeError&&missing instanceof TypeError&&convert===marker&&converted===1&&p.size===0})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{try{new URLSearchParams([[1]])}catch(reason){return reason instanceof TypeError&&reason.message==="Expected each pair to contain exactly 2 items"}return false})()')! == 'true'
}

fn test_native_url_search_params_iterator_and_callback_observe_actual_live_owner() {
	$if !darwin { return }
	mut runtime := native_url_search_params_runtime()
	defer { runtime.close() }
	mut url :=
		domurl.DOMURL.create_from_url('https://native-query.example.test/?a=1&b=2&c=3', none)!
	mut params := url.search_params()
	actual := runtime.javascript_url_search_params(params)!
	bridge := runtime.make_value_host_function(fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	runtime.call_javascript_function(runtime.evaluate_host_value('(function(get){globalThis.ownedQuery=get()})')!,
		runtime.evaluate_host_value('undefined')!, [bridge])!
	assert voidptr(runtime.native_url_search_params(actual)!) == voidptr(params)
	assert runtime.evaluate_host('globalThis.iterator=ownedQuery.entries();iterator.next().value.join(":")==="a:1"')! == 'true'
	url.set_search('?x=9&y=8&z=7')
	assert runtime.evaluate_host('iterator.next().value.join(":")==="y:8"&&iterator.next().value.join(":")==="z:7"&&iterator.next().done')! == 'true'
	assert runtime.evaluate_host('ownedQuery.append("tail","6");iterator.next().value.join(":")==="tail:6"&&iterator.next().done')! == 'true'
	assert url.search() == '?x=9&y=8&z=7&tail=6'
	assert runtime.evaluate_host(r'(()=>{const p=new URLSearchParams("a=1&b=2&c=3"),seen=[],receiver={};p.forEach(function(value,key,owner){if(this!==receiver||owner!==p)throw new Error("callback identity");seen.push(key+value);if(key==="a"){p.delete("b");p.append("d","4")}return {get then(){throw new Error("unexpected adoption")}}},receiver);return seen.join(",")==="a1,c3,d4"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const marker={},p=new URLSearchParams("a=1&b=2");let calls=0,failure;try{p.forEach(()=>{calls++;throw marker})}catch(reason){failure=reason}const iterator=p.keys();return calls===1&&failure===marker&&iterator[Symbol.iterator]()===iterator&&iterator.next().value==="a"&&Object.prototype.toString.call(iterator)==="[object URLSearchParams Iterator]"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{const p=new URLSearchParams([["\uE000","b"],["😀","a"],["😀","c"]]);p.sort();return [...p.values()].join(",")==="a,c,b"&&p[Symbol.iterator]===p.entries&&(()=>{try{p.entries().next.call({});return false}catch(reason){return reason instanceof TypeError}})()})()')! == 'true'
}

fn test_native_url_search_params_metadata_subclass_and_close_ownership() {
	$if !darwin { return }
	mut runtime := native_url_search_params_runtime()
	assert runtime.evaluate_host(r'(()=>{const get=Object.getOwnPropertyDescriptor,c=URLSearchParams,p=c.prototype,g=get(globalThis,"URLSearchParams"),ctor=get(c,"prototype"),size=get(p,"size"),iter=get(p,Symbol.iterator);return c.name==="URLSearchParams"&&c.length===0&&g.value===c&&g.writable&&!g.enumerable&&g.configurable&&!ctor.writable&&!ctor.enumerable&&!ctor.configurable&&size.get.name==="get size"&&size.get.length===0&&size.enumerable&&size.configurable&&p.append.name==="append"&&p.append.length===2&&p.delete.length===1&&p.forEach.length===1&&p.entries.length===0&&Function.prototype.toString.call(p.append).includes("[native code]")&&iter.value===p.entries&&!iter.enumerable&&iter.writable&&iter.configurable&&Object.getPrototypeOf(new URLSearchParams().entries())===Object.getPrototypeOf(new URLSearchParams().entries())})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{class Query extends URLSearchParams{}const p=new Query("x=1");return p instanceof Query&&p instanceof URLSearchParams&&p.get("x")==="1"&&Object.prototype.toString.call(p)==="[object URLSearchParams]"})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{try{URLSearchParams()}catch(reason){return reason instanceof TypeError&&reason.message==="URLSearchParams constructor must be called with \u0027new\u0027"}return false})()')! == 'true'
	actual := runtime.evaluate_host_value('new URLSearchParams("retained=value")')!
	mut native := runtime.native_url_search_params(actual)!
	runtime.close()
	assert native.get('retained') or { '' } == 'value'
	if _ := runtime.native_url_search_params(actual) {
		assert false, 'closed runtime retained its wrapper table'
	}
}

fn test_native_url_search_params_keeps_conversion_intrinsics_after_author_mutation() {
	$if !darwin { return }
	mut runtime := native_url_search_params_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(()=>{const marker={},iterator=Array.prototype[Symbol.iterator],define=Object.defineProperty,ownKeys=Reflect.ownKeys,apply=Reflect.apply,string=String;try{Array.prototype[Symbol.iterator]=function(){throw marker};Object.defineProperty=Reflect.ownKeys=Reflect.apply=globalThis.String=function(){throw marker};const p=new URLSearchParams({a:"1"});p.append("b",2);return p.toString()==="a=1&b=2"&&p.getAll("b")[0]==="2"}finally{Array.prototype[Symbol.iterator]=iterator;Object.defineProperty=define;Reflect.ownKeys=ownKeys;Reflect.apply=apply;globalThis.String=string}})()')! == 'true'
}
