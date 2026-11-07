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
	if op in ['write', 'writeln'] && binding.write_after_current_script(mut document, text.join('') +
		if op == 'writeln' { '\n' } else { '' })! {
		return json2.encode({
			'refresh': binding.mutation_refresh(document.as_node())
		})
	}
	match op {
		// A running parser-inserted script has script nesting level > 0, so
		// open() leaves its document alone.
		'open' { if compact_parser_inserted_script(document) == none { document.open()! } }
		'write' { document.write_strings(text)! }
		'writeln' { document.writeln_strings(text)! }
		'close' {
			opened := document.parser != unsafe { nil } && document.parser.is_script_created()
			document.close()!
			if opened && !document.has_pending_parsing_blocking_script() { compact_queue_container_load(document) }
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
	html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), element.document(), fn [element] () {
		element.as_node().dispatch_event(dom.Event.create('load', dom.EventInit{}))
	})
}

// Pages run their parser-inserted scripts after the whole document has been
// parsed, so a classic script's write has no insertion point left in the
// input stream. Its output is placed where that point would have been,
// directly after the script: everything the script has written so far is
// reparsed in the script's parent context so markup split across write()
// calls (`<p>` then `text</p>`) still forms one tree.
struct CompactScriptWrite {
	script &dom.Element
mut:
	markup string
	nodes  []&dom.Node
}

// The script whose execution stands in for the parser's insertion point.
fn compact_parser_inserted_script(document &dom.Document) ?&dom.Element {
	if document.parser != unsafe { nil } && document.parser.is_insertion_point_defined() { return none }
	if document.ready_state() == 'complete' { return none }
	script := document.current_script() or { return none }
	element := unsafe { &dom.Element(script) }
	if !element.as_node().is_connected() || voidptr(element.document()) != voidptr(document) { return none }
	parent := element.as_node().parent() or { return none }
	if parent.as_element() == none { return none }
	return element
}

fn (mut binding CompactElementQueryBinding) write_after_current_script(mut document dom.Document, markup string) !bool {
	element := compact_parser_inserted_script(document) or { return false }
	mut parent := element.as_node().parent() or { return false }
	mut write := binding.script_writes[voidptr(&document)] or { CompactScriptWrite{ script: element } }
	if voidptr(write.script) != voidptr(element) { write = CompactScriptWrite{ script: element } }
	// Reparsing replaces the earlier output of this script.
	for node in write.nodes {
		if current := node.parent() {
			mut owner := unsafe { &dom.Node(current) }
			owner.remove_child(node) or {}
		}
	}
	write.markup += markup
	mut range := dom.Range.create(&document)
	range.select_node(element.as_node())!
	fragment := range.create_contextual_fragment(write.markup)!
	write.nodes = fragment.as_node().children.clone()
	parent.insert_before(fragment.as_node(), element.as_node().next_sibling(), false)
	binding.script_writes[voidptr(&document)] = write
	return true
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
  // The main document keeps these as own properties captured at startup.
  for(const name of ["documentElement","head","body"]){
   if(Object.prototype.hasOwnProperty.call(receiver,name))receiver[name]=__queryElements(state.bridgeKey,"documentNode",name);
  }
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
