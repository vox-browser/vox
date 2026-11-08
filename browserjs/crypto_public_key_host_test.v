module browserjs

import dom
import html
import webcrypto

fn public_key_host_fixture() !(&Runtime, &CryptoHost) {
	url := dom.URL{ value: 'https://public-key-binding.test/' }
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() })!
	host.install(mut runtime)!
	return runtime, host
}

fn public_key_host_tasks(owner &html.EventLoop) {
	mut loop := unsafe { &html.EventLoop(owner) }
	mut queue := loop.task_queue()
	for turn in 0 .. 1000 {
		if task := queue.dequeue() {
			assert task.source() in [.unspecified, .crypto]
			task.execute()
		}
		for _ in 0 .. 1000 {
			job := loop.dequeue_microtask() or { break }
			job.execute()
		}
		if queue.is_empty() { return }
		assert turn < 999
	}
}

fn test_native_get_public_key_retains_private_keys_copies_usages_and_settles_crypto_task() {
	$if !darwin { return }
	mut runtime, host := public_key_host_fixture()!
	defer { runtime.close() }
	mut loop := host.settings.responsible_event_loop()
	pause := loop.pause()
	defer { loop.unpause(pause) }
	generated := webcrypto.SubtleCrypto.create().generate_key(webcrypto.EcKeyGenParams{ name: 'ECDSA', named_curve: 'P-256' }, false, [.sign, .verify])!
	pair := generated.pair or { panic('missing generated pair') }
	wrapper := runtime.javascript_crypto_key(pair.private_key)!
	runtime.define_value_host_function('__privateKey', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	assert runtime.evaluate_host(r'
 globalThis.publicKeyResult=null;globalThis.publicKeyOrder=[];
 const descriptor=Object.getOwnPropertyDescriptor(SubtleCrypto.prototype,"getPublicKey");
 if(descriptor.value.length!==2||descriptor.value.name!=="getPublicKey"||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable)throw new Error("metadata");
 const usages={[Symbol.iterator](){publicKeyOrder.push("iterator");let n=0;return {next(){publicKeyOrder.push("next");return n++<2?{value:{toString(){publicKeyOrder.push("usage");return "verify"}},done:false}:{done:true}}}}};
 globalThis.publicKeyPromise=crypto.subtle.getPublicKey(__privateKey(),usages);publicKeyPromise.then(key=>publicKeyResult=key);
 publicKeyPromise instanceof Promise&&publicKeyResult===null&&publicKeyOrder.join(",")==="iterator,next,usage,next,usage,next"
 ')! == 'true'
	mut queue := loop.task_queue()
	work := queue.dequeue() or { panic('missing derivation work') }
	assert work.source() == .unspecified
	work.execute()
	settle := queue.dequeue() or { panic('missing derivation settlement') }
	assert settle.source() == .crypto
	assert runtime.evaluate_host('publicKeyResult===null')! == 'true'
	settle.execute()
	assert runtime.evaluate_host('publicKeyResult===null')! == 'true'
	public_key_host_tasks(loop)
	assert runtime.evaluate_host('publicKeyResult instanceof CryptoKey&&publicKeyResult.type==="public"&&publicKeyResult.extractable&&Object.isFrozen(publicKeyResult.usages)&&publicKeyResult.usages.join() === "verify"&&__privateKey().extractable===false')! == 'true'
}

fn test_native_get_public_key_rejects_conversion_errors_and_preserves_author_exceptions() {
	$if !darwin { return }
	mut runtime, host := public_key_host_fixture()!
	defer { runtime.close() }
	mut loop := host.settings.responsible_event_loop()
	pause := loop.pause()
	defer { loop.unpause(pause) }
	key := webcrypto.CryptoKey.create(.private_key, false, webcrypto.KeyAlgorithm{ name: 'Ed25519' }, [.sign], [])
	wrapper := runtime.javascript_crypto_key(key)!
	runtime.define_value_host_function('__privateKey', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	assert runtime.evaluate_host(r'
 globalThis.publicKeyFailures=[];globalThis.publicKeyMarker={};globalThis.publicKeyConverted=false;globalThis.publicKeyClosed=false;
 const usages={get [Symbol.iterator](){publicKeyConverted=true;throw publicKeyMarker}};
 const invalid={[Symbol.iterator](){return {next(){return {value:"not-a-usage",done:false}},return(){publicKeyClosed=true;return {done:true}}}}};
 const cases=[()=>crypto.subtle.getPublicKey(),()=>SubtleCrypto.prototype.getPublicKey.call({},__privateKey(),usages),()=>crypto.subtle.getPublicKey(Object.create(CryptoKey.prototype),usages),()=>crypto.subtle.getPublicKey(__privateKey(),usages),()=>crypto.subtle.getPublicKey(__privateKey(),null),()=>crypto.subtle.getPublicKey(__privateKey(),invalid)];
 for(const invoke of cases){let promise;try{promise=invoke()}catch(error){throw new Error("synchronous throw")};if(!(promise instanceof Promise))throw new Error("not promise");promise.catch(error=>publicKeyFailures.push(error))}
 publicKeyFailures.length===0&&publicKeyConverted&&!publicKeyClosed
 ')! == 'true'
	assert loop.task_queue().is_empty()
	public_key_host_tasks(loop)
	assert runtime.evaluate_host('publicKeyFailures.length===6&&publicKeyFailures[3]===publicKeyMarker&&publicKeyFailures.filter(e=>e instanceof TypeError).length===5')! == 'true'
}

fn test_native_get_public_key_type_and_usage_errors_arrive_after_deferred_work() {
	$if !darwin { return }
	mut runtime, host := public_key_host_fixture()!
	defer { runtime.close() }
	mut loop := host.settings.responsible_event_loop()
	pause := loop.pause()
	defer { loop.unpause(pause) }
	assert runtime.evaluate_host(r'
 globalThis.publicKeyOutcomes=[];
 crypto.subtle.generateKey({name:"ECDSA",namedCurve:"P-256"},false,["sign","verify"]).then(async pair=>{
  for(const [key,usages] of [[pair.publicKey,["verify"]],[pair.privateKey,["sign"]]])try{await crypto.subtle.getPublicKey(key,usages);publicKeyOutcomes.push("accepted")}catch(e){publicKeyOutcomes.push(e.name)}
  const first=await crypto.subtle.getPublicKey(pair.privateKey,[]),second=await crypto.subtle.getPublicKey(pair.privateKey,[]);
  publicKeyOutcomes.push(first!==second&&first.usages.length===0&&second.usages.length===0);
 });true
 ')! == 'true'
	public_key_host_tasks(loop)
	assert runtime.evaluate_host('JSON.stringify(publicKeyOutcomes)')! == '["InvalidAccessError","SyntaxError",true]'
}
