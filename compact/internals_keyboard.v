module main

import browserjs
import dom
import html
import page
import x.json2

struct CompactInternalsTextQuery {
	text string
	modifiers u32
	state json2.Any
}

// Internals.cpp::send_text uses Page's actual keyboard dispatch and editing
// default actions. Listener cancellation, focus and trusted events stay native.
fn (mut binding CompactElementQueryBinding) internals_send_text(key string, source string) !string {
	query := compact_decode_query[CompactInternalsTextQuery](source)!
	node := binding.equality_node(key, query.state)!
	element := node.as_element() or { return error('TypeError: Expected an HTMLElement') }
	if !element.is_html_element() { return error('TypeError: Expected an HTMLElement') }
	document := element.document()
	if !document.has_page() || document.page().target == unsafe { nil } {
		return error('InvalidStateError: Keyboard input requires the owning Page')
	}
	mut owner := unsafe { &page.Page(document.page().target) }
	if !owner.has_local_root_navigable() { return error('InvalidStateError: Keyboard input requires an active navigable') }
	if element.local_name() == 'input' {
		mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		model.create_shadow_tree_if_needed()
	} else if element.local_name() == 'textarea' {
		mut model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
		model.create_shadow_tree_if_needed()
	}
	dom.run_focusing_steps_for_node(node, none, .other)
	for point in query.text.runes() {
		code := u32(point)
		key_code, code_point, extra := compact_webdriver_key(code)
		owner.handle_keydown(int(key_code), query.modifiers | extra, code_point, false)
		owner.handle_keyup(int(key_code), query.modifiers | extra, code_point, false)
	}
	binding.note_node_tree_mutation()
	mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
	runtime.mark_document_replay_effects()
	// Editing can add or remove attributes on existing inline elements. Reuse
	// execCommand's refresh so retained wrappers and Attr objects see them.
	return json2.encode({'refresh': binding.mutation_refresh(document.as_node())})
}

fn compact_webdriver_key(code u32) (dom.KeyCode, u32, u32) {
	return match code {
		0xe003 { dom.KeyCode.backspace, u32(8), u32(0) }
		0xe004 { dom.KeyCode.tab, u32(9), u32(0) }
		0xe006 { dom.KeyCode.return_, u32(10), u32(0) }
		0xe007 { dom.KeyCode.return_, u32(10), dom.modifier_keypad }
		0xe008 { dom.KeyCode.left_shift, u32(0), dom.modifier_shift }
		0xe009 { dom.KeyCode.left_control, u32(0), dom.modifier_ctrl }
		0xe00a { dom.KeyCode.left_alt, u32(0), dom.modifier_alt }
		0xe00d { dom.KeyCode.space, u32(32), u32(0) }
		0xe010 { dom.KeyCode.end, u32(0), u32(0) }
		0xe011 { dom.KeyCode.home, u32(0), u32(0) }
		0xe012 { dom.KeyCode.left, u32(0), u32(0) }
		0xe013 { dom.KeyCode.up, u32(0), u32(0) }
		0xe014 { dom.KeyCode.right, u32(0), u32(0) }
		0xe015 { dom.KeyCode.down, u32(0), u32(0) }
		0xe017 { dom.KeyCode.delete, u32(0), u32(0) }
		0xe03d { dom.KeyCode.left_super, u32(0), dom.modifier_super }
		else { dom.code_point_to_key_code(code), code, u32(0) }
	}
}

fn compact_keyboard_internals_bootstrap() string {
	return r'
if(window.internals)window.internals.sendText=({sendText(element,text,modifiers=0){
 if(arguments.length<2)throw new TypeError("sendText requires an HTMLElement and text");
 const state=__elementApply(__elementRecordGet,__elementRecords,[element]);
 if(!state||state.namespaceURI!=="http://www.w3.org/1999/xhtml")throw new TypeError("sendText requires an HTMLElement");
 if(typeof text==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 text=String(text);
 const number=+modifiers;modifiers=Number.isFinite(number)?((Math.trunc(number)%65536)+65536)%65536:0;
 __compactInvalidateContent(state);
 try{__compactApplyMutationRefresh(__queryElements(state.bridgeKey,"internalsSendText",JSON.stringify({text,modifiers,state:state.created?state:undefined}),true));}
 finally{__compactInvalidateContent(state);}
}}).sendText;
'
}
