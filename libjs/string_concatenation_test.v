module libjs

fn concatenation_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'string-concatenation.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 500000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

// The + operator's string branch: empty sides, short (cached) and long
// results, non-ASCII code units, lone surrogates and converted operands.
fn test_string_concatenation_keeps_values() {
	for source, expected in {
		'var a="",b="xyz";[a+b,b+a,a+a,"x"+"",""+1].join("|")':                               'xyz|xyz||x|1'
		'var s="";for(var i=0;i<40;i++)s=s+(i%10);s.length+":"+s.slice(28)':                   '40:890123456789'
		'var s="ab";var t=s+"cdefg";var u=t+"h";[t,u,t.length,u.length,t===s+"cdefg"].join()': 'abcdefg,abcdefgh,7,8,true'
		'var s="é"+"😀"+"x";[s.length,s.charCodeAt(0),s.codePointAt(1),s[3]].join()':          '4,233,128512,x'
		'var s="\\ud800"+"\\udc00";[s.length,s.codePointAt(0)].join()':                         '2,65536'
		'var o={toString(){return "o"}};[o+"k","k"+o,1+"2",null+"",[1,2]+"",true+"!"].join()':  'ok,ko,12,null,1,2,true!'
		'var big="";for(var j=0;j<300;j++)big=big+"<li>"+j+"</li>";big.length+":"+big.slice(-12)': '3490:<li>299</li>'
	} {
		assert concatenation_eval(source)! == expected, source
	}
}

// Short ASCII results still come from the string cache.
fn test_short_concatenations_share_cached_strings() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	a := vm.create_string(utf16_string('ab'))
	b := vm.create_string(utf16_string('cd'))
	first := vm.concatenate_strings(a, b)
	second := vm.concatenate_strings(a, b)
	assert first.utf16.str() == 'abcd' && voidptr(first) == voidptr(second)
	long := vm.concatenate_strings(vm.create_string(utf16_string('abcdef')), b)
	assert long.utf16.str() == 'abcdefcd' && long.utf16.data.cap == long.utf16.data.len
	empty := vm.create_string(Utf16String.new())
	assert voidptr(vm.concatenate_strings(long, empty)) == voidptr(long)
	assert voidptr(vm.concatenate_strings(empty, long)) == voidptr(long)
}
