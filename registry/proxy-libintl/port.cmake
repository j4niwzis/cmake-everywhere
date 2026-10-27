# GLib's own fallback for platforms without gettext, including Android.
# Its Meson build uses STUB_ONLY: untranslated messages and plural selection,
# as appropriate for the GLib source recipe's disabled native language support.
cme_declare_port(
  NAME proxy-libintl PROVIDES proxy-libintl
  VERSION 0.4 GITHUB_REPOSITORY frida/proxy-libintl
  GIT_TAG c03e1a74b17fa7ec467e110130775409e4828a4c
  LICENSE LGPL-2.0-or-later IMPORT meson SYSTEM NEVER
  IMPORT_TARGETS "intl=Intl::Intl" SYSTEM_PKGCONFIG "proxy-libintl:Intl::Intl"
  LINK_NAMES "intl=Intl::Intl" TARGETS Intl::Intl CHECK_HEADER libintl.h
)

function(cme_adapt_proxy-libintl source binary)
  target_include_directories(proxy-libintl_intl INTERFACE "$<BUILD_INTERFACE:${source}>")
  target_compile_definitions(proxy-libintl_intl INTERFACE G_INTL_STATIC_COMPILATION)
endfunction()
