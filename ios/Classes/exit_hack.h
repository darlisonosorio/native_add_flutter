#ifndef _EXITHACK_LIB
    #define _EXITHACK_LIB 1
    #ifndef _STDLIB_H
        #error "This header must be included after stdlib"
    #endif

    #include<setjmp.h>
    #include<stdio.h>
    #include<unistd.h>

    jmp_buf global_teleport;
    #define exit(x) longjmp(global_teleport, x)
    #define setup_exit_hack() int ___code = setjmp(global_teleport); if(___code){ printf("Exit hack [%d]!\n", ___code); return ___code; }

    void redirect_streams(char* stdout_path, char* stderr_path);
    void restore_streams();
    void set_env_var(char* key, char* value);
#endif