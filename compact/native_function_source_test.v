module main

import browserjs
import html

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
