module main

import browserjs
import dom
import html
import json2

struct BrowserStorageOperation {
	area  string
	op    string
	key   string
	value string
	index u32
}

struct BrowserStorageResult {
	value     ?string
	keys      []string
	length    int
	error     string
}

// Expose the owning WindowModel's native storage bottles before publisher
// scriptlets and page scripts execute. Storage contents stay in the translated
// HTML storage records, including their quota and origin/traversable ownership.
fn install_browser_page_storage(document &dom.Document, runtime &browserjs.Runtime) ! {
	if runtime.evaluate_host('typeof globalThis.__voxPageStorageInstalled === "boolean"')! == 'true' {
		return
	}
	if document.get_window() == none {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	window_pointer := document.get_window() or { return error('Web Storage requires its owning Window') }
	window := unsafe { &html.WindowModel(window_pointer) }
	mut mutable_runtime := unsafe { &browserjs.Runtime(runtime) }
	mutable_runtime.define_host_function('__voxNativePageStorage', fn [window, document] (input string) !string {
		operation := json2.decode[BrowserStorageOperation](input)!
		if document.origin().is_opaque() {
			return json2.encode(BrowserStorageResult{error: 'SecurityError: Storage is unavailable for an opaque origin'}, escape_unicode: true)
		}
		mut mutable_window := unsafe { &html.WindowModel(window) }
		mut storage := if operation.area == 'session' {
			mutable_window.session_storage()!
		} else {
			mutable_window.local_storage()!
		}
		match operation.op {
			'access' { return json2.encode(BrowserStorageResult{}, escape_unicode: true) }
			'get' {
				// Keep absent native entries distinct from stored empty strings.
				if operation.key !in storage.storage_bottle.entries {
					return json2.encode(BrowserStorageResult{}, escape_unicode: true)
				}
				return json2.encode(BrowserStorageResult{value: storage.get_item(operation.key)}, escape_unicode: true)
			}
			'key' { return json2.encode(BrowserStorageResult{value: storage.key(uint(operation.index))}, escape_unicode: true) }
			'keys' { return json2.encode(BrowserStorageResult{keys: storage.supported_property_names()}, escape_unicode: true) }
			'length' { return json2.encode(BrowserStorageResult{length: int(storage.length())}, escape_unicode: true) }
			'set' {
				storage.set_item(operation.key, operation.value) or {
					return json2.encode(BrowserStorageResult{error: err.msg()}, escape_unicode: true)
				}
			}
			'remove' { storage.remove_item(operation.key) }
			'clear' { storage.clear() }
			else { return error('Unknown native Storage operation') }
		}
		return json2.encode(BrowserStorageResult{}, escape_unicode: true)
	})!
	runtime.evaluate_host(browser_page_storage_binding)!
}

const browser_page_storage_binding = r'(function(){
    const native = globalThis.__voxNativePageStorage;
    const owners = new WeakMap();
    const convert = value => `${value}`;
    const operate = (area,op,key="",value="",index=0) => {
        const result = JSON.parse(native(JSON.stringify({area,op,key,value,index})));
        if(result.error){
            const split=result.error.indexOf(":");
            const name=split<0?"Error":result.error.slice(0,split);
            const message=split<0?result.error:result.error.slice(split+1).trim();
            if(typeof DOMException==="function")throw new DOMException(message,name);
            const error=new Error(message);error.name=name;throw error;
        }
        return result;
    };
    const owner = receiver => {
        const area=owners.get(receiver);
        if(!area)throw new TypeError("Illegal invocation");
        return area;
    };
    const required = (args,count) => {
        if(args.length<count)throw new TypeError("Not enough arguments");
    };
    class Storage {
        constructor(){throw new TypeError("Illegal constructor")}
        get length(){return operate(owner(this),"length").length}
        key(index){required(arguments,1);return operate(owner(this),"key","","",Number(index)>>>0).value??null}
        getItem(key){required(arguments,1);return operate(owner(this),"get",convert(key)).value??null}
        setItem(key,value){required(arguments,2);operate(owner(this),"set",convert(key),convert(value))}
        removeItem(key){required(arguments,1);operate(owner(this),"remove",convert(key))}
        clear(){operate(owner(this),"clear")}
    }
    Object.defineProperty(Storage.prototype,Symbol.toStringTag,{value:"Storage",configurable:true});
    for(const key of Object.getOwnPropertyNames(Storage.prototype)){
        if(key==="constructor")continue;
        Object.defineProperty(Storage.prototype,key,{...Object.getOwnPropertyDescriptor(Storage.prototype,key),enumerable:true});
    }
    const create = area => {
        const target=Object.create(Storage.prototype);
        owners.set(target,area);
        const named = key => typeof key==="string"&&!Reflect.has(target,key);
        const proxy=new Proxy(target,{
            get(target,key,receiver){
                if(!named(key))return Reflect.get(target,key,receiver);
                return operate(area,"get",key).value??undefined;
            },
            set(target,key,value,receiver){
                if(typeof key!=="string")return Reflect.set(target,key,value,target);
                operate(area,"set",key,convert(value));return true;
            },
            deleteProperty(target,key){
                if(typeof key!=="string")return Reflect.deleteProperty(target,key);
                operate(area,"remove",key);return true;
            },
            has(target,key){return Reflect.has(target,key)||(typeof key==="string"&&operate(area,"get",key).value!=null)},
            ownKeys(target){return [...new Set([...operate(area,"keys").keys,...Reflect.ownKeys(target)])]},
            getOwnPropertyDescriptor(target,key){
                const existing=Reflect.getOwnPropertyDescriptor(target,key);
                if(existing)return existing;
                if(named(key)){
                    const result=operate(area,"get",key);
                    if(result.value!=null)return {value:result.value,writable:true,enumerable:true,configurable:true};
                }
            },
            defineProperty(target,key,descriptor){
                if(typeof key!=="string")return Reflect.defineProperty(target,key,descriptor);
                if(!("value" in descriptor)||descriptor.get||descriptor.set)return false;
                operate(area,"set",key,convert(descriptor.value));return true;
            },
            preventExtensions(){return false},
        });
        owners.set(proxy,area);
        return proxy;
    };
    const local=create("local"),session=create("session");
    Object.defineProperty(globalThis,"Storage",{value:Storage,writable:true,configurable:true});
    Object.defineProperty(globalThis,"localStorage",{get(){operate("local","access");return local},enumerable:true,configurable:true});
    Object.defineProperty(globalThis,"sessionStorage",{get(){operate("session","access");return session},enumerable:true,configurable:true});
    Object.defineProperty(globalThis,"__voxPageStorageInstalled",{value:true});
})();'
