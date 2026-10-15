module browserjs

import html

fn test_compact_console_info_keeps_argument_conversion_order_and_detached_calls() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><body></body>')
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	runtime.evaluate_host(bridge_program(bridge_initial_state(document, 'about:blank')))!
	assert runtime.evaluate_host(r'(()=>{
		const conversions=[];
		const first={toString(){conversions.push("first");return "one";}};
		const second={toString(){conversions.push("second");return "two";}};
		const info=console.info;
		if(info(first,second,17,null,undefined)!==undefined)throw new Error("return value");
		info();
		return JSON.stringify({conversions,logs:JSON.parse(__ladybirdSnapshot()).logs});
	})()')! == r'{"conversions":["first","second"],"logs":["one two 17 null undefined",""]}'
}

fn test_compact_console_info_preserves_original_conversion_errors_without_partial_logs() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><body></body>')
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	runtime.evaluate_host(bridge_program(bridge_initial_state(document, 'about:blank')))!
	assert runtime.evaluate_host(r'(()=>{
		const original={message:"original info conversion"};let caught=false,converted=false;
		try{console.info("prefix",{toString(){throw original;}},{toString(){converted=true;return "late";}});}
		catch(error){caught=error===original;}
		return caught && !converted && JSON.parse(__ladybirdSnapshot()).logs.length===0;
	})()')! == 'true'
}
