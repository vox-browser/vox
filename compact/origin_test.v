module main

import browserjs
import dom

fn test_compact_origin_interface_compares_tuple_and_opaque_origins() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><body><a id=link href="https://sub.example.com:8443/x">x</a><a id=bare>y</a></body>',
		dom.URL{ value: 'https://www.example.com/page' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const fail=message=>{throw new Error(message);};
const opaque=new Origin();
if(!opaque.opaque||opaque.isSameOrigin(new Origin())||!opaque.isSameOrigin(opaque))fail("opaque");
const a=Origin.from("https://www.example.com/path"),b=Origin.from("https://www.example.com:443/other");
if(a.opaque||!a.isSameOrigin(b))fail("tuple equality");
const link=Origin.from(document.getElementById("link"));
if(link.isSameOrigin(a)||!link.isSameSite(a))fail("same site");
if(Origin.from("http://www.example.com").isSameSite(a))fail("scheme is part of the site");
if(!Origin.from(globalThis).isSameOrigin(a))fail("global");
if(!Origin.from(new URL("https://www.example.com/q")).isSameOrigin(a))fail("URL");
if(!Origin.from(a).isSameOrigin(a)||Origin.from(a)===a)fail("copy");
for(const value of ["not a url",document.getElementById("bare"),{},1,null,window.location]){
 let threw=false;try{Origin.from(value);}catch(error){threw=error instanceof TypeError;}
 if(!threw)fail("from "+String(value));
}
let threw=false;try{Origin();}catch(error){threw=error instanceof TypeError;}
if(!threw)fail("call without new");
console.log("origin passed");
'], runtime, mut messages)
	assert messages == ['origin passed'], messages.str()
}
