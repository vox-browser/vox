#ifndef VOX_ADBLOCK_SNAPSHOT_H
#define VOX_ADBLOCK_SNAPSHOT_H
#include <JavaScriptCore/JavaScriptCore.h>
#include <stdlib.h>
#include <stdint.h>
#include "runtime.h"

static JSValueRef vox_adblock_snapshot_error(JSContextRef context,
        const char *text, JSValueRef *exception) {
    JSStringRef message = JSStringCreateWithUTF8CString(text);
    JSValueRef argument = JSValueMakeString(context, message);
    JSStringRelease(message);
    JSObjectRef error = JSObjectMakeError(context, 1, &argument, NULL);
    if (exception) *exception = error;
    return JSValueMakeUndefined(context);
}

// Same signed 32-bit djb2/xor hash as uBO's i32Checksum. The original
// JS fallback remains in the bundle; this host callback validates every word.
static JSValueRef vox_adblock_trie_checksum(JSContextRef context,
        JSObjectRef function, JSObjectRef self, size_t count,
        const JSValueRef arguments[], JSValueRef *exception) {
    (void)function; (void)self;
    if (count != 1 || JSValueGetTypedArrayType(context, arguments[0], exception)
            != kJSTypedArrayTypeUint32Array) {
        return vox_adblock_snapshot_error(context, "Expected a Uint32Array trie", exception);
    }
    JSObjectRef array = (JSObjectRef)arguments[0];
    size_t length = JSObjectGetTypedArrayLength(context, array, exception);
    if (exception && *exception) return JSValueMakeUndefined(context);
    size_t offset = JSObjectGetTypedArrayByteOffset(context, array, exception);
    if (exception && *exception) return JSValueMakeUndefined(context);
    const unsigned char *base = JSObjectGetTypedArrayBytesPtr(context, array, exception);
    if (exception && *exception) return JSValueMakeUndefined(context);
    if (length && !base) return vox_adblock_snapshot_error(context, "Missing Uint32Array trie bytes", exception);
    const uint32_t *words = length ? (const uint32_t *)(base + offset) : NULL;
    uint32_t hash = 177573u ^ (uint32_t)length;
    for (size_t index = 0; index < length; ++index) hash = hash * 33u ^ words[index];
    return JSValueMakeNumber(context, (int32_t)hash);
}

// The ArrayBuffer owns this malloc allocation until its last JS view dies.
static void vox_adblock_release_snapshot(void *bytes, void *context) {
    (void)context;
    free(bytes);
}

static int vox_adblock_install_snapshot(JSGlobalContextRef context,
        const unsigned char *compressed, size_t compressed_size) {
    if (!context || compressed_size < 18) return 1;
    const unsigned char *size_bytes = compressed + compressed_size - 4;
    size_t size = (size_t)size_bytes[0] | ((size_t)size_bytes[1] << 8) |
        ((size_t)size_bytes[2] << 16) | ((size_t)size_bytes[3] << 24);
    if (!size || size > 128 * 1024 * 1024) return 2;
    void *bytes = malloc(size);
    if (!bytes) return 3;
    if (vox_adblock_gunzip(compressed, compressed_size, bytes, size) != Z_OK) {
        free(bytes);
        return 4;
    }
    JSValueRef exception = NULL;
    JSStringRef checksum_key = JSStringCreateWithUTF8CString("voxAdblockTrieChecksum");
    JSObjectRef checksum = JSObjectMakeFunctionWithCallback(context, checksum_key,
        vox_adblock_trie_checksum);
    JSValueProtect(context, checksum);
    JSObjectSetProperty(context, JSContextGetGlobalObject(context), checksum_key, checksum,
        kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontEnum |
        kJSPropertyAttributeDontDelete, &exception);
    JSStringRelease(checksum_key);
    JSValueUnprotect(context, checksum);
    if (exception) { free(bytes); return 5; }

    JSObjectRef view = JSObjectMakeTypedArrayWithBytesNoCopy(context,
        kJSTypedArrayTypeUint8Array, bytes, size,
        vox_adblock_release_snapshot, NULL, &exception);
    // JSC calls the deallocator on exception as well as on normal destruction.
    if (!view || exception) return 5;
    JSValueProtect(context, view);
    JSStringRef key = JSStringCreateWithUTF8CString("voxAdblockSnapshotBytes");
    JSObjectSetProperty(context, JSContextGetGlobalObject(context), key, view,
        kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontEnum |
        kJSPropertyAttributeDontDelete, &exception);
    JSStringRelease(key);
    JSValueUnprotect(context, view);
    return exception ? 6 : 0;
}
#endif
