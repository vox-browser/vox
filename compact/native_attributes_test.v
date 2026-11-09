module main

import browserjs
import dom
import html
import layout

fn test_native_attributes_observe_native_changes_without_a_refresh_or_observer() {
	mut document := html.parse_document('<!doctype html><div id="target" class="before" name="old" title="old-title" data-value="first"></div><div id="other"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.attributeTarget=document.getElementById("target");
globalThis.attributeMap=attributeTarget.attributes;
globalThis.originalAttribute=attributeTarget.getAttributeNode("data-value");
'], runtime, mut messages)
	assert messages == []string{}
	mut element := document.get_element_by_id('target')?
	element.set_attribute_value('id', 'renamed')
	element.set_attribute_value('class', 'native-class')
	element.set_attribute_value('name', 'native-name')
	element.set_attribute_value('title', 'native-title')
	element.set_attribute_value('hidden', '')
	element.set_attribute_value('disabled', '')
	element.set_attribute_value('data-value', 'native-value')
	assert runtime.evaluate_host(r'
attributeTarget.id==="renamed"&&attributeTarget.className==="native-class"&&attributeTarget.name==="native-name"&&attributeTarget.title==="native-title"&&attributeTarget.hidden&&attributeTarget.disabled&&
attributeTarget.getAttribute("DATA-VALUE")==="native-value"&&attributeTarget.hasAttribute("hidden")&&attributeTarget.getAttributeNames().includes("disabled")&&
attributeMap===attributeTarget.attributes&&attributeMap.getNamedItem("data-value")===originalAttribute&&originalAttribute.value==="native-value"&&document.getElementById("renamed")===attributeTarget
')! == 'true'
	// There is no script read between native removal and recreation. A name
	// cache would attach the old wrapper to the replacement attribute.
	element.remove_attribute('data-value')
	element.set_attribute_value('data-value', 'replacement')
	assert runtime.evaluate_host(r'
originalAttribute.ownerElement===null&&originalAttribute.value==="native-value"&&originalAttribute.ownerDocument===document&&
attributeMap.getNamedItem("data-value")!==originalAttribute&&attributeMap.getNamedItem("data-value").value==="replacement"
')! == 'true'
	assert messages == []string{}
}

fn test_native_attribute_identity_survives_detachment_replacement_and_document_adoption() {
	mut document := html.parse_document('<!doctype html><div id="target" data-value="first"></div><div id="other" data-value="second"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const check=(value,label)=>{if(!value)throw new Error(label);};
const target=document.getElementById("target"),other=document.getElementById("other");
const node=target.getAttributeNode("data-value"),otherNode=other.getAttributeNode("data-value");
check(target.removeAttributeNode(node)===node&&node.ownerElement===null,"detach identity");
node.value="detached change";
check(other.attributes.setNamedItem(node)===otherNode,"replacement identity");
check(otherNode.ownerElement===null&&otherNode.value==="second"&&node.ownerElement===other&&other.getAttributeNode("data-value")===node,"native owner");
let inUse=false;try{target.attributes.setNamedItem(node);}catch(error){inUse=error.name==="InUseAttributeError";}
check(inUse&&node.ownerElement===other,"in-use attribute");
check(other.attributes.removeNamedItem("data-value")===node,"remove identity");
check(target.attributes.setNamedItem(node)===null,"append returns null");
const foreign=document.implementation.createHTMLDocument("foreign");
foreign.body.appendChild(target);
// Detach before reading the Attr again: ownerDocument must follow native
// adoption even though the facade never saw the intermediate owner.
target.removeAttribute("data-value");
check(node.ownerDocument===foreign&&node.ownerElement===null,"adopted detached document");
check(other.attributes.setNamedItem(node)===null&&node.ownerDocument===document,"reattachment document");
const created=document.createElement("span");created.setAttributeNS("urn:test","p:token","namespaced");
const namespaced=created.attributes.getNamedItemNS("urn:test","token");
check(namespaced===created.getAttributeNode("p:token")&&namespaced.prefix==="p","namespace identity");
check(created.attributes.removeNamedItemNS("urn:test","token")===namespaced,"namespace removal");
check(other.attributes.setNamedItemNS(namespaced)===null&&other.getAttributeNS("urn:test","token")==="namespaced","namespace reattachment");
namespaced.value="changed";
check(other.getAttributeNS("urn:test","token")==="changed"&&other.getAttributeNodeNS("urn:test","token")===namespaced,"namespace value write");
'], runtime, mut messages)
	assert messages == []string{}, messages.join('\n')
}

fn test_native_attributes_keep_reflections_collections_and_replayed_handlers_live() {
	mut document := html.parse_document('<!doctype html><a id="native-link" name="old-name" class="attribute-member" href="/before" lang="en"></a><iframe id="native-frame" frameborder="1" loading="eager" referrerpolicy="origin"></iframe><meta id="native-meta" content="before"><img id="native-image" onload="globalThis.attributeEventValue=\'old\'">')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://native-attributes.test/base/', [r'
globalThis.reflectionLink=document.getElementById("native-link");
globalThis.reflectionFrame=document.getElementById("native-frame");
globalThis.reflectionMeta=document.getElementById("native-meta");
globalThis.reflectionImage=document.getElementById("native-image");
globalThis.reflectionCollection=document.getElementsByClassName("attribute-member");
// Keep the wrappers and their initial attributes alive before native changes.
reflectionLink.href;reflectionFrame.loading;reflectionMeta.content;reflectionImage.getAttribute("onload");
'], runtime, mut messages)
	assert messages == []string{}, messages.join('\n')
	mut link := document.get_element_by_id('native-link')?
	link.set_attribute_value('href', '/native')
	link.set_attribute_value('lang', 'fr')
	link.set_attribute_value('id', 'renamed-link')
	link.set_attribute_value('name', 'renamed-name')
	mut frame := document.get_element_by_id('native-frame')?
	frame.set_attribute_value('frameborder', '0')
	frame.set_attribute_value('loading', 'LAZY')
	frame.set_attribute_value('referrerpolicy', 'NO-REFERRER')
	frame.set_attribute_value('allowfullscreen', '')
	mut meta := document.get_element_by_id('native-meta')?
	meta.set_attribute_value('content', 'native')
	mut image := document.get_element_by_id('native-image')?
	image.set_attribute_value('onload', 'globalThis.attributeEventValue="native"')
	image.set_attribute_value('id', 'renamed-image')
	assert runtime.evaluate_host(r'(function(){
const check=(value,label)=>{if(!value)throw new Error(label);};
check(reflectionLink.href.endsWith("/native")&&reflectionLink.lang==="fr","native hyperlink and language reflection");
check(reflectionFrame.frameBorder==="0"&&reflectionFrame.loading==="lazy"&&reflectionFrame.referrerPolicy==="no-referrer"&&reflectionFrame.allowFullscreen,"native iframe reflection");
check(reflectionMeta.content==="native","native content reflection");
// Named collection lookup uses native content attributes even if author code
// replaces a reflected property on the wrapper.
Object.defineProperty(reflectionLink,"id",{value:"author-id",configurable:true});
Object.defineProperty(reflectionLink,"name",{value:"author-name",configurable:true});
check(reflectionCollection.namedItem("renamed-link")===reflectionLink&&reflectionCollection["renamed-name"]===reflectionLink&&!reflectionCollection.namedItem("old-name"),"native named collection lookup");
const keys=Reflect.ownKeys(reflectionCollection);check(keys.includes("renamed-link")&&keys.includes("renamed-name")&&!keys.includes("old-name")&&!keys.includes("author-id"),"live collection property names");
reflectionLink.getAttributeNode("href").value="/value";
check(reflectionLink.href.endsWith("/value")&&reflectionLink.pathname==="/value","Attr.value URL reflection");
const href=reflectionLink.attributes.removeNamedItem("href");
check(reflectionLink.href===""&&reflectionLink.origin==="","removed hyperlink reflection");
href.value="/reattached";reflectionLink.attributes.setNamedItem(href);
check(reflectionLink.href.endsWith("/reattached"),"reattached hyperlink reflection");
reflectionLink.toggleAttribute("href",false);check(reflectionLink.href==="","toggled hyperlink reflection");
reflectionLink.toggleAttribute("href",true);check(reflectionLink.href!=="","present empty hyperlink reflection");
reflectionLink.getAttributeNode("lang").value="de";check(reflectionLink.lang==="de","Attr.value language reflection");
reflectionFrame.getAttributeNode("loading").value="invalid";check(reflectionFrame.loading==="eager","native enumeration default");
reflectionFrame.attributes.removeNamedItem("allowfullscreen");check(!reflectionFrame.allowFullscreen,"removed boolean reflection");
reflectionFrame.removeAttributeNS(null,"loading");reflectionFrame.setAttributeNS("urn:foreign","loading","foreign");reflectionFrame.loading="lazy";
check(reflectionFrame.getAttributeNS(null,"loading")==="lazy"&&reflectionFrame.getAttributeNS("urn:foreign","loading")==="foreign"&&reflectionFrame.loading==="lazy","reflections use the null namespace");
reflectionMeta.getAttributeNode("content").value="updated";check(reflectionMeta.content==="updated","Attr.value content reflection");
__ladybirdDispatch("load","renamed-image");check(attributeEventValue==="native","native event target and handler lookup");
reflectionImage.getAttributeNode("onload").value="globalThis.attributeEventValue=\"updated\"";
__ladybirdDispatch("load","renamed-image");check(attributeEventValue==="updated","Attr.value replayed handler");
return true;
})()')! == 'true'
}

fn test_native_attribute_writes_preserve_observation_conversion_and_input_state() {
	mut document := html.parse_document('<!doctype html><input id="field" value="old"><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const check=(value,label)=>{if(!value)throw new Error(label);};
const target=document.getElementById("target"),field=document.getElementById("field");
const records=[],observer=new MutationObserver(()=>{});observer.observe(target,{attributes:true,attributeOldValue:true});
target.id="renamed";target.setAttribute("data-value","one");const attr=target.getAttributeNode("data-value");attr.value="two";target.removeAttribute("data-value");
const pending=observer.takeRecords();
check(pending.length===4&&pending[1].oldValue===null&&pending[2].oldValue==="one"&&pending[3].oldValue==="two","ordered native mutations");
check(target.getAttribute("data-value")===null&&attr.value==="two"&&attr.ownerElement===null,"removed native value");
field.setAttribute("value","clean");check(field.value==="clean","clean value follows default");
field.value="dirty";const value=field.getAttributeNode("value");value.value="new default";
check(field.value==="dirty"&&field.defaultValue==="new default","dirty value remains native");
field.removeAttribute("value");check(field.value==="dirty"&&field.defaultValue==="","remove updates native default");
const canvas=document.createElement("canvas");canvas.setAttribute("width","12");const width=canvas.getAttributeNode("width");
const context=canvas.getContext("2d"),canvasObserver=new MutationObserver(()=>{});canvasObserver.observe(canvas,{attributes:true});
context.lineWidth=7;check(canvas.attributes.setNamedItem(width)===width&&context.lineWidth===7&&canvasObserver.takeRecords().length===0,"same native Attr is a no-op");
width.value="24";
check(canvas.width===24&&context.lineWidth===1,"canvas Attr resets native context");
let canvasRecords=canvasObserver.takeRecords();check(canvasRecords.length===1&&canvasRecords[0].attributeName==="width","one native canvas mutation");
context.lineWidth=9;width.value="24";check(context.lineWidth===1&&canvasObserver.takeRecords().length===1,"equal canvas size resets once");
context.lineWidth=5;canvas.attributes.removeNamedItem("width");
check(canvas.width===300&&context.lineWidth===1&&canvasObserver.takeRecords().length===1,"canvas removal resets once");
const events=[];class Observed extends HTMLElement{static get observedAttributes(){return ["data-value"];}attributeChangedCallback(name,old,value){events.push([old,value,this.getAttribute(name)].join("|"));}}
customElements.define("x-native-attribute",Observed);const observed=new Observed();
observed.setAttribute("data-value","a");observed.getAttributeNode("data-value").value="b";observed.removeAttribute("data-value");
check(events.join(",")==="|a|a,a|b|b,b||","synchronous native reactions");
let conversions=0;try{Element.prototype.getAttribute.call({}, {toString(){conversions++;return "id";}});}catch(error){check(error instanceof TypeError,"brand error");}
check(conversions===0,"receiver before conversion");
const reason={original:true};let caught;try{target.setAttribute("title",{toString(){throw reason;}});}catch(error){caught=error;}
check(caught===reason,"original conversion exception");
let invalid=false;try{target.toggleAttribute("bad name",false);}catch(error){invalid=error.name==="InvalidCharacterError";}
check(invalid,"native name validation on no-op");
'], runtime, mut messages)
	assert messages == []string{}, messages.join('\n')
}

fn test_native_attr_value_and_named_map_attachment_use_trusted_types() {
	url := dom.URL{ value: 'https://native-attributes.test/' }
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><meta http-equiv="Content-Security-Policy" content="require-trusted-types-for &apos;script&apos;"><body><div id="target"></div><div id="other"></div>')
	allocation.finish()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [r'
const check=(value,label)=>{if(!value)throw new Error(label);};
const policy=trustedTypes.createPolicy("native-attr",{createScript:value=>value,createHTML:value=>value});
const frame=document.createElement("iframe");frame.srcdoc=policy.createHTML("<b>trusted</b>");
check(frame.srcdoc==="<b>trusted</b>","srcdoc reflection preserves TrustedHTML");
target.setAttribute("onclick",policy.createScript("initial"));
const attr=target.getAttributeNode("onclick");
let rejected=false;try{attr.value="unsafe";}catch(error){rejected=error instanceof TypeError;}
check(rejected&&attr.value==="initial","Attr.value enforcement");
target.removeAttribute("onclick");attr.value="detached";
rejected=false;try{other.attributes.setNamedItem(attr);}catch(error){rejected=error instanceof TypeError;}
check(rejected&&attr.ownerElement===null&&!other.hasAttribute("onclick"),"NamedNodeMap enforcement");
let calls=0;trustedTypes.createPolicy("default",{createScript(value){calls++;if(value==="incoming")other.removeAttribute("onclick");return "safe:"+value;}});
check(other.attributes.setNamedItem(attr)===null&&attr.value==="safe:detached"&&calls===1,"native default policy");
attr.value="next";check(attr.value==="safe:next"&&calls===2,"native Attr policy");
target.setAttribute("onclick",policy.createScript("incoming"));const incoming=target.removeAttributeNode(target.getAttributeNode("onclick"));
check(other.attributes.setNamedItem(incoming)===null&&attr.ownerElement===null&&incoming.ownerElement===other&&incoming.value==="safe:incoming","reentrant native replacement result");
let inUse=false;try{target.attributes.setNamedItem(incoming);}catch(error){inUse=error.name==="InUseAttributeError";}
check(inUse&&incoming.ownerElement===other&&incoming.value==="safe:incoming","failed attachment preserves source value");
console.log("trusted attribute passed");
'], runtime, mut messages)
	assert messages == ['trusted attribute passed'], messages.join('\n')
}

fn image_attribute_change_fixture() !(&dom.Document, &browserjs.Runtime, &html.HTMLImageElementModel) {
	url := dom.URL{ value: 'https://image-attributes.test/' }
	mut document := html.parse_navigation_document('<!doctype html><style>html,body{margin:0}img{width:1px;height:1px}</style><img id="photo" srcset="">',
		url, url.origin(), none)!
	document.set_viewport_rect(dom.Rect{ width: 80, height: 60 })
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	// Bind the native image before installing the controlled fetch hook.
	run_document_javascript(document, url.serialize(), [r'
globalThis.photo=document.getElementById("photo");
globalThis.imageSourceAttribute=photo.getAttributeNode("srcset");
if(photo.currentSrc!=="")throw new Error("unexpected initial source");
'], runtime, mut messages)
	assert messages == []string{}, messages.join('\n')
	mut element := document.get_element_by_id('photo') or { return error('missing image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn (resource dom.URL) !html.DecodedImageData {
		pixels := if resource.serialize().contains('green') {
			[u8(0), 255, 0, 255]
		} else {
			[u8(255), 0, 0, 255]
		}
		bitmap := &dom.Bitmap_{ width: 1, height: 1, pitch: 4, data: pixels }
		return html.BitmapDecodedImageData.create([
			html.BitmapDecodedImageFrame{ frame: dom.DecodedImageFrame_.create(bitmap) },
		], 0, false)
	})
	element.set_attribute_value('src', '/red-fallback.png')
	element.set_attribute_value('srcset', '/red.png 1x')
	model.update_the_image_data(false, false)
	assert model.current_src() == 'https://image-attributes.test/red.png'
	frame := model.current_image_frame() or { return error('missing initial image frame') }
	assert frame.bitmap().data[..4] == [u8(255), 0, 0, 255]
	return document, runtime, model
}

fn test_image_srcset_attr_and_element_writes_replace_same_size_pixels_and_invalidate_paint() {
	mut document, mut runtime, model := image_attribute_change_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	element := document.get_element_by_id('photo')?
	for index, write in [
		'imageSourceAttribute.value=value',
		'imageSourceAttribute.nodeValue=value',
		'imageSourceAttribute.textContent=value',
		'photo.setAttribute("srcset",value)',
		'photo.setAttributeNS(null,"srcset",value)',
	] {
		_ = layout.run_document_layout(document, 80, 60)?
		_ = document.record_display_list()?
		assert document.cached_display_list() != none
		candidate := '/green-${index}.png'
		value := '${candidate} 1x'
		_ = runtime.evaluate_host('(()=>{const value="${value}";${write};})()')!
		assert element.get_attribute_value('srcset') == value
		assert model.current_src() == 'https://image-attributes.test${candidate}'
		assert model.natural_width() == 1 && model.natural_height() == 1
		assert model.current_image_frame()?.bitmap().data[..4] == [u8(0), 255, 0, 255]
		assert document.cached_display_list() == none
	}
}

fn test_namespaced_srcset_writes_leave_the_html_image_selection_unchanged() {
	mut document, mut runtime, model := image_attribute_change_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	_ = runtime.evaluate_host('photo.setAttributeNS("urn:image-test","test:srcset","/green-foreign.png 1x")')!
	element := document.get_element_by_id('photo')?
	assert element.get_attribute_ns('urn:image-test', 'srcset')? == '/green-foreign.png 1x'
	assert element.get_attribute_value('srcset') == '/red.png 1x'
	assert model.current_src() == 'https://image-attributes.test/red.png'
	assert model.current_image_frame()?.bitmap().data[..4] == [u8(255), 0, 0, 255]
}
