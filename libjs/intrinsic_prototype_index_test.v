module libjs

fn intrinsic_index_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'intrinsic-index.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

fn test_intrinsic_prototypes_use_complete_key_indexes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	assert realm.object_prototype_record().indexed_properties != none
	assert realm.function_prototype_record().indexed_properties != none
}

// Script additions, redefinitions and deletions on the indexed prototypes
// stay visible through inherited reads, writes and `in`.
fn test_intrinsic_prototype_index_follows_script_mutations() {
	for source, expected in {
		'var o={};var r=[o.extra];Object.prototype.extra=1;r.push(o.extra,"extra" in o);delete Object.prototype.extra;r.push(o.extra,"extra" in o);r.join()': ',1,true,,false'
		'var log=[];Object.defineProperty(Object.prototype,"x",{set(v){log.push(v)},configurable:true});var o={};o.x=5;var r=log.join()+":"+o.hasOwnProperty("x");delete Object.prototype.x;o.x=6;r+":"+o.x': '5:false:6'
		'Object.defineProperty(Object.prototype,"ro",{value:1,writable:false,configurable:true});var o={};o.ro=2;var r=o.ro+":"+o.hasOwnProperty("ro");delete Object.prototype.ro;o.ro=3;r+":"+o.ro': '1:false:3'
		'Array.prototype.last=function(){return this[this.length-1]};var r=[[1,2,3].last()];Array.prototype.push=function(){return "patched"};r[1]=[].push(1);r.join()': '3,patched'
		'function f(){return 1}Function.prototype.tag="t";var r=[f.tag,(()=>0).tag];Function.prototype.call=function(){return "call"};r.push(f.call());r.join()': 't,t,call'
		'var keys=[];for(var i=0;i<40;i++){Object.prototype["k"+i]=i}var o={};for(var i=0;i<40;i+=13){keys.push(o["k"+i])}for(var i=0;i<40;i++){delete Object.prototype["k"+i]}keys.push(o.k0);keys.join()': '0,13,26,39,'
		'Object.prototype.toString=function(){return "own"};var r=String({});delete Object.prototype.toString;r+":"+(typeof ({}).toString)': 'own:undefined'
	} {
		assert intrinsic_index_eval(source)! == expected, source
	}
}
