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
        const unsigned char *snapshot, size_t snapshot_size) {
    if (!context || !snapshot || snapshot_size < 16) return 1;
    if (memcmp(snapshot, "VOXSNAP1", 8)) return 2;
    const unsigned char *size_bytes = snapshot + 8;
    size_t size = (size_t)size_bytes[0] | ((size_t)size_bytes[1] << 8) |
        ((size_t)size_bytes[2] << 16) | ((size_t)size_bytes[3] << 24);
    if (!size || size > 128 * 1024 * 1024 || size != snapshot_size - 16) return 2;
    const unsigned char *crc_bytes = snapshot + 12;
    uint32_t expected_crc = (uint32_t)crc_bytes[0] | ((uint32_t)crc_bytes[1] << 8) |
        ((uint32_t)crc_bytes[2] << 16) | ((uint32_t)crc_bytes[3] << 24);
    const unsigned char *payload = snapshot + 16;
    if ((uint32_t)crc32(0, payload, (uInt)size) != expected_crc) return 4;
    void *bytes = malloc(size);
    if (!bytes) return 3;
    // The embedded payload remains immutable; each context owns its own copy.
    memcpy(bytes, payload, size);
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
// The callable owns immutable JSON text in its own context. Each invocation
// parses fresh objects, so default/custom/default reinitialization never shares
// a mutable restored graph with another engine or with an earlier restore.
struct vox_adblock_snapshot_metadata {
    JSStringRef text;
};

static void vox_adblock_release_snapshot_metadata(JSObjectRef object) {
    struct vox_adblock_snapshot_metadata *metadata = JSObjectGetPrivate(object);
    if (!metadata) return;
    if (metadata->text) JSStringRelease(metadata->text);
    free(metadata);
}

static JSValueRef vox_adblock_read_snapshot_metadata(JSContextRef context,
        JSObjectRef function, JSObjectRef self, size_t count,
        const JSValueRef arguments[], JSValueRef *exception) {
    (void)self; (void)count; (void)arguments;
    struct vox_adblock_snapshot_metadata *metadata = JSObjectGetPrivate(function);
    if (!metadata || !metadata->text)
        return vox_adblock_snapshot_error(context, "Missing bundled snapshot metadata", exception);
    JSValueRef value = JSValueMakeFromJSONString(context, metadata->text);
    if (!value)
        return vox_adblock_snapshot_error(context, "Invalid bundled snapshot metadata JSON", exception);
    return value;
}

static int vox_adblock_install_snapshot_metadata(JSGlobalContextRef context,
        const unsigned char *compressed, size_t compressed_size) {
    if (!context || !compressed || compressed_size < 18) return 1;
    const unsigned char *size_bytes = compressed + compressed_size - 4;
    size_t size = (size_t)size_bytes[0] | ((size_t)size_bytes[1] << 8) |
        ((size_t)size_bytes[2] << 16) | ((size_t)size_bytes[3] << 24);
    if (!size || size > 128 * 1024 * 1024) return 2;
    unsigned char *bytes = malloc(size);
    if (!bytes) return 3;
    if (vox_adblock_gunzip(compressed, compressed_size, bytes, size) != Z_OK) {
        free(bytes);
        return 4;
    }
    // Reject non-ASCII input explicitly: CoreFoundation's ASCII conversion can
    // accept high bytes on some system versions. Scan aligned-size chunks so
    // validating the generated multi-megabyte metadata remains inexpensive.
    size_t offset = 0;
    uint64_t high_bits = 0;
    while (size - offset >= sizeof(uint64_t)) {
        uint64_t word;
        memcpy(&word, bytes + offset, sizeof word);
        high_bits |= word;
        offset += sizeof word;
    }
    int ascii = !(high_bits & UINT64_C(0x8080808080808080));
    while (offset < size) ascii &= !(bytes[offset++] & 0x80);
    if (!ascii) { free(bytes); return 5; }
    // The generator emits ASCII JSON escapes, retaining Unicode/NUL/BOM values
    // while keeping CoreFoundation's conversion on its fast ASCII path.
    CFStringRef text = CFStringCreateWithBytes(kCFAllocatorDefault, bytes,
        (CFIndex)size, kCFStringEncodingASCII, false);
    free(bytes);
    if (!text) return 5;
    JSStringRef json = JSStringCreateWithCFString(text);
    CFRelease(text);
    if (!json) return 5;
    struct vox_adblock_snapshot_metadata *metadata = malloc(sizeof *metadata);
    if (!metadata) { JSStringRelease(json); return 3; }
    metadata->text = json;
    JSClassDefinition definition = kJSClassDefinitionEmpty;
    definition.className = "VoxAdblockSnapshotMetadata";
    definition.finalize = vox_adblock_release_snapshot_metadata;
    definition.callAsFunction = vox_adblock_read_snapshot_metadata;
    JSClassRef klass = JSClassCreate(&definition);
    JSObjectRef reader = JSObjectMake(context, klass, metadata);
    JSClassRelease(klass);
    if (!reader) { JSStringRelease(json); free(metadata); return 6; }
    JSValueProtect(context, reader);
    JSStringRef key = JSStringCreateWithUTF8CString("voxAdblockReadSnapshotMetadata");
    JSValueRef exception = NULL;
    JSObjectSetProperty(context, JSContextGetGlobalObject(context), key, reader,
        kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontEnum |
        kJSPropertyAttributeDontDelete, &exception);
    JSStringRelease(key);
    JSValueUnprotect(context, reader);
    return exception ? 6 : 0;
}
#endif
