module main

import browserjs
import dom
import math
import os
import page
import x.json2

// Only explicit automation launches receive a trusted-input entry point.
const wpt_testdriver_enabled = os.getenv('VOX_WPT_TESTDRIVER') == '1'

struct CompactTestDriverClickQuery {
	x     f64
	y     f64
	state json2.Any
}

fn (mut binding CompactElementQueryBinding) testdriver_click(key string, source string) !string {
	if !wpt_testdriver_enabled { return error('NotSupportedError: Native WPT input is disabled') }
	query := compact_decode_query[CompactTestDriverClickQuery](source)!
	if math.is_nan(query.x) || math.is_nan(query.y) || math.is_inf(query.x, 0) || math.is_inf(query.y, 0) {
		return error('TypeError: Click coordinates must be finite')
	}
	node := binding.equality_node(key, query.state)!
	element := node.as_element() or { return error('TypeError: Click requires an Element') }
	document := element.document()
	if !document.is_fully_active() || !document.has_page() || document.page().target == unsafe { nil } {
		return error('InvalidStateError: Native WPT input requires an active owning Page')
	}
	mut owner := unsafe { &page.Page(document.page().target) }
	if !owner.has_local_root_navigable() {
		return error('InvalidStateError: Native WPT input requires an active navigable')
	}
	_ = element.get_bounding_client_rect()
	hit := document.element_from_point(query.x, query.y) or { return error('Element click intercepted: no element at coordinates') }
	if voidptr(hit) != voidptr(element) && !hit.as_node().is_descendant_of(node) {
		return error('Element click intercepted by ${hit.local_name()}#${hit.id()}')
	}
	point := page.PixelPoint{ x: query.x, y: query.y }
	mut handler := owner.event_handler
	handler.set_document_state(document.is_fully_active(), document.layout_node() != none)
	target := handler.target_node_for_mouse_position(document, point) or { return error('Element click intercepted: no native paint hit') }
	handler.handle_platform_pointer_event('pointermove', page.InputTarget.from_node(target), point, point, 0, 0, 0, 0)
	down := handler.target_node_for_mouse_position(document, point) or { return error('Element click intercepted: no native paint hit after pointer move') }
	handler.handle_platform_pointer_event('pointerdown', page.InputTarget.from_node(down), point, point, 0, 1, 0, 1)
	up := handler.target_node_for_mouse_position(document, point)
	handler.handle_platform_pointer_event('pointerup', if value := up {
		?page.InputTarget(page.InputTarget.from_node(value))
	} else {
		none
	}, point, point, 0, 0, 0, 1)
	binding.note_node_tree_mutation()
	mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
	runtime.mark_document_replay_effects()
	return json2.encode({
		'refresh': binding.mutation_refresh(document.as_node())
	})
}

fn compact_testdriver_click_bootstrap() string {
	if !wpt_testdriver_enabled { return '' }
	return r'
if(window.internals)window.internals.testDriverClick=({testDriverClick(element,x,y){
 if(arguments.length<3)throw new TypeError("testDriverClick requires an Element and two coordinates");
 const state=__elementApply(__elementRecordGet,__elementRecords,[element]);
 if(!state)throw new TypeError("testDriverClick requires an Element");
 x=+x;y=+y;if(!Number.isFinite(x)||!Number.isFinite(y))throw new TypeError("Click coordinates must be finite");
 __compactInvalidateContent(state);
 try{__compactApplyMutationRefresh(__queryElements(state.bridgeKey,"testdriverClick",JSON.stringify({x,y,state:state.created?state:undefined}),true));}
 finally{__compactInvalidateContent(state);}
}}).testDriverClick;
'
}
