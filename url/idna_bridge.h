#pragma once

#include <stdlib.h>
#include <unicode/uidna.h>

#define LIBWEB_V_IGNORED_NONSTRICT_IDNA_ERRORS (UIDNA_ERROR_HYPHEN_3_4 | UIDNA_ERROR_LEADING_HYPHEN | UIDNA_ERROR_TRAILING_HYPHEN | UIDNA_ERROR_EMPTY_LABEL | UIDNA_ERROR_LABEL_TOO_LONG | UIDNA_ERROR_DOMAIN_NAME_TOO_LONG)

static char* libweb_v_idna_to_ascii(char const* input, int input_length, int strict, int* output_length)
{
    uint32_t options = UIDNA_CHECK_BIDI | UIDNA_CHECK_CONTEXTJ | UIDNA_NONTRANSITIONAL_TO_ASCII | UIDNA_NONTRANSITIONAL_TO_UNICODE;
    if (strict)
        options |= UIDNA_USE_STD3_RULES;
    UErrorCode status = U_ZERO_ERROR;
    UIDNA* idna = uidna_openUTS46(options, &status);
    if (U_FAILURE(status))
        return NULL;

    int capacity = input_length * 4 + 64;
    if (capacity < 64)
        capacity = 64;
    char* output = malloc((size_t)capacity + 1);
    if (!output) {
        uidna_close(idna);
        return NULL;
    }
    UIDNAInfo info = UIDNA_INFO_INITIALIZER;
    int length = uidna_nameToASCII_UTF8(idna, input, input_length, output, capacity, &info, &status);
    if (status == U_BUFFER_OVERFLOW_ERROR) {
        status = U_ZERO_ERROR;
        char* larger = realloc(output, (size_t)length + 1);
        if (!larger) {
            free(output);
            uidna_close(idna);
            return NULL;
        }
        output = larger;
        capacity = length;
        info = (UIDNAInfo)UIDNA_INFO_INITIALIZER;
        length = uidna_nameToASCII_UTF8(idna, input, input_length, output, capacity, &info, &status);
    }
    uidna_close(idna);
    uint32_t errors = info.errors;
    if (!strict)
        errors &= ~LIBWEB_V_IGNORED_NONSTRICT_IDNA_ERRORS;
    if (U_FAILURE(status) || errors != 0 || length == 0) {
        free(output);
        return NULL;
    }
    output[length] = '\0';
    *output_length = length;
    return output;
}
