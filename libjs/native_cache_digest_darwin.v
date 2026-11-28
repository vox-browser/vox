module libjs

#include <CommonCrypto/CommonDigest.h>

fn C.CC_SHA256(data voidptr, length u32, digest &u8) &u8
