# The drivers themselves.
#
# Mesa is what turns a draw call into work on a GPU, and on Linux it is
# every GPU that is not NVIDIA's own: AMD, Intel, Adreno, Mali, VideoCore,
# Vivante, and NVIDIA's cards through the drivers written for them without
# NVIDIA's help. It is normally a set of shared objects that libGL and the
# Vulkan loader open by name at run time.
#
# Here it is archives. A program that links this contains the drivers, and
# nothing is opened at run time -- which is what a single-file build needs,
# and which Mesa is closer to allowing than it looks: the gallium target
# already links every gallium driver into one object, and EGL already links
# that target and calls into it rather than looking for it. What was in the
# way was the word shared_library on four kinds of target, which the patch
# beside this changes to library.
#
# Vulkan is a second half of the same idea and needs one thing more: every
# driver defines vk_icdGetInstanceProcAddr, so two of them in one program is
# two definitions of one symbol. The consumer's build is what resolves that,
# by keeping one global name per driver; this port's job is to produce the
# archives.
cme_declare_port(
  NAME mesa
  PROVIDES Mesa mesa
  VERSION 26.2.2
  GIT_REPOSITORY https://gitlab.freedesktop.org/mesa/mesa.git
  GIT_TAG mesa-26.2.2
  GIT_TAG_TEMPLATE "mesa-@VERSION@"
  LICENSE MIT
  IMPORT meson
  PATCHES patches/0001-let-what-must-be-an-archive-be-an-archive.patch
  # What the kernel side and the window systems are. libdrm speaks to the
  # driver in the kernel; the rest is how a rendered image reaches a screen.
  DEPENDS libdrm libxcb wayland wayland-protocols expat zlib
  IMPORT_TARGETS
    "EGL=Mesa::EGL"
    "gallium_dri=Mesa::gallium"
  SYSTEM_PKGCONFIG "egl:Mesa::EGL"
  LINK_NAMES "EGL=Mesa::EGL"
  TARGETS Mesa::EGL
  CHECK_HEADER EGL/egl.h
  OPTIONS
    # Archives, which is the whole point.
    "default_library static"
    # No dispatch library to be found at run time, and no vendor-neutral
    # dispatch either: glvnd exists to choose between an NVIDIA driver and
    # this one at run time, by opening both.
    "glvnd disabled"
    "gbm enabled"
    "egl enabled"
    "opengl true"
    "gles1 disabled"
    "gles2 enabled"
    # GLX is the X11 way of getting a context, and it needs libX11 rather
    # than the connection this build has. EGL does the same job on both
    # window systems.
    "glx disabled"
    "platforms x11,wayland"
    # Nothing that is not a driver: no video acceleration frontends, no
    # OpenCL, no tools, no tests.
    "gallium-va disabled"
    "gallium-vdpau disabled"
    "gallium-rusticl false"
    "gallium-opencl disabled"
    "video-codecs ''"
    "build-tests false"
    "install-mesa-clc disabled"
    "install-precomp-compiler disabled"
    "llvm disabled"
    "shared-llvm disabled"
    "gallium-drivers ''"
    "vulkan-drivers ''"
)

# The drivers, one feature each: what a build asks for is what it carries,
# and what it carries is what it can draw on.
#
# The gallium ones have no target of their own: they end up inside the one
# gallium object, which EGL links, so asking for the feature is the whole of
# it. Each Vulkan driver is a target, because a Vulkan driver is a thing a
# program picks between at run time and this is where the picking starts.
#
# Each names the kernel wrapper it speaks through, because a driver without
# it compiles and then cannot open a device.

cme_port_feature(mesa gl-amd
  SUMMARY "OpenGL on AMD, through radeonsi"
  DEPENDS "libdrm[amdgpu]" llvm
  OPTIONS "gallium-drivers +radeonsi" "llvm enabled")

cme_port_feature(mesa gl-intel
  SUMMARY "OpenGL on Intel, through iris"
  DEPENDS "libdrm[intel]"
  OPTIONS "gallium-drivers +iris")

cme_port_feature(mesa gl-nouveau
  SUMMARY "OpenGL on NVIDIA, through nouveau"
  DEPENDS "libdrm[nouveau]"
  OPTIONS "gallium-drivers +nouveau")

cme_port_feature(mesa gl-adreno
  SUMMARY "OpenGL on Adreno, through freedreno"
  DEPENDS "libdrm[freedreno]"
  OPTIONS "gallium-drivers +freedreno")

cme_port_feature(mesa gl-mali
  SUMMARY "OpenGL on Mali, through panfrost"
  OPTIONS "gallium-drivers +panfrost")

cme_port_feature(mesa gl-broadcom
  SUMMARY "OpenGL on VideoCore, through v3d"
  OPTIONS "gallium-drivers +v3d,vc4")

cme_port_feature(mesa gl-software
  SUMMARY "OpenGL on the processor, through llvmpipe"
  DEPENDS llvm
  OPTIONS "gallium-drivers +llvmpipe,softpipe" "llvm enabled")

cme_port_feature(mesa vulkan-amd
  SUMMARY "Vulkan on AMD, through RADV"
  DEPENDS "libdrm[amdgpu]"
  OPTIONS "vulkan-drivers +amd"
  IMPORT_TARGETS "vulkan_radeon=Mesa::vulkan-amd")

cme_port_feature(mesa vulkan-intel
  SUMMARY "Vulkan on Intel, through ANV"
  DEPENDS "libdrm[intel]"
  OPTIONS "vulkan-drivers +intel"
  IMPORT_TARGETS "vulkan_intel=Mesa::vulkan-intel")

cme_port_feature(mesa vulkan-nouveau
  SUMMARY "Vulkan on NVIDIA Turing and later, through NVK"
  DEPENDS "libdrm[nouveau]"
  OPTIONS "vulkan-drivers +nouveau"
  IMPORT_TARGETS "vulkan_nouveau=Mesa::vulkan-nouveau")

cme_port_feature(mesa vulkan-adreno
  SUMMARY "Vulkan on Adreno, through Turnip"
  DEPENDS "libdrm[freedreno]"
  OPTIONS "vulkan-drivers +freedreno"
  IMPORT_TARGETS "vulkan_freedreno=Mesa::vulkan-adreno")

cme_port_feature(mesa vulkan-mali
  SUMMARY "Vulkan on Mali, through PanVK"
  OPTIONS "vulkan-drivers +panfrost"
  IMPORT_TARGETS "vulkan_panfrost=Mesa::vulkan-mali")

cme_port_feature(mesa vulkan-broadcom
  SUMMARY "Vulkan on VideoCore, through V3DV"
  OPTIONS "vulkan-drivers +broadcom"
  IMPORT_TARGETS "vulkan_broadcom=Mesa::vulkan-broadcom")

cme_port_feature(mesa vulkan-software
  SUMMARY "Vulkan on the processor, through lavapipe"
  DEPENDS llvm
  OPTIONS "vulkan-drivers +swrast" "llvm enabled"
  IMPORT_TARGETS "vulkan_lvp=Mesa::vulkan-software")
