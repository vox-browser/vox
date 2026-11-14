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
static void check(JSGlobalContextRef context,const char *script) {
    JSStringRef source=JSStringCreateWithUTF8CString(script);JSValueRef exception=NULL;
    JSValueRef value=JSEvaluateScript(context,source,NULL,NULL,1,&exception);
    if(exception){JSStringRef text=JSValueToStringCopy(context,exception,NULL);char error[1024];JSStringGetUTF8CString(text,error,sizeof error);fprintf(stderr,"%s\n",error);JSStringRelease(text);}
    assert(!exception&&JSValueToBoolean(context,value));JSStringRelease(source);
}
int main(void) {
    // The installer receives JSON that V has already inflated and checked
    // (adblock/snapshot_jsc.c.v), so it allocates only the per-context record.
    const char *json="{\"nested\":{\"text\":\"\\u0000\\ufeff\\ud83d\\ude00\\ud800\"},\"array\":[1,2]}";
    unsigned char text[2048];size_t length=strlen(json);memcpy(text,json,length);
    JSGlobalContextRef first=JSGlobalContextCreate(NULL),second=JSGlobalContextCreate(NULL);
    assert(vox_adblock_install_snapshot_metadata(NULL,text,length)==1);
    assert(vox_adblock_install_snapshot_metadata(first,NULL,length)==1);
    assert(vox_adblock_install_snapshot_metadata(first,text,0)==2);
    assert(vox_adblock_install_snapshot_metadata(first,text,128*1024*1024+1)==2);
    assert(released_allocations==0);
    assert(vox_adblock_install_snapshot_metadata(first,text,length)==0);
    assert(vox_adblock_install_snapshot_metadata(second,text,length)==0);
    assert(released_allocations==0);
    memset(text,0,length); // Each context owns text independently of input.
    check(first,"(()=>{const a=voxAdblockReadSnapshotMetadata();const s=a.nested.text;if(s.length!==5||s.charCodeAt(0)!==0||s.charCodeAt(1)!==65279||s.charCodeAt(2)!==55357||s.charCodeAt(3)!==56832||s.charCodeAt(4)!==55296)return false;a.nested.text='changed';a.array.push(3);const b=voxAdblockReadSnapshotMetadata();return b!==a&&b.nested!==a.nested&&b.array!==a.array&&b.array.length===2&&b.nested.text.length===5&&delete globalThis.voxAdblockReadSnapshotMetadata===false;})()");
    JSGarbageCollect(first);
    check(first,"voxAdblockReadSnapshotMetadata().array.length===2");
    assert(released_allocations==0);
    JSGlobalContextRelease(first);
    assert(released_allocations==1);
    check(second,"voxAdblockReadSnapshotMetadata().nested.text.charCodeAt(1)===65279");
    JSGlobalContextRelease(second);
    assert(released_allocations==2);
    JSGlobalContextRef invalid=JSGlobalContextCreate(NULL);
    assert(vox_adblock_install_snapshot_metadata(invalid,(const unsigned char *)"not JSON",8)==0);
    check(invalid,"(()=>{try{voxAdblockReadSnapshotMetadata();return false;}catch(error){return /Invalid bundled snapshot metadata JSON/.test(String(error));}})()");
    JSGlobalContextRelease(invalid);
    assert(released_allocations==3);
    invalid=JSGlobalContextCreate(NULL);
    assert(vox_adblock_install_snapshot_metadata(invalid,(const unsigned char *)"{\"bad\":\"\xff\"}",12)==5);
    JSGlobalContextRelease(invalid);
    assert(released_allocations==3);
    puts("PASS native snapshot metadata bounds/ASCII rejection, Unicode/BOM/NUL/surrogate fidelity, fresh graphs, per-context ownership, GC retention and finalization");
}
