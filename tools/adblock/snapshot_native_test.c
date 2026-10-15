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
static unsigned char valid[] = {
    'V','O','X','S','N','A','P','1',4,0,0,0,0xcd,0xfb,0x3c,0xb6,1,2,3,4
};
int main(void) {
    JSGlobalContextRef ctx = JSGlobalContextCreate(NULL);
    assert(vox_adblock_install_snapshot(NULL, valid, sizeof valid) == 1);
    assert(vox_adblock_install_snapshot(ctx, NULL, sizeof valid) == 1);
    assert(vox_adblock_install_snapshot(ctx, valid, 0) == 1);
    assert(vox_adblock_install_snapshot(ctx, valid, sizeof valid - 1) == 2);
    unsigned char corrupt[sizeof valid];
    memcpy(corrupt,valid,sizeof valid);corrupt[16]^=1;
    assert(vox_adblock_install_snapshot(ctx, corrupt, sizeof corrupt) == 4);
    assert(released_buffers==0);
    memcpy(corrupt,valid,sizeof valid);corrupt[0]^=1;
    assert(vox_adblock_install_snapshot(ctx, corrupt, sizeof corrupt) == 2);
    memcpy(corrupt,valid,sizeof valid);corrupt[11]=0xff;
    assert(vox_adblock_install_snapshot(ctx, corrupt, sizeof corrupt) == 2);
    unsigned char trailing[sizeof valid + 1];memcpy(trailing,valid,sizeof valid);trailing[sizeof valid]=0;
    assert(vox_adblock_install_snapshot(ctx, trailing, sizeof trailing) == 2);
    assert(vox_adblock_install_snapshot(ctx, valid, sizeof valid) == 0);
    valid[16]=99; // The live array must own an independent mutable copy.
    assert(released_buffers==0);
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
    assert(released_buffers==1);
    puts("PASS native snapshot raw bounds/magic/CRC rejection, independent content, GC retention, release ownership, and native/JS checksum equality");
}
