module main

import browserjs
import dom
import html

fn test_canvas_drawing_flushes_compact_filter_mutations_after_state_restore() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><svg><defs><filter id="live" color-interpolation-filters="sRGB"><feOffset id="offset" dx="2"/></filter></defs></svg><canvas id="target" width="32" height="24"></canvas><canvas id="source" width="2" height="2"></canvas>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
 const context=target.getContext("2d"), sourceContext=source.getContext("2d");
 const primitive=document.getElementById("offset");
 sourceContext.fillStyle="red";sourceContext.fillRect(0,0,2,2);
 context.filter="url(#live)";
 context.save();context.filter="none";context.restore();
 context.fillStyle="red";context.fillRect(0,2,2,2);
 primitive.setAttribute("dx","8");
 context.fillRect(0,8,2,2);
 primitive.setAttribute("dx","14");
 context.drawImage(source,0,14);
 globalThis.liveFilterPixels=JSON.stringify([2,8,14].map((x,i)=>
  Array.from(context.getImageData(x,2+6*i,1,1).data)));
 globalThis.staleFilterPixels=JSON.stringify([
  Array.from(context.getImageData(2,8,1,1).data),
  Array.from(context.getImageData(8,14,1,1).data)]);
 '], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('liveFilterPixels')! == '[[255,0,0,255],[255,0,0,255],[255,0,0,255]]'
	assert runtime.evaluate_host('staleFilterPixels')! == '[[0,0,0,0],[0,0,0,0]]'
	assert document.get_element_by_id('offset')?.get_attribute_value('dx') == '14'
}

fn test_canvas_drawing_resolves_new_and_replaced_compact_svg_filter_children() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><svg><defs id="definitions"></defs></svg><canvas id="target" width="32" height="24"></canvas>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
 const context=target.getContext("2d");
 const filter=document.createElementNS("http://www.w3.org/2000/svg","filter");
 filter.id="created";filter.setAttribute("color-interpolation-filters","sRGB");
 const primitive=document.createElementNS("http://www.w3.org/2000/svg","feOffset");
 primitive.setAttribute("dx","6");filter.appendChild(primitive);
 definitions.appendChild(filter);
 context.filter="url(#created)";context.fillStyle="lime";
 context.beginPath();context.rect(0,2,2,2);context.fill();
 filter.innerHTML=`<feOffset dx="12"/>`;
 context.beginPath();context.rect(0,8,2,2);context.fill();
 globalThis.createdFilterPixels=JSON.stringify([
  Array.from(context.getImageData(6,2,1,1).data),
  Array.from(context.getImageData(12,8,1,1).data),
  Array.from(context.getImageData(6,8,1,1).data)]);
 '], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('createdFilterPixels')! == '[[0,255,0,255],[0,255,0,255],[0,0,0,0]]'
}
