// The isolated realm needs these Web APIs for some filter operations. Keep the
// original pinned polyfill bundle, loading it before the first property read.
export function base64Stub() {
    return `const pending=new Map();
function load(){
    for(const [name,get] of pending){
        const descriptor=Object.getOwnPropertyDescriptor(globalThis,name);
        if(descriptor?.get===get)delete globalThis[name];
    }
    pending.clear();
    globalThis.voxAdblockLoadBase64();
}
for(const name of ['atob','btoa','DOMException']){
    if(typeof globalThis[name]!=='undefined')continue;
    const get=()=>{load();return globalThis[name];};
    pending.set(name,get);
    Object.defineProperty(globalThis,name,{configurable:true,enumerable:name!=='DOMException',get,
        set(value){load();Object.defineProperty(globalThis,name,
            {configurable:true,writable:true,enumerable:name!=='DOMException',value});}});
}`;
}
