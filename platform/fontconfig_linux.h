#pragma once
#include <fontconfig/fontconfig.h>
#include <stdbool.h>
#include <string.h>
#include <strings.h>

static char *vox_fontconfig_path(const char *family, int weight, bool exact) {
    FcPattern *query = FcPatternCreate();
    FcPatternAddString(query, FC_FAMILY, (const FcChar8 *)family);
    FcPatternAddInteger(query, FC_WEIGHT, weight >= 600 ? FC_WEIGHT_BOLD : FC_WEIGHT_REGULAR);
    FcConfigSubstitute(NULL, query, FcMatchPattern);
    FcDefaultSubstitute(query);
    FcResult result;
    FcPattern *match = FcFontMatch(NULL, query, &result);
    FcPatternDestroy(query);
    if (!match) return NULL;
    bool found = !exact;
    FcChar8 *value;
    for (int i = 0; exact && FcPatternGetString(match, FC_FAMILY, i, &value) == FcResultMatch; ++i)
        if (!strcasecmp((const char *)value, family)) found = true;
    char *path = NULL;
    if (found && FcPatternGetString(match, FC_FILE, 0, &value) == FcResultMatch)
        path = strdup((const char *)value);
    FcPatternDestroy(match);
    return path;
}
