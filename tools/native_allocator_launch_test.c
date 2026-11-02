#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static int allocator_test_exec(const char *path, char *const arguments[])
{
    fprintf(stderr, "allocator restart\n");
    return execv(path, arguments);
}

#define execv allocator_test_exec
#include "../native_allocator_policy_darwin.h"
#undef execv

int main(void)
{
    printf("policy=%s\npid=%d\n", getenv("MallocSpaceEfficient"), getpid());
    return 0;
}
