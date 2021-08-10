cmake_minimum_required(VERSION 3.4.1)  # for example

# SET(LOCAL_CFLAGS, "-DHAVE_CONFIG_H -UAF_INET6 -w -Wno-error=format-security -fPIE -pie")
#SET(CMAKE_CXX_FLAGS, "-DHAVE_CONFIG_H -UAF_INET6 -w -Wno-error=format-security -fPIE -pie")
#SET(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} TESTESSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS")
#SET(CMAKE_EXE_LINKER_FLAGS  "${CMAKE_EXE_LINKER_FLAGS} -DHAVE_CONFIG_H -UAF_INET6 -w -Wno-error=format-security -fPIE -pie")
#CMAKE_CXX_FLAGS

#SET(LOCAL_CFLAGS  "${LOCAL_CFLAGS} -std=c11 -DANDROID_STL=gnustl_static -fexceptions")
#SET(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -std=c11 -DANDROID_STL=gnustl_static -fexceptions")
#SET(CMAKE_EXE_LINKER_FLAGS  "${CMAKE_EXE_LINKER_FLAGS} -std=c11 -DANDROID_STL=gnustl_static -fexceptions")

set(
    SOURCE_FILES

    ../ios/Classes/exit_hack.c
    ../ios/Classes/native_add.cpp
    ../ios/Classes/cjson.c
    ../ios/Classes/dscp.c
    ../ios/Classes/iperf_api.c
    ../ios/Classes/iperf_auth.c
    ../ios/Classes/iperf_client_api.c
    ../ios/Classes/iperf_error.c
    ../ios/Classes/iperf_locale.c
    ../ios/Classes/iperf_sctp.c
    ../ios/Classes/iperf_server_api.c
    ../ios/Classes/iperf_tcp.c
    ../ios/Classes/iperf_time.c
    ../ios/Classes/iperf_udp.c
    ../ios/Classes/iperf_util.c
    ../ios/Classes/main.c
    ../ios/Classes/net.c
    ../ios/Classes/tcp_info.c
    ../ios/Classes/timer.c
    ../ios/Classes/units.c
)


add_library(
    native_add

    # Sets the library as a shared library.
    SHARED

    # Provides a relative path to your source file(s).
    ${SOURCE_FILES}
)

add_executable(
    libiperf_bundle.so

    ${SOURCE_FILES}
)
