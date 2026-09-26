# A wrapper around OpenSSL's own build, and it says so first: OpenSSL is
# configured by a perl script of its own (Configure), which writes the
# Makefile and generates part of its sources -- the assembly for each
# machine among them -- as it goes. There is nothing to read before it has
# run, and what it would compile cannot be taken out of its make without
# running its generators too. So it is configured, made and installed into a
# prefix of this build's choosing, and the two archives are imported. Built
# outside the graph, with this build's compiler and flags.
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
  # The libraries and headers, and not its configuration directory: that
  # is /etc/ssl below, where it looks at run time, and a build does not
  # write there.
  CONFIGURE_INSTALL install_sw
  INSTALLED_TARGETS
    "lib/libcrypto.a=OpenSSL::Crypto"
    "lib/libssl.a=OpenSSL::SSL"
  INSTALLED_INCLUDE include
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
  # What each archive calls that is not in it: libssl calls libcrypto, and
  # libcrypto calls the thread library and the dynamic loader (for its
  # providers and engines). A static archive says none of that itself.
  find_package(Threads REQUIRED)
  if(TARGET OpenSSL::SSL AND TARGET OpenSSL::Crypto)
    set_property(TARGET OpenSSL::SSL APPEND PROPERTY INTERFACE_LINK_LIBRARIES OpenSSL::Crypto)
  endif()
  if(TARGET OpenSSL::Crypto)
    set_property(TARGET OpenSSL::Crypto APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                 Threads::Threads ${CMAKE_DL_LIBS})
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
  if(CME_INSTALLED_openssl)
    cme_export_variable(OpenSSL OPENSSL_INCLUDE_DIR "${CME_INSTALLED_openssl}/include")
  endif()
endfunction()
