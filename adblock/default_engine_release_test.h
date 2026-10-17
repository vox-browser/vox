#ifndef VOX_ADBLOCK_DEFAULT_ENGINE_RELEASE_TEST_H
#define VOX_ADBLOCK_DEFAULT_ENGINE_RELEASE_TEST_H

#include "runtime.h"

// Tests restore the exact previous pointer; the production error setter owns
// its strdup allocation and intentionally has no reset operation.
static char *vox_adblock_test_exchange_error(char *replacement) {
    char *previous = vox_adblock_error_value;
    vox_adblock_error_value = replacement;
    return previous;
}

#endif
