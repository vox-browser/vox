#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../../adblock/snapshot.h"

int main(void) {
    static const unsigned char embedded[128 * 1024] = {1, 2, 3};
    void *embedded_owner = NULL;
    unsigned char *embedded_copy = vox_adblock_copy_snapshot(embedded, sizeof embedded, &embedded_owner);
    assert(embedded_copy && embedded_owner);
    embedded_copy[0] = 9;
    assert(embedded[0] == 1 && embedded_copy[0] == 9);
    vox_adblock_release_snapshot(embedded_copy, embedded_owner);
    size_t size = 1024 * 1024 + 123;
    unsigned char *source = malloc(size + 17);
    assert(source);
    unsigned char *payload = source + 17;
    for (size_t i = 0; i < size; ++i) payload[i] = (unsigned char)(i * 13);
    void *first_owner = NULL, *second_owner = NULL;
    unsigned char *first = vox_adblock_copy_snapshot(payload, size, &first_owner);
    unsigned char *second = vox_adblock_copy_snapshot(payload, size, &second_owner);
    assert(first && second && first_owner && second_owner);
    assert(!memcmp(first, payload, size) && !memcmp(second, payload, size));
    payload[0] = 99;
    first[1] = 77;
    first[size - 1] = 55;
    assert(first[0] == 0 && second[0] == 0);
    assert(payload[1] == 13 && second[1] == 13);
    free(source);
    assert(first[size - 1] == 55);
    assert(second[size - 1] == (unsigned char)((size - 1) * 13));
    vox_adblock_release_snapshot(first, first_owner);
    second[1234] = 42;
    assert(second[1234] == 42);
    vox_adblock_release_snapshot(second, second_owner);

    unsigned char tiny[] = {1, 2, 3};
    void *tiny_owner = (void *)1;
    unsigned char *copy = vox_adblock_copy_snapshot(tiny, sizeof tiny, &tiny_owner);
    assert(copy && !tiny_owner && !memcmp(copy, tiny, sizeof tiny));
    tiny[0] = 9;
    assert(copy[0] == 1);
    vox_adblock_release_snapshot(copy, tiny_owner);

    unsigned char *envelope = malloc(size + 16);
    assert(envelope);
    memcpy(envelope, "VOXSNAP1", 8);
    uint32_t payload_size = (uint32_t)size;
    memcpy(envelope + 8, &payload_size, 4);
    for (size_t i = 0; i < size; ++i) envelope[i + 16] = (unsigned char)(i * 13);
    uint32_t checksum = vox_crc32(0, envelope + 16, size);
    memcpy(envelope + 12, &checksum, 4);
    JSGlobalContextRef contexts[] = {JSGlobalContextCreate(NULL), JSGlobalContextCreate(NULL)};
    unsigned char *views[2];
    JSStringRef key = JSStringCreateWithUTF8CString("voxAdblockSnapshotBytes");
    for (int i = 0; i < 2; ++i) {
        assert(vox_adblock_install_snapshot(contexts[i], envelope, size + 16) == 0);
        JSObjectRef view = JSValueToObject(contexts[i], JSObjectGetProperty(contexts[i],
            JSContextGetGlobalObject(contexts[i]), key, NULL), NULL);
        assert(JSObjectGetTypedArrayByteLength(contexts[i], view, NULL) == size);
        views[i] = JSObjectGetTypedArrayBytesPtr(contexts[i], view, NULL);
    }
    char filename[] = "/tmp/vox-snapshot-file.XXXXXX";
    int fd = mkstemp(filename);
    assert(fd >= 0);
    FILE *file = fdopen(fd, "wb");
    assert(file && fwrite(envelope, 1, size + 16, file) == size + 16);
    assert(!fclose(file));
    JSGlobalContextRef file_context = JSGlobalContextCreate(NULL);
    assert(vox_adblock_install_snapshot_file(NULL, filename) == 1);
    assert(vox_adblock_install_snapshot_file(file_context, "/vox-missing-snapshot.bin") == 1);
    assert(vox_adblock_install_snapshot_file(file_context, filename) == 0);
    JSObjectRef file_view = JSValueToObject(file_context, JSObjectGetProperty(file_context,
        JSContextGetGlobalObject(file_context), key, NULL), NULL);
    unsigned char *file_bytes = JSObjectGetTypedArrayBytesPtr(file_context, file_view, NULL);
    assert(!unlink(filename));
    // Atomic resource replacement must leave an already-running context intact.
    file = fopen(filename, "wb");
    assert(file);
    envelope[16] ^= 1;
    assert(fwrite(envelope, 1, size + 16, file) == size + 16 && !fclose(file));
    assert(vox_adblock_install_snapshot_file(file_context, filename) == 4);
    envelope[16] ^= 1;
    assert(!unlink(filename));
    JSGarbageCollect(file_context);
    assert(file_bytes[0] == 0 && file_bytes[size - 1] == (unsigned char)((size - 1) * 13));
    file_bytes[0] = 88;
    assert(views[0][0] == 0);
    JSGlobalContextRelease(file_context);
    JSStringRef script = JSStringCreateWithUTF8CString(
        "(()=>{for(const Type of [Uint8Array,Uint32Array,Int32Array])for(const n of [0,1,65537]){"
        "const source=new Type(n+2);for(let i=0;i<source.length;i++)source[i]=i*13;"
        "const view=source.subarray(1,n+1),copy=voxAdblockCloneSnapshotView(view);"
        "if(!(copy instanceof Type)||copy.length!==n||copy.byteOffset!==0)throw Error('view shape');"
        "for(let i=0;i<n;i++)if(copy[i]!==view[i])throw Error('offset/content');"
        "if(n){const first=copy[0];source[1]=99;if(copy[0]!==first)throw Error('source alias');"
        "copy[n-1]=42;if(n>1&&source[n]===42)throw Error('clone alias');}}"
        "for(const invalid of [null,{},[],new Uint16Array(2)]){let threw=false;"
        "try{voxAdblockCloneSnapshotView(invalid)}catch{threw=true}if(!threw)throw Error('invalid input');}"
        "return delete globalThis.voxAdblockCloneSnapshotView===false;})()");
    JSValueRef exception = NULL;
    JSValueRef result = JSEvaluateScript(contexts[0], script, NULL, NULL, 1, &exception);
    assert(!exception && JSValueToBoolean(contexts[0], result));
    JSStringRelease(script);
    envelope[16] = 99;
    free(envelope);
    views[0][1] = 77;
    JSGarbageCollect(contexts[0]);
    assert(views[0][0] == 0 && views[1][0] == 0 && views[1][1] == 13);
    JSGlobalContextRelease(contexts[0]);
    JSGarbageCollect(contexts[1]);
    assert(views[1][size - 1] == (unsigned char)((size - 1) * 13));
    JSGlobalContextRelease(contexts[1]);
    JSStringRelease(key);
    puts("PASS private snapshot mappings, unaligned bounds, independent mutations, source lifetime, release and small-buffer fallback");
}
