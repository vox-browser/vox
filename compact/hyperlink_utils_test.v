module main

import browserjs
import html

fn test_compact_hyperlink_utils_read_and_update_href_components() {
	mut document := html.parse_document('<!doctype html><a id="link" href="https://user:pw@example.com:8080/dir/file?q=1#top">x</a><area id="spot">')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://example.com/', [r'
const fail=message=>{throw new Error(message);};
const link=document.getElementById("link");
const expected={protocol:"https:",username:"user",password:"pw",host:"example.com:8080",hostname:"example.com",port:"8080",pathname:"/dir/file",search:"?q=1",hash:"#top",origin:"https://example.com:8080"};
for(const [name,value] of Object.entries(expected))if(link[name]!==value)fail(name+" read "+link[name]);
link.pathname="/other";link.search="a=b";link.hash="frag";link.host="example.net";
if(link.getAttribute("href")!=="https://user:pw@example.net:8080/other?a=b#frag")fail("setters "+link.getAttribute("href"));
link.protocol="http";
if(link.href!=="http://user:pw@example.net:8080/other?a=b#frag"||String(link)!==link.href)fail("protocol "+link.href);
const spot=document.getElementById("spot");
if(spot.protocol!==":"||spot.host!==""||spot.origin!=="")fail("absent href");
spot.pathname="/ignored";
if(spot.hasAttribute("href"))fail("setter without href must not create one");
spot.href="sc://x/";spot.host="";
if(spot.href!=="sc:///")fail("non-special host "+spot.href);
console.log("hyperlink passed");
'], runtime, mut messages)
	assert messages == ['hyperlink passed']
}
