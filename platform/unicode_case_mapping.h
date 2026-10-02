#pragma once
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
struct LibWebVCaseEdit {
    int source_start, source_length, rendered_start, rendered_length;
};
struct LibWebVCaseMapping {
    uint16_t* text;
    int text_length;
    struct LibWebVCaseEdit* edits;
    int edit_count;
};
bool libweb_v_case_mapping(uint16_t const*, int, char const*, int, struct LibWebVCaseMapping*);
void libweb_v_case_mapping_free(struct LibWebVCaseMapping*);
#ifdef __cplusplus
}
#endif
