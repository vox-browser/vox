module browserjs

import dom
import html

fn test_native_supports_static_overloads_and_conversion_boundaries() {
 $if !darwin { return }
 url := dom.URL{value:'https://supports-binding.test/'}
 mut runtime := Runtime.create()
 defer { runtime.close() }
 mut host := CryptoHost.create(&dom.Document{url:url,origin_:url.origin()})!
 host.install(mut runtime)!
 assert runtime.evaluate_host(r'
 const d=Object.getOwnPropertyDescriptor(SubtleCrypto,"supports");
 if(d.value.length!==2||d.value.name!=="supports"||!d.writable||!d.enumerable||!d.configurable||"supports" in crypto.subtle)throw new Error("metadata");
 let errors=0;for(const invoke of [()=>SubtleCrypto.supports(),()=>SubtleCrypto.supports("digest"),()=>SubtleCrypto.supports(Symbol(),"SHA-256"),()=>SubtleCrypto.supports("deriveBits","HKDF",Infinity),()=>SubtleCrypto.supports("deriveBits","HKDF",-1)])try{invoke()}catch(e){if(e instanceof TypeError)errors++}
 let order=[];const marker={};const result=SubtleCrypto.supports.call(null,{toString(){order.push("operation");return "generateKey"}},{get name(){order.push("name");return "AES-GCM"},get length(){order.push("length");return 128}});
 const swallowed=SubtleCrypto.supports("digest",{get name(){throw marker}})===false;
 errors===5&&result&&swallowed&&order.join() === "operation,name,length"&&SubtleCrypto.supports("digest","sHa-256")&&!SubtleCrypto.supports("GENERATEKEY","AES-GCM")
 ')! == 'true'
 assert host.settings.responsible_event_loop().task_queue().is_empty()
}

fn test_native_supports_additional_algorithm_is_normalized_in_source_order() {
 $if !darwin { return }
 url := dom.URL{value:'https://supports-order.test/'}
 mut runtime := Runtime.create()
 defer { runtime.close() }
 mut host := CryptoHost.create(&dom.Document{url:url,origin_:url.origin()})!
 host.install(mut runtime)!
 assert runtime.evaluate_host(r'
 let reads=0;const additional={get name(){reads++;if(reads===3)throw new Error("third normalization");return "HMAC"},hash:"SHA-256"};
 const rejected=SubtleCrypto.supports("deriveKey",{name:"HKDF",hash:"SHA-256",salt:new Uint8Array(),info:new Uint8Array()},additional)===false;
 rejected&&reads===3&&SubtleCrypto.supports("wrapKey","AES-KW","AES-GCM")&&!SubtleCrypto.supports("wrapKey","AES-KW","HKDF")&&SubtleCrypto.supports("encapsulateKey","ML-KEM-768",{name:"AES-GCM",length:256})&&!SubtleCrypto.supports("encapsulateKey","ML-KEM-768",{name:"HMAC",hash:"SHA-256",length:128})
 ')! == 'true'
 assert host.settings.responsible_event_loop().task_queue().is_empty()
}
