module main

import adblock
import browserjs
import css
import dom
import html
import platform

fn compact_sheet_test_document(markup string) &dom.Document {
	address := dom.URL{ value: 'https://styles.test/board/' }
	return html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
}

fn test_compact_link_sheet_exposes_the_live_native_cssom_and_preserves_mutations() {
	mut document := compact_sheet_test_document('<!doctype html><link id="theme" rel="stylesheet" href="theme.css"><p id="target">text</p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	link := document.get_element_by_id('theme')?
	complete_browser_link_stylesheet(link, PreloadedResource{
		url:  'https://styles.test/board/theme.css'
		body: '#target { color: red }'
	})
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const sheet=theme.sheet;
if(sheet!==theme.sheet||!(sheet instanceof CSSStyleSheet)||!(sheet instanceof StyleSheet)||sheet.ownerNode!==theme||sheet.href!==theme.href||sheet.type!=="text/css"||sheet.title!==null||sheet.ownerRule!==null||sheet.parentStyleSheet!==null)throw new Error("native sheet identity");
const rules=sheet.cssRules,first=rules[0];
if(!(rules instanceof CSSRuleList)||rules!==sheet.cssRules||rules.length!==1||rules.item(0)!==first||rules.item(3)!==null||rules[3]!==undefined||[...rules][0]!==first)throw new Error("live rule list");
if(!(first instanceof CSSStyleRule)||!(first instanceof CSSRule)||first.type!==1||first.parentStyleSheet!==sheet||first.parentRule!==null||first.selectorText!=="#target"||!first.cssText.includes("color: red"))throw new Error("native rule metadata");
if(first.style!==first.style||first.style.parentRule!==first||first.style.color!=="red")throw new Error("native declaration");
first.style.color="blue";first.style.setProperty("width","42px","important");
if(first.style.color!=="blue"||first.style.getPropertyPriority("width")!=="important")throw new Error("native declaration edit");
if(sheet.insertRule("#target { height: 23px }",1)!==1||rules.length!==2)throw new Error("insert native rule");
const removed=rules[1];sheet.deleteRule(1);
if(rules.length!==1||removed.parentStyleSheet!==null||sheet.cssRules[0]!==first)throw new Error("delete native rule");
sheet.media="screen";const media=sheet.media;
if(!(media instanceof MediaList)||media!==sheet.media||media.mediaText!=="screen"||media.length!==1||media.item(0)!=="screen"||media.item(8)!==null)throw new Error("native media list");
media.appendMedium("print");media.deleteMedium("screen");if(media.mediaText!=="print")throw new Error("native media edit");
media.mediaText="";sheet.disabled=true;if(!sheet.disabled)throw new Error("disable sheet");sheet.disabled=false;
'], runtime, mut messages)
	assert messages == []string{}
	sheet := css.style_sheet_for_owner_node(document, link)?
	assert sheet.rules.item(0)?.style()?.get_property_value('color') == 'blue'
	css.sync_document_style_elements(document)
	assert voidptr(css.style_sheet_for_owner_node(document, link)?) == voidptr(sheet)
	assert sheet.rules.item(0)?.style()?.get_property_value('width') == '42px'
}

fn test_compact_stylesheet_construction_brands_and_native_errors() {
	mut document := compact_sheet_test_document('<!doctype html><link id="theme" rel="stylesheet" href="theme.css">')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	link := document.get_element_by_id('theme') or { panic('missing theme') }
	complete_browser_link_stylesheet(link, PreloadedResource{ url: 'https://styles.test/board/theme.css', body: 'p { color: red }' })
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
function expect(name,call){let actual="";try{call()}catch(error){actual=error.name}if(actual!==name)throw new Error("expected "+name+", received "+actual);}
expect("TypeError",()=>CSSStyleSheet());expect("TypeError",()=>new CSSRuleList());
expect("TypeError",()=>Object.getOwnPropertyDescriptor(StyleSheet.prototype,"href").get.call({}));
expect("TypeError",()=>CSSStyleSheet.prototype.insertRule.call({},"p{}"));
expect("TypeError",()=>theme.sheet.insertRule());expect("TypeError",()=>theme.sheet.insertRule(Symbol()));
expect("SyntaxError",()=>theme.sheet.insertRule("not a rule"));expect("IndexSizeError",()=>theme.sheet.deleteRule(10));
expect("NotAllowedError",()=>theme.sheet.replaceSync("p{}"));
const constructed=new CSSStyleSheet({disabled:true,media:"screen"});
if(!(constructed instanceof CSSStyleSheet)||constructed.ownerNode!==null||!constructed.disabled||constructed.media.mediaText!=="screen")throw new Error("constructed sheet");
const live=constructed.cssRules;constructed.replaceSync("@import url(ignored.css); p { color: green }");
if(live.length!==1||live[0].style.color!=="green"||live[0].parentStyleSheet!==constructed)throw new Error("native replace");
expect("SyntaxError",()=>constructed.insertRule("@import url(ignored.css)"));
constructed.replace("b { color: blue }").then(value=>{if(value!==constructed||live[0].selectorText!=="b")throw new Error("replace promise");globalThis.replacementDone=true;});
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('globalThis.replacementDone')! == 'true'
}

fn test_stylesheet_load_listener_sees_the_sheet_and_opaque_rules_stay_private() {
	mut document := compact_sheet_test_document('<!doctype html><link id="theme" rel="stylesheet" href="https://other.test/theme.css">')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.sheetEvents=[];
theme.addEventListener("load",()=>{const sheet=theme.sheet;sheetEvents.push(sheet!==null&&sheet.ownerNode===theme);for(const call of [()=>sheet.cssRules,()=>sheet.insertRule("p{}"),()=>sheet.deleteRule(0)]){try{call();sheetEvents.push("exposed")}catch(error){sheetEvents.push(error.name)}}});
theme.addEventListener("error",()=>sheetEvents.push(theme.sheet===null?"failed":"stale"));
'], runtime, mut messages)
	assert messages == []string{}
	link := document.get_element_by_id('theme')?
	complete_browser_link_stylesheet(link, PreloadedResource{ url: 'https://other.test/theme.css', body: 'p { color: red }' })
	assert runtime.evaluate_host('JSON.stringify(sheetEvents)')! == '[true,"SecurityError","SecurityError","SecurityError"]'
	complete_browser_link_stylesheet(link, PreloadedResource{ url: 'https://other.test/theme.css', body: '<html>error</html>', response_headers: [adblock.ResponseHeader{ name: 'Content-Type', value: 'text/html' }] })
	assert runtime.evaluate_host('JSON.stringify(sheetEvents)')!.ends_with(',"failed"]')
}

fn test_cached_stylesheet_response_completes_each_link_once_without_duplicate_fetches() {
	mut document := compact_sheet_test_document('<!doctype html><link id="first" rel="stylesheet" href="theme.css"><link id="second" rel="stylesheet" href="theme.css">')
	defer { document.finalize() }
	address := 'https://styles.test/board/theme.css'
	mut app := BrowserApp{
		document:                    document
		script_stylesheet_requests:  {
			address: true
		}
		background_resource_results: chan PreloadedResource{cap: 2}
	}
	assert !app.request_script_inserted_stylesheets()
	assert app.install_script_inserted_stylesheet(PreloadedResource{ url: address, body: 'p { color: blue }', request_type: 'stylesheet' })
	mut links := css.query_selector_all(document.as_node(), 'link')
	for link in links {
		model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
		assert model.event_count('load') == 1
		assert css.style_sheet_for_owner_node(document, link) != none
	}
	mut late := document.create_element('link')!
	late.set_attribute_value('rel', 'stylesheet')
	late.set_attribute_value('href', 'theme.css')
	mut head := document.head()?
	head.as_node().append_child(late.as_node())!
	assert app.request_script_inserted_stylesheets()
	assert !app.request_script_inserted_stylesheets()
	links << late
	for link in links {
		model := html.html_link_element_model_for_dom_element(unsafe { &dom.HTMLLinkElement(link) })
		assert model.event_count('load') == 1
	}
	assert app.script_stylesheet_requests.len == 1
}

fn test_link_sheet_and_rule_bindings_survive_retiring_query_scratch() {
	mut document := compact_sheet_test_document('<!doctype html><link id="theme" rel="stylesheet" href="theme.css">')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	link := document.get_element_by_id('theme') or { panic('missing link') }
	complete_browser_link_stylesheet(link, PreloadedResource{ url: 'https://styles.test/board/theme.css', body: 'p { color: red }' })
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), ['globalThis.sheetProbeReady=true;'], runtime, mut messages)
	assert messages == []string{}
	mut scratch := platform.begin_thread_scratch('CSSOM query lifetime')
	assert runtime.evaluate_host('globalThis.retainedSheet=theme.sheet;retainedSheet.insertRule("b { width: 42px }",1);retainedSheet.cssRules.length')! == '2'
	scratch.finish()
	mut overwrite := platform.begin_thread_scratch('CSSOM query overwrite')
	_ = 'overwrite retired query strings'.repeat(16384)
	overwrite.finish()
	assert runtime.evaluate_host('retainedSheet===theme.sheet&&retainedSheet.ownerNode===theme&&retainedSheet.cssRules[1].style.width==="42px"')! == 'true'
	$if prealloc {
		sheet := css.style_sheet_for_owner_node(document, link) or { panic('missing sheet') }
		assert document.native_storage().arena.contains(sheet)
	}
}
