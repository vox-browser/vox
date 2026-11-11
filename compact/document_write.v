module main

import dom
import html
import x.json2

// document.open(), write(), writeln() and close() run the translated dynamic
// markup insertion algorithms on the native Document; the realm then drops
// the content it had cached for the rewritten tree.
fn (mut binding CompactElementQueryBinding) document_write_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid document write operation') }
	node := binding.equality_node(key, json2.Any(json2.Null{}))!
	mut document := node.as_document() or { return error('TypeError: Illegal Document receiver') }
	mut text := []string{}
	if values := request['text'] {
		if values is []json2.Any {
			for value in values as []json2.Any {
				text << value.str()
			}
		}
	}
	// An initial about:blank document is created without the parser hooks
	// that parsed documents receive; open() needs its scripting parser.
	if document.html_fragment_parsing_hook() == none { html.install_document_fragment_parsing_hook(document) }
	match op {
		// A running parser-inserted script has script nesting level > 0, so
		// open() leaves its document alone.
		'open' { document.open()! }
		'write' { document.write_strings(text)! }
		'writeln' { document.writeln_strings(text)! }
		'close' {
			opened := document.parser != unsafe { nil } && document.parser.is_script_created()
			document.close()!
			if opened && !document.has_html_parser_creation_hook()
				&& !document.has_pending_parsing_blocking_script() {
				compact_queue_container_load(document)
			}
		}
		else { return error('Invalid document write operation') }
	}
	return json2.encode({
		'refresh': binding.mutation_refresh(document.as_node())
	})
}

// The translated end steps leave the iframe load event to the embedder; a
// closed document.open() stream fires it at the frame's container.
fn compact_queue_container_load(document &dom.Document) {
	navigable := document.navigable() or { return }
	container := navigable.container() or { return }
	element := container.as_element() or { return }
	if !element.is_html_element() || element.local_name() != 'iframe' { return }
	html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), element.document(), fn [document, element] () {
		if document.should_mute_iframe_load() { return }
		mut child_document := unsafe { &dom.Document(document) }
		child_document.set_iframe_load_in_progress(true)
		defer { child_document.set_iframe_load_in_progress(false) }
		element.as_node().dispatch_event(dom.Event.create('load', dom.EventInit{}))
	})
}

fn compact_document_write_bootstrap() string {
	return r'
(function(){
 const refresh=globalThis.__compactApplyMutationRefresh;
 function fail(error){
  const match=/^([A-Za-z]*Error):\s*(.*)/.exec(String(error&&error.message));
  if(!match)throw error;
  if(match[1]==="TypeError")throw new TypeError(match[2]);
  throw new DOMException(match[2],match[1]);
 }
 function run(receiver,op,values){
  const state=__compactDocumentState(receiver);
  const text=[];
  for(const value of values){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");text.push(String(value));}
  let result;
  try{result=__queryElements(state.bridgeKey,"documentWrite",JSON.stringify({op,text}),true);}catch(error){fail(error);}
  refresh(result);
  if(typeof globalThis.__ladybirdRefreshNamedElements==="function")globalThis.__ladybirdRefreshNamedElements();
 }
 const methods={
  open(){
   // The three-argument form is window.open().
   if(arguments.length>=3)return globalThis.open(arguments[0],arguments[1],arguments[2]);
   run(this,"open",[]);return this;
  },
  write(){run(this,"write",arguments);},
  writeln(){run(this,"writeln",arguments);},
  close(){run(this,"close",[]);}
 };
 for(const name of Object.keys(methods)){
  Object.defineProperty(Document.prototype,name,{value:methods[name],writable:true,enumerable:true,configurable:true});
  if(Object.prototype.hasOwnProperty.call(document,name))delete document[name];
 }
})();
'
}
