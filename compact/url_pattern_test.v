module main

import browserjs
import html

fn test_compact_url_pattern_constructs_matches_and_reports_errors() {
	mut document := html.parse_document('<!doctype html><p></p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://example.com/', [r'
const fail=message=>{throw new Error(message);};
const pattern=new URLPattern({pathname:"/books/:id"});
if(!(pattern instanceof URLPattern)||pattern.pathname!=="/books/:id"||pattern.protocol!=="*"||pattern.hasRegExpGroups)fail("components "+pattern.pathname+" "+pattern.protocol);
if(!pattern.test("https://example.com/books/123")||pattern.test("https://example.com/films/1"))fail("test");
const result=pattern.exec("https://example.com/books/123");
if(!result||result.pathname.input!=="/books/123"||result.pathname.groups.id!=="123"||result.inputs[0]!=="https://example.com/books/123")fail("exec "+JSON.stringify(result));
if(pattern.exec("https://example.com/films/1")!==null)fail("exec miss");
const based=new URLPattern("/a/*","https://example.com");
if(based.hostname!=="example.com"||!based.test("https://example.com/a/b"))fail("base url");
const relative=new URLPattern({pathname:"/x"});
if(!relative.test("/x","https://example.com"))fail("test base");
const regexp=new URLPattern({pathname:"/(\\d+)"});
if(!regexp.hasRegExpGroups||!regexp.test({pathname:"/42"})||regexp.test({pathname:"/x"}))fail("regexp");
const insensitive=new URLPattern({pathname:"/ABC"},{ignoreCase:true});
if(!insensitive.test({pathname:"/abc"}))fail("ignoreCase");
let threw=false;try{new URLPattern({pathname:"/(["});}catch(error){threw=error instanceof TypeError;}
if(!threw)fail("invalid pattern");
console.log("urlpattern passed");
'], runtime, mut messages)
	assert messages == ['urlpattern passed']
}
