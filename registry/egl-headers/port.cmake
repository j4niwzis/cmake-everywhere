# EGL's headers, and the Khronos platform header they include: what a
# program compiles against to call EGL. No library: SDL, the reason this
# port is here, loads libEGL itself when a window first draws
# (SDL_LoadObject), so the headers are its whole dependency on EGL -- and a
# machine that runs the program has the library its GPU driver came with.
#
# The registry publishes no releases; this names a commit.
cme_declare_port(
  NAME egl-headers
  PROVIDES EGL egl-headers
  VERSION 0.0.0
  GITHUB_REPOSITORY KhronosGroup/EGL-Registry
  GIT_TAG 8e56e86e65687697ef54114cdb1afabdfac756bf
  OVERLAY overlay
  LICENSE Apache-2.0 MIT
  SYSTEM_PKGCONFIG "egl:EGL::Headers"
  TARGETS EGL::Headers
  CHECK_HEADER EGL/egl.h
)
function(cme_adapt_egl-headers source binary)
  cme_export_variable(EGL EGL_FOUND TRUE)
  cme_export_variable(EGL EGL_INCLUDE_DIRS "${source}/api")
endfunction()
