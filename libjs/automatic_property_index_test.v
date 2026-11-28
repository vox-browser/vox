module libjs

fn automatic_index_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'automatic-index.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 2000000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Large ordinary objects switch to the complete key index; insertion order,
// deletion, re-addition, accessors, literal and JSON construction and
// prototype reads keep their results either way.
fn test_large_objects_keep_semantics_with_the_complete_index() {
	defer { set_automatic_property_index_for_testing(true) }
	for enabled in [false, true] {
		set_automatic_property_index_for_testing(enabled)
		for source, expected in {
			'var d={};for(var i=0;i<200;i++)d["k"+i]=i;delete d.k7;d.k7=7;delete d.k100;var s=0;for(var j=0;j<200;j++)s+=d["k"+j]||0;var ks=Object.keys(d);[s,ks.length,ks[0],ks[197],ks[198],"k100" in d].join()': '19800,199,k0,k199,k7,false'
			'var p={inherited:1};var o=Object.create(p);for(var i=0;i<100;i++)o["f"+i]=i;[o.inherited,o.f99,o.missing,Object.getOwnPropertyNames(o).length].join()':     '1,99,,100'
			'var t={};for(var i=0;i<100;i++)t["a"+i]=i;var o=JSON.parse(JSON.stringify(t));o.extra=1;[Object.keys(o).length,o.a0+o.a99,o.extra].join()':                   '101,99,1'
			'var o={};for(var i=0;i<80;i++)o[i]=i;for(var i=0;i<80;i++)o["s"+i]=i;var g=0;Object.defineProperty(o,"acc",{get(){return ++g}});[o.acc,o.acc,o[79],o.s79,Object.keys(o).length].join()': '1,2,79,79,160'
			'var src="({";for(var i=0;i<90;i++)src+="x"+i+":"+i+",";src+="x5:500,["+"\\"x\\"+1]:100})";var o=Function("return "+src)();[o.x5,o.x1,o.x89,Object.keys(o).length].join()':           '500,100,89,90'
			'var o={};for(var i=0;i<70;i++)o["m"+i]=function(){return this.v};o.v=3;var f=Object.freeze(o);"use strict";[o.m69(),Object.isFrozen(f),(function(){"use strict";try{o.z=1;return "added"}catch(e){return e.name}})()].join()': '3,true,TypeError'
		} {
			assert automatic_index_eval(source)! == expected, '${enabled}: ${source}'
		}
	}
}
