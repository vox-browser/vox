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
	assert created.properties.len == 0 && created.private_elements.len == 0
	mut copy := *created
	// Equal but separately allocated: compare every other byte.
	copy.properties = reference.properties
	copy.private_elements = reference.private_elements
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
