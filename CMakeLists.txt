cmake_minimum_required(VERSION 3.16)
project(AndroidStreamManager VERSION 1.1.0 LANGUAGES C CXX)

# =========================
# Configuração Geral
# =========================
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Build estático por padrão para facilitar a distribuição
set(BUILD_SHARED_LIBS OFF)

option(BUILD_DASHBOARD "Build Qt Dashboard" ON)
option(BUILD_APK_BUILDER "Build APK Builder" ON)
option(BUILD_SERVER "Build Stream Server" ON)
option(BUILD_TESTS "Build unit tests" OFF)

include(GNUInstallDirs)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_BINDIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR})

# =========================
# Dependências do Sistema
# =========================
find_package(OpenSSL REQUIRED)
find_package(ZLIB REQUIRED)
find_package(SQLite3 REQUIRED)
find_package(Threads REQUIRED)

# =========================
# Dependências Externas (FetchContent)
# =========================
include(FetchContent)
set(CMAKE_POLICY_DEFAULT_CMP0135 NEW)

# nlohmann_json
FetchContent_Declare(
    nlohmann_json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG v3.11.2
)
FetchContent_MakeAvailable(nlohmann_json)

# cxxopts
FetchContent_Declare(
    cxxopts
    GIT_REPOSITORY https://github.com/jarro2783/cxxopts.git
    GIT_TAG v3.1.1
)
FetchContent_MakeAvailable(cxxopts)

# jwt-cpp
FetchContent_Declare(
    jwt_cpp
    GIT_REPOSITORY https://github.com/Thalhammer/jwt-cpp.git
    GIT_TAG v0.7.0
)
set(JWT_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(JWT_BUILD_TESTS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(jwt_cpp)

# uSockets
FetchContent_Declare(
    usockets
    GIT_REPOSITORY https://github.com/uNetworking/uSockets.git
    GIT_TAG v0.8.6
)
FetchContent_GetProperties(usockets)
if(NOT usockets_POPULATED)
    FetchContent_Populate(usockets)
    add_library(uSockets STATIC 
        ${usockets_SOURCE_DIR}/src/bsd.c
        ${usockets_SOURCE_DIR}/src/context.c
        ${usockets_SOURCE_DIR}/src/loop.c
        ${usockets_SOURCE_DIR}/src/socket.c
        ${usockets_SOURCE_DIR}/src/udp.c
        ${usockets_SOURCE_DIR}/src/quic.c
        ${usockets_SOURCE_DIR}/src/crypto/openssl.c
        ${usockets_SOURCE_DIR}/src/crypto/sni_tree.cpp
        ${usockets_SOURCE_DIR}/src/eventing/epoll_kqueue.c
    )
    target_include_directories(uSockets PUBLIC ${usockets_SOURCE_DIR}/src)
    target_link_libraries(uSockets PRIVATE OpenSSL::SSL OpenSSL::Crypto)
endif()

# uWebSockets
FetchContent_Declare(
    uWebSockets
    GIT_REPOSITORY https://github.com/uNetworking/uWebSockets.git
    GIT_TAG v20.45.0
)
FetchContent_GetProperties(uWebSockets)
if(NOT uwebsockets_POPULATED)
    FetchContent_Populate(uWebSockets)
    add_library(uWebSockets INTERFACE)
    target_include_directories(uWebSockets INTERFACE ${uwebsockets_SOURCE_DIR}/src)
    target_link_libraries(uWebSockets INTERFACE uSockets)
endif()

# LZ4
FetchContent_Declare(
    lz4_fetch
    GIT_REPOSITORY https://github.com/lz4/lz4.git
    GIT_TAG v1.9.4
    SOURCE_SUBDIR build/cmake
)
set(LZ4_BUILD_CLI OFF CACHE BOOL "" FORCE)
set(LZ4_BUILD_LEGACY_UTILS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(lz4_fetch)

# libzip
FetchContent_Declare(
    libzip_fetch
    URL https://libzip.org/download/libzip-1.10.1.tar.gz
    URL_HASH SHA256=9669ae5dfe3ac5b3897536dc8466a874c8cf2c0e3b1fdd08d75b273884299363
)
set(BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(ENABLE_GNUTLS OFF CACHE BOOL "" FORCE)
set(ENABLE_MBEDTLS OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(libzip_fetch)

# =========================
# Plataforma
# =========================
if(WIN32)
    add_definitions(-DWINDOWS_BUILD -D_CRT_SECURE_NO_WARNINGS)
    set(PLATFORM_LIBS ws2_32 crypt32)
else()
    add_definitions(-DLINUX_BUILD)
    set(PLATFORM_LIBS pthread dl)
endif()

# =========================
# Biblioteca Principal
# =========================
add_library(android_stream_lib STATIC
    # Core
    core/system_manager.cpp
    core/apk_builder.cpp
    core/device_manager.cpp
    
    # Optimization
    optimization/stream_optimizer.cpp
    optimization/build_cache.cpp
    optimization/thread_pool.cpp
    
    # Compliance
    compliance/compliance_manager.cpp
    
    # Security
    security/tls_manager.cpp
    security/jwt_manager.cpp
    security/apk_signer.cpp
    
    # Database
    database/database_manager.cpp
    
    # Server
    server/stream_server.cpp
    server/websocket_session.cpp
    server/http_server.cpp
    
    # Monitoring
    monitoring/metrics_collector.cpp
    monitoring/alerts_manager.cpp
    monitoring/health_checker.cpp
    monitoring/prometheus_exporter.cpp
    
    # Shared
    shared/protocol.cpp
    
    # Utilities
    base64.cpp
)

target_include_directories(android_stream_lib PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/shared
)

target_link_libraries(android_stream_lib PRIVATE
    OpenSSL::SSL
    OpenSSL::Crypto
    ZLIB::ZLIB
    SQLite::SQLite3
    Threads::Threads
    jwt-cpp
    nlohmann_json::nlohmann_json
    lz4_static
    zip
    uWebSockets
    uSockets
    ${PLATFORM_LIBS}
)

# =========================
# Dashboard Qt
# =========================
if(BUILD_DASHBOARD)
    find_package(Qt6 COMPONENTS Core Widgets Network Multimedia WebSockets QUIET)
    find_package(PkgConfig QUIET)

    if(Qt6_FOUND AND PKG_CONFIG_FOUND)
        pkg_check_modules(AVCODEC REQUIRED libavcodec)
        pkg_check_modules(AVUTIL REQUIRED libavutil)
        pkg_check_modules(SWSCALE REQUIRED libswscale)

        set(CMAKE_AUTOMOC ON)
        set(CMAKE_AUTOUIC ON)
        set(CMAKE_AUTORCC ON)

        add_executable(android_stream_dashboard
            dashboard/main.cpp
            dashboard/main_window.cpp
            dashboard/apk_config_widget.cpp
            dashboard/monitoring_widget.cpp
            dashboard/streaming_viewer.cpp
            dashboard/app_monitoring_widget.cpp
            dashboard/resources.qrc
        )

        target_include_directories(android_stream_dashboard PRIVATE
            ${AVCODEC_INCLUDE_DIRS}
            ${AVUTIL_INCLUDE_DIRS}
            ${SWSCALE_INCLUDE_DIRS}
        )

        target_link_libraries(android_stream_dashboard PRIVATE
            android_stream_lib
            Qt6::Core
            Qt6::Widgets
            Qt6::Network
            Qt6::Multimedia
            Qt6::WebSockets
            ${AVCODEC_LIBRARIES}
            ${AVUTIL_LIBRARIES}
            ${SWSCALE_LIBRARIES}
        )
    endif()
endif()

# =========================
# APK Builder Executable
# =========================
if(BUILD_APK_BUILDER)
    add_executable(apk_builder builder/main.cpp)
    target_link_libraries(apk_builder PRIVATE
        android_stream_lib
        cxxopts
    )
endif()

# =========================
# Stream Server Executable
# =========================
if(BUILD_SERVER)
    add_executable(stream_server server/main.cpp)
    target_link_libraries(stream_server PRIVATE
        android_stream_lib
    )
endif()

# =========================
# Instalação
# =========================
install(TARGETS android_stream_lib DESTINATION ${CMAKE_INSTALL_LIBDIR})

if(BUILD_DASHBOARD AND TARGET android_stream_dashboard)
    install(TARGETS android_stream_dashboard DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

if(BUILD_APK_BUILDER)
    install(TARGETS apk_builder DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

if(BUILD_SERVER)
    install(TARGETS stream_server DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
