#ifndef VOX_ADBLOCK_SNAPSHOT_H
#define VOX_ADBLOCK_SNAPSHOT_H
#include <JavaScriptCore/JavaScript.h>
#include <stdlib.h>
#include <stdint.h>
#ifdef __APPLE__
#include <mach/mach.h>
#include <mach/mach_vm.h>
#endif
#include <fcntl.h>
#ifdef _WIN32
#include "../platform/windows_path.h"
#endif
#ifndef _WIN32
#include <sys/mman.h>
#endif
#include <sys/stat.h>
#include <unistd.h>
#include "runtime.h"
#include "../native/include/native_crc32.h"

static JSValueRef vox_adblock_snapshot_error(JSContextRef context,
        const char *text, JSValueRef *exception) {
    JSStringRef message = JSStringCreateWithUTF8CString(text);
    JSValueRef argument = JSValueMakeString(context, message);
    JSStringRelease(message);
    JSObjectRef error = JSObjectMakeError(context, 1, &argument, NULL);
    if (exception) *exception = error;
    return JSValueMakeUndefined(context);
}

#include "snapshot_packed.h"

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
    // The recurrence is serial; unrolling only removes per-word loop overhead
    // and lets the compiler pair the loads (5 -> 3 instructions per word).
    size_t index = 0;
    for (; index + 8 <= length; index += 8) {
        const uint32_t *w = words + index;
        hash = hash * 33u ^ w[0]; hash = hash * 33u ^ w[1];
        hash = hash * 33u ^ w[2]; hash = hash * 33u ^ w[3];
        hash = hash * 33u ^ w[4]; hash = hash * 33u ^ w[5];
        hash = hash * 33u ^ w[6]; hash = hash * 33u ^ w[7];
    }
    for (; index < length; ++index) hash = hash * 33u ^ words[index];
    return JSValueMakeNumber(context, (int32_t)hash);
}

// The ArrayBuffer owns this private mapping or malloc allocation until its last
// JS view dies. A non-null owner records the rounded mapping length.
static void vox_adblock_release_snapshot(void *bytes, void *context) {
    if (context) {
#ifdef __APPLE__
        mach_vm_address_t base = (mach_vm_address_t)(uintptr_t)bytes
            & ~((mach_vm_address_t)vm_page_size - 1);
        mach_vm_deallocate(mach_task_self(), base, (mach_vm_size_t)(uintptr_t)context);
#endif
    } else {
        free(bytes);
    }
}

// Large bundled snapshots can share their original clean pages until a caller
// writes. A private COW mapping still gives every context independent mutable
// bytes and remains valid after the source allocation is changed or released.
static void *vox_adblock_copy_snapshot(const void *source, size_t size, void **owner) {
    *owner = NULL;
#ifdef __APPLE__
    if (size >= 64 * 1024) {
        mach_vm_address_t address = (mach_vm_address_t)(uintptr_t)source;
        mach_vm_address_t base = address & ~((mach_vm_address_t)vm_page_size - 1);
        mach_vm_size_t offset = address - base;
        mach_vm_size_t length = (offset + size + vm_page_size - 1)
            & ~((mach_vm_size_t)vm_page_size - 1);
        mach_vm_address_t copy = 0;
        vm_prot_t current = 0, maximum = 0;
        kern_return_t status = mach_vm_remap(mach_task_self(), &copy, length, 0,
            VM_FLAGS_ANYWHERE, mach_task_self(), base, TRUE, &current, &maximum,
            VM_INHERIT_NONE);
        if (status == KERN_SUCCESS) {
            status = mach_vm_protect(mach_task_self(), copy, length, FALSE,
                VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
            if (status == KERN_SUCCESS) {
                *owner = (void *)(uintptr_t)length;
                return (void *)(uintptr_t)(copy + offset);
            }
            mach_vm_deallocate(mach_task_self(), copy, length);
        }
    }
#endif
    void *copy = malloc(size);
    if (copy) memcpy(copy, source, size);
    return copy;
}

static JSValueRef vox_adblock_clone_snapshot_view(JSContextRef context,
        JSObjectRef function, JSObjectRef this_object, size_t count,
        const JSValueRef arguments[], JSValueRef *exception) {
    (void)function; (void)this_object;
    if (count != 1 || !JSValueIsObject(context, arguments[0]))
        return vox_adblock_snapshot_error(context, "Expected a filter snapshot typed array", exception);
    JSTypedArrayType type = JSValueGetTypedArrayType(context, arguments[0], exception);
    if (exception && *exception) return JSValueMakeUndefined(context);
    if (type != kJSTypedArrayTypeUint8Array && type != kJSTypedArrayTypeUint32Array
        && type != kJSTypedArrayTypeInt32Array)
        return vox_adblock_snapshot_error(context, "Unsupported filter snapshot view", exception);
    JSObjectRef source = JSValueToObject(context, arguments[0], exception);
    size_t size = JSObjectGetTypedArrayByteLength(context, source, exception);
    if (exception && *exception) return JSValueMakeUndefined(context);
    if (size > 128 * 1024 * 1024)
        return vox_adblock_snapshot_error(context, "Filter snapshot view exceeds its limit", exception);
    if (!size) return JSObjectMakeTypedArray(context, type, 0, exception);
    size_t offset = JSObjectGetTypedArrayByteOffset(context, source, exception);
    if (exception && *exception) return JSValueMakeUndefined(context);
    const unsigned char *bytes = JSObjectGetTypedArrayBytesPtr(context, source, exception);
    if (exception && *exception) return JSValueMakeUndefined(context);
    if (!bytes) return vox_adblock_snapshot_error(context, "Missing filter snapshot bytes", exception);
    void *owner = NULL;
    void *copy = vox_adblock_copy_snapshot(bytes + offset, size, &owner);
    if (!copy) return vox_adblock_snapshot_error(context, "Cannot copy filter snapshot view", exception);
    // The callback also releases storage when JSC rejects the typed array.
    return JSObjectMakeTypedArrayWithBytesNoCopy(context, type, copy, size,
        vox_adblock_release_snapshot, owner, exception);
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
    if ((uint32_t)vox_crc32(0, payload, (uInt)size) != expected_crc) return 4;
    void *owner = NULL;
    void *bytes = vox_adblock_copy_snapshot(payload, size, &owner);
    if (!bytes) return 3;
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
    if (exception) { vox_adblock_release_snapshot(bytes, owner); return 5; }

    JSStringRef packed_key = JSStringCreateWithUTF8CString("voxAdblockReadPackedValue");
    JSObjectRef packed = JSObjectMakeFunctionWithCallback(context, packed_key,
        vox_adblock_read_packed_value);
    JSValueProtect(context, packed);
    JSObjectSetProperty(context, JSContextGetGlobalObject(context), packed_key, packed,
        kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontEnum |
        kJSPropertyAttributeDontDelete, &exception);
    JSStringRelease(packed_key);
    JSValueUnprotect(context, packed);
    if (exception) { vox_adblock_release_snapshot(bytes, owner); return 5; }
    if (getenv("VOX_DISABLE_LAZY_FILTER_TABLES")) {
        JSStringRef eager_key = JSStringCreateWithUTF8CString("voxAdblockEagerSnapshotTables");
        JSObjectSetProperty(context, JSContextGetGlobalObject(context), eager_key,
            JSValueMakeBoolean(context, true), kJSPropertyAttributeReadOnly |
            kJSPropertyAttributeDontEnum | kJSPropertyAttributeDontDelete, &exception);
        JSStringRelease(eager_key);
        if (exception) { vox_adblock_release_snapshot(bytes, owner); return 5; }
    }

    JSStringRef clone_key = JSStringCreateWithUTF8CString("voxAdblockCloneSnapshotView");
    JSObjectRef clone = JSObjectMakeFunctionWithCallback(context, clone_key,
        vox_adblock_clone_snapshot_view);
    JSValueProtect(context, clone);
    JSObjectSetProperty(context, JSContextGetGlobalObject(context), clone_key, clone,
        kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontEnum |
        kJSPropertyAttributeDontDelete, &exception);
    JSStringRelease(clone_key);
    JSValueUnprotect(context, clone);
    if (exception) { vox_adblock_release_snapshot(bytes, owner); return 5; }

    JSObjectRef view = JSObjectMakeTypedArrayWithBytesNoCopy(context,
        kJSTypedArrayTypeUint8Array, bytes, size,
        vox_adblock_release_snapshot, owner, &exception);
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

static int vox_adblock_install_snapshot_file(JSGlobalContextRef context, const char *path) {
    if (!context || !path) return 1;
#ifdef _WIN32
    // The installed ArrayBuffer owns a private copy, as with the mapped path.
    wchar_t *wide = vox_windows_wide_path(path);
    if (!wide) return 1;
    FILE *file = _wfopen(wide, L"rb");
    free(wide);
    if (!file) return 1;
    if (fseek(file, 0, SEEK_END)) { fclose(file); return 2; }
    long size = ftell(file);
    if (size < 16 || size > 128 * 1024 * 1024 + 16 || fseek(file, 0, SEEK_SET)) {
        fclose(file); return 2;
    }
    void *bytes = malloc((size_t)size);
    if (!bytes) { fclose(file); return 3; }
    size_t read_size = fread(bytes, 1, (size_t)size, file);
    fclose(file);
    int result = read_size == (size_t)size
        ? vox_adblock_install_snapshot(context, bytes, (size_t)size) : 3;
    free(bytes);
    return result;
#else
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return 1;
    struct stat info;
    if (fstat(fd, &info) || info.st_size < 16 || info.st_size > 128 * 1024 * 1024 + 16) {
        close(fd);
        return 2;
    }
    size_t size = (size_t)info.st_size;
    void *bytes = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (bytes == MAP_FAILED) return 3;
    int result = vox_adblock_install_snapshot(context, bytes, size);
    // The installed private mapping owns its pages independently of this view.
    munmap(bytes, size);
    return result;
#endif
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
    unsigned char *bytes = malloc(size + 1);
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
#ifdef __APPLE__
    CFStringRef text = CFStringCreateWithBytes(kCFAllocatorDefault, bytes,
        (CFIndex)size, kCFStringEncodingASCII, false);
    free(bytes);
    if (!text) return 5;
    JSStringRef json = JSStringCreateWithCFString(text);
    CFRelease(text);
#else
    bytes[size] = 0;
    JSStringRef json = JSStringCreateWithUTF8CString((const char *)bytes);
    free(bytes);
#endif
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
