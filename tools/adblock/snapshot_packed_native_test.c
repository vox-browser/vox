#include <assert.h>
#include <stdio.h>
#include <JavaScriptCore/JavaScriptCore.h>
#include "../../adblock/snapshot.h"

int main(int argc, char **argv) {
    assert(argc == 2);
    FILE *file = fopen(argv[1], "rb"); assert(file);
    assert(!fseek(file, 0, SEEK_END)); long size = ftell(file); assert(size > 0);
    rewind(file); char *text = calloc((size_t)size + 1, 1); assert(text);
    assert(fread(text, 1, (size_t)size, file) == (size_t)size); fclose(file);
    JSGlobalContextRef context = JSGlobalContextCreate(NULL); assert(context);
    JSStringRef key = JSStringCreateWithUTF8CString("readPackedValue");
    JSObjectRef reader = JSObjectMakeFunctionWithCallback(context, key, vox_adblock_read_packed_value);
    JSObjectSetProperty(context, JSContextGetGlobalObject(context), key, reader, 0, NULL);
    JSStringRelease(key);
    JSStringRef source = JSStringCreateWithUTF8CString(text); free(text);
    JSValueRef exception = NULL;
    JSValueRef result = JSEvaluateScript(context, source, NULL, NULL, 1, &exception);
    if (exception) {
        JSStringRef string = JSValueToStringCopy(context, exception, NULL);
        char message[4096]; JSStringGetUTF8CString(string, message, sizeof message);
        fprintf(stderr, "%s\n", message); JSStringRelease(string);
    }
    assert(!exception && JSValueToBoolean(context, result));
    JSStringRelease(source); JSGarbageCollect(context); JSGlobalContextRelease(context);
    puts("PASS native packed lookups, Unicode, view offsets, bounds and mutations");
}
