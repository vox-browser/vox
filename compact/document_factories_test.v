module main

import browserjs
import html

fn test_compact_document_factories_create_native_documents_and_nodes() {
	mut document := html.parse_document('<!doctype html><div id="host"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const constructed=new Document();
if(!(constructed instanceof Document)||constructed instanceof HTMLDocument||constructed.nodeType!==9)fail("new Document");
if(constructed.contentType!=="application/xml"||constructed.childNodes.length!==0)fail("new Document state "+constructed.contentType);
const doctype=document.implementation.createDocumentType("html","-//W3C//DTD XHTML 1.0 Strict//EN","about:legacy-compat");
if(!(doctype instanceof DocumentType)||doctype.nodeType!==10||doctype.name!=="html"||doctype.publicId!=="-//W3C//DTD XHTML 1.0 Strict//EN"||doctype.systemId!=="about:legacy-compat")fail("doctype");
const xml=document.implementation.createDocument("http://www.w3.org/1999/xhtml","html",doctype);
if(!(xml instanceof XMLDocument)||xml.contentType!=="application/xhtml+xml"||xml.doctype!==doctype||xml.documentElement.localName!=="html")fail("createDocument");
const empty=document.implementation.createDocument(null,"",null);
if(empty.documentElement!==null||empty.childNodes.length!==0)fail("empty createDocument");
let threw=false;try{document.implementation.createDocument(null,"1bad");}catch(error){threw=error instanceof DOMException&&error.name==="InvalidCharacterError";}
if(!threw)fail("invalid qualified name");
const instruction=xml.createProcessingInstruction("target","data");
if(!(instruction instanceof ProcessingInstruction)||instruction.nodeType!==7||instruction.data!=="data")fail("processing instruction");
const section=xml.createCDATASection("cdata");
if(!(section instanceof CDATASection)||section.nodeType!==4||section.data!=="cdata")fail("cdata");
const parsed=new DOMParser().parseFromString("<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"foo\"><html xmlns=\"http://www.w3.org/1999/xhtml\"><body id=\"test\">&Aacute;&amp;</body></html>","application/xhtml+xml");
const body=parsed.getElementById("test");
if(!body||body.firstChild.nodeType!==3||body.firstChild.data!=="Á&")fail("DOMParser xhtml "+(body&&body.firstChild&&body.firstChild.data));
const html=new DOMParser().parseFromString("<p id=x>hi</p>","text/html");
if(html.getElementById("x").textContent!=="hi"||html.body.firstChild.localName!=="p")fail("DOMParser html");
threw=false;try{new DOMParser().parseFromString("","text/plain");}catch(error){threw=error instanceof TypeError;}
if(!threw)fail("DOMParser type");
const tree=document.implementation.createDocument(null,"",null);
const root=tree.createElementNS("urn:test","root");
if(tree.appendChild(root)!==root||tree.documentElement!==root||!tree.hasChildNodes())fail("document appendChild");
const comment=tree.createComment("c");
if(tree.insertBefore(comment,root)!==comment||tree.firstChild!==comment)fail("document insertBefore");
if(tree.removeChild(comment)!==comment||tree.firstChild!==root||tree.childNodes.length!==1)fail("document removeChild");
threw=false;try{tree.removeChild(comment);}catch(error){threw=error instanceof DOMException&&error.name==="NotFoundError";}
if(!threw)fail("document removeChild missing child");
console.log("factories passed");
'], runtime, mut messages)
	assert messages == ['factories passed']
}
