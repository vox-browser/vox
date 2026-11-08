#include "../native/include/native_allocator_policy_darwin.h"

int main(int argc, char **argv)
{
    printf("pid=%d\npolicy=%s\n", getpid(), getenv("MallocSpaceEfficient"));
    for (int index = 1; index < argc; ++index)
        printf("argument=%s\n", argv[index]);
    const char *descriptor = getenv("VOX_ALLOCATOR_TEST_FD");
    if (descriptor) {
        const char payload[] = "inherited descriptor\n";
        if (write(atoi(descriptor), payload, sizeof payload - 1) != sizeof payload - 1)
            return 1;
    }
    return 0;
}
