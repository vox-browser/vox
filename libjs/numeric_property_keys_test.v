module libjs

fn numeric_key_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'numeric-keys.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// Integral Numbers in the array-index range become numeric keys directly;
// every other Number keeps ToString's key.
fn test_numeric_property_keys_match_tostring_keys() {
	for source, expected in {
		'var o={};o[0]="a";o[-0]="b";o[1.5]="c";o[-1]="d";Object.keys(o).join()+":"+o["0"]+o["1.5"]+o["-1"]': '0,1.5,-1:bcd'
		'var o={};o[4294967294]="max";o[4294967295]="big";o[4294967296]="bigger";Object.keys(o).join()':           '4294967294,4294967295,4294967296'
		'var a=[];a[4294967294]=1;a[4294967295]=2;a.length+":"+Object.keys(a).join()':                             '4294967295:4294967294,4294967295'
		'var o={};o[NaN]=1;o[Infinity]=2;o[-Infinity]=3;o[1e21]=4;Object.keys(o).join()':                          'NaN,Infinity,-Infinity,1e+21'
		'var a=[10,20,30];[a[0],a[1.0],a["2"],a[2.5],a[-0]].join()':                                               '10,20,30,,10'
		'var s="abc";[s[0],s[2],s[3],s[-0]].join()':                                                             'a,c,,a'
		'var t=new Uint8Array(3);t[1]=7;t[1.5]=9;[t[1],t[1.5],Object.keys(t).join("|")].join()':                   '7,,0|1|2'
		'var o={"7":"s"};[o[7],7 in o,"7" in o,delete o[7],o[7]].join()':                                         's,true,true,true,'
	} {
		assert numeric_key_eval(source)! == expected, source
	}
}
