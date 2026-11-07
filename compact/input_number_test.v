module main

import browserjs
import html

fn test_input_number_and_date_accessors_use_the_input_model() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><input id="n" type="number" value="5" step="2" min="1"><input id="d" type="date" value="2020-01-02"><input id="t" type="text" value="x">')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'console.log(n.valueAsNumber,String(t.valueAsNumber),d.valueAsDate.toISOString(),String(n.valueAsDate));n.stepUp();console.log(n.value);n.stepDown(2);console.log(n.value);n.valueAsNumber=11;console.log(n.value);d.valueAsDate=new Date(Date.UTC(2021,5,7));console.log(d.value);try{t.stepUp()}catch(e){console.log(e.name)}try{n.valueAsNumber=Infinity}catch(e){console.log(e.name)}',
	], runtime, mut messages)
	assert messages == ['5 NaN 2020-01-02T00:00:00.000Z null', '7', '3', '11', '2021-06-07',
		'InvalidStateError', 'TypeError']
}
