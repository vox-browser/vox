module main

import browserjs
import html
import dom
import page
import time

// Sizzle (jQuery) enables its fast paths only for functions that print as
// native code; page functions must keep their own source text.
fn test_bridge_platform_functions_print_as_native_code() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><html><body><div id="a" class="x"></div></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [r'
		const rnative=/^[^{]+\{\s*\[native \w/, root=document.documentElement;
		function pageFunction(value) { return value + 1; }
		let threw=false;
		try { Function.prototype.toString.call({}); } catch (error) { threw = error instanceof TypeError; }
		globalThis.result = [
			rnative.test(document.getElementsByClassName), rnative.test(document.body.getElementsByClassName),
			rnative.test(root.compareDocumentPosition), rnative.test(root.contains),
			rnative.test(document.getElementsByTagName), rnative.test(window.getComputedStyle),
			rnative.test(Function.prototype.toString),
			String(document.getElementsByClassName) === "function getElementsByClassName() {\n    [native code]\n}",
			rnative.test(pageFunction), String(pageFunction).indexOf("return value + 1") >= 0,
			rnative.test(function () {}), threw,
		].join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'true|true|true|true|true|true|true|true|false|true|false|true'
	assert messages == []
}

fn test_platform_function_source_is_preserved_across_same_origin_realms() {
	$if !darwin {
		return
	}
	owner := page.Page.create(1)!
	address := dom.URL{ value: 'https://native-source.test/' }
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><body><iframe id="frame"></iframe></body>', address, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		if mut host := browser_child_document_hosts_[voidptr(document)] { host.close() }
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [r'
	 const frame=document.getElementById("frame"),view=frame.contentWindow;
	 const childSource=view.Function.prototype.toString,parentSource=Function.prototype.toString;
	 const native=/\[native code\]/;
	 function authorFunction(value){return value+17;}
	 const childAuthor=view.eval("(function childAuthor(value){return value+23;})");
	 globalThis.crossRealmChecks=[
	  native.test(childSource.call(document.getElementsByClassName)),
	  native.test(parentSource.call(view.document.getElementsByClassName)),
	  childSource.call(authorFunction).includes("value+17"),
	  parentSource.call(childAuthor).includes("value+23"),
	  !native.test(childSource.call(authorFunction)),
	  !native.test(parentSource.call(childAuthor))
	 ];
	 globalThis.retainedChildSource=childSource;
	 globalThis.retainedPlatformMethod=document.getElementsByClassName;
	 frame.remove();
	'], runtime, mut messages)
	assert messages == []string{}, messages.join('\n')
	assert runtime.evaluate_host('crossRealmChecks.every(Boolean)')! == 'true'
	mut host := browser_child_document_hosts_[voidptr(document)] or { panic('missing child host') }
	host.poll(mut messages)
	assert host.children[0].closed
	assert runtime.evaluate_host(r'/\[native code\]/.test(retainedChildSource.call(retainedPlatformMethod))')! == 'true'
}

fn test_platform_function_source_is_native_on_error_and_ignores_name_getters() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><body></body>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://native-source.test/', [r'
 const platform=document.getElementsByClassName,original=String(platform);
 Object.defineProperty(platform,"name",{get(){throw Error("author name getter")},configurable:true});
 let nativeStack=false;
 try{Function.prototype.toString.call({})}catch(error){nativeStack=error instanceof TypeError&&!error.stack.split("\n").some(line=>line==="@"||line==="toString@");}
 globalThis.nativeSourceBoundary=String(platform)===original&&nativeStack;
 '], runtime, mut messages)
	assert messages == []string{}, messages.join('\n')
	assert runtime.evaluate_host('nativeSourceBoundary')! == 'true'
}
