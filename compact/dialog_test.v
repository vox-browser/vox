module main

import browserjs
import dom

fn test_compact_dialog_methods_run_the_translated_dialog_steps() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><body><dialog id=d><p>x</p></dialog></body>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const fail=message=>{throw new Error(message);};
const dialog=document.getElementById("d");
dialog.show();
if(!dialog.open||!dialog.hasAttribute("open")||dialog.matches(":modal"))fail("show");
let threw="";try{dialog.showModal();}catch(error){threw=error.name;}
if(threw!=="InvalidStateError")fail("showModal while open "+threw);
dialog.close("done");
if(dialog.open||dialog.returnValue!=="done")fail("close "+dialog.returnValue);
dialog.returnValue="";dialog.showModal();
if(!dialog.matches(":modal"))fail("modal");
dialog.requestClose("asked");
if(dialog.open||dialog.returnValue!=="asked")fail("requestClose");
console.log("dialog passed");
'], runtime, mut messages)
	assert messages == ['dialog passed'], messages.str()
}
