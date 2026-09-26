# OpenSSL is configured by a perl script of its own (Configure), which
# writes the Makefile -- and nothing can be read before it has run. So it is
# run, and then its make is asked what it would do rather than told to do
# it, the shape FFmpeg's port has: every source is compiled in the
# consumer's graph, with the flags OpenSSL said to compile it with, and the
# archives are this build's targets. What is neither -- the perl that writes
# each machine's assembly and the headers made from templates -- becomes a
# command in the same graph, run as make would have run it.
#
# The LTS release: supported until April 2030. OpenSSL 4 removes APIs that
# many libraries still call; this is the version everything builds with.

# The machine, in the names OpenSSL's Configure knows, for a cross build: it
# reads no triple, and a target it is not told is the machine it runs on.
set(cme_openssl_machine "")
if(CMAKE_CROSSCOMPILING)
  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" cme_openssl_processor)
  if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    if(cme_openssl_processor MATCHES "^(aarch64|arm64)$")
      set(cme_openssl_machine "android-arm64")
    elseif(cme_openssl_processor MATCHES "^arm")
      set(cme_openssl_machine "android-arm")
    elseif(cme_openssl_processor MATCHES "^(x86_64|amd64)$")
      set(cme_openssl_machine "android-x86_64")
    elseif(cme_openssl_processor MATCHES "^(i[3-6]86|x86)$")
      set(cme_openssl_machine "android-x86")
    endif()
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    if(cme_openssl_processor MATCHES "^(aarch64|arm64)$")
      set(cme_openssl_machine "linux-aarch64")
    elseif(cme_openssl_processor MATCHES "^arm")
      set(cme_openssl_machine "linux-armv4")
    elseif(cme_openssl_processor MATCHES "^(x86_64|amd64)$")
      set(cme_openssl_machine "linux-x86_64")
    elseif(cme_openssl_processor MATCHES "^(i[3-6]86|x86)$")
      set(cme_openssl_machine "linux-x86")
    elseif(cme_openssl_processor MATCHES "^riscv64")
      set(cme_openssl_machine "linux64-riscv64")
    endif()
  endif()
  if(NOT cme_openssl_machine)
    # Its generic targets: no assembly, and nothing it would have to guess.
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
      set(cme_openssl_machine "linux-generic64")
    else()
      set(cme_openssl_machine "linux-generic32")
    endif()
  endif()
endif()

cme_declare_port(
  NAME openssl
  PROVIDES OpenSSL openssl OPENSSL
  VERSION 3.5.8
  URL "https://github.com/openssl/openssl/releases/download/openssl-3.5.8/openssl-3.5.8.tar.gz"
  URL_HASH "SHA256=a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2"
  LICENSE Apache-2.0
  CONFIGURE Configure
  IMPORT make
  IMPORT_TARGETS
    "crypto=OpenSSL::Crypto"
    "ssl=OpenSSL::SSL"
  SYSTEM_PKGCONFIG
    "libcrypto:OpenSSL::Crypto"
    "libssl:OpenSSL::SSL"
  LINK_NAMES
    "crypto=OpenSSL::Crypto"
    "ssl=OpenSSL::SSL"
  TARGETS OpenSSL::SSL OpenSSL::Crypto
  CHECK_HEADER openssl/ssl.h
  CONFIGURE_ARGS
    # Into lib whatever the machine: its default is lib64 on some, and the
    # paths above are what this port promises.
    "--libdir=lib"
    # Where it looks for its configuration and certificates at run time: the
    # system's, not a directory inside this build that nothing will fill.
    "--openssldir=/etc/ssl"
    # Libraries to link, and nothing else: no shared objects, no command
    # line tool, no test programs, no manual pages to write.
    "no-shared"
    "no-apps"
    "no-tests"
    "no-docs"
    # Position-independent, so that it can go into a shared object of the
    # consumer's; on the platforms that build it that way anyway, a no-op.
    "-fPIC"
  CONFIGURE_CROSS
    "${cme_openssl_machine}"
    # The compiler named in CC already is the cross compiler, with its
    # target in the flags; a prefix would be put in front of it again.
    "--cross-compile-prefix="
)

function(cme_adapt_openssl source binary)
  # Where its headers are, for whoever links it: the checkout's, and the
  # ones Configure made from templates beside the objects -- opensslv.h and
  # configuration.h among them, which every other header includes.
  set(built "${CMAKE_BINARY_DIR}/_cme/openssl-build")
  foreach(cme_openssl_target OpenSSL::SSL OpenSSL::Crypto)
    if(TARGET ${cme_openssl_target})
      get_target_property(cme_openssl_real ${cme_openssl_target} ALIASED_TARGET)
      if(NOT cme_openssl_real)
        set(cme_openssl_real ${cme_openssl_target})
      endif()
      target_include_directories(${cme_openssl_real} INTERFACE
        "$<BUILD_INTERFACE:${built}/include>" "$<BUILD_INTERFACE:${source}/include>")
    endif()
  endforeach()
  # What each archive calls that is not in it: libssl calls libcrypto, and
  # libcrypto calls the thread library and the dynamic loader (for its
  # providers and engines). A static archive says none of that itself.
  find_package(Threads REQUIRED)
  if(TARGET OpenSSL::SSL AND TARGET OpenSSL::Crypto)
    get_target_property(cme_openssl_ssl OpenSSL::SSL ALIASED_TARGET)
    if(NOT cme_openssl_ssl)
      set(cme_openssl_ssl OpenSSL::SSL)
    endif()
    target_link_libraries(${cme_openssl_ssl} INTERFACE OpenSSL::Crypto)
  endif()
  if(TARGET OpenSSL::Crypto)
    get_target_property(cme_openssl_crypto OpenSSL::Crypto ALIASED_TARGET)
    if(NOT cme_openssl_crypto)
      set(cme_openssl_crypto OpenSSL::Crypto)
    endif()
    target_link_libraries(${cme_openssl_crypto} INTERFACE Threads::Threads ${CMAKE_DL_LIBS})
  endif()
  # And what FindOpenSSL sets, for the projects that read variables.
  cme_export_variable(OpenSSL OPENSSL_FOUND TRUE)
  cme_export_variable(OpenSSL OpenSSL_FOUND TRUE)
  cme_export_variable(OpenSSL OPENSSL_VERSION 3.5.8)
  cme_export_variable(OpenSSL OPENSSL_SSL_LIBRARY OpenSSL::SSL)
  cme_export_variable(OpenSSL OPENSSL_SSL_LIBRARIES OpenSSL::SSL)
  cme_export_variable(OpenSSL OPENSSL_CRYPTO_LIBRARY OpenSSL::Crypto)
  cme_export_variable(OpenSSL OPENSSL_CRYPTO_LIBRARIES OpenSSL::Crypto)
  cme_export_variable(OpenSSL OPENSSL_LIBRARIES "OpenSSL::SSL;OpenSSL::Crypto")
  cme_export_variable(OpenSSL OPENSSL_INCLUDE_DIR "${source}/include")
endfunction()
