module main

import browserjs
import html

fn test_compact_xpath_evaluates_typed_results_and_expressions() {
	mut document := html.parse_document('<!doctype html><div id="root"><p class="a">one</p><p class="b">two</p></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const count=document.evaluate("count(//p)",document,null,XPathResult.NUMBER_TYPE,null);
if(!(count instanceof XPathResult)||count.resultType!==1||count.numberValue!==2)fail("number "+count.numberValue);
if(document.evaluate("string(//p[2])",document).stringValue!=="two")fail("string");
if(document.evaluate("//p[@class=\"a\"]",document,null,XPathResult.BOOLEAN_TYPE,null).booleanValue!==true)fail("boolean");
const nan=document.evaluate("number(\"x\")",document,null,XPathResult.NUMBER_TYPE,null);
if(!Number.isNaN(nan.numberValue))fail("NaN");
const snapshot=document.evaluate("//p",document,null,XPathResult.ORDERED_NODE_SNAPSHOT_TYPE,null);
if(snapshot.snapshotLength!==2||snapshot.snapshotItem(1).textContent!=="two"||snapshot.snapshotItem(5)!==null)fail("snapshot");
const iterator=document.evaluate("//p",document.getElementById("root"),null,XPathResult.ORDERED_NODE_ITERATOR_TYPE,null);
if(iterator.iterateNext().className!=="a"||iterator.iterateNext().className!=="b"||iterator.iterateNext()!==null)fail("iterator");
const first=document.evaluate("//p",document,null,XPathResult.FIRST_ORDERED_NODE_TYPE,null);
if(first.singleNodeValue.className!=="a")fail("first node");
let threw=false;try{first.numberValue;}catch(error){threw=error instanceof TypeError;}
if(!threw)fail("typed getter");
const stale=document.evaluate("//p",document,null,XPathResult.UNORDERED_NODE_ITERATOR_TYPE,null);
document.getElementById("root").appendChild(document.createElement("p"));
threw=false;try{stale.iterateNext();}catch(error){threw=error.name==="InvalidStateError";}
if(!threw||!stale.invalidIteratorState)fail("invalid iterator");
const expression=document.createExpression("count(//p)");
if(expression.evaluate(document,XPathResult.NUMBER_TYPE).numberValue!==3)fail("expression");
if(new XPathEvaluator().evaluate("count(//p)",document,null,XPathResult.NUMBER_TYPE,null).numberValue!==3)fail("evaluator");
threw=false;try{document.createExpression("//[");}catch(error){threw=error.name==="SyntaxError";}
if(!threw)fail("syntax error");
console.log("xpath passed");
'], runtime, mut messages)
	assert messages == ['xpath passed']
}
