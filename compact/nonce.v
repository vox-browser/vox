module main

import x.json2

fn (mut binding CompactElementQueryBinding) nonce_query(key string, input string) !string {
	request := json2.decode[map[string]json2.Any](input)!
	node := binding.equality_node(key, request['ownState'] or { json2.Any(json2.Null{}) })!
	mut element := node.as_element() or { return error('TypeError: Invalid nonce receiver') }
	if !(element.is_html_element() || element.is_svg_element()) { return error('TypeError: Invalid nonce receiver') }
	if json_string_property(request,'op') or { '' } == 'set' {
		element.set_cryptographic_nonce(json_string_property(request,'value') or { '' })
	}
	return json2.encode(element.cryptographic_nonce())
}

fn compact_nonce_bootstrap() string {
	return r'
(function(){
 function owner(value){const state=__elementApply(__elementRecordGet,__elementRecords,[value]);if(!state||(state.namespaceURI!=="http://www.w3.org/1999/xhtml"&&state.namespaceURI!=="http://www.w3.org/2000/svg"))throw new TypeError("Illegal nonce receiver");return state;}
 for(const prototype of [HTMLElement.prototype,SVGElement.prototype])Object.defineProperty(prototype,"nonce",{
  get:function(){const state=owner(this);return __queryElements(state.bridgeKey,"nonce",JSON.stringify({ownState:state,op:"get"}),true);},
  set:function(value){const state=owner(this);if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");value=String(value);__queryElements(state.bridgeKey,"nonce",JSON.stringify({ownState:state,op:"set",value}),true);},
  enumerable:true,configurable:true
 });
})();
'
}
