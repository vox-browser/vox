#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <JavaScriptCore/JavaScriptCore.h>
#include "../../adblock/runtime.h"
static int released_buffers;
static void snapshot_test_free(void *bytes) {
    ++released_buffers;
    free(bytes);
}
#define free snapshot_test_free
#include "../../adblock/snapshot.h"
#undef free
static const unsigned char valid[] = {
    0x1f,0x8b,0x08,0,0,0,0,0,0x02,0x03,0x63,0x64,0x62,0x66,0x01,0,0xcd,0xfb,0x3c,0xb6,0x04,0,0,0
};
int main(void) {
    JSGlobalContextRef ctx = JSGlobalContextCreate(NULL);
    assert(vox_adblock_install_snapshot(NULL, valid, sizeof valid) == 1);
    assert(vox_adblock_install_snapshot(ctx, valid, 0) == 1);
    unsigned char corrupt[sizeof valid];
    memcpy(corrupt,valid,sizeof valid);corrupt[12]^=1;
    assert(vox_adblock_install_snapshot(ctx, corrupt, sizeof corrupt) == 4);
    assert(released_buffers==1);
    assert(vox_adblock_install_snapshot(ctx, valid, sizeof valid) == 0);
    assert(released_buffers==1);
    JSStringRef source=JSStringCreateWithUTF8CString("voxAdblockSnapshotBytes instanceof Uint8Array && voxAdblockSnapshotBytes.length===4 && voxAdblockSnapshotBytes[0]===1 && voxAdblockSnapshotBytes[3]===4");
    JSValueRef exception=NULL;
    assert(JSValueToBoolean(ctx,JSEvaluateScript(ctx,source,NULL,NULL,1,&exception)));
    assert(!exception);JSStringRelease(source);
    source=JSStringCreateWithUTF8CString("(()=>{const ref=a=>{let hash=177573^a.length;for(let i=0;i<a.length;i++)hash=(hash<<5)+hash^a[i];return hash;};let checks=0;let seed=123456789;for(const size of [0,1,2,3,31,256,4096]){const words=new Uint32Array(size+4);for(let i=0;i<words.length;i++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;words[i]=seed;}for(const array of [words,words.subarray(1,size+1),words.subarray(2,2),words.subarray(1,size+100),words.subarray(size+100,999999)]){if(voxAdblockTrieChecksum(array)!==ref(array))throw Error('checksum mismatch '+size+' offset '+array.byteOffset);checks++;}}for(const invalid of [null,[],{},new Uint8Array(4),new Int32Array(3)]){let threw=false;try{voxAdblockTrieChecksum(invalid)}catch{threw=true}if(!threw)throw Error('invalid checksum argument accepted');}const edges=new Uint32Array([0,0xffffffff,0x80000000,0x7fffffff]);if(voxAdblockTrieChecksum(edges)!==ref(edges))throw Error('boundary mismatch');return checks===35;})()");
    JSValueRef result=JSEvaluateScript(ctx,source,NULL,NULL,1,&exception);
    if(exception){JSStringRef error=JSValueToStringCopy(ctx,exception,NULL);char message[512];JSStringGetUTF8CString(error,message,sizeof message);fprintf(stderr,"%s\n",message);JSStringRelease(error);}
    assert(!exception);assert(JSValueToBoolean(ctx,result));JSStringRelease(source);
    JSGarbageCollect(ctx);
    source=JSStringCreateWithUTF8CString("voxAdblockSnapshotBytes[2]===3");
    assert(JSValueToBoolean(ctx,JSEvaluateScript(ctx,source,NULL,NULL,1,&exception)));
    assert(!exception);JSStringRelease(source);
    JSGlobalContextRelease(ctx);
    assert(released_buffers==2);
    puts("PASS native snapshot allocation, CRC rejection, content, GC retention, release ownership, and native/JS checksum equality");
}
