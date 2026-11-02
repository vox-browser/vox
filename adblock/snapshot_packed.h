#ifndef VOX_ADBLOCK_SNAPSHOT_PACKED_H
#define VOX_ADBLOCK_SNAPSHOT_PACKED_H
#include <math.h>

static uint32_t vox_adblock_packed_u32(const unsigned char *bytes) {
    return (uint32_t)bytes[0] | (uint32_t)bytes[1] << 8 |
        (uint32_t)bytes[2] << 16 | (uint32_t)bytes[3] << 24;
}

static JSValueRef vox_adblock_packed_entry(JSContextRef context,
        const unsigned char *bytes, size_t size, uint32_t count, uint32_t index,
        JSValueRef *exception) {
    if (index >= count) return vox_adblock_snapshot_error(context, "Packed table index out of bounds", exception);
    size_t start = vox_adblock_packed_u32(bytes + 8 + (size_t)index * 4);
    size_t end = vox_adblock_packed_u32(bytes + 12 + (size_t)index * 4);
    int array = vox_adblock_packed_u32(bytes) == 1;
    size_t header = array ? 12 + (size_t)count * 4 : 16 + (size_t)count * 12;
    if (!array) {
        size_t end_keys = vox_adblock_packed_u32(bytes + 12 + (size_t)count * 12);
        if (end_keys < header || end_keys > size)
            return vox_adblock_snapshot_error(context, "Invalid packed key storage", exception);
        header = end_keys;
    }
    if (start < header || start >= end || end > size)
        return vox_adblock_snapshot_error(context, "Invalid packed table entry bounds", exception);
    // JSON payloads include their own quotes/escapes. This preserves every
    // Unicode code unit, embedded NUL and leading BOM inside string values.
    char *text = malloc(end - start + 1);
    if (!text) return vox_adblock_snapshot_error(context, "Cannot read packed table entry", exception);
    memcpy(text, bytes + start, end - start); text[end - start] = 0;
    JSStringRef string = JSStringCreateWithUTF8CString(text);
    free(text);
    JSValueRef result = string ? JSValueMakeFromJSONString(context, string) : NULL;
    if (string) JSStringRelease(string);
    return result ? result : vox_adblock_snapshot_error(context, "Invalid packed table JSON", exception);
}

static int vox_adblock_packed_string_compare(const unsigned char *a, size_t an, JSStringRef b) {
    size_t bn = JSStringGetLength(b), n = an < bn ? an : bn;
    const JSChar *bp = JSStringGetCharactersPtr(b);
    for (size_t index = 0; index < n; ++index) {
        unsigned value = a[index * 2] | (unsigned)a[index * 2 + 1] << 8;
        if (value != bp[index]) return value < bp[index] ? -1 : 1;
    }
    return an < bn ? -1 : an > bn ? 1 : 0;
}

static JSValueRef vox_adblock_read_packed_value(JSContextRef context,
        JSObjectRef function, JSObjectRef self, size_t argc,
        const JSValueRef arguments[], JSValueRef *exception) {
    (void)function; (void)self;
    if ((argc != 2 && argc != 3) || JSValueGetTypedArrayType(context, arguments[0], exception)
            != kJSTypedArrayTypeUint8Array)
        return vox_adblock_snapshot_error(context, "Expected packed lookup bytes and key", exception);
    JSObjectRef object = (JSObjectRef)arguments[0];
    size_t size = JSObjectGetTypedArrayByteLength(context, object, exception);
    size_t offset = JSObjectGetTypedArrayByteOffset(context, object, exception);
    const unsigned char *base = JSObjectGetTypedArrayBytesPtr(context, object, exception);
    if ((exception && *exception) || !base || size < 12 || size > 128 * 1024 * 1024)
        return vox_adblock_snapshot_error(context, "Invalid packed lookup storage", exception);
    const unsigned char *bytes = base + offset;
    uint32_t kind = vox_adblock_packed_u32(bytes), count = vox_adblock_packed_u32(bytes + 4);
    if (kind < 1 || kind > 3 || (kind != 1 && size < 16)
        || count > (size - (kind == 1 ? 12 : 16)) / (kind == 1 ? 4 : 12))
        return vox_adblock_snapshot_error(context, "Invalid packed lookup header", exception);
    int indexed = kind == 1 || (argc == 3 && JSValueToBoolean(context, arguments[2]));
    if (indexed) {
        if (!JSValueIsNumber(context, arguments[1])) return JSValueMakeUndefined(context);
        double index = JSValueToNumber(context, arguments[1], exception);
        if (!isfinite(index) || index < 0 || index >= count || floor(index) != index)
            return JSValueMakeUndefined(context);
        return vox_adblock_packed_entry(context, bytes, size, count, (uint32_t)index, exception);
    }
    if ((kind == 2 && !JSValueIsString(context, arguments[1]))
        || (kind == 3 && !JSValueIsNumber(context, arguments[1]))) return JSValueMakeUndefined(context);
    double number = kind == 3 ? JSValueToNumber(context, arguments[1], exception) : 0;
    if (kind == 3 && (!isfinite(number) || number < 0 || floor(number) != number || number > 9007199254740991.0))
        return JSValueMakeUndefined(context);
    JSStringRef key = kind == 2 ? JSValueToStringCopy(context, arguments[1], exception) : NULL;
    uint32_t low = 0, high = count;
    JSValueRef result = JSValueMakeUndefined(context);
    while (low < high && !(exception && *exception)) {
        uint32_t mid = low + (high - low) / 2;
        uint32_t index = vox_adblock_packed_u32(bytes + 12 + (size_t)count * 4 + (size_t)mid * 4);
        if (index >= count) {
            result = vox_adblock_snapshot_error(context, "Invalid packed map index", exception); break;
        }
        size_t key_table = 12 + (size_t)count * 8;
        size_t start = vox_adblock_packed_u32(bytes + key_table + (size_t)index * 4);
        size_t end = vox_adblock_packed_u32(bytes + key_table + (size_t)index * 4 + 4);
        if (start < 16 + (size_t)count * 12 || start > end || end > size || (end - start) % 2) {
            result = vox_adblock_snapshot_error(context, "Invalid packed map key bounds", exception); break;
        }
        int comparison;
        if (kind == 2) {
            comparison = vox_adblock_packed_string_compare(bytes + start, (end - start) / 2, key);
        } else {
            double value = 0;
            if (start == end) {
                result = vox_adblock_snapshot_error(context, "Invalid packed numeric key", exception); break;
            }
            for (size_t offset = start; offset < end; offset += 2) {
                unsigned digit = bytes[offset] | (unsigned)bytes[offset + 1] << 8;
                if (digit < '0' || digit > '9') {
                    result = vox_adblock_snapshot_error(context, "Invalid packed numeric key", exception); break;
                }
                value = value * 10 + (digit - '0');
            }
            if (exception && *exception) break;
            comparison = value < number ? -1 : value > number ? 1 : 0;
        }
        if (comparison == 0) {
            JSValueRef entry = vox_adblock_packed_entry(context, bytes, size, count, index, exception);
            if (exception && *exception) break;
            if (!JSValueIsArray(context, entry)) {
                result = vox_adblock_snapshot_error(context, "Invalid packed map entry", exception); break;
            }
            JSValueProtect(context, entry);
            result = JSObjectGetPropertyAtIndex(context, (JSObjectRef)entry, 1, exception);
            JSValueUnprotect(context, entry);
        }
        if (comparison < 0) low = mid + 1;
        else if (comparison > 0) high = mid;
        else break;
    }
    if (key) JSStringRelease(key);
    return result;
}
#endif
