// SPDX-License-Identifier: BSD-2-Clause
// Portable JavaScriptCore C API declarations used by the Windows JSC build
// and Vox's V8 adapter. Only the subset Vox uses is declared; types, enum
// values and signatures match the public JavaScriptCore headers.
#ifndef VOX_JAVASCRIPTCORE_JAVASCRIPT_H
#define VOX_JAVASCRIPTCORE_JAVASCRIPT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>


#ifdef __cplusplus
extern "C" {
#endif

#ifndef JS_EXPORT
#ifdef _WIN32
#define JS_EXPORT __declspec(dllimport)
#else
#define JS_EXPORT __attribute__((visibility("default")))
#endif
#endif

typedef const struct OpaqueJSContextGroup* JSContextGroupRef;
typedef const struct OpaqueJSContext* JSContextRef;
typedef struct OpaqueJSContext* JSGlobalContextRef;
typedef struct OpaqueJSString* JSStringRef;
typedef struct OpaqueJSClass* JSClassRef;
typedef struct OpaqueJSPropertyNameArray* JSPropertyNameArrayRef;
typedef struct OpaqueJSPropertyNameAccumulator* JSPropertyNameAccumulatorRef;
typedef void (*JSTypedArrayBytesDeallocator)(void* bytes, void* deallocatorContext);
typedef const struct OpaqueJSValue* JSValueRef;
typedef struct OpaqueJSValue* JSObjectRef;
typedef unsigned short JSChar;

typedef enum {
    kJSTypeUndefined,
    kJSTypeNull,
    kJSTypeBoolean,
    kJSTypeNumber,
    kJSTypeString,
    kJSTypeObject,
    kJSTypeSymbol,
    kJSTypeBigInt
} JSType;

typedef enum {
    kJSTypedArrayTypeInt8Array,
    kJSTypedArrayTypeInt16Array,
    kJSTypedArrayTypeInt32Array,
    kJSTypedArrayTypeUint8Array,
    kJSTypedArrayTypeUint8ClampedArray,
    kJSTypedArrayTypeUint16Array,
    kJSTypedArrayTypeUint32Array,
    kJSTypedArrayTypeFloat32Array,
    kJSTypedArrayTypeFloat64Array,
    kJSTypedArrayTypeArrayBuffer,
    kJSTypedArrayTypeNone,
    kJSTypedArrayTypeBigInt64Array,
    kJSTypedArrayTypeBigUint64Array
} JSTypedArrayType;

enum {
    kJSPropertyAttributeNone = 0,
    kJSPropertyAttributeReadOnly = 1 << 1,
    kJSPropertyAttributeDontEnum = 1 << 2,
    kJSPropertyAttributeDontDelete = 1 << 3
};
typedef unsigned JSPropertyAttributes;

enum {
    kJSClassAttributeNone = 0,
    kJSClassAttributeNoAutomaticPrototype = 1 << 1
};
typedef unsigned JSClassAttributes;

typedef void (*JSObjectInitializeCallback)(JSContextRef ctx, JSObjectRef object);
typedef void (*JSObjectFinalizeCallback)(JSObjectRef object);
typedef bool (*JSObjectHasPropertyCallback)(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
typedef JSValueRef (*JSObjectGetPropertyCallback)(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);
typedef bool (*JSObjectSetPropertyCallback)(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef value, JSValueRef* exception);
typedef bool (*JSObjectDeletePropertyCallback)(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);
typedef void (*JSObjectGetPropertyNamesCallback)(JSContextRef ctx, JSObjectRef object, JSPropertyNameAccumulatorRef propertyNames);
typedef JSValueRef (*JSObjectCallAsFunctionCallback)(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
typedef JSObjectRef (*JSObjectCallAsConstructorCallback)(JSContextRef ctx, JSObjectRef constructor, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
typedef bool (*JSObjectHasInstanceCallback)(JSContextRef ctx, JSObjectRef constructor, JSValueRef possibleInstance, JSValueRef* exception);
typedef JSValueRef (*JSObjectConvertToTypeCallback)(JSContextRef ctx, JSObjectRef object, JSType type, JSValueRef* exception);

typedef struct {
    const char* name;
    JSObjectGetPropertyCallback getProperty;
    JSObjectSetPropertyCallback setProperty;
    JSPropertyAttributes attributes;
} JSStaticValue;

typedef struct {
    const char* name;
    JSObjectCallAsFunctionCallback callAsFunction;
    JSPropertyAttributes attributes;
} JSStaticFunction;

typedef struct {
    int version;
    JSClassAttributes attributes;
    const char* className;
    JSClassRef parentClass;
    const JSStaticValue* staticValues;
    const JSStaticFunction* staticFunctions;
    JSObjectInitializeCallback initialize;
    JSObjectFinalizeCallback finalize;
    JSObjectHasPropertyCallback hasProperty;
    JSObjectGetPropertyCallback getProperty;
    JSObjectSetPropertyCallback setProperty;
    JSObjectDeletePropertyCallback deleteProperty;
    JSObjectGetPropertyNamesCallback getPropertyNames;
    JSObjectCallAsFunctionCallback callAsFunction;
    JSObjectCallAsConstructorCallback callAsConstructor;
    JSObjectHasInstanceCallback hasInstance;
    JSObjectConvertToTypeCallback convertToType;
} JSClassDefinition;

static const JSClassDefinition kJSClassDefinitionEmpty = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

// JSBase.h
JS_EXPORT JSValueRef JSEvaluateScript(JSContextRef ctx, JSStringRef script, JSObjectRef thisObject, JSStringRef sourceURL, int startingLineNumber, JSValueRef* exception);
JS_EXPORT bool JSCheckScriptSyntax(JSContextRef ctx, JSStringRef script, JSStringRef sourceURL, int startingLineNumber, JSValueRef* exception);
JS_EXPORT void JSGarbageCollect(JSContextRef ctx);

// JSContextRef.h
JS_EXPORT JSContextGroupRef JSContextGroupCreate(void);
JS_EXPORT JSContextGroupRef JSContextGroupRetain(JSContextGroupRef group);
JS_EXPORT void JSContextGroupRelease(JSContextGroupRef group);
JS_EXPORT JSGlobalContextRef JSGlobalContextCreate(JSClassRef globalObjectClass);
JS_EXPORT JSGlobalContextRef JSGlobalContextCreateInGroup(JSContextGroupRef group, JSClassRef globalObjectClass);
JS_EXPORT JSGlobalContextRef JSGlobalContextRetain(JSGlobalContextRef ctx);
JS_EXPORT void JSGlobalContextRelease(JSGlobalContextRef ctx);
JS_EXPORT JSObjectRef JSContextGetGlobalObject(JSContextRef ctx);
JS_EXPORT JSContextGroupRef JSContextGetGroup(JSContextRef ctx);
JS_EXPORT JSGlobalContextRef JSContextGetGlobalContext(JSContextRef ctx);

// JSValueRef.h
JS_EXPORT JSType JSValueGetType(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsUndefined(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsNull(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsBoolean(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsNumber(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsString(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsSymbol(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsBigInt(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsObject(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsArray(JSContextRef ctx, JSValueRef value);
JS_EXPORT bool JSValueIsDate(JSContextRef ctx, JSValueRef value);
JS_EXPORT JSTypedArrayType JSValueGetTypedArrayType(JSContextRef ctx, JSValueRef value, JSValueRef* exception);
JS_EXPORT bool JSValueIsEqual(JSContextRef ctx, JSValueRef a, JSValueRef b, JSValueRef* exception);
JS_EXPORT bool JSValueIsStrictEqual(JSContextRef ctx, JSValueRef a, JSValueRef b);
JS_EXPORT bool JSValueIsInstanceOfConstructor(JSContextRef ctx, JSValueRef value, JSObjectRef constructor, JSValueRef* exception);
JS_EXPORT JSValueRef JSValueMakeUndefined(JSContextRef ctx);
JS_EXPORT JSValueRef JSValueMakeNull(JSContextRef ctx);
JS_EXPORT JSValueRef JSValueMakeBoolean(JSContextRef ctx, bool boolean);
JS_EXPORT JSValueRef JSValueMakeNumber(JSContextRef ctx, double number);
JS_EXPORT JSValueRef JSValueMakeString(JSContextRef ctx, JSStringRef string);
JS_EXPORT JSValueRef JSValueMakeSymbol(JSContextRef ctx, JSStringRef description);
JS_EXPORT JSValueRef JSValueMakeFromJSONString(JSContextRef ctx, JSStringRef string);
JS_EXPORT JSStringRef JSValueCreateJSONString(JSContextRef ctx, JSValueRef value, unsigned indent, JSValueRef* exception);
JS_EXPORT bool JSValueToBoolean(JSContextRef ctx, JSValueRef value);
JS_EXPORT double JSValueToNumber(JSContextRef ctx, JSValueRef value, JSValueRef* exception);
JS_EXPORT JSStringRef JSValueToStringCopy(JSContextRef ctx, JSValueRef value, JSValueRef* exception);
JS_EXPORT JSObjectRef JSValueToObject(JSContextRef ctx, JSValueRef value, JSValueRef* exception);
JS_EXPORT void JSValueProtect(JSContextRef ctx, JSValueRef value);
JS_EXPORT void JSValueUnprotect(JSContextRef ctx, JSValueRef value);

// JSObjectRef.h
JS_EXPORT JSClassRef JSClassCreate(const JSClassDefinition* definition);
JS_EXPORT JSClassRef JSClassRetain(JSClassRef jsClass);
JS_EXPORT void JSClassRelease(JSClassRef jsClass);
JS_EXPORT JSObjectRef JSObjectMake(JSContextRef ctx, JSClassRef jsClass, void* data);
JS_EXPORT JSObjectRef JSObjectMakeFunctionWithCallback(JSContextRef ctx, JSStringRef name, JSObjectCallAsFunctionCallback callAsFunction);
JS_EXPORT JSObjectRef JSObjectMakeArray(JSContextRef ctx, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
JS_EXPORT JSObjectRef JSObjectMakeDate(JSContextRef ctx, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
JS_EXPORT JSObjectRef JSObjectMakeError(JSContextRef ctx, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
JS_EXPORT JSObjectRef JSObjectMakeFunction(JSContextRef ctx, JSStringRef name, unsigned parameterCount, const JSStringRef parameterNames[], JSStringRef body, JSStringRef sourceURL, int startingLineNumber, JSValueRef* exception);
JS_EXPORT JSObjectRef JSObjectMakeDeferredPromise(JSContextRef ctx, JSObjectRef* resolve, JSObjectRef* reject, JSValueRef* exception);
JS_EXPORT JSValueRef JSObjectGetPrototype(JSContextRef ctx, JSObjectRef object);
JS_EXPORT void JSObjectSetPrototype(JSContextRef ctx, JSObjectRef object, JSValueRef value);
JS_EXPORT bool JSObjectHasProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName);
JS_EXPORT JSValueRef JSObjectGetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);
JS_EXPORT void JSObjectSetProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef value, JSPropertyAttributes attributes, JSValueRef* exception);
JS_EXPORT bool JSObjectDeleteProperty(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception);
JS_EXPORT JSValueRef JSObjectGetPropertyAtIndex(JSContextRef ctx, JSObjectRef object, unsigned propertyIndex, JSValueRef* exception);
JS_EXPORT void JSObjectSetPropertyAtIndex(JSContextRef ctx, JSObjectRef object, unsigned propertyIndex, JSValueRef value, JSValueRef* exception);
JS_EXPORT void* JSObjectGetPrivate(JSObjectRef object);
JS_EXPORT bool JSObjectSetPrivate(JSObjectRef object, void* data);
JS_EXPORT bool JSObjectIsFunction(JSContextRef ctx, JSObjectRef object);
JS_EXPORT JSValueRef JSObjectCallAsFunction(JSContextRef ctx, JSObjectRef object, JSObjectRef thisObject, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);
JS_EXPORT bool JSObjectIsConstructor(JSContextRef ctx, JSObjectRef object);
JS_EXPORT JSObjectRef JSObjectCallAsConstructor(JSContextRef ctx, JSObjectRef object, size_t argumentCount, const JSValueRef arguments[], JSValueRef* exception);

// JSStringRef.h
JS_EXPORT JSStringRef JSStringCreateWithCharacters(const JSChar* chars, size_t numChars);
JS_EXPORT JSStringRef JSStringCreateWithUTF8CString(const char* string);
JS_EXPORT JSStringRef JSStringRetain(JSStringRef string);
JS_EXPORT void JSStringRelease(JSStringRef string);
JS_EXPORT size_t JSStringGetLength(JSStringRef string);
JS_EXPORT const JSChar* JSStringGetCharactersPtr(JSStringRef string);
JS_EXPORT size_t JSStringGetMaximumUTF8CStringSize(JSStringRef string);
JS_EXPORT size_t JSStringGetUTF8CString(JSStringRef string, char* buffer, size_t bufferSize);
JS_EXPORT bool JSStringIsEqual(JSStringRef a, JSStringRef b);
JS_EXPORT bool JSStringIsEqualToUTF8CString(JSStringRef a, const char* b);

// JSTypedArray.h
JS_EXPORT JSObjectRef JSObjectMakeTypedArray(JSContextRef ctx, JSTypedArrayType arrayType, size_t length, JSValueRef* exception);
JS_EXPORT JSObjectRef JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef ctx, JSTypedArrayType arrayType, void* bytes, size_t byteLength, JSTypedArrayBytesDeallocator bytesDeallocator, void* deallocatorContext, JSValueRef* exception);
JS_EXPORT JSObjectRef JSObjectMakeTypedArrayWithArrayBuffer(JSContextRef ctx, JSTypedArrayType arrayType, JSObjectRef buffer, JSValueRef* exception);
JS_EXPORT void* JSObjectGetTypedArrayBytesPtr(JSContextRef ctx, JSObjectRef object, JSValueRef* exception);
JS_EXPORT size_t JSObjectGetTypedArrayLength(JSContextRef ctx, JSObjectRef object, JSValueRef* exception);
JS_EXPORT size_t JSObjectGetTypedArrayByteLength(JSContextRef ctx, JSObjectRef object, JSValueRef* exception);
JS_EXPORT size_t JSObjectGetTypedArrayByteOffset(JSContextRef ctx, JSObjectRef object, JSValueRef* exception);
JS_EXPORT JSObjectRef JSObjectGetTypedArrayBuffer(JSContextRef ctx, JSObjectRef object, JSValueRef* exception);
JS_EXPORT JSObjectRef JSObjectMakeArrayBufferWithBytesNoCopy(JSContextRef ctx, void* bytes, size_t byteLength, JSTypedArrayBytesDeallocator bytesDeallocator, void* deallocatorContext, JSValueRef* exception);
JS_EXPORT void* JSObjectGetArrayBufferBytesPtr(JSContextRef ctx, JSObjectRef object, JSValueRef* exception);
JS_EXPORT size_t JSObjectGetArrayBufferByteLength(JSContextRef ctx, JSObjectRef object, JSValueRef* exception);

// Vox V8 backend extensions.
JS_EXPORT const char* VoxJavaScriptEngineName(void);
JS_EXPORT const char* VoxJavaScriptEngineVersion(void);
// Releases temporary value handles created since the last turn. The backend
// calls this from a run-loop observer; embedders without a CFRunLoop may call
// it when no JSValueRef temporaries remain on their stack.
JS_EXPORT void VoxJavaScriptEndTurn(JSContextRef ctx);

#ifdef __cplusplus
}
#endif

#endif
