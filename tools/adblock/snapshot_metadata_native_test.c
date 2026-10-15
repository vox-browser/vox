#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <JavaScriptCore/JavaScriptCore.h>
#include "../../adblock/runtime.h"
static int released_allocations;
static void metadata_test_free(void *bytes) { ++released_allocations; free(bytes); }
#define free metadata_test_free
#include "../../adblock/snapshot.h"
#undef free
static size_t compress_json(const char *text,unsigned char *output,size_t capacity) {
    z_stream stream={0};
    assert(deflateInit2(&stream,9,Z_DEFLATED,MAX_WBITS+16,8,Z_DEFAULT_STRATEGY)==Z_OK);
    stream.next_in=(Bytef *)text;stream.avail_in=(uInt)strlen(text);
    stream.next_out=output;stream.avail_out=(uInt)capacity;
    assert(deflate(&stream,Z_FINISH)==Z_STREAM_END);
    size_t length=stream.total_out;assert(deflateEnd(&stream)==Z_OK);return length;
}
static void check(JSGlobalContextRef context,const char *script) {
    JSStringRef source=JSStringCreateWithUTF8CString(script);JSValueRef exception=NULL;
    JSValueRef value=JSEvaluateScript(context,source,NULL,NULL,1,&exception);
    if(exception){JSStringRef text=JSValueToStringCopy(context,exception,NULL);char error[1024];JSStringGetUTF8CString(text,error,sizeof error);fprintf(stderr,"%s\n",error);JSStringRelease(text);}
    assert(!exception&&JSValueToBoolean(context,value));JSStringRelease(source);
}
int main(void) {
    const char *json="{\"nested\":{\"text\":\"\\u0000\\ufeff\\ud83d\\ude00\\ud800\"},\"array\":[1,2]}";
    unsigned char compressed[2048],corrupt[2048];size_t length=compress_json(json,compressed,sizeof compressed);
    JSGlobalContextRef first=JSGlobalContextCreate(NULL),second=JSGlobalContextCreate(NULL);
    assert(vox_adblock_install_snapshot_metadata(NULL,compressed,length)==1);
    assert(vox_adblock_install_snapshot_metadata(first,NULL,length)==1);
    assert(vox_adblock_install_snapshot_metadata(first,compressed,0)==1);
    memcpy(corrupt,compressed,length);corrupt[length-8]^=1;
    assert(vox_adblock_install_snapshot_metadata(first,corrupt,length)==4);
    assert(released_allocations==1);
    memcpy(corrupt,compressed,length);corrupt[length-1]=0xff;
    assert(vox_adblock_install_snapshot_metadata(first,corrupt,length)==2);
    assert(released_allocations==1);
    assert(vox_adblock_install_snapshot_metadata(first,compressed,length)==0);
    assert(vox_adblock_install_snapshot_metadata(second,compressed,length)==0);
    assert(released_allocations==3);
    memset(compressed,0,length); // Each context owns text independently of input.
    check(first,"(()=>{const a=voxAdblockReadSnapshotMetadata();const s=a.nested.text;if(s.length!==5||s.charCodeAt(0)!==0||s.charCodeAt(1)!==65279||s.charCodeAt(2)!==55357||s.charCodeAt(3)!==56832||s.charCodeAt(4)!==55296)return false;a.nested.text='changed';a.array.push(3);const b=voxAdblockReadSnapshotMetadata();return b!==a&&b.nested!==a.nested&&b.array!==a.array&&b.array.length===2&&b.nested.text.length===5&&delete globalThis.voxAdblockReadSnapshotMetadata===false;})()");
    JSGarbageCollect(first);
    check(first,"voxAdblockReadSnapshotMetadata().array.length===2");
    assert(released_allocations==3);
    JSGlobalContextRelease(first);
    assert(released_allocations==4);
    check(second,"voxAdblockReadSnapshotMetadata().nested.text.charCodeAt(1)===65279");
    JSGlobalContextRelease(second);
    assert(released_allocations==5);
    JSGlobalContextRef invalid=JSGlobalContextCreate(NULL);
    length=compress_json("not JSON",compressed,sizeof compressed);
    assert(vox_adblock_install_snapshot_metadata(invalid,compressed,length)==0);
    check(invalid,"(()=>{try{voxAdblockReadSnapshotMetadata();return false;}catch(error){return /Invalid bundled snapshot metadata JSON/.test(String(error));}})()");
    JSGlobalContextRelease(invalid);
    assert(released_allocations==7);
    length=compress_json("{\"bad\":\"\xff\"}",compressed,sizeof compressed);
    invalid=JSGlobalContextCreate(NULL);
    assert(vox_adblock_install_snapshot_metadata(invalid,compressed,length)==5);
    JSGlobalContextRelease(invalid);
    assert(released_allocations==8);
    puts("PASS native snapshot metadata CRC/bounds/ASCII rejection, Unicode/BOM/NUL/surrogate fidelity, fresh graphs, per-context ownership, GC retention and finalization");
}
