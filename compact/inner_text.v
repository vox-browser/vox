module main

import dom
import html
import x.json2

// HTMLElement.innerText and outerText through the translated rendered-text
// algorithms, which read the attached layout and otherwise fall back to the
// element's descendant text content.
fn (mut binding CompactElementQueryBinding) inner_text_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	node := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
	element := node.as_element() or { return error('TypeError: Illegal HTMLElement receiver') }
	if !element.is_html_element() { return error('TypeError: Illegal HTMLElement receiver') }
	html_element := unsafe { &dom.HTMLElement(element) }
	op := json_string_property(request, 'op') or { '' }
	value := json_string_property(request, 'value') or { '' }
	match op {
		'get' { return json2.encode({ 'value': json2.Any(html.html_element_inner_text(html_element)) }) }
		'set' {
			html.html_element_set_inner_text(html_element, value)
			return json2.encode({ 'refresh': binding.structure_refresh() })
		}
		'setOuter' {
			parent := node.parent() or {
				return error('NoModificationAllowedError: The element has no parent')
			}
			compact_set_outer_text(node, parent, value)!
			return json2.encode({ 'refresh': binding.structure_refresh() })
		}
		else { return error('Invalid innerText operation') }
	}
}

// https://html.spec.whatwg.org/multipage/dom.html#set-the-outer-text
fn compact_set_outer_text(node &dom.Node, parent &dom.Node, value string) ! {
	next := node.next_sibling()
	previous := node.previous_sibling()
	document := node.document()
	// The rendered text fragment for value, built by the innerText setter.
	mut holder := document.create_element('div')!
	holder.set_inner_text(value)
	mut fragment := document.create_document_fragment()
	mut fragment_node := unsafe { &dom.Node(fragment) }
	for child in holder.as_node().children_as_vector() {
		fragment_node.append_child(child)!
	}
	if fragment_node.children.len == 0 {
		fragment_node.append_child(document.create_text_node('').as_node())!
	}
	mut owner := unsafe { &dom.Node(parent) }
	owner.replace_child(fragment_node, node)!
	if after := next {
		if before := after.previous_sibling() { compact_merge_with_next_text(before)! }
	}
	if before := previous { compact_merge_with_next_text(before)! }
}

// https://html.spec.whatwg.org/multipage/dom.html#merge-with-the-next-text-node
fn compact_merge_with_next_text(node &dom.Node) ! {
	if !node.is_text() { return }
	next := node.next_sibling() or { return }
	if !next.is_text() { return }
	mut text := node.as_character_data() or { return }
	following := next.as_character_data() or { return }
	text.append_data(following.data())!
	mut next_node := unsafe { &dom.Node(next) }
	next_node.remove(false)
}

fn compact_inner_text_bootstrap() string {
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
  if(!state)throw new TypeError("Illegal HTMLElement receiver");
  request.state=state.created?state:undefined;
  try{return __queryElements(state.bridgeKey,"innerText",JSON.stringify(request),true);}catch(error){fail(error);}
 }
 function text(value){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return value===null?"":String(value);}
 const accessors={
  get innerText(){return call(this,{op:"get"}).value;},
  set innerText(value){refresh(call(this,{op:"set",value:text(value)}));},
  get outerText(){return call(this,{op:"get"}).value;},
  set outerText(value){refresh(call(this,{op:"setOuter",value:text(value)}));}
 };
 const owner=typeof HTMLElement==="function"?HTMLElement.prototype:Element.prototype;
 for(const name of ["innerText","outerText"]){
  const descriptor=Object.getOwnPropertyDescriptor(accessors,name);
  Object.defineProperty(owner,name,{get:descriptor.get,set:descriptor.set,enumerable:true,configurable:true});
 }
})();
'
}
