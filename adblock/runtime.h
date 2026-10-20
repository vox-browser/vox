// Serializes the shared isolated JavaScriptCore engine. Page JS never sees it.
#ifndef VOX_ADBLOCK_RUNTIME_H
#define VOX_ADBLOCK_RUNTIME_H
#include <pthread.h>
#include <string.h>
static pthread_mutex_t vox_adblock_mutex = PTHREAD_MUTEX_INITIALIZER;
// The compatibility JSON codec lazily publishes per-type field metadata.
// Protect conversion separately; never hold this mutex while entering JSC.
static pthread_mutex_t vox_adblock_json_mutex = PTHREAD_MUTEX_INITIALIZER;
static void vox_adblock_json_lock(void) { pthread_mutex_lock(&vox_adblock_json_mutex); }
static void vox_adblock_json_unlock(void) { pthread_mutex_unlock(&vox_adblock_json_mutex); }
static pthread_mutex_t vox_adblock_log_mutex = PTHREAD_MUTEX_INITIALIZER;
static void vox_adblock_log_lock(void) { pthread_mutex_lock(&vox_adblock_log_mutex); }
static void vox_adblock_log_unlock(void) { pthread_mutex_unlock(&vox_adblock_log_mutex); }
static void *vox_adblock_context_value = NULL;
static int vox_adblock_enabled_value = 1;
static char *vox_adblock_error_value = NULL;
static char *vox_adblock_get_error(void) { return vox_adblock_error_value; }
static void vox_adblock_set_error(const char *message) { vox_adblock_error_value = strdup(message); }
static void vox_adblock_lock(void) { pthread_mutex_lock(&vox_adblock_mutex); }
static int vox_adblock_try_lock(void) { return pthread_mutex_trylock(&vox_adblock_mutex) == 0; }
static void vox_adblock_unlock(void) { pthread_mutex_unlock(&vox_adblock_mutex); }
static void *vox_adblock_get_context(void) { return vox_adblock_context_value; }
static void vox_adblock_set_context(void *context) { vox_adblock_context_value = context; }
static int vox_adblock_get_enabled(void) { return vox_adblock_enabled_value; }
static void vox_adblock_set_enabled(int enabled) { vox_adblock_enabled_value = enabled; }
#ifdef __APPLE__
#include <CoreFoundation/CoreFoundation.h>
#include <JavaScriptCore/JSStringRefCF.h>
#endif
#include <zlib.h>
#include <limits.h>
static JSStringRef vox_adblock_utf8_string(const unsigned char *bytes, size_t length) {
#ifdef __APPLE__
    if (!length || length > LONG_MAX) return NULL;
    // CF strips a leading UTF-8 BOM. The existing decoder retains U+FEFF.
    if (length >= 3 && bytes[0] == 0xef && bytes[1] == 0xbb && bytes[2] == 0xbf)
        return NULL;
    CFStringRef text = CFStringCreateWithBytes(kCFAllocatorDefault, bytes,
        (CFIndex)length, kCFStringEncodingUTF8, false);
    if (!text) return NULL;
    JSStringRef result = JSStringCreateWithCFString(text);
    CFRelease(text);
    return result;
#else
    // Use the existing length-aware UTF-16 decoder, including embedded NULs.
    (void)bytes; (void)length;
    return NULL;
#endif
}
static int vox_adblock_gunzip(const unsigned char *input, size_t input_size,
        unsigned char *output, size_t output_size) {
    if (input_size > UINT_MAX || output_size > UINT_MAX) return Z_MEM_ERROR;
    z_stream stream = {0};
    unsigned char empty_output;
    stream.next_in = (Bytef *)input;
    stream.avail_in = (uInt)input_size;
    stream.next_out = output_size ? output : &empty_output;
    stream.avail_out = output_size ? (uInt)output_size : 1;
    int status = inflateInit2(&stream, MAX_WBITS + 16);
    if (status != Z_OK) return status;
    status = inflate(&stream, Z_FINISH);
    int valid = status == Z_STREAM_END && stream.total_in == input_size &&
        stream.total_out == output_size;
    inflateEnd(&stream);
    return valid ? Z_OK : (status == Z_STREAM_END ? Z_DATA_ERROR : status);
}
#endif
