#pragma once

#include <stdlib.h>
#include <unicode/stringoptions.h>
#include <unicode/utypes.h>

// Apple's libicucore exports the stable UCaseMap API but its SDK omits the
// public ucasemap.h header. Keep the ABI declarations local so the same bridge
// builds against both libicucore and ordinary ICU installations.
typedef struct UCaseMap UCaseMap;
UCaseMap* ucasemap_open(char const*, uint32_t, UErrorCode*);
void ucasemap_close(UCaseMap*);
int32_t ucasemap_utf8ToUpper(UCaseMap const*, char*, int32_t, char const*, int32_t, UErrorCode*);
int32_t ucasemap_utf8ToLower(UCaseMap const*, char*, int32_t, char const*, int32_t, UErrorCode*);
int32_t ucasemap_utf8ToTitle(UCaseMap*, char*, int32_t, char const*, int32_t, UErrorCode*);

enum LibWebVTextCaseTransform {
    LIBWEB_V_TEXT_CASE_UPPERCASE,
    LIBWEB_V_TEXT_CASE_LOWERCASE,
    LIBWEB_V_TEXT_CASE_TITLECASE,
};

static char* libweb_v_transform_utf8_case(char const* input, int input_length, char const* locale, int transform, int* output_length)
{
    UErrorCode status = U_ZERO_ERROR;
    uint32_t options = transform == LIBWEB_V_TEXT_CASE_TITLECASE ? U_TITLECASE_NO_LOWERCASE : 0;
    UCaseMap* case_map = ucasemap_open(locale, options, &status);
    if (U_FAILURE(status))
        return NULL;

    int capacity = input_length * 3 + 16;
    if (capacity < 16)
        capacity = 16;
    char* output = malloc((size_t)capacity + 1);
    if (!output) {
        ucasemap_close(case_map);
        return NULL;
    }

    int length = 0;
    switch (transform) {
    case LIBWEB_V_TEXT_CASE_UPPERCASE:
        length = ucasemap_utf8ToUpper(case_map, output, capacity, input, input_length, &status);
        break;
    case LIBWEB_V_TEXT_CASE_LOWERCASE:
        length = ucasemap_utf8ToLower(case_map, output, capacity, input, input_length, &status);
        break;
    case LIBWEB_V_TEXT_CASE_TITLECASE:
        length = ucasemap_utf8ToTitle(case_map, output, capacity, input, input_length, &status);
        break;
    default:
        free(output);
        ucasemap_close(case_map);
        return NULL;
    }

    if (status == U_BUFFER_OVERFLOW_ERROR) {
        status = U_ZERO_ERROR;
        char* larger = realloc(output, (size_t)length + 1);
        if (!larger) {
            free(output);
            ucasemap_close(case_map);
            return NULL;
        }
        output = larger;
        capacity = length;
        switch (transform) {
        case LIBWEB_V_TEXT_CASE_UPPERCASE:
            length = ucasemap_utf8ToUpper(case_map, output, capacity, input, input_length, &status);
            break;
        case LIBWEB_V_TEXT_CASE_LOWERCASE:
            length = ucasemap_utf8ToLower(case_map, output, capacity, input, input_length, &status);
            break;
        case LIBWEB_V_TEXT_CASE_TITLECASE:
            length = ucasemap_utf8ToTitle(case_map, output, capacity, input, input_length, &status);
            break;
        }
    }

    ucasemap_close(case_map);
    if (U_FAILURE(status)) {
        free(output);
        return NULL;
    }
    output[length] = '\0';
    *output_length = length;
    return output;
}
