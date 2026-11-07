module main

import browserjs
import dom
import html
import x.json2

// https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#textFieldSelection
// selectionStart, selectionEnd, selectionDirection, setSelectionRange() and
// setRangeText() of input and textarea read and update the native text
// control, which also decides when the APIs apply to an input type.
fn compact_text_selection_mode(value string) !html.SelectionMode {
	return match value {
		'select' { .select }
		'start' { .start }
		'end' { .end }
		'preserve' { .preserve }
		else { error('TypeError: Invalid SelectionMode') }
	}
}

fn compact_text_selection_index(value json2.Any) ?u32 {
	return match value {
		f64 { u32(value) }
		i64 { u32(value) }
		int { u32(value) }
		else { none }
	}
}

fn (mut binding CompactElementQueryBinding) text_selection_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	node := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
	mut element := node.as_element() or { return error('TypeError: Invalid text control receiver') }
	if !element.is_html_element() || element.local_name() !in ['input', 'textarea'] {
		return error('TypeError: Invalid text control receiver')
	}
	mut text := if element.local_name() == 'input' {
		html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) }).text_control
	} else {
		html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) }).text
	}
	op := json_string_property(request, 'op') or { 'get' }
	value := request['value'] or { json2.Any(json2.Null{}) }
	direction := json_string_property(request, 'direction')
	match op {
		'get' {}
		'setStart' { text.set_selection_start_binding(compact_text_selection_index(value))! }
		'setEnd' { text.set_selection_end_binding(compact_text_selection_index(value))! }
		'setDirection' { text.set_selection_direction_binding(direction)! }
		'setRange' {
			text.set_selection_range(compact_text_selection_index(request['start'] or { json2.Any(0) }),
				compact_text_selection_index(request['end'] or { json2.Any(0) }), direction)!
		}
		'setRangeText' {
			replacement := json_string_property(request, 'replacement') or { '' }
			if start := compact_text_selection_index(request['start'] or { json2.Any(json2.Null{}) }) {
				end := compact_text_selection_index(request['end'] or { json2.Any(0) }) or { 0 }
				mode := compact_text_selection_mode(json_string_property(request, 'mode') or { 'preserve' })!
				text.set_range_text_binding(replacement, start, end, mode)!
			} else {
				text.set_range_text_at_selection(replacement)!
			}
			// The changed text is the control's API value, not its default.
			if element.local_name() == 'textarea' {
				mut model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
				model.dirty_value = true
			}
			mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
			runtime.mark_document_state_dirty()
			runtime.mark_document_replay_effects()
		}
		else { return error('Invalid text selection operation') }
	}
	start := text.selection_start_binding()
	end := text.selection_end_binding()
	return json2.encode({
		'start':     if index := start { json2.Any(i64(index)) } else { json2.Any(json2.Null{}) }
		'end':       if index := end { json2.Any(i64(index)) } else { json2.Any(json2.Null{}) }
		'direction': if current := text.selection_direction() { json2.Any(current) } else { json2.Any(json2.Null{}) }
	})
}

fn compact_text_selection_bootstrap() string {
	return r'
(function(){
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
 const index=value=>{const number=Number(value);return Number.isFinite(number)?Math.trunc(number)>>>0:0;};
 function call(receiver,request){
  const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
  if(!state||state.namespaceURI!=="http://www.w3.org/1999/xhtml"||(state.tagName!=="input"&&state.tagName!=="textarea"))throw new TypeError("Illegal text control receiver");
  request.state=state.created?state:undefined;
  try{return __queryElements(state.bridgeKey,"textSelection",JSON.stringify(request),true);}
  catch(error){const match=/^(InvalidStateError|IndexSizeError|SyntaxError|TypeError):\s*(.*)/.exec(String(error.message));if(!match)throw error;if(match[1]==="TypeError")throw new TypeError(match[2]);throw new DOMException(match[2],match[1]);}
 }
 const accessors={
  selectionStart:{get(){return call(this,{op:"get"}).start;},set(value){call(this,{op:"setStart",value:value===null?null:index(value)});}},
  selectionEnd:{get(){return call(this,{op:"get"}).end;},set(value){call(this,{op:"setEnd",value:value===null?null:index(value)});}},
  selectionDirection:{get(){return call(this,{op:"get"}).direction;},set(value){call(this,{op:"setDirection",direction:value===null?undefined:string(value)});}}
 };
 const methods={
  setSelectionRange(start,end){
   if(arguments.length<2)throw new TypeError("setSelectionRange requires a start and an end");
   const request={op:"setRange",start:index(start),end:index(end)};
   if(arguments.length>2&&arguments[2]!==undefined)request.direction=string(arguments[2]);
   call(this,request);
  },
  setRangeText(replacement){
   if(arguments.length<1)throw new TypeError("setRangeText requires a replacement");
   const request={op:"setRangeText",replacement:string(replacement)};
   if(arguments.length>1){
    if(arguments.length<3)throw new TypeError("setRangeText requires both a start and an end");
    request.start=index(arguments[1]);request.end=index(arguments[2]);
    if(request.start>request.end)throw new DOMException("The start offset is after the end offset","IndexSizeError");
    request.mode=arguments[3]===undefined?"preserve":string(arguments[3]);
   }
   call(this,request);
  }
 };
 for(const constructor of [HTMLInputElement,HTMLTextAreaElement]){
  for(const [name,descriptor] of Object.entries(accessors))Object.defineProperty(constructor.prototype,name,Object.assign({enumerable:true,configurable:true},descriptor));
  for(const [name,value] of Object.entries(methods))Object.defineProperty(constructor.prototype,name,{value,writable:true,enumerable:true,configurable:true});
 }
})();
'
}
