module main

import browserjs
import html

fn test_named_elements_build_wrappers_on_first_read() {
	$if darwin {
		document :=
			html.parse_document('<!doctype html><div id="target">t</div><p id="other">o</p><span id="123">n</span><b id="setTimeout">s</b><i id="unread">u</i>')
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close() }
		mut messages := []string{}
		_ = run_document_script_sources(document, 'about:blank', [
			browserjs.ScriptSource{
				code: '
				const before=Object.getOwnPropertyDescriptor(window,"target");
				if(typeof before.get!=="function"||!before.enumerable||!before.configurable)throw new Error("lazy accessor");
				if(target!==document.getElementById("target")||target.textContent!=="t")throw new Error("first read identity");
				const after=Object.getOwnPropertyDescriptor(window,"target");
				if(after.value!==target||!after.writable||!after.enumerable||!after.configurable)throw new Error("settled data property");
				window.other=5;
				if(other!==5||Object.getOwnPropertyDescriptor(window,"other").value!==5)throw new Error("assignment before read");
				if(window["123"]!==document.getElementById("123"))throw new Error("numeric id");
				const collision=Object.getOwnPropertyDescriptor(window,"setTimeout");
				if(!collision||"get" in collision)throw new Error("collision keeps eager assignment");
				if(!Object.keys(window).includes("unread"))throw new Error("enumerable before read");
				delete window.unread;
				if("unread" in window)throw new Error("configurable before read");
				console.log("named elements passed");
			'
			},
		], runtime, mut messages)
		assert messages == ['named elements passed']
	}
}
