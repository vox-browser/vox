module libjs

// Object.create() allocates a zeroed record and sets the non-zero defaults;
// it must equal the struct literal's defaults in every other byte.
fn test_object_create_matches_struct_literal_defaults() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := vm.realm().object_prototype_record()
	created := Object.create(vm.realm(), prototype)
	reference := Object{
		prototype: prototype
	}
	assert created.extensible == reference.extensible && created.class_name == reference.class_name
	assert created.properties.len == 0 && voidptr(created.slots) == voidptr(empty_object_slots)
	mut copy := *created
	// Equal but separately allocated: compare every other byte.
	copy.properties = reference.properties
	copy.class_name = reference.class_name
	assert unsafe { vmemcmp(&copy, &reference, int(sizeof(Object))) } == 0
	mut object := Object.create(vm.realm(), none)
	assert object.prototype == none
	object.properties << OwnProperty{key: PropertyName.from_str('a'), value: Value.from_i32(1)}
	assert object.properties.len == 1 && object.properties[0].value.number == 1
}

fn object_creation_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'object-creation.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Literals reserve storage for their definitions; later additions still grow it.
fn test_literals_reserve_property_storage_without_changing_semantics() {
	for source, expected in {
		'var o={a:1,b:2,c:3};o.d=4;o.e=5;delete o.b;Object.keys(o).join()+":"+o.e':                  'a,c,d,e:5'
		'var o={a:1,...{b:2,c:3},a:4,get g(){return 9}};JSON.stringify(o)+o.g':                         '{"a":4,"b":2,"c":3,"g":9}9'
		'var a=[1,2,3];a.push(4);a[9]=10;a.length+":"+a.join()':                                         '10:1,2,3,4,,,,,,10'
		'var a=[,1,,];a.length+":"+(0 in a)+(1 in a)':                                                   '3:falsetrue'
		'var big={};for(var i=0;i<50;i++){big["k"+i]=i}var o={x:1,y:2};Object.keys(o).length+":"+big.k49': '2:49'
	} {
		assert object_creation_eval(source)! == expected, source
	}
}

// Constructors reserve their last instance's property count; instances with
// fewer, more or different properties keep ordinary semantics.
fn test_constructors_reserve_their_instances_property_storage() {
	for source, expected in {
		'function P(n){this.a=n;if(n>1){this.b=n;this.c=n}}var r=[];for(var i=0;i<4;i++){r.push(Object.keys(new P(i)).join(""))}r.join()': 'a,a,abc,abc'
		'class C{x=1;constructor(v){this.v=v}}var o=[new C(1),new C(2)];o.map(c=>c.x+c.v+Object.keys(c).join("")).join()':               '2xv,3xv'
		'function R(){return {r:1}}var a=new R,b=new R;(a.r+b.r)+":"+Object.keys(a).join()':                                             '2:r'
		'class B{constructor(){this.p=1}}class D extends B{constructor(){super();this.q=2}}var d=new D;Object.keys(d).join()+new D().q':   'p,q2'
	} {
		assert object_creation_eval(source)! == expected, source
	}
}

fn assert_empty_slots_unchanged() {
	empty := empty_object_slots
	assert empty.private_elements.len == 0 && empty.error_data == none && empty.regexp_object == none
	assert empty.keyed_collection == none && empty.keyed_iterator == none && empty.weak_map == none
	assert empty.weak_set == none && empty.weak_ref == none && empty.date_object == none
	assert empty.boolean_object == none && empty.number_object == none && empty.bigint_object == none
	assert empty.symbol_object == none && empty.string_iterator == none && empty.property_name_iterator == none
	assert empty.bound_function == none && empty.data_view == none && empty.binding_reference == none
	assert empty.super_property_base == none && empty.regexp_string_iterator == none
	assert empty.intl_locale == none && empty.intl_collator == none && empty.intl_number_format == none
}

// Ordinary objects and functions share the empty slots record; an object that
// gains a rare internal slot gets its own record and leaves the shared one empty.
fn test_rare_internal_slots_are_allocated_per_object() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut first := Object.create(vm.realm(), none)
	second := Object.create(vm.realm(), none)
	assert voidptr(first.slots) == voidptr(second.slots)
	first.mut_slots().private_elements << PrivateElement{ kind: .field, value: Value.from_i32(1) }
	assert voidptr(first.slots) != voidptr(empty_object_slots) && first.slots.private_elements.len == 1
	assert voidptr(second.slots) == voidptr(empty_object_slots)
	slots := first.slots
	first.mut_slots().private_elements[0].value = Value.from_i32(2)
	assert voidptr(first.slots) == voidptr(slots) && first.slots.private_elements[0].value.number == 2
	assert_empty_slots_unchanged()
	for source, expected in {
		'var o={a:1},f=function(){};[typeof o,typeof f].join()':                                                       'object,function'
		'var d=new Date(0),r=/a(b)/g,m=new Map([[1,2]]),s=new Set([3]);[d.getTime(),r.exec("ab")[1],m.get(1),s.has(3)].join()': '0,b,2,true'
		'var w=new WeakMap,k={};w.set(k,5);var ws=new WeakSet;ws.add(k);[w.get(k),ws.has(k),new WeakRef(k).deref()===k].join()': '5,true,true'
		'var e=new TypeError("x"),b=Object(true),n=Object(4),i=Object(5n),y=Object(Symbol("q"));[e.message,b.valueOf(),n+1,i+1n,y.description].join()': 'x,true,5,6,q'
		'class C{#p=1;get p(){return this.#p}set p(v){this.#p=v}}var c=new C;c.p=7;var it="ab"[Symbol.iterator]();it.next();[c.p,it.next().value].join()': '7,b'
		'function t(){return this.v}var g=t.bind({v:8});var x;[x]=[9];var out=[];for(var key in {u:1})out.push(key);[g(),x,out].join()': '8,9,u'
		'var dv=new DataView(new ArrayBuffer(4));dv.setInt8(1,3);class A{m(){return 1}}class B extends A{m(){return super.m()+1}}[dv.getInt8(1),new B().m()].join()': '3,2'
	} {
		assert object_creation_eval(source)! == expected, source
	}
	assert_empty_slots_unchanged()
	mut script := Script.parse('var plain={a:1};function fn(){}', vm.realm(), 'slots.js', unsafe { nil })!
	vm.run(mut script)!
	global := script.realm.global_object or { panic('Missing global') }
	for name in ['plain', 'fn'] {
		value := global.internal_get(mut vm, PropertyName.from_str(name), Value.from_object(global))!
		assert voidptr(value.as_object().slots) == voidptr(empty_object_slots), name
	}
}
