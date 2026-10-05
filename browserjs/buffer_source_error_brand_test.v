module browserjs

import dom
import html

fn test_native_buffer_copy_detachment_does_not_invoke_author_type_error_has_instance() {
	$if !darwin { return }
	address := dom.URL{
		value: 'https://buffer-copy-brand.example.test/'
	}
	document := &dom.Document{
		url:     address
		origin_: address.origin()
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut crypto := CryptoHost.create(document)!
	crypto.install(mut runtime)!
	mut loop := crypto.settings.responsible_event_loop()
	pause := loop.pause()
	defer { loop.unpause(pause) }
	runtime.evaluate_host(r'
 globalThis.brandReads=0;globalThis.brandResults=[];globalThis.brandFailures=[];
 Object.defineProperty(TypeError,Symbol.hasInstance,{value(){brandReads++;throw "author error-brand hook"},configurable:true});
 for(const make of [buffer=>buffer,buffer=>new Uint8Array(buffer),buffer=>new DataView(buffer)]){
  const backing=new ArrayBuffer(4),input=make(backing);backing.transfer();
  crypto.subtle.digest("SHA-256",input).then(value=>brandResults.push(Array.from(new Uint8Array(value),byte=>byte.toString(16).padStart(2,"0")).join("")),reason=>brandFailures.push(reason));
 }
 ')!
	for _ in 0 .. 100 {
		mut queue := loop.task_queue()
		task := queue.dequeue() or { break }
		task.execute()
	}
	for _ in 0 .. 100 {
		job := loop.dequeue_microtask() or { break }
		job.execute()
	}
	assert runtime.evaluate_host('brandReads')! == '0'
	assert runtime.evaluate_host('brandFailures.length===0&&brandResults.length===3&&brandResults.every(hash=>hash==="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")')! == 'true'
}
