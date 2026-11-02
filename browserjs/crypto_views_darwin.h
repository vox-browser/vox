#pragma once
#include "jsc_abi.h"

// The native engine brand is used; constructor names and JS properties cannot spoof it.
static int vox_jsc_crypto_integer_view_kind(void* context, void* value, void** exception)
{
    switch (vox_jsc_JSValueGetTypedArrayType(context, value, exception)) {
    case kJSTypedArrayTypeInt8Array: return 0;
    case kJSTypedArrayTypeUint8Array: return 1;
    case kJSTypedArrayTypeUint8ClampedArray: return 2;
    case kJSTypedArrayTypeInt16Array: return 3;
    case kJSTypedArrayTypeUint16Array: return 4;
    case kJSTypedArrayTypeInt32Array: return 5;
    case kJSTypedArrayTypeUint32Array: return 6;
    case kJSTypedArrayTypeBigInt64Array: return 7;
    case kJSTypedArrayTypeBigUint64Array: return 8;
    default: return -1;
    }
}
