module main

import dom
import x.json2

// The shared query boundary has already replayed pending DOM and style writes.
// Use the document's paint hit test, including transforms and pointer-events,
// and return the same native element identities used by selector queries.
fn (mut binding CompactElementQueryBinding) hit_test_query(action string, input string) !string {
	point := json2.decode[[]f64](input)!
	if point.len != 2 { return error('Invalid hit-test coordinates') }
	mut document := unsafe { &dom.Document(binding.document) }
	if action == 'elementFromPoint' {
		element := document.element_from_point(point[0], point[1]) or { return 'null' }
		return binding.encode_element_state(element)
	}
	mut states := []json2.Any{}
	for element in document.elements_from_point(point[0], point[1]) {
		states << binding.element_state(element)
	}
	return json2.encode(states)
}

fn compact_hit_testing_bootstrap() string {
	return r'
const __hitTestFinite=Number.isFinite;
for(const name of ["elementFromPoint","elementsFromPoint"]){
 const method={ [name](x,y){
  "use strict";
  if(this!==document)throw new TypeError("Illegal Document receiver");
  if(arguments.length<2)throw new TypeError(name+" requires two arguments");
  x=+x;
  if(!__hitTestFinite(x))throw new TypeError("The x coordinate must be finite");
  y=+y;
  if(!__hitTestFinite(y))throw new TypeError("The y coordinate must be finite");
  return __queryElements("",name,JSON.stringify([x,y]));
 }}[name];
 Object.defineProperty(document,name,{value:method,writable:true,enumerable:true,configurable:true});
}
'
}
