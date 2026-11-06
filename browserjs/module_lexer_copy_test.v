module browserjs

fn run_module_lexer_copy_fixture(source string) !string {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	// Exercise the native transport directly even when the retained-JS control
	// is selected for the module-host integration tests.
	copy := runtime.retain_javascript_value(C.vox_make_module_lexer_copy(runtime.context))!
	fixture := runtime.evaluate_host_value(source)!
	value := runtime.call_javascript_function(fixture, C.vox_jsc_JSValueMakeUndefined(runtime.context), [copy])!
	return runtime.binding_dom_string(value)
}

fn test_module_lexer_native_copy_preserves_code_units_and_independent_storage() {
	$if !darwin {
		return
	}
	assert run_module_lexer_copy_fixture(r'(copy)=>{
 let previous;
 for(const source of ["","ASCII","éĀ😀\u0000\ud800\udfff", "x".repeat(131072),"Ā".repeat(65537)]){
  const value=copy(source);
  if(!(value instanceof Uint16Array)||value.length!==source.length)return "invalid output";
  const bytes=new Uint8Array(value.buffer);
  for(let i=0;i<source.length;i++){
   const unit=source.charCodeAt(i);
   if(bytes[2*i] !== (unit&255) || bytes[1+2*i] !== (unit>>>8))return "unit mismatch";
  }
  value.fill(42);
  const next=copy(source);
  for(let i=0;i<source.length;i++)if(next[i]!==source.charCodeAt(i))return "aliased storage";
  if(previous&&previous.some(unit=>unit!==42))return "previous output mutated";
  previous=value;
 }
 return "exact";
}')! == 'exact'
}

fn test_module_lexer_native_copy_rejects_non_strings_without_author_conversion() {
	$if !darwin {
		return
	}
	assert run_module_lexer_copy_fixture(r'(copy)=>{
 let hooks=0;const fake={toString(){hooks++;throw 2}};
 for(const args of [[fake],[123],[null],[undefined],[new String("text")],[],["one","extra"]]){
  if(copy(...args)!==undefined)return "accepted non-string";
 }
 return hooks===0?"exact":"author conversion";
}')! == 'exact'
}

fn test_module_lexer_native_copy_transfers_into_current_wasm_view_after_growth() {
	$if !darwin {
		return
	}
	result := run_module_lexer_copy_fixture(r'(copy)=>{
 let memory;try{memory=new WebAssembly.Memory({initial:1,maximum:3})}catch(e){return "unavailable"}
 const first=copy("first");
 new Uint16Array(memory.buffer,8,8).set(first);
 memory.grow(1);
 const next=new Uint16Array(memory.buffer,70000,8);next.fill(555);
 next.set(copy("é😀\ud800"));
 if(String(next.slice(0,4))!=="233,55357,56832,55296"||next.slice(4).some(x=>x!==555))return "growth mismatch";
 if(String(first)!=="102,105,114,115,116")return "snapshot mutated";
 return "exact";
}')!
	assert result in ['exact', 'unavailable'], result
}
