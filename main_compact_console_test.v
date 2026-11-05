module main

import browserjs
import html

// Discord calls console.debug while starting its web app; a console that only
// had log/info/warn/error threw before the app rendered.
fn test_console_exposes_the_console_standard_namespace() {
	mut document := html.parse_document('<!doctype html><p>console</p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://console.test/', [r'
globalThis.missing=["assert","clear","debug","error","info","log","table","trace","warn","dir","dirxml","count","countReset","group","groupCollapsed","groupEnd","time","timeLog","timeEnd"].filter(name=>typeof console[name]!=="function");
console.debug("debug",1);
console.trace("where");
console.assert(true,"hidden");console.assert(false,"shown",2);
console.count();console.count();console.count("named");console.countReset();console.count();console.countReset("absent");
console.group("outer");console.log("inside");console.groupCollapsed();console.dir({});console.groupEnd();console.groupEnd();console.log("outside");
console.time("t");console.time("t");console.timeEnd("t");console.timeEnd("t");
console.table([1]);console.dirxml("x");console.clear();
'], runtime, mut messages)
	assert runtime.evaluate_host('missing.length')! == '0'
	assert messages.filter(!it.starts_with('t: ')) == ['debug 1', 'Trace: where', 'Assertion failed: shown 2',
		'default: 1', 'default: 2', 'named: 1', 'default: 1', 'Count for absent does not exist', 'outer',
		'  inside', '    [object Object]', 'outside', 'Timer t already exists', 'Timer t does not exist', '1',
		'x']
	assert messages.filter(it.starts_with('t: ') && it.ends_with(' ms')).len == 1
}
