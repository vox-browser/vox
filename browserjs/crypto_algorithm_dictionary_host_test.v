// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html

fn test_native_string_algorithm_dictionary_preserves_source_ordinary_prototype_reads() {
	$if !darwin {
		return
	}
	url := dom.URL{'https://algorithm-dictionary.example/'}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() })!
	host.install(mut runtime)!
	mut owner := unsafe { &html.EventLoop(host.settings.responsible_event_loop()) }
	pause := owner.pause()
	defer { owner.unpause(pause) }
	assert runtime.evaluate_host(r'(function(){
 globalThis.algorithmPrototypeOrder=[];globalThis.algorithmPrototypeResult=null;globalThis.algorithmPrototypeMarker={original:true};globalThis.algorithmPrototypeFailure=null;
 const define=Object.defineProperty;define(Object.prototype,"name",{get(){throw algorithmPrototypeMarker},set(){throw "author name setter"},configurable:true});
 define(Object.prototype,"outputLength",{get(){algorithmPrototypeOrder.push("length");return 256.9},configurable:true});
 define(Object.prototype,"functionName",{get(){algorithmPrototypeOrder.push("function");return new Uint8Array()},configurable:true});
 define(Object.prototype,"customization",{get(){algorithmPrototypeOrder.push("customization");return new ArrayBuffer(0)},configurable:true});
 try{crypto.subtle.digest("cSHAKE128",new Uint8Array()).then(buffer=>algorithmPrototypeResult=buffer);crypto.subtle.digest({},new Uint8Array()).catch(reason=>algorithmPrototypeFailure=reason)}finally{delete Object.prototype.name;delete Object.prototype.outputLength;delete Object.prototype.functionName;delete Object.prototype.customization}
 return algorithmPrototypeOrder.join(",")==="length,function,customization"&&algorithmPrototypeResult===null&&algorithmPrototypeFailure===null;
 })()')! == 'true'
	mut queue := owner.task_queue()
	for _ in 0 .. 20 {
		task := queue.dequeue() or { break }
		task.execute()
	}
	for _ in 0 .. 20 {
		job := owner.dequeue_microtask() or { break }
		job.execute()
	}
	assert runtime.evaluate_host('algorithmPrototypeFailure===algorithmPrototypeMarker&&algorithmPrototypeResult instanceof ArrayBuffer&&Array.from(new Uint8Array(algorithmPrototypeResult),byte=>byte.toString(16).padStart(2,"0")).join("")==="7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26"')! == 'true'
}
