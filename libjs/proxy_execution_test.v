// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn proxy_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'proxy-execution.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_proxy_creation_shape_revocation_and_transparent_array_branding() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var errors=0;for(var f of [()=>Proxy({},{}),()=>new Proxy(1,{}),()=>new Proxy({},null)])try{f()}catch(e){if(e instanceof TypeError)errors++}var a=new Proxy([1,2],{}),b=new Proxy(a,{});errors===3&&Proxy.length===2&&Proxy.revocable.length===2&&!Object.hasOwn(Proxy,"prototype")&&Array.isArray(b)&&b.length===2&&b[1]===2&&Object.prototype.toString.call(b)==="[object Array]"')!.as_bool()
	assert proxy_eval(mut vm, r'var r=Proxy.revocable({},{}),p=r.proxy;r.revoke();r.revoke();var errors=0;for(var f of [()=>p.x,()=>{p.x=1},()=>"x" in p,()=>delete p.x,()=>Reflect.ownKeys(p),()=>Object.getOwnPropertyDescriptor(p,"x"),()=>Reflect.defineProperty(p,"x",{}),()=>Reflect.getPrototypeOf(p),()=>Reflect.setPrototypeOf(p,null),()=>Reflect.isExtensible(p),()=>Reflect.preventExtensions(p),()=>Array.isArray(p)])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===12&&typeof p==="object"&&r.revoke.length===0&&r.revoke.name===""')!.as_bool()
	// A proxy wrapping a revoked target still checks target invariants after
	// its own get trap; successful creation does not make that read valid.
	assert proxy_eval(mut vm, r'var errors=0;var wrapper=new Proxy(p,{get(){return 42}});try{wrapper.x}catch(e){if(e instanceof TypeError)errors++}errors===1')!.as_bool()
}

fn test_proxy_preserves_trap_receiver_and_ordinary_set_receiver_descriptor_dispatch() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var seen="",receiver={},target={get x(){return this}},handler={get(t,k,r){if(this!==handler||t!==target)throw 1;seen+=k;return Reflect.get(t,k,r)}};var p=new Proxy(target,handler);Reflect.get(p,"x",receiver)===receiver&&seen==="x"&&Object.create(p).x!==p')!.as_bool()
	assert proxy_eval(mut vm, r'var log="",target={x:1};var p=new Proxy(target,{getOwnPropertyDescriptor(t,k){log+="descriptor:"+k+";";return Reflect.getOwnPropertyDescriptor(t,k)},defineProperty(t,k,d){log+="define:"+Object.keys(d).join()+";";return Reflect.defineProperty(t,k,d)}});p.x=42;target.x===42&&log==="descriptor:x;define:value;"')!.as_bool()
	assert proxy_eval(mut vm, r'var target={},r=Proxy.revocable(target,{get(t,k){r.revoke();return 42}});r.proxy.x===42&&typeof r.proxy==="object"')!.as_bool()
}

fn test_proxy_get_set_has_and_delete_enforce_target_invariants_and_same_value() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var t={};Object.defineProperty(t,"x",{value:NaN});var p=new Proxy(t,{get(){return NaN},set(){return true}});var ok=Number.isNaN(p.x)&&Reflect.set(p,"x",NaN);var errors=0;for(var f of [()=>new Proxy(t,{get(){return 1}}).x,()=>Reflect.set(p,"x",1),()=>"x" in new Proxy(t,{has(){return false}}),()=>Reflect.deleteProperty(new Proxy(t,{deleteProperty(){return true}}),"x")])try{f()}catch(e){if(e instanceof TypeError)errors++}var z={};Object.defineProperty(z,"zero",{value:-0});try{new Proxy(z,{get(){return 0}}).zero}catch(e){if(e instanceof TypeError)errors++}ok&&errors===5')!.as_bool()
	assert proxy_eval(mut vm, r'var t={};Object.defineProperty(t,"x",{get:undefined,set:undefined});var errors=0;for(var f of [()=>new Proxy(t,{get(){return 42}}).x,()=>Reflect.set(new Proxy(t,{set(){return true}}),"x",42)])try{f()}catch(e){if(e instanceof TypeError)errors++}var p=new Proxy({x:1},{set(){return false},deleteProperty(){return false}});errors===2&&!Reflect.set(p,"x",2)&&!Reflect.deleteProperty(p,"x")')!.as_bool()
	assert proxy_eval(mut vm, r'var t={x:1};Object.preventExtensions(t);var errors=0;for(var f of [()=>"x" in new Proxy(t,{has(){return false}}),()=>Reflect.deleteProperty(new Proxy(t,{deleteProperty(){return true}}),"x")])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===2&&!("absent" in new Proxy(t,{has(){return false}}))&&Reflect.deleteProperty(new Proxy(t,{deleteProperty(){return true}}),"absent")')!.as_bool()
}

fn test_proxy_descriptor_traps_preserve_partial_descriptors_and_post_trap_invariants() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var seen="",t={},p=new Proxy(t,{defineProperty(target,key,d){seen=Object.keys(d).join();return Reflect.defineProperty(target,key,d)}});Object.defineProperty(p,"x",{value:42});seen==="value"&&t.x===42&&Object.getOwnPropertyDescriptor(p,"x").configurable===false')!.as_bool()
	assert proxy_eval(mut vm, r'var errors=0,t={};Object.defineProperty(t,"x",{value:1,writable:true});var p=new Proxy(t,{getOwnPropertyDescriptor(){return {value:1,writable:false,configurable:false}}});try{Object.getOwnPropertyDescriptor(p,"x")}catch(e){if(e instanceof TypeError)errors++}try{Reflect.defineProperty(new Proxy(t,{defineProperty(){return true}}),"x",{writable:false})}catch(e){if(e instanceof TypeError)errors++}try{Object.getOwnPropertyDescriptor(new Proxy(t,{getOwnPropertyDescriptor(){return undefined}}),"x")}catch(e){if(e instanceof TypeError)errors++}try{Reflect.defineProperty(new Proxy({},{defineProperty(){return true}}),"invented",{configurable:false})}catch(e){if(e instanceof TypeError)errors++}errors===4')!.as_bool()
	assert proxy_eval(mut vm, r'var t={},p=new Proxy(t,{getOwnPropertyDescriptor(target,key){Object.defineProperty(target,key,{value:42});return {value:42}},defineProperty(target,key,d){return Reflect.defineProperty(target,key,d)}});Object.getOwnPropertyDescriptor(p,"x").value===42&&Reflect.defineProperty(p,"x",{value:42})')!.as_bool()
	assert proxy_eval(mut vm, r'var log="",d=new Proxy({value:42,configurable:true},{has(t,k){log+="h:"+k+";";return Reflect.has(t,k)},get(t,k){log+="g:"+k+";";return Reflect.get(t,k)}});var p=new Proxy({},{getOwnPropertyDescriptor(){return d}});Object.getOwnPropertyDescriptor(p,"x").value===42&&log==="h:enumerable;h:configurable;g:configurable;h:value;g:value;h:writable;h:get;h:set;"')!.as_bool()
}

fn test_proxy_own_keys_preserve_symbols_utf16_order_and_finish_list_conversion_before_duplicates() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var a=Symbol("same"),b=Symbol("same"),keys=["2","1",a,b,"\ud800","\ud801"],p=new Proxy({},{ownKeys(){return keys}}),actual=Reflect.ownKeys(p);actual.length===6&&actual.every((k,i)=>k===keys[i])&&Object.getOwnPropertyNames(p).join(":")==="2:1:\ud800:\ud801"&&Object.getOwnPropertySymbols(p)[1]===b')!.as_bool()
	assert proxy_eval(mut vm, r'var marker={},reads="",list={length:3,0:"x",1:"x",get 2(){reads+="last";throw marker}},caught=false;try{Reflect.ownKeys(new Proxy({},{ownKeys(){return list}}))}catch(e){caught=e===marker}var errors=0;for(var keys of [["x","x"],[1],[Symbol.iterator,Symbol.iterator]])try{Reflect.ownKeys(new Proxy({},{ownKeys(){return keys}}))}catch(e){if(e instanceof TypeError)errors++}caught&&reads==="last"&&errors===3')!.as_bool()
	assert proxy_eval(mut vm, r'var t={};Object.defineProperty(t,"fixed",{value:1});var errors=0;try{Reflect.ownKeys(new Proxy(t,{ownKeys(){return []}}))}catch(e){if(e instanceof TypeError)errors++}var target=Object.preventExtensions({a:1});for(var keys of [[],["a","extra"]])try{Reflect.ownKeys(new Proxy(target,{ownKeys(){return keys}}))}catch(e){if(e instanceof TypeError)errors++}errors===3&&Reflect.ownKeys(new Proxy(target,{ownKeys(){return ["a"]}}))[0]==="a"')!.as_bool()
}

fn test_proxy_prototypes_extensibility_and_integrity_operations() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var proto={},other={},t=Object.create(proto);Object.preventExtensions(t);var errors=0;for(var f of [()=>Reflect.getPrototypeOf(new Proxy(t,{getPrototypeOf(){return other}})),()=>Reflect.setPrototypeOf(new Proxy(t,{setPrototypeOf(){return true}}),other),()=>Reflect.isExtensible(new Proxy(t,{isExtensible(){return true}})),()=>Reflect.preventExtensions(new Proxy({},{preventExtensions(){return true}}))])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===4&&Reflect.getPrototypeOf(new Proxy(t,{getPrototypeOf(){return proto}}))===proto&&Reflect.setPrototypeOf(new Proxy(t,{setPrototypeOf(){return true}}),proto)')!.as_bool()
	assert proxy_eval(mut vm, r'var t={x:42},p=new Proxy(t,{});Object.freeze(p);Object.isFrozen(p)&&Object.isSealed(p)&&!Object.isExtensible(p)&&Object.isFrozen(t)&&p.x===42')!.as_bool()
	assert proxy_eval(mut vm, r'var log="",p=new Proxy({},{getPrototypeOf(){log+="p";return null}}),o={};Object.setPrototypeOf(o,p);log===""&&Object.getPrototypeOf(o)===p')!.as_bool()
}

fn test_proxy_calls_construction_bind_and_revoked_callability() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var receiver={},handler={apply(t,r,a){return this===handler&&r===receiver&&Array.isArray(a)&&a.join()=== "20,22"?42:0}},p=new Proxy(function(){throw 1},handler);p.call(receiver,20,22)===42&&p.bind(receiver,20)(22)===42&&typeof p==="function"&&Function.prototype.toString.call(p).includes("[native code]")')!.as_bool()
	assert proxy_eval(mut vm, r'function Target(x){this.x=x;this.nt=new.target}var seen;var p=new Proxy(Target,{construct(t,args,nt){seen=nt;return Reflect.construct(t,args,nt)}}),o=new p(42);o.x===42&&o.nt===p&&seen===p&&o instanceof Target&&o instanceof p&&new Proxy(Target,{}).prototype===Target.prototype')!.as_bool()
	assert proxy_eval(mut vm, r'var errors=0,r=Proxy.revocable(function(){},{});r.revoke();for(var f of [()=>r.proxy(),()=>new r.proxy(),()=>Function.prototype.bind.call(r.proxy,null)])try{f()}catch(e){if(e instanceof TypeError)errors++}try{new (new Proxy(function(){},{construct(){return 1}}))()}catch(e){if(e instanceof TypeError)errors++}try{new (new Proxy(()=>1,{construct(){return {}}}))()}catch(e){if(e instanceof TypeError)errors++}errors===5&&typeof r.proxy==="function"')!.as_bool()
}

fn test_proxy_for_in_traversal_is_lazy_and_does_not_call_has() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var log="",p=new Proxy({a:1,b:2},{ownKeys(t){log+="keys;";return Reflect.ownKeys(t)},getOwnPropertyDescriptor(t,k){log+="desc:"+k+";";return Reflect.getOwnPropertyDescriptor(t,k)},getPrototypeOf(){log+="proto;";return null},has(){throw 1}});for(var k in p){log+="body:"+k+";";break}log==="keys;desc:a;body:a;"')!.as_bool()
	assert proxy_eval(mut vm, r'var log="",proto={a:7,b:8,c:9},target={a:1,b:2};var p=new Proxy(target,{ownKeys(){log+="keys;";return ["a","b"]},getOwnPropertyDescriptor(t,k){log+="desc:"+k+";";return Reflect.getOwnPropertyDescriptor(t,k)},getPrototypeOf(){log+="proto;";return proto},has(){throw 1}}),names="";for(var k in p){names+=k;delete target.b}names==="abc"&&log==="keys;desc:a;desc:b;proto;"')!.as_bool()
}

fn test_proxy_array_methods_object_spread_and_descriptors_preserve_abrupt_traps() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var log="",p=new Proxy([1,,3],{has(t,k){log+="h"+k;return Reflect.has(t,k)}});var result=p.map(v=>v*2);result[0]===2&&!(1 in result)&&result[2]===6&&log==="h0h1h2"')!.as_bool()
	assert proxy_eval(mut vm, r'var marker={},p=new Proxy({x:1},{getOwnPropertyDescriptor(){throw marker}}),errors=0;for(var f of [()=>Object.keys(p),()=>Object.hasOwn(p,"x"),()=>Object.getOwnPropertyDescriptors(p),()=>({...p}),()=>Object.assign({},p)])try{f()}catch(e){if(e===marker)errors++}errors===5')!.as_bool()
}

fn test_proxy_recursive_traps_share_budget_and_leave_the_vm_usable() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, r'var handler={},p=new Proxy({},handler);Object.setPrototypeOf(handler,p);var caught=false;try{p.x}catch(e){caught=e instanceof Error}caught')!.as_bool()
	assert vm.proxy_operation_depth == 0 && vm.interpreter_stack().depth() == 0
	assert proxy_eval(mut vm, '6*7')!.number == 42
}

fn test_proxy_dispatch_runs_from_reused_native_code_without_the_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-proxy-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert proxy_eval(mut vm, r'function read(o){return o.answer}function put(o,v){o.answer=v}var t={answer:20},p=new Proxy(t,{get(t,k,r){return Reflect.get(t,k,r)},set(t,k,v,r){return Reflect.set(t,k,v,r)}});put(p,42);read(p)===42&&Object.keys(p).join()==="answer"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert vm.proxy_operation_depth == 0 && vm.interpreter_stack().depth() == 0
		vm.close_native_code()!
	}
}

fn test_proxy_array_species_and_abrupt_trap_lookup_are_observable() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert proxy_eval(mut vm, 'var calls=0;class A extends Array{static get [Symbol.species](){calls++;return Array}}var a=new Proxy(new A(1,2),{});a.map(x=>x*2).join() === "2,4"&&a.slice().join() === "1,2"&&calls===2')!.as_bool()
	assert proxy_eval(mut vm, 'var marker={},reads=0,handler={get get(){reads++;throw marker}},p=new Proxy({},handler),caught=false;try{p.x}catch(e){caught=e===marker}var errors=0;try{new Proxy({},{get:1}).x}catch(e){if(e instanceof TypeError)errors++}caught&&reads===1&&errors===1&&new Proxy({x:42},{get:null}).x===42')!.as_bool()
}
