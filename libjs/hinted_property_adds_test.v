module libjs

fn hinted_adds_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'hinted-adds.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 5000000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Each source runs one adding site (`o.x = v` on objects that lack x) while
// the receiver or its prototype chain changes.
const hinted_add_sources = {
	// Adds, then a receiver that already has the key, then adds again; order and capacity.
	'function put(o,v){o.x=v;return o}var r=[];for(var i=0;i<3;i++)r.push(put({},i).x);var has={a:1,x:0};put(has,7);r.push(has.x,Object.keys(has).join(""));r.push(put({},8).x);var sizes=[];for(var n=1;n<8;n++){var o={};for(var k=0;k<n;k++)o["k"+k]=k;sizes.push(Object.keys(o).join("")+"="+JSON.stringify(o).length)}r.join()+"|"+sizes.join(" ")': '0,1,2,7,ax,8|k0=8 k0k1=15 k0k1k2=22 k0k1k2k3=29 k0k1k2k3k4=36 k0k1k2k3k4k5=43 k0k1k2k3k4k5k6=50'
	// A setter appears on the prototype, then on Object.prototype; both receive the receiver.
	'function put(o,v){o.x=v}var proto={};var seen=[];var a=Object.create(proto);put(a,1);var b=Object.create(proto);Object.defineProperty(proto,"x",{set(v){seen.push("proto:"+v+(this===b))},configurable:true});put(b,2);delete proto.x;Object.defineProperty(Object.prototype,"x",{set(v){seen.push("object:"+v)},configurable:true});var c={};put(c,3);delete Object.prototype.x;var d={};put(d,4);[a.x,Object.keys(b).length,Object.keys(c).length,d.x,seen.join()].join()': '1,0,0,4,proto:2true,object:3'
	// Read-only inherited properties and non-extensible receivers: sloppy ignores, strict throws.
	'function put(o,v){o.x=v}function strictPut(o,v){"use strict";o.x=v}var ro=Object.create(Object.defineProperty({},"x",{value:"ro",writable:false}));put(ro,1);var r=[ro.x,Object.keys(ro).length];try{strictPut(ro,2)}catch(e){r.push(e.name)}var sealed=Object.preventExtensions({});put(sealed,3);r.push(sealed.x);try{strictPut(sealed,4)}catch(e){r.push(e.name)}var ok={};strictPut(ok,5);r.push(ok.x);r.join()': 'ro,0,TypeError,,TypeError,5'
	// Proxy receivers and prototypes, null prototypes, arrays and symbol keys.
	'function put(o,v){o.x=v}var log=[];var p=new Proxy({},{set(t,k,v,rc){log.push("trap:"+String(k)+v);t[k]=v;return true}});put(p,1);var child=Object.create(new Proxy({},{set(t,k,v,rc){log.push("chain:"+v+(rc===child));return Reflect.set(t,k,v,rc)}}));put(child,2);var bare=Object.create(null);put(bare,3);var arr=[1];put(arr,4);var s=Symbol("s");function sym(o,v){o[s]=v}var so={};sym(so,5);sym({},6);[p.x,Object.keys(child).join(""),child.x,bare.x,arr.x,arr.length,so[s],log.join()].join()': '1,x,2,3,4,1,5,trap:x1,chain:2true'
	// Key-indexed receivers (64 or more properties) keep their index current.
	'var big={};for(var i=0;i<70;i++)big["p"+i]=i;function put(o,k,v){o[k]=v}put(big,"q1","a");put(big,"q2","b");var r=[big.q1,big.q2,big.p69,Object.keys(big).length,"q1" in big,big.hasOwnProperty("q2")];r.join()': 'a,b,69,72,true,true'
}

fn test_hinted_property_adds_match_complete_sets() {
	defer { set_hinted_adds_for_testing(true) }
	for enabled in [false, true] {
		set_hinted_adds_for_testing(enabled)
		for source, expected in hinted_add_sources {
			assert hinted_adds_eval(source)! == expected, '${enabled}: ${source}'
		}
	}
}

// The first added property reserves room for four.
fn test_first_added_property_reserves_four_slots() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), vm.realm().object_prototype_record())
	assert object.properties.cap == 0
	assert object.set_absent_own_data_property(PropertyName.from_str('a'), Value.from_i32(1)) == absent_own_set_added
	assert object.properties.len == 1 && object.properties.cap == 4
	for name in ['b', 'c', 'd'] {
		assert object.set_absent_own_data_property(PropertyName.from_str(name), Value.from_i32(2)) == absent_own_set_added
	}
	assert object.properties.len == 4 && object.properties.cap == 4
}
