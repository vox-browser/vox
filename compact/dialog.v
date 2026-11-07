module main

import dom
import html
import x.json2

// HTMLDialogElement's show(), showModal(), close(), requestClose() and
// returnValue over the translated dialog algorithms.
// https://html.spec.whatwg.org/multipage/interactive-elements.html#the-dialog-element
fn (mut binding CompactElementQueryBinding) dialog_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	node := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
	element := node.as_element() or { return error('TypeError: Illegal HTMLDialogElement receiver') }
	if !element.is_html_element() || element.local_name() != 'dialog' {
		return error('TypeError: Illegal HTMLDialogElement receiver')
	}
	mut dialog := unsafe { &dom.HTMLDialogElement(element) }
	op := json_string_property(request, 'op') or { '' }
	value := if raw := request['value'] {
		if raw is string { ?string(raw) } else { ?string(none) }
	} else {
		?string(none)
	}
	match op {
		'returnValue' {
			return json2.encode({
				'value': json2.Any(html.html_dialog_element_return_value(dialog))
			})
		}
		'setReturnValue' {
			html.set_html_dialog_element_return_value(mut dialog, value or { '' })
			return '{}'
		}
		'show' {
			html.html_dialog_element_show(dialog)!
		}
		'showModal' {
			html.html_dialog_element_show_modal(dialog)!
		}
		'close' {
			html.html_dialog_element_close(dialog, value)
		}
		'requestClose' {
			html.html_dialog_element_request_close(dialog, value)
		}
		else {
			return error('TypeError: Invalid dialog operation')
		}
	}
	mut reaction_document := unsafe { &dom.Document(element.document()) }
	reaction_document.invoke_custom_element_reactions()
	return json2.encode({
		'refresh': binding.element_attribute_refresh(element)
	})
}

fn compact_dialog_bootstrap() string {
	return r'
(function(){
 if(typeof HTMLDialogElement!=="function")return;
 const refresh=globalThis.__compactApplyMutationRefresh;
 function call(receiver,request){
  const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
  if(!state||state.namespaceURI!=="http://www.w3.org/1999/xhtml"||String(state.tagName).split(":").pop()!=="dialog")throw new TypeError("Illegal HTMLDialogElement receiver");
  request.state=state.created?state:undefined;
  try{return __queryElements(state.bridgeKey,"dialog",JSON.stringify(request),true);}
  catch(error){
   const match=/^([A-Za-z]*Error):\s*(.*)/.exec(String(error&&error.message));
   if(match&&match[1]!=="TypeError")throw new DOMException(match[2],match[1]);
   if(error&&error.name&&error.name!=="TypeError"&&error.name!=="Error"&&!(error instanceof DOMException))throw new DOMException(error.message,error.name);
   throw error;
  }
 }
 function string(value){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);}
 const prototype=HTMLDialogElement.prototype;
 const methods={
  show(){refresh(call(this,{op:"show"}));},
  showModal(){refresh(call(this,{op:"showModal"}));},
  close(returnValue){refresh(call(this,returnValue===undefined?{op:"close"}:{op:"close",value:string(returnValue)}));},
  requestClose(returnValue){refresh(call(this,returnValue===undefined?{op:"requestClose"}:{op:"requestClose",value:string(returnValue)}));}
 };
 for(const [name,value] of Object.entries(methods))if(!Object.prototype.hasOwnProperty.call(prototype,name))Object.defineProperty(prototype,name,{value,writable:true,enumerable:true,configurable:true});
 if(!Object.prototype.hasOwnProperty.call(prototype,"returnValue"))Object.defineProperty(prototype,"returnValue",{get:function(){return call(this,{op:"returnValue"}).value;},set:function(value){call(this,{op:"setReturnValue",value:string(value)});},enumerable:true,configurable:true});
 if(!Object.prototype.hasOwnProperty.call(prototype,"open"))Object.defineProperty(prototype,"open",{get:function(){return this.hasAttribute("open");},set:function(value){if(value)this.setAttribute("open","");else this.removeAttribute("open");},enumerable:true,configurable:true});
})();
'
}
