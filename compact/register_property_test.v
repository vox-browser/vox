module main

import browserjs
import dom

fn test_compact_css_register_property_registers_typed_custom_properties() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><div id="target" style="--size: 5px"></div>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const fail=message=>{throw new Error(message);};
const expectError=(name,callback)=>{try{callback();}catch(error){if(error.name===name)return;fail("expected "+name+" got "+error.name);}fail("expected "+name);};
CSS.registerProperty({name:"--size",syntax:"<length>",inherits:false,initialValue:"0px"});
CSS.registerProperty({name:"--other",syntax:"<color>",inherits:true,initialValue:"red"});
const style=getComputedStyle(document.getElementById("target"));
if(style.getPropertyValue("--size")!=="5px"||style.getPropertyValue("--other")==="")fail("registered values "+style.getPropertyValue("--size")+" "+style.getPropertyValue("--other"));
expectError("InvalidModificationError",()=>CSS.registerProperty({name:"--size",syntax:"<length>",inherits:false,initialValue:"1px"}));
expectError("SyntaxError",()=>CSS.registerProperty({name:"size",syntax:"*",inherits:false}));
expectError("SyntaxError",()=>CSS.registerProperty({name:"--bad",syntax:"<length>",inherits:false}));
expectError("TypeError",()=>CSS.registerProperty({name:"--missing"}));
console.log("registerProperty passed");
'], runtime, mut messages)
	assert messages == ['registerProperty passed']
}
