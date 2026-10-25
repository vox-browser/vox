module browserjs

import dom
import html
import loader

fn test_global_base64_uses_native_algorithms_and_binary_strings() {
	$if !darwin && !linux {
		return
	}
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://base64.test/' }
	mut document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_base64_binding()!
	assert runtime.evaluate_host(r'
 const binary=String.fromCharCode(...Array.from({length:256},(_,i)=>i));
 atob(btoa(binary))===binary&&btoa("hello")==="aGVsbG8="&&atob(" aGVs\nbG8= ")==="hello"&&atob("Zg")==="f"&&atob("Zm8")==="fo"&&atob("")==="";
 ')! == 'true'
	assert runtime.evaluate_host(r'
 let rejected=0;
 for(const value of ["Z", "Zg=", "Zg===", "=Zg=", "Z=g=", "====", "Zg==x", "Zg==\u00a0", "€"]){try{atob(value)}catch(error){if(error instanceof DOMException&&error.name==="InvalidCharacterError"&&error.code===5)rejected++}}
 for(const value of ["€", "\ud800", "😀"]){try{btoa(value)}catch(error){if(error instanceof DOMException&&error.name==="InvalidCharacterError")rejected++}}
 rejected===12;
 ')! == 'true'
	assert runtime.evaluate_host(r'
 let conversions=0;const original={};
 const value={toString(){conversions++;return "Zg=="}};
 let preserved=false;try{atob({toString(){throw original}})}catch(error){preserved=error===original}
 let rejected=0;for(const f of [()=>atob(),()=>btoa(),()=>atob(Symbol()),()=>btoa.call({},"a"),()=>new btoa("a")]){try{f()}catch(error){if(error instanceof TypeError)rejected++}}
 const descriptor=Object.getOwnPropertyDescriptor(globalThis,"atob");
 atob(value)==="f"&&conversions===1&&preserved&&rejected===5&&atob.name==="atob"&&atob.length===1&&descriptor.writable&&descriptor.enumerable&&descriptor.configurable;
 ')! == 'true'
	assert runtime.evaluate_host('globalThis.atob=17;true')! == 'true'
	runtime.install_base64_binding()!
	assert runtime.evaluate_host('atob===17')! == 'true'
}
