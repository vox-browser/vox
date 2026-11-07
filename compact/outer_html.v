module main

import x.json2

// Element.outerHTML serializes and replaces the element through the native
// fragment serializer and parser.
fn (mut binding CompactElementQueryBinding) outer_html_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	node := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
	mut element := node.as_element() or { return error('TypeError: Illegal Element receiver') }
	value := request['value'] or { return json2.encode({ 'value': json2.Any(element.outer_html()!) }) }
	if node.parent() == none { return '{}' }
	element.set_outer_html(value.str())!
	return json2.encode({
		'refresh': binding.structure_refresh()
	})
}

fn compact_outer_html_bootstrap() string {
	return r'
(function(){
 const refresh=globalThis.__compactApplyMutationRefresh;
 function fail(error){
  const match=/^([A-Za-z]*Error):\s*(.*)/.exec(String(error&&error.message));
  if(!match)throw error;
  if(match[1]==="TypeError")throw new TypeError(match[2]);
  throw new DOMException(match[2],match[1]);
 }
 function call(receiver,request){
  const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
  if(!state)throw new TypeError("Illegal Element receiver");
  request.state=state.created?state:undefined;
  try{return __queryElements(state.bridgeKey,"outerHTML",JSON.stringify(request),true);}catch(error){fail(error);}
 }
 const accessors={
  get outerHTML(){return call(this,{}).value;},
  set outerHTML(value){
   // [LegacyNullToEmptyString]
   if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
   refresh(call(this,{value:value===null?"":String(value)}));
  }
 };
 const descriptor=Object.getOwnPropertyDescriptor(accessors,"outerHTML");
 Object.defineProperty(Element.prototype,"outerHTML",{get:descriptor.get,set:descriptor.set,enumerable:true,configurable:true});
})();
'
}
