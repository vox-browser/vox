module browserjs

import css
import dom
import html
import json2
import layout
import os

fn bridge_offset_parent(element &dom.Element) ?&dom.Element {
	mut ancestor := element.as_node().parent_element() or { return none }
	for {
		local_name := ancestor.local_name()
		positioned := if computed := css.computed_properties_for_element(ancestor) {
			computed.position() != .static_
		} else {
			false
		}
		if positioned || local_name in ['body', 'td', 'th', 'table'] {
			return ancestor
		}
		ancestor = ancestor.as_node().parent_element() or { return none }
	}
	return none
}

fn bridge_geometry(element &dom.Element) map[string]json2.Any {
	layout_node := element.as_node().layout_node() or { return map[string]json2.Any{} }
	if !layout_node.has_geometry_ {
		return map[string]json2.Any{}
	}
	border_box := layout_node.border_box_
	mut offset_left := border_box.x
	mut offset_top := border_box.y
	if offset_parent := bridge_offset_parent(element) {
		// CSSOM View treats body as the initial containing block for these
		// coordinates. Other offset parents contribute their padding edge.
		if offset_parent.local_name() != 'body' {
			if parent_layout := offset_parent.as_node().layout_node() {
				if parent_layout.has_geometry_ {
					offset_left -= parent_layout.border_box_.x + parent_layout.border_left_
					offset_top -= parent_layout.border_box_.y + parent_layout.border_top_
				}
			}
		}
	}
	return {
		'x':          json2.Any(border_box.x)
		'y':          json2.Any(border_box.y)
		'width':      json2.Any(border_box.width)
		'height':     json2.Any(border_box.height)
		'top':        json2.Any(border_box.y)
		'left':       json2.Any(border_box.x)
		'right':      json2.Any(border_box.x + border_box.width)
		'bottom':     json2.Any(border_box.y + border_box.height)
		'offsetLeft': json2.Any(offset_left)
		'offsetTop':  json2.Any(offset_top)
	}
}

fn bridge_document_title(document &dom.Document) string {
	root := unsafe { &dom.Node(document) }
	title := css.query_selector(root, 'title') or { return '' }
	return title.as_node().text_content() or { '' }
}

fn bridge_initial_state(document &dom.Document, current_url string) map[string]json2.Any {
	root := unsafe { &dom.Node(document) }
	body := css.query_selector(root, 'body')
	mut elements := map[string]json2.Any{}
	all_elements := css.query_selector_all(root, '*')
	mut element_indexes := map[u32]int{}
	for index, element in all_elements {
		element_indexes[element.as_node().unique_id()] = index
	}
	mut nodes := []json2.Any{cap: all_elements.len}
	mut body_index := -1
	for index, element in all_elements {
		mut attributes := map[string]json2.Any{}
		for name in element.get_attribute_names() {
			attributes[name] = json2.Any(element.get_attribute_value(name))
		}
		parent_index := if parent := element.as_node().parent_element() {
			element_indexes[parent.as_node().unique_id()] or { -1 }
		} else {
			-1
		}
		id := element.get_attribute_value('id')
		if id != '' {
			elements[id] = json2.Any(index)
		}
		if body_element := body {
			if voidptr(body_element) == voidptr(element) {
				body_index = index
			}
		}
		nodes << json2.Any({
			'index':              json2.Any(index)
			'parentIndex':        json2.Any(parent_index)
			'tagName':            json2.Any(element.local_name())
			'namespaceURI':       json2.Any(element.namespace_uri() or { '' })
			'id':                 json2.Any(id)
			'textContent':        json2.Any(element.as_node().text_content() or { '' })
			'defaultTextContent': json2.Any(element.as_node().text_content() or { '' })
			'innerHTML':          json2.Any(element.inner_html() or { '' })
			'className':          json2.Any(element.get_attribute_value('class'))
			'styleText':          json2.Any(element.get_attribute_value('style'))
			'onclick':            json2.Any(element.get_attribute_value('onclick'))
			'attributes':         json2.Any(attributes)
			'created':            json2.Any(false)
			'rect':               json2.Any(bridge_geometry(element))
		})
	}
	return {
		'title':         json2.Any(bridge_document_title(document))
		'bodyHTML':      json2.Any(if body_element := body {
			body_element.inner_html() or { '' }
		} else {
			''
		})
		'bodyText':      json2.Any(if body_element := body {
			body_element.as_node().text_content() or { '' }
		} else {
			''
		})
		'bodyHTMLDirty': json2.Any(false)
		'bodyTextDirty': json2.Any(false)
		'location':      json2.Any(current_url)
		'navigate':      json2.Any('')
		'logs':          json2.Any([]json2.Any{})
		'elements':      json2.Any(elements)
		'nodes':         json2.Any(nodes)
		'bodyIndex':     json2.Any(body_index)
		'operations':    json2.Any([]json2.Any{})
	}
}

fn bridge_program(state map[string]json2.Any) string {
	state_json := json2.encode(state)
	return [
		'(function () {',
		'const __state = ${state_json};',
		'const __listeners = Object.create(null);',
		'const __objects = []; let __lastRectElement = null;',
		'const __canvases = Object.create(null);',
		'let __nextStyleSheetId = 1; const __styleSheetObjects = Object.create(null); let __adoptedStyleSheets = [];',
		'function __listenerKey(s, n) { return (s && s.id ? s.id : "document") + ":" + n; }',
		'function __cssName(p) { return String(p).replace(/[A-Z]/g, function (c) { return "-" + c.toLowerCase(); }); }',
		'function __styleProxy(s) {',
		'  const values = Object.create(null);',
		'  String(s.styleText || "").split(";").forEach(function (part) { const i = part.indexOf(":"); if (i > 0) values[part.slice(0, i).trim()] = part.slice(i + 1).trim(); });',
		'  function sync() { s.styleText = Object.keys(values).map(function (k) { return k + ": " + values[k]; }).join("; "); s.attributes.style = s.styleText; s.attributesDirty = true; }',
		'  return new Proxy(values, { set: function (o, p, v) { if (p === "cssText") { for (const key of Object.keys(o)) delete o[key]; String(v).split(";").forEach(function (part) { const i=part.indexOf(":"); if(i>0)o[part.slice(0,i).trim()]=part.slice(i+1).trim(); }); sync(); return true; } o[__cssName(p)] = String(v); sync(); return true; }, get: function (o, p) { if (p === "cssText") return s.styleText; if (p === "setProperty") return function (name, value) { values[String(name)] = String(value); sync(); }; return o[__cssName(p)] || ""; } });',
		'}',
		'function __canvasDimension(s, name) { const fallback = name === "width" ? 300 : 150; const value = Number(s.attributes[name]); return Number.isFinite(value) && value >= 0 ? Math.trunc(value) : fallback; }',
		'function __canvasFor(s) { let c = __canvases[s.index]; const width = __canvasDimension(s, "width"), height = __canvasDimension(s, "height"); if (!c || c.width !== width || c.height !== height) c = __canvases[s.index] = { width: width, height: height, data: new Uint8ClampedArray(width * height * 4), fillStyle: "#000000" }; return c; }',
		'function __canvasColor(value) { const names = { black:[0,0,0,255], white:[255,255,255,255], red:[255,0,0,255], green:[0,128,0,255], blue:[0,0,255,255], transparent:[0,0,0,0] }; const text = String(value).trim().toLowerCase(); if (names[text]) return names[text]; let m = /^#([0-9a-f]{6})\$/.exec(text); if (m) return [parseInt(m[1].slice(0,2),16),parseInt(m[1].slice(2,4),16),parseInt(m[1].slice(4,6),16),255]; m = /^rgba?\\(\\s*(\\d+)\\s*[, ]\\s*(\\d+)\\s*[, ]\\s*(\\d+)(?:\\s*[,/]\\s*([0-9.]+))?\\s*\\)\$/.exec(text); if (m) return [+m[1],+m[2],+m[3],m[4] === undefined ? 255 : Math.round(+m[4] * 255)]; return [0,0,0,255]; }',
		'function __canvasFill(c, x, y, w, h, color) { const left = Math.max(0,Math.floor(Math.min(x,x+w))), top = Math.max(0,Math.floor(Math.min(y,y+h))), right = Math.min(c.width,Math.ceil(Math.max(x,x+w))), bottom = Math.min(c.height,Math.ceil(Math.max(y,y+h))); for (let yy=top; yy<bottom; ++yy) for (let xx=left; xx<right; ++xx) { const i=(yy*c.width+xx)*4; c.data[i]=color[0]; c.data[i+1]=color[1]; c.data[i+2]=color[2]; c.data[i+3]=color[3]; } }',
		'function __canvasDraw(destination, source, args) { const snapshot = source.data.slice(); let sx=0,sy=0,sw=source.width,sh=source.height,dx=+args[0],dy=+args[1],dw=sw,dh=sh; if (args.length === 4) { dw=+args[2]; dh=+args[3]; } else if (args.length >= 8) { sx=+args[0]; sy=+args[1]; sw=+args[2]; sh=+args[3]; dx=+args[4]; dy=+args[5]; dw=+args[6]; dh=+args[7]; } if (!sw || !sh || !dw || !dh) return; const left=Math.max(0,Math.floor(Math.min(dx,dx+dw))),top=Math.max(0,Math.floor(Math.min(dy,dy+dh))),right=Math.min(destination.width,Math.ceil(Math.max(dx,dx+dw))),bottom=Math.min(destination.height,Math.ceil(Math.max(dy,dy+dh))); for(let y=top;y<bottom;++y) for(let x=left;x<right;++x){ const u=(x-dx)/dw,v=(y-dy)/dh,sourceX=Math.floor(sx+u*sw),sourceY=Math.floor(sy+v*sh); if(sourceX<0||sourceY<0||sourceX>=source.width||sourceY>=source.height)continue; const si=(sourceY*source.width+sourceX)*4,di=(y*destination.width+x)*4; destination.data[di]=snapshot[si];destination.data[di+1]=snapshot[si+1];destination.data[di+2]=snapshot[si+2];destination.data[di+3]=snapshot[si+3]; } }',
		'function __canvasContext(s) { const c=__canvasFor(s); if(c.context)return c.context; const target={ fillRect:function(x,y,w,h){__canvasFill(c,+x,+y,+w,+h,__canvasColor(c.fillStyle));}, clearRect:function(x,y,w,h){__canvasFill(c,+x,+y,+w,+h,[0,0,0,0]);}, drawImage:function(source){if(!source||!source.__state||source.__state.tagName!=="canvas")throw new TypeError("Unsupported CanvasImageSource");__canvasDraw(c,__canvasFor(source.__state),Array.prototype.slice.call(arguments,1));}, getImageData:function(x,y,w,h){const output=new Uint8ClampedArray(Math.max(0,Math.trunc(w))*Math.max(0,Math.trunc(h))*4);for(let yy=0;yy<h;++yy)for(let xx=0;xx<w;++xx){const sourceX=Math.trunc(x)+xx,sourceY=Math.trunc(y)+yy,di=(yy*w+xx)*4;if(sourceX<0||sourceY<0||sourceX>=c.width||sourceY>=c.height)continue;const si=(sourceY*c.width+sourceX)*4;output[di]=c.data[si];output[di+1]=c.data[si+1];output[di+2]=c.data[si+2];output[di+3]=c.data[si+3];}return{data:output,width:w,height:h};} }; c.context=new Proxy(target,{get:function(o,p){if(p==="fillStyle")return c.fillStyle;return o[p];},set:function(o,p,v){if(p==="fillStyle"){c.fillStyle=String(v);return true;}o[p]=v;return true;}});return c.context; }',
		'function __styleElementSheet(s) { if (s.tagName !== "style") return null; if (s.sheetObject) return s.sheetObject; const sheet = { insertRule: function(rule,index) { const resolved = index === undefined ? -1 : Number(index); __state.operations.push({op:"insertStyleRule",target:s.index,rule:String(rule),index:resolved}); return resolved < 0 ? 0 : resolved; }, deleteRule: function(index) { __state.operations.push({op:"deleteStyleRule",target:s.index,index:Number(index)}); } }; s.sheetObject=sheet; return sheet; }',
		'function CSSStyleSheet() { if (!(this instanceof CSSStyleSheet)) throw new TypeError("CSSStyleSheet constructor requires new"); this.__sheetId=__nextStyleSheetId++; __styleSheetObjects[this.__sheetId]=this; __state.operations.push({op:"constructStyleSheet",sheet:this.__sheetId}); }',
		'CSSStyleSheet.prototype.replaceSync = function(text) { __state.operations.push({op:"replaceStyleSheet",sheet:this.__sheetId,text:String(text)}); };',
		'const __htmlNamespace = "http://www.w3.org/1999/xhtml";',
		'function __attributeName(s, n) { n = String(n); return s.namespaceURI === __htmlNamespace ? n.toLowerCase() : n; }',
		'function __setAttribute(s, n, v) { n = __attributeName(s, n); s.attributes[n] = String(v); s.attributesDirty = true; if (n === "id") s.id = String(v); if (n === "class") s.className = String(v); if (n === "style") s.styleText = String(v); }',
		'function __removeAttribute(s, n) { n = __attributeName(s, n); delete s.attributes[n]; s.attributesDirty = true; if (n === "id") s.id = ""; if (n === "class") s.className = ""; if (n === "style") s.styleText = ""; }',
		'function __classList(s) { function tokens() { const value=String(s.className || "").trim(); return value ? value.split(/\\s+/) : []; } function sync(values) { __setAttribute(s, "class", values.join(" ")); } return { add: function () { const values=tokens(); for (const item of arguments) { const value=String(item); if (values.indexOf(value) < 0) values.push(value); } sync(values); }, remove: function () { const removed=Array.prototype.map.call(arguments,String); sync(tokens().filter(function(value){return removed.indexOf(value)<0;})); }, contains: function (value) { return tokens().indexOf(String(value)) >= 0; }, toggle: function (value, force) { value=String(value); const values=tokens(), index=values.indexOf(value), present=index>=0; if (force === true || (!present && force !== false)) { if (!present) values.push(value); sync(values); return true; } if (present) values.splice(index,1); sync(values); return false; } }; }',
		'function __isDescendant(s, ancestor) { for (let p = s.parentIndex; p >= 0; p = __state.nodes[p].parentIndex) if (p === ancestor) return true; return false; }',
		'function __matches(s, q) { q = String(q || "").trim(); if (!q) return false; if (q[0] === "#") return s.id === q.slice(1); if (q[0] === ".") return String(s.className || "").split(/\\s+/).indexOf(q.slice(1)) >= 0; const a = /^\\[([^=\\]]+)(?:=["\']?([^"\']*)["\']?)?\\]\$/.exec(q); if (a) return Object.prototype.hasOwnProperty.call(s.attributes, a[1]) && (a[2] === undefined || s.attributes[a[1]] === a[2]); return s.tagName === q.toLowerCase(); }',
		'function __element(s) {',
		'  if (__objects[s.index]) return __objects[s.index];',
		'  const target = {',
		'    getAttribute: function (n) { n = __attributeName(s, n); return Object.prototype.hasOwnProperty.call(s.attributes, n) ? s.attributes[n] : null; },',
		'    hasAttribute: function (n) { return Object.prototype.hasOwnProperty.call(s.attributes, __attributeName(s, n)); },',
		'    setAttribute: function (n, v) { __setAttribute(s, n, v); }, removeAttribute: function (n) { __removeAttribute(s, n); },',
		'    addEventListener: function (n, f) { (__listeners[__listenerKey(s, n)] ||= []).push(f); },',
		'    appendChild: function (child) { const c = child && child.__state; if (!c) return child; c.parentIndex = s.index; __state.operations.push({ op: "append", target: s.index, child: c.index }); return child; },',
		'    removeChild: function (child) { const c = child && child.__state; if (!c || c.parentIndex !== s.index) throw new Error("NotFoundError"); __state.operations.push({ op: "remove", target: s.index, child: c.index }); c.parentIndex = -1; return child; },',
		'    remove: function () { if (s.parentIndex < 0) return; const parent=s.parentIndex; __state.operations.push({ op: "remove", target: parent, child: s.index }); s.parentIndex=-1; },',
		'    reset: function () { for (const n of __state.nodes) { if (!__isDescendant(n, s.index)) continue; if (n.tagName === "textarea") { n.textContent = n.defaultTextContent || ""; n.innerHTML = ""; n.textContentDirty = true; } } },',
		'    prepend: function (value) { const c = value && value.__state; __state.operations.push(c ? { op: "prependNode", target: s.index, child: c.index } : { op: "prependText", target: s.index, text: String(value) }); },',
		'    insertAdjacentHTML: function (position, value) { __state.operations.push({ op: "insertAdjacentHTML", target: s.index, position: String(position), html: String(value) }); },',
		'    showModal: function () { __state.operations.push({ op: "showModal", target: s.index }); },',
		'    show: function () { __state.operations.push({ op: "showDialog", target: s.index }); },',
		'    getContext: function (kind) { if (s.tagName === "canvas" && String(kind).toLowerCase() === "2d") return __canvasContext(s); return null; },',
		'    getBoundingClientRect: function () { __lastRectElement = s.index; return s.rect || { x: 0, y: 0, width: 0, height: 0, top: 0, left: 0, right: 0, bottom: 0 }; },',
		'    querySelector: function (q) { const found = __state.nodes.find(function (n) { return __isDescendant(n, s.index) && __matches(n, q); }); return found ? __element(found) : null; },',
		'    querySelectorAll: function (q) { return __state.nodes.filter(function (n) { return __isDescendant(n, s.index) && __matches(n, q); }).map(__element); }',
		'  };',
		'  target.style = __styleProxy(s); Object.defineProperty(target, "__state", { value: s });',
		'  const proxy = new Proxy(target, {',
		'    get: function (o, p) { if (p in o) return o[p]; if (p === "id") return s.id; if (p === "tagName") return s.namespaceURI === __htmlNamespace ? String(s.tagName).toUpperCase() : String(s.tagName); if (p === "namespaceURI") return s.namespaceURI || null; if (p === "textContent" || p === "innerText") return s.textContent; if (p === "innerHTML") return s.innerHTML; if (p === "className") return s.className; if (p === "classList") return __classList(s); if (p === "sheet") return __styleElementSheet(s); if (p === "offsetLeft") return Math.trunc((s.rect && s.rect.offsetLeft) || 0); if (p === "offsetTop") return Math.trunc((s.rect && s.rect.offsetTop) || 0); if (p === "offsetWidth") return Math.trunc((s.rect && s.rect.width) || 0); if (p === "offsetHeight") return Math.trunc((s.rect && s.rect.height) || 0); if (p === "selectedIndex") return s.selectedIndex === undefined ? -1 : s.selectedIndex; if (["multiple", "hidden", "controls"].indexOf(p) >= 0) return Object.prototype.hasOwnProperty.call(s.attributes, p); if (s.tagName === "canvas" && (p === "width" || p === "height")) return __canvasDimension(s,p); if (["type", "value", "placeholder", "src", "width", "height"].indexOf(p) >= 0) return s.attributes[p] || ""; return undefined; },',
		'    set: function (o, p, v) { if (p === "style") { o.style.cssText = String(v); return true; } if (p === "textContent" || p === "innerText") { s.textContent = String(v); s.innerHTML = ""; s.textContentDirty = true; return true; } if (p === "innerHTML") { s.innerHTML = String(v); s.innerHTMLDirty = true; return true; } if (p === "className") { s.className = String(v); __setAttribute(s, "class", v); return true; } if (p === "selectedIndex") { s.selectedIndex = Number(v); __state.operations.push({ op: "selectedIndex", target: s.index, value: s.selectedIndex }); return true; } if (["multiple", "hidden", "controls"].indexOf(p) >= 0) { if (v) __setAttribute(s, p, ""); else __removeAttribute(s, p); return true; } if (p === "value" && s.tagName === "textarea") { s.textContent = String(v); s.innerHTML = ""; s.textContentDirty = true; return true; } if (p === "value" && s.tagName === "input") { s.value = String(v); __state.operations.push({ op: "inputValue", target: s.index, value: s.value }); return true; } if (["type", "value", "placeholder", "src", "width", "height"].indexOf(p) >= 0) { __setAttribute(s, p, v); if(s.tagName === "canvas" && (p === "width" || p === "height")){delete __canvases[s.index];__canvasFor(s);} return true; } o[p] = v; return true; }',
		'  }); __objects[s.index] = proxy; return proxy;',
		'}',
		'const document = {',
		'  getElementById: function (id) { const i = __state.elements[String(id)]; return i === undefined ? null : __element(__state.nodes[i]); },',
		'  querySelector: function (q) { const s = __state.nodes.find(function (n) { return __matches(n, q); }); return s ? __element(s) : null; },',
		'  querySelectorAll: function (q) { return __state.nodes.filter(function (n) { return __matches(n, q); }).map(__element); },',
		'  getElementsByTagName: function (n) { return this.querySelectorAll(String(n).toLowerCase()); },',
		'  addEventListener: function (n, f) { (__listeners[__listenerKey(null, n)] ||= []).push(f); },',
		'  createElement: function (name) { return this.createElementNS(__htmlNamespace, name); },',
		'  createElementNS: function (namespace, name) { namespace = String(namespace); const s = { index: __state.nodes.length, parentIndex: -1, tagName: namespace === __htmlNamespace ? String(name).toLowerCase() : String(name), namespaceURI: namespace, id: "", textContent: "", innerHTML: "", className: "", styleText: "", onclick: "", attributes: {}, created: true }; __state.nodes.push(s); return __element(s); },',
		'  write: function (value) { __state.writeHTML = String(__state.writeHTML || "") + String(value); }, close: function () {}',
		'};',
		'Object.defineProperty(document, "title", { get: function () { return __state.title; }, set: function (v) { __state.title = String(v); } });',
		'Object.defineProperty(document, "adoptedStyleSheets", { get: function () { return __adoptedStyleSheets.slice(); }, set: function (value) { __adoptedStyleSheets=Array.from(value || []); __state.operations.push({op:"setAdoptedStyleSheets",sheets:__adoptedStyleSheets.map(function(sheet){return sheet && sheet.__sheetId || 0;})}); } });',
		'document.documentElement = (__state.nodes.filter(function (node) { return node.tagName === "html"; })[0] || null); document.documentElement = document.documentElement ? __element(document.documentElement) : null;',
		'document.body = __state.bodyIndex >= 0 ? __element(__state.nodes[__state.bodyIndex]) : null;',
		'const console = { log: function () { __state.logs.push(Array.prototype.map.call(arguments, String).join(" ")); }, info: function () { __state.logs.push(Array.prototype.map.call(arguments, String).join(" ")); }, warn: function () { this.log.apply(this, arguments); }, error: function () { this.log.apply(this, arguments); } };',
		'const location = {}; Object.defineProperty(location, "href", { get: function () { return __state.location; }, set: function (v) { __state.navigate = String(v); } });',
		'const window = globalThis; window.window = window; window.document = document; window.console = console; window.location = location; window.CSSStyleSheet = CSSStyleSheet; window.alert = function (v) { console.log(v); }; window.setTimeout = function (f) { if (typeof f === "function") f(); return 1; }; window.addEventListener = document.addEventListener; window.getComputedStyle = function (element) { return element ? element.style : {}; }; window.internals = { click: function () { if (__lastRectElement !== null) __state.operations.push({ op: "click", target: __lastRectElement }); } };',
		'for (const id of Object.keys(__state.elements)) { try { window[id] = document.getElementById(id); } catch (_) {} }',
		'window.__ladybirdSnapshot = function () { return JSON.stringify(__state); };',
		'window.__ladybirdFinalize = function () { for (const __index of Object.keys(__canvases)) { const c=__canvases[__index]; __state.operations.push({op:"canvasPixels",target:Number(__index),width:c.width,height:c.height,pixels:Array.from(c.data)}); } return window.__ladybirdSnapshot(); };',
		'window.__ladybirdDocumentReady = function () {',
		'for (const __name of ["DOMContentLoaded", "load"]) { const target = document; const event = { type: __name, target: target, defaultPrevented: false, preventDefault: function () { this.defaultPrevented = true; } }; for (const listener of (__listeners[__listenerKey(null, __name)] || [])) { try { listener.call(target, event); } catch (e) { console.error(e); } } if (__name === "load" && typeof window.onload === "function") { try { window.onload.call(window, event); } catch (e) { console.error(e); } } }',
		'};',
		'return window.__ladybirdSnapshot();',
		'})()',
	].join('\n')
}

fn bridge_string_property(object map[string]json2.Any, name string) ?string {
	value := object[name] or { return none }
	if value is string {
		return value
	}
	return none
}

fn bridge_bool_property(object map[string]json2.Any, name string) bool {
	value := object[name] or { return false }
	return if value is bool { value } else { false }
}

fn bridge_int_property(object map[string]json2.Any, name string) ?int {
	value := object[name] or { return none }
	return match value {
		int { value }
		i64 { int(value) }
		i32 { int(value) }
		u64 { int(value) }
		u32 { int(value) }
		f64 { int(value) }
		f32 { int(value) }
		else { none }
	}
}

fn bridge_byte_array_property(object map[string]json2.Any, name string) []u8 {
	value := object[name] or { return []u8{} }
	if value !is []json2.Any {
		return []u8{}
	}
	mut result := []u8{cap: (value as []json2.Any).len}
	for item in value as []json2.Any {
		number := match item {
			int { item }
			i64 { int(item) }
			i32 { int(item) }
			u64 { int(item) }
			u32 { int(item) }
			f64 { int(item) }
			f32 { int(item) }
			else { 0 }
		}
		result << u8(number)
	}
	return result
}

fn bridge_int_array_property(object map[string]json2.Any, name string) []int {
	value := object[name] or { return []int{} }
	if value !is []json2.Any {
		return []int{}
	}
	mut result := []int{cap: (value as []json2.Any).len}
	for item in value as []json2.Any {
		result << match item {
			int { item }
			i64 { int(item) }
			i32 { int(item) }
			u64 { int(item) }
			u32 { int(item) }
			f64 { int(item) }
			f32 { int(item) }
			else { 0 }
		}
	}
	return result
}

// Attribute::handle_attribute_changes() invokes the concrete HTML element's
// attribute_changed() override after the generic Element steps. The DOM module
// cannot import HTML in V, so replay that second half at this bridge boundary.
// This keeps reflected IDL properties such as input.type/placeholder/multiple
// on the same translated code path as Ladybird instead of merely editing the
// serialized attribute map.
fn bridge_html_attribute_changed(element &dom.Element, name string, old_value ?string, value ?string) {
	if !element.is_html_element() {
		return
	}
	match element.local_name() {
		'input' {
			mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
			model.form_associated_element_attribute_changed(name, old_value, value, none)
		}
		'option' {
			option := unsafe { &dom.HTMLOptionElement(element) }
			if name == 'selected' {
				html.html_option_element_selected_attribute_changed(option, value)
			} else if name == 'label' {
				html.html_option_element_update_selection_label(option)
			}
		}
		'select' {
			if name == 'multiple' {
				mut model := html.HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) })
				model.form_associated_element_attribute_changed(name, value)
			}
		}
		'canvas' {
			html.html_canvas_element_attribute_changed(unsafe { &dom.HTMLCanvasElement(element) }, name, old_value, value, none)
		}
		else {}
	}
}

// Parser-created platform objects exist before an attribute mutation reaches
// their virtual attribute_changed() hook upstream. The compact bridge creates
// models lazily, so materialize an input model while its old type is still
// observable; otherwise a text-to-image transition would initialize directly
// in the new state and retain the old TextInputBox layout node.
fn bridge_prepare_html_attribute_change(element &dom.Element, name string) {
	if element.is_html_element() && element.local_name() == 'input' && name == 'type' {
		_ = html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	}
}

fn apply_bridge_state(document &dom.Document, encoded string) ! {
	if os.getenv('LIBWEB_V_BRIDGE_DUMP') == '1' {
		eprintln(encoded)
	}
	value := json2.decode[json2.Any](encoded)!
	if value !is map[string]json2.Any {
		return
	}
	state := value as map[string]json2.Any
	root := unsafe { &dom.Node(document) }
	initial_elements := css.query_selector_all(root, '*')
	body := css.query_selector(root, 'body')
	if bridge_bool_property(state, 'bodyHTMLDirty') {
		body_html := bridge_string_property(state, 'bodyHTML') or { '' }
		if mut body_element := body {
			if body_html != (body_element.inner_html() or { '' }) {
				body_element.set_inner_html(body_html)!
			}
		}
	} else if bridge_bool_property(state, 'bodyTextDirty') {
		body_text := bridge_string_property(state, 'bodyText') or { '' }
		if mut body_element := body {
			if body_text != (body_element.as_node().text_content() or { '' }) {
				mut body_node := unsafe { &dom.Node(body_element) }
				body_node.set_text_content(body_text)!
			}
		}
	}
	mut element_by_index := map[int]&dom.Element{}
	for index, element in initial_elements {
		element_by_index[index] = element
	}
	if node_values := state['nodes'] {
		if node_values is []json2.Any {
			states := node_values as []json2.Any
			// Create every script-created element before replaying tree operations,
			// so append/prepend can reference nodes created later in the script.
			for item in states {
				if item !is map[string]json2.Any {
					continue
				}
				node_state := item as map[string]json2.Any
				if !bridge_bool_property(node_state, 'created') {
					continue
				}
				index := bridge_int_property(node_state, 'index') or { continue }
				tag_name := bridge_string_property(node_state, 'tagName') or { 'div' }
				namespace_uri := bridge_string_property(node_state, 'namespaceURI') or {
					'http://www.w3.org/1999/xhtml'
				}
				created := document.create_element_ns(namespace_uri, tag_name) or {
					continue
				}
				element_by_index[index] = created
			}
			for item in states {
				if item !is map[string]json2.Any {
					continue
				}
				node_state := item as map[string]json2.Any
				index := bridge_int_property(node_state, 'index') or { continue }
				mut element := element_by_index[index] or { continue }
				if bridge_bool_property(node_state, 'attributesDirty')
					|| bridge_bool_property(node_state, 'created') {
					if attribute_values := node_state['attributes'] {
						if attribute_values is map[string]json2.Any {
							attributes := attribute_values as map[string]json2.Any
							for existing_name in element.get_attribute_names() {
								if existing_name !in attributes {
									old_value := element.get_attribute(existing_name)
									bridge_prepare_html_attribute_change(element, existing_name)
									element.remove_attribute(existing_name)
									bridge_html_attribute_changed(element, existing_name, old_value, none)
								}
							}
							for name, attribute_value in attributes {
								if attribute_value is string {
									old_value := element.get_attribute(name)
									if old_value or { '\x00' } != attribute_value {
										bridge_prepare_html_attribute_change(element, name)
										element.set_attribute_value(name, attribute_value)
										bridge_html_attribute_changed(element, name, old_value, attribute_value)
									}
								}
							}
						}
					}
				}
				if bridge_bool_property(node_state, 'innerHTMLDirty') {
					element.set_inner_html(bridge_string_property(node_state, 'innerHTML') or { '' })!
				} else if bridge_bool_property(node_state, 'textContentDirty') {
					mut node := unsafe { &dom.Node(element) }
					node.set_text_content(bridge_string_property(node_state, 'textContent') or {
						''
					})!
				}
			}
		}
	}
	// Preserve the parser's trailing nodes while replaying body.appendChild().
	// Keep the original insertion point: recomputing script.nextSibling after
	// each insertion would reverse consecutive appends.
	mut body_append_reference := ?&dom.Node(none)
	if body_element := body {
		for script in css.query_selector_all(root, 'script') {
			if parent := script.as_node().parent_element() {
				if voidptr(parent) == voidptr(body_element) {
					body_append_reference = script.as_node().next_sibling()
				}
			}
		}
	}
	mut constructed_style_sheets := map[int]&css.CSSStyleSheet{}
	if operation_values := state['operations'] {
		if operation_values is []json2.Any {
			for item in operation_values as []json2.Any {
				if item !is map[string]json2.Any {
					continue
				}
				operation := item as map[string]json2.Any
				kind := bridge_string_property(operation, 'op') or { continue }
				if kind == 'constructStyleSheet' {
					sheet_id := bridge_int_property(operation, 'sheet') or { continue }
					constructed_style_sheets[sheet_id] = css.css_style_sheet_construct(none,
						document)!
					continue
				}
				if kind == 'replaceStyleSheet' {
					sheet_id := bridge_int_property(operation, 'sheet') or { continue }
					mut sheet := constructed_style_sheets[sheet_id] or { continue }
					sheet.replace_sync(bridge_string_property(operation, 'text') or { '' })!
					continue
				}
				if kind == 'setAdoptedStyleSheets' {
					mut sheets := []&css.CSSStyleSheet{}
					for sheet_id in bridge_int_array_property(operation, 'sheets') {
						sheets << (constructed_style_sheets[sheet_id] or { continue })
					}
					mut adopted := css.create_adopted_style_sheets_list(root)
					adopted.replace(sheets)!
					continue
				}
				target_index := bridge_int_property(operation, 'target') or { continue }
				mut target := element_by_index[target_index] or { continue }
				match kind {
					'insertStyleRule' {
						mut sheet := css.style_sheet_for_owner_node(document, target) or { continue }
						requested_index := bridge_int_property(operation, 'index') or { -1 }
						index := if requested_index < 0 {
							u32(sheet.css_rules().length())
						} else {
							u32(requested_index)
						}
						sheet.insert_rule(bridge_string_property(operation, 'rule') or { '' },
							index)!
					}
					'deleteStyleRule' {
						mut sheet := css.style_sheet_for_owner_node(document, target) or { continue }
						index := bridge_int_property(operation, 'index') or { continue }
						if index >= 0 {
							sheet.delete_rule(u32(index))!
						}
					}
					'append', 'prependNode' {
						child_index := bridge_int_property(operation, 'child') or { continue }
						child := element_by_index[child_index] or { continue }
						mut target_node := unsafe { &dom.Node(target) }
						if kind == 'prependNode' {
							target_node.insert_before(child.as_node(), target_node.first_child(), false)
						} else if target.local_name() == 'body' {
							target_node.insert_before(child.as_node(), body_append_reference, false)
						} else {
							target_node.append_child(child.as_node())!
						}
					}
					'remove' {
						child_index := bridge_int_property(operation, 'child') or { continue }
						child := element_by_index[child_index] or { continue }
						mut target_node := unsafe { &dom.Node(target) }
						target_node.remove_child(child.as_node())!
					}
					'prependText' {
						text_node := document.create_text_node(bridge_string_property(operation, 'text') or { '' })
						mut target_node := unsafe { &dom.Node(target) }
						target_node.insert_before(text_node.as_node(), target_node.first_child(), false)
					}
					'insertAdjacentHTML' {
						target.insert_adjacent_html(bridge_string_property(operation, 'position') or {
							'beforeend'
						}, bridge_string_property(operation, 'html') or { '' })!
					}
					'showModal' {
						mut dialog := unsafe { &dom.HTMLDialogElement(target) }
						html.show_modal_html_dialog_element(mut dialog) or {}
					}
					'showDialog' {
						mut dialog := unsafe { &dom.HTMLDialogElement(target) }
						html.show_html_dialog_element(mut dialog) or {}
					}
					'selectedIndex' {
						selected_index := bridge_int_property(operation, 'value') or { -1 }
						html.set_html_select_element_selected_index(unsafe {
							&dom.HTMLSelectElement(target)
						}, i32(selected_index))
					}
					'inputValue' {
						mut model := html.HTMLInputElementModel.create(unsafe {
							&dom.HTMLInputElement(target)
						})
						model.set_value(bridge_string_property(operation, 'value') or { '' }) or {}
					}
					'canvasPixels' {
						if target.local_name() != 'canvas' {
							continue
						}
						width := bridge_int_property(operation, 'width') or { continue }
						height := bridge_int_property(operation, 'height') or { continue }
						if width < 0 || height < 0 {
							continue
						}
						mut canvas := unsafe { &dom.HTMLCanvasElement(target) }
						if html.html_canvas_element_width(canvas) != u32(width) {
							html.html_canvas_element_set_width(mut canvas, u32(width)) or { continue }
						}
						if html.html_canvas_element_height(canvas) != u32(height) {
							html.html_canvas_element_set_height(mut canvas, u32(height)) or { continue }
						}
						mut context := html.html_canvas_element_get_context(canvas, '2d', none) or {
							continue
						}
						pixels := bridge_byte_array_property(operation, 'pixels')
						if pixels.len != width * height * 4 {
							continue
						}
						bitmap := context.surface() or { continue }
						mut mutable_bitmap := unsafe { &dom.Bitmap_(bitmap) }
						mutable_bitmap.data = pixels.clone()
						mutable_bitmap.pitch = width * 4
						context.did_draw(html.CanvasFloatRect{0, 0, f64(width), f64(height)})
					}
					'click' {
						target_id := target.get_attribute_value('popovertarget')
						if target_id.len > 0 {
							if mut popover := document.get_element_by_id(target_id) {
								mut html_popover := unsafe { &dom.HTMLElement(popover) }
								html_popover.set_popover_visibility_state(.showing)
								mut mutable_document := unsafe { &dom.Document(document) }
								mutable_document.add_an_element_to_the_top_layer(popover)
							}
						}
					}
					else {}
				}
			}
		}
	}
	if write_html := bridge_string_property(state, 'writeHTML') {
		if write_html.len > 0 {
			if mut script := css.query_selector(root, 'script') {
				script.insert_adjacent_html('beforebegin', write_html)!
			}
		}
	}
	if title := bridge_string_property(state, 'title') {
		if mut title_element := css.query_selector(root, 'title') {
			mut title_node := unsafe { &dom.Node(title_element) }
			title_node.set_text_content(title) or {}
		}
	}
}

// Execute the document's inline classic scripts and reflect DOM mutations
// back into the translated DOM before layout. Layout corpus inputs do not use
// external script resources.
pub fn run_inline_document_scripts(document &dom.Document, current_url string, runtime &Runtime) ! {
	root := unsafe { &dom.Node(document) }
	mut sources := []ScriptSource{}
	for script_element in css.query_selector_all(root, 'script') {
		type_ := script_element.get_attribute_value('type').trim_space().to_lower()
		if type_ != '' && type_ !in ['text/javascript', 'application/javascript', 'module'] {
			continue
		}
		if script_element.get_attribute('src') != none {
			continue
		}
		sources << ScriptSource{
			code: script_element.as_node().text_content() or { '' }
			url: current_url
			source_type: if type_ == 'module' { .module } else { .script }
		}
	}
	if sources.len == 0 {
		return
	}
	viewport := document.viewport_rect()
	layout.run_document_layout(document, viewport.width, viewport.height) or {}
	runtime.evaluate_host(bridge_program(bridge_initial_state(document, current_url)))!
	mut mutable_runtime := unsafe { &Runtime(runtime) }
	mut animation_frame_host := AnimationFrameHost.create(document, fn [document] (callback_runtime &Runtime) ! {
		state := callback_runtime.evaluate_host('__ladybirdFinalize()')!
		apply_bridge_state(document, state)!
	})!
	animation_frame_host.install(mut mutable_runtime)!
	runtime.run_document_scripts(sources)!
	runtime.evaluate_host('__ladybirdDocumentReady()')!
	// Promise reactions queued by inline scripts run at JavaScriptCore's next
	// evaluation checkpoint. Snapshot once that queue has drained.
	encoded := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_bridge_state(document, encoded)!
}
