module libjs

fn inherited_hints_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'inherited-hints.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 5000000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Each source reads through one site repeatedly while the receiver, its
// prototype or the holder changes underneath the remembered position.
const inherited_hint_sources = {
	// Shadowing: an own property added after the site cached the prototype's position.
	'var p={m:1,n:2};var o=Object.create(p);function r(x){return x.m}var a=[r(o),r(o)];o.m=3;a.push(r(o));delete o.m;a.push(r(o));a.join()': '1,1,3,1'
	// The holder's property deleted, re-added at another position, replaced by an accessor.
	'var p={a:0,m:1};var o=Object.create(p);function r(x){return x.m}var v=[r(o),r(o)];delete p.m;v.push(r(o));p.z=5;p.m=7;v.push(r(o));Object.defineProperty(p,"m",{get(){return this===o?"getter":"other"},configurable:true});v.push(r(o),r(o));v.join()': '1,1,,7,getter,getter'
	// Re-parenting, a proxy prototype, then a deeper holder.
	'var p1={m:"p1"},p2={x:0,y:0,m:"p2"};var o=Object.create(p1);function r(x){return x.m}var v=[r(o),r(o)];Object.setPrototypeOf(o,p2);v.push(r(o));Object.setPrototypeOf(o,new Proxy({},{get(t,k,rc){return k==="m"&&rc===o?"trap":undefined}}));v.push(r(o));var g={m:"g"};var mid=Object.create(g);Object.setPrototypeOf(o,mid);v.push(r(o),r(o));mid.m="mid";v.push(r(o));delete mid.m;v.push(r(o));v.join()': 'p1,p1,p2,trap,g,g,mid,g'
	// One site, receivers with own, inherited and absent keys in turn.
	'var p={m:"inherited"};var own={m:"own"};var kid=Object.create(p);var none={};function r(x){return x.m}var v=[];for(var i=0;i<3;i++)v.push(r(kid),r(own),r(none),r(kid));v.join()': 'inherited,own,,inherited,inherited,own,,inherited,inherited,own,,inherited'
	// Arrays: methods, symbol keys, own string keys, length and elements.
	'var a=[3,1,2];function r(x){return typeof x.indexOf}var v=[r(a),r(a),typeof a[Symbol.iterator],a.length,a[1]];a.indexOf=5;v.push(r(a));delete a.indexOf;v.push(r(a));a.length=1;v.push(a.length,a[1]);Array.prototype.extra=9;v.push(a.extra,a.extra);delete Array.prototype.extra;v.push(a.extra);v.join()': 'function,function,function,3,1,number,function,1,,9,9,'
	// String objects: virtual characters, length, own and prototype keys.
	'var s=new String("abc");function r(x,k){return x[k]}var v=[s.length,s[1],r(s,"charAt")===String.prototype.charAt,s.charAt(2),r(s,"0"),r(s,1)];s.extra="own";String.prototype.more="proto";v.push(s.extra,s.more,"xy".more);delete String.prototype.more;v.push(s.more,s[5],s["-0"]);v.join()': '3,b,true,c,a,b,own,proto,proto,,,'
	// Large key-indexed objects as receiver and as prototype.
	'var big={};for(var i=0;i<100;i++)big["k"+i]=i;var kid=Object.create(big);function r(x,k){return x[k]}var v=[];for(var j=0;j<3;j++)v.push(kid.k7,big.k42,kid.k99,kid.missing);big.k7="changed";delete big.k99;v.push(kid.k7,kid.k99);kid.k42="own";v.push(kid.k42,big.k42);v.join()': '7,42,99,,7,42,99,,7,42,99,,changed,,own,42'
	// Keys equal by contents only: lengths around the 8-byte compare, differing last units, surrogates.
	'var o={abc:1,abd:2,abcdefgh:3,abcdefgi:4,abcdefghijklmnop:5,abcdefghijklmnoq:6,"\\ud83d\\ude00":7,"\\ud83d\\ude01":8};var p=Object.create(o);var k=["ab"+"c","ab"+"d","abcdefg"+"h","abcdefg"+"i","abcdefghijklmno"+"p","abcdefghijklmno"+"q","\\ud83d"+"\\ude00","\\ud83d"+"\\ude01","abcdefghijklmnopq",""];var v=[];for(var i=0;i<k.length;i++)v.push(p[k[i]],o[k[i]]);v.join()': '1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,,,,'
}

fn test_inherited_property_hints_follow_every_change() {
	defer {
		set_wide_property_hints_for_testing(true)
		diagnose_property_hints_for_testing(false)
	}
	for wide in [false, true] {
		set_wide_property_hints_for_testing(wide)
		diagnose_property_hints_for_testing(true)
		for source, expected in inherited_hint_sources {
			assert inherited_hints_eval(source)! == expected, '${wide}: ${source}'
		}
		hits := inherited_property_hint_hits_for_testing()
		if wide { assert hits > 20 } else { assert hits == 0 }
	}
}

// String.prototype methods read through the site's hint, so a primitive
// receiver and a String object share it with ordinary objects.
fn test_string_prototype_reads_use_hints() {
	defer { diagnose_property_hints_for_testing(false) }
	diagnose_property_hints_for_testing(true)
	assert inherited_hints_eval('var t="abc";var n=0;for(var i=0;i<10;i++)n+=t.charCodeAt(i%3);String(n)')! == '979'
	assert diagnose_property_hints_for_testing(true) >= 9
	assert inherited_hints_eval('var t=new String("abc");var n=0;for(var i=0;i<10;i++)n+=t.charCodeAt(i%3);String(n)')! == '979'
	assert inherited_property_hint_hits_for_testing() >= 9
}

fn test_property_key_equality_compares_all_code_units() {
	for length in 0 .. 20 {
		mut units := []u16{len: length, init: u16(0x61 + index % 26)}
		a := Utf16String{data: units.clone()}
		b := Utf16String{data: units.clone()}
		assert PropertyName{string_value: &a}.equals(PropertyName{string_value: &b})
		for position in 0 .. length {
			mut changed := units.clone()
			changed[position] = 0xd83d
			c := Utf16String{data: changed}
			assert !PropertyName{string_value: &a}.equals(PropertyName{string_value: &c}), '${length} ${position}'
		}
		units << u16(0x7a)
		d := Utf16String{data: units}
		assert !PropertyName{string_value: &a}.equals(PropertyName{string_value: &d})
	}
	empty := Utf16String{}
	assert PropertyName{string_value: unsafe { nil }}.equals(PropertyName{string_value: &empty})
}
