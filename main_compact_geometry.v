module main

import dom
import html
import math
import x.json2

fn (mut binding CompactElementQueryBinding) client_rects_query(key string, source string) !string {
	query := json2.decode[map[string]json2.Any](source)!
	node := binding.node_for_key(key) or {
		binding.materialize_shadow_host(key, query['state'] or { json2.Any(json2.Null{}) })!
	}
	return compact_element_geometry_query(node, 'clientRects')
}

fn compact_image_dimension(image &dom.HTMLImageElement, width bool) u32 {
	// Flush pending layout through the translated getter, retaining its attribute
	// and intrinsic-size fallback for images without a rendered box. Blink rounds
	// the rendered content size to the nearest CSS pixel rather than truncating.
	fallback := if width { html.html_image_element_width(image) } else { html.html_image_element_height(image) }
	element := unsafe { &dom.Element(image) }
	if node := element.as_node().layout_node() {
		if node.has_geometry_ {
			value := if width { node.content_width_ } else { node.content_height_ }
			return u32(math.floor(value / element.document().layout_coordinate_scale() + .5))
		}
	}
	return fallback
}

// Use the translated CSSOM View algorithms after the shared query boundary has
// flushed pending DOM and style mutations. Menu positioning must see live boxes.
fn compact_element_geometry_query(root &dom.Node, name string) !string {
	if name in ['scrollX', 'scrollY'] {
		document := root.document()
		window := document.get_window() or { return '0' }
		owner := unsafe { &html.WindowModel(window) }
		value := if name == 'scrollX' { owner.scroll_x() } else { owner.scroll_y() }
		return json2.encode(value)
	}
	element := root.as_element() or { return error('TypeError: Invalid Element receiver') }
	if name in ['imageWidth', 'imageHeight'] {
		if !element.is_html_element() || element.local_name() != 'img' {
			return error('TypeError: Invalid HTMLImageElement receiver')
		}
		image := unsafe { &dom.HTMLImageElement(element) }
		return compact_image_dimension(image, name == 'imageWidth').str()
	}
	if name == 'rect' {
		rect := element.get_bounding_client_rect()
		return json2.encode({
			'x':      rect.x
			'y':      rect.y
			'width':  rect.width
			'height': rect.height
			'top':    rect.y
			'left':   rect.x
			'right':  rect.x + rect.width
			'bottom': rect.y + rect.height
		})
	}
	if name == 'clientRects' {
		mut result := []map[string]f64{}
		for rect in element.get_client_rects_for_bindings() {
			result << {'x': rect.x_, 'y': rect.y_, 'width': rect.width_, 'height': rect.height_}
		}
		return json2.encode(result)
	}
	if name == 'clientTop' { return element.client_top().str() }
	if name == 'clientLeft' { return element.client_left().str() }
	if name == 'clientWidth' { return element.client_width().str() }
	if name == 'clientHeight' { return element.client_height().str() }
	if name == 'scrollTop' { return json2.encode(element.scroll_top()) }
	if name == 'scrollLeft' { return json2.encode(element.scroll_left()) }
	if name in ['scrollWidth', 'scrollHeight'] {
		mut owner := unsafe { &dom.Element(element) }
		mut document := unsafe { &dom.Document(element.document()) }
		document.update_layout(if name == 'scrollWidth' { .element_scroll_width } else { .element_scroll_height })
		return if name == 'scrollWidth' { owner.scroll_width().str() } else { owner.scroll_height().str() }
	}
	if !element.is_html_element() { return error('TypeError: Invalid HTMLElement receiver') }
	host := unsafe { &dom.HTMLElement(element) }
	return match name {
		'offsetTop' { html.html_element_offset_top(host).str() }
		'offsetLeft' { html.html_element_offset_left(host).str() }
		'offsetWidth' { html.html_element_offset_width(host).str() }
		'offsetHeight' { html.html_element_offset_height(host).str() }
		else { return error('Invalid element geometry property') }
	}
}

fn compact_element_geometry_bootstrap() string {
	return r'
function DOMRectList(){throw new TypeError("Illegal DOMRectList constructor");}
Object.defineProperty(globalThis,"DOMRectList",{value:DOMRectList,writable:true,configurable:true});
Object.defineProperty(DOMRectList,"prototype",{writable:false});
Object.defineProperty(DOMRectList.prototype,Symbol.toStringTag,{value:"DOMRectList",configurable:true});
const __compactRectLists=new WeakMap(),__compactRectConstructor=globalThis.DOMRect;
function __compactRectListRead(receiver){const rects=__elementApply(__compactNodeGet,__compactRectLists,[receiver]);if(!rects)throw new TypeError("Illegal DOMRectList receiver");return rects;}
Object.defineProperty(DOMRectList.prototype,"length",{get:function(){return __compactRectListRead(this).length;},enumerable:true,configurable:true});
Object.defineProperty(DOMRectList.prototype,"item",{value:function item(index){const rects=__compactRectListRead(this);if(arguments.length===0)throw new TypeError("item requires an index");return rects[(+index)>>>0]||null;},writable:true,enumerable:true,configurable:true});
Object.defineProperty(DOMRectList.prototype,Symbol.iterator,{value:function values(){return __compactRectListRead(this)[Symbol.iterator]();},writable:true,configurable:true});
function __compactRectList(values){
 const rects=values.map(rect=>new __compactRectConstructor(rect.x,rect.y,rect.width,rect.height)),target=Object.create(DOMRectList.prototype);
 const indexed=key=>typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key)&&Number(key)<4294967295;
 const list=new Proxy(target,{
  get(target,key,receiver){return indexed(key)?rects[Number(key)]:Reflect.get(target,key,receiver);},
  has(target,key){return indexed(key)?Number(key)<rects.length:Reflect.has(target,key);},
  ownKeys(target){return [...rects.keys()].map(String).concat(Reflect.ownKeys(target));},
  getOwnPropertyDescriptor(target,key){if(indexed(key)){const rect=rects[Number(key)];return rect?{value:rect,writable:false,enumerable:true,configurable:true}:undefined;}return Reflect.getOwnPropertyDescriptor(target,key);},
  set(target,key,value,receiver){return indexed(key)?false:Reflect.set(target,key,value,receiver);},
  defineProperty(target,key,descriptor){return indexed(key)?false:Reflect.defineProperty(target,key,descriptor);},
  deleteProperty(target,key){return indexed(key)?false:Reflect.deleteProperty(target,key);},
  preventExtensions(){return false;}
 });
 __elementApply(__elementRecordSet,__compactRectLists,[list,rects]);return list;
}
Object.defineProperty(Element.prototype,"getClientRects",{value:function getClientRects(){const state=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!state)throw new TypeError("Illegal Element receiver");const request={};if(state.created)request.state=state;return __compactRectList(__queryElements(state.bridgeKey,"geometry",JSON.stringify(request)));},writable:true,enumerable:true,configurable:true});
' + compact_element_geometry_bindings() + r'
const __compactScrollFinite=Number.isFinite;
Object.defineProperty(Element.prototype,"ownerDocument",{get:function(){
 if(!__elementApply(__elementRecordGet,__elementRecords,[this]))throw new TypeError("Illegal Node receiver");
 return __compactOwnerDocument(this);
},enumerable:true,configurable:true});
Object.defineProperty(document,"defaultView",{get(){return globalThis;},enumerable:true,configurable:true});
for(const [name,axis] of [["pageXOffset","scrollX"],["pageYOffset","scrollY"],["scrollX","scrollX"],["scrollY","scrollY"]]){
 Object.defineProperty(globalThis,name,{get(){return __queryElements("","geometry",axis);},enumerable:true,configurable:true});
}'
}
