#include "../webcrypto/native_aes.h"
#include "../webcrypto/native_crypto.h"
#include "../webcrypto/native_edwards.h"
#include "../webcrypto/native_kdf.h"
#include <assert.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

static void* hmac_worker(void* unused)
{
    (void)unused;
    unsigned char output[32]; size_t size = sizeof(output);
    assert(vox_hmac("SHA256",(unsigned char const*)"key",3,
        (unsigned char const*)"The quick brown fox jumps over the lazy dog",43,output,&size));
    static unsigned char const expected[] = {
        0xf7,0xbc,0x83,0xf4,0x30,0x53,0x84,0x24,0xb1,0x32,0x98,0xe6,0xaa,0x6f,0xb1,0x43,
        0xef,0x4d,0x59,0xa1,0x49,0x46,0x17,0x59,0x97,0x47,0x9d,0xbc,0x2d,0x1a,0x3c,0xd8};
    assert(size == sizeof(expected) && !memcmp(output,expected,size));
    return NULL;
}

int main(int argc,char** argv)
{
    unsigned char key[32] = {0}, input[16] = {0}, iv[16] = {0}, output[64], restored[64];
    size_t size = sizeof(output), restored_size = sizeof(restored);
    if (argc == 2 && !strcmp(argv[1],"--unavailable")) {
        assert(getenv("VOX_WEBCRYPTO_LIBRARY"));
        assert(!vox_aes_cbc(0,1,key,16,input,16,iv,output,&size));
        assert(!vox_kdf_derive(1,"SHA256",key,16,iv,16,NULL,0,1,output,32));
        assert(!vox_crypto_prepare());
        puts("PASS unavailable backend returns ordinary operation failures");
        return 0;
    }
    void* loaded = dlopen(VOX_WEBCRYPTO_LIBRARY_PATH,RTLD_LAZY|RTLD_NOLOAD);
    assert((loaded != NULL) == (getenv("VOX_EAGER_WEBCRYPTO_BACKEND") != NULL));
    if (loaded) dlclose(loaded);
    pthread_t threads[8];
    for (unsigned i = 0; i < 8; ++i) assert(!pthread_create(&threads[i],NULL,hmac_worker,NULL));
    for (unsigned i = 0; i < 8; ++i) assert(!pthread_join(threads[i],NULL));
    assert(vox_crypto_prepare());
    assert(vox_aes_cbc(0,1,key,16,input,16,iv,output,&size));
    assert(vox_aes_cbc(1,1,key,16,output,size,iv,restored,&restored_size));
    assert(restored_size == sizeof(input) && !memcmp(input,restored,sizeof(input)));
    unsigned char secret[32], public_bytes[32], signature[64];
    size_t secret_size=sizeof(secret), public_size=sizeof(public_bytes), signature_size=sizeof(signature);
    assert(vox_edwards_private("Ed25519",secret,&secret_size));
    assert(vox_edwards_public("Ed25519",secret,secret_size,public_bytes,&public_size));
    assert(vox_edwards_sign("Ed25519",secret,secret_size,input,sizeof(input),NULL,0,signature,&signature_size));
    assert(vox_edwards_verify("Ed25519",public_bytes,public_size,signature,signature_size,input,sizeof(input),NULL,0) == 1);
    puts("PASS lazy/eager backend, concurrent first use, HMAC vector, AES and Ed25519");
}
