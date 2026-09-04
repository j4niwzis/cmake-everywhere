# The kernel's side of a graphics driver: the ioctls, and one small library
# per family that wraps them.
#
# Every Mesa driver links the one for its hardware -- radeonsi and RADV
# amdgpu, iris intel, freedreno and Turnip freedreno -- and the core library
# is what enumerates the devices a machine has. That enumeration reads
# sysfs, not udev, which is what lets a static program find a GPU without
# opening anything.
#
# Each family is a feature rather than always built, because a build that
# names one driver has no use for the others' ioctl wrappers.
cme_declare_port(
  NAME libdrm
  PROVIDES libdrm DRM
  VERSION 2.4.125
  GIT_REPOSITORY https://gitlab.freedesktop.org/mesa/drm.git
  GIT_TAG libdrm-2.4.125
  GIT_TAG_TEMPLATE "libdrm-@VERSION@"
  LICENSE MIT
  IMPORT meson
  IMPORT_TARGETS "drm=DRM::drm"
  SYSTEM_PKGCONFIG "libdrm:DRM::drm"
  LINK_NAMES "drm=DRM::drm"
  TARGETS DRM::drm
  CHECK_HEADER xf86drm.h
  # None of the tools, none of the tests: what a consumer links is the
  # library, and everything else here wants cairo, or a display to run on.
  OPTIONS
    "cairo-tests disabled"
    "man-pages disabled"
    "valgrind disabled"
    "tests false"
    "install-test-programs false"
)

cme_port_feature(libdrm amdgpu
  SUMMARY "the ioctl wrapper for AMD's kernel driver"
  OPTIONS "amdgpu enabled"
  IMPORT_TARGETS "drm_amdgpu=DRM::amdgpu")

cme_port_feature(libdrm intel
  SUMMARY "the ioctl wrapper for Intel's kernel driver"
  OPTIONS "intel enabled"
  IMPORT_TARGETS "drm_intel=DRM::intel")

cme_port_feature(libdrm nouveau
  SUMMARY "the ioctl wrapper for the open NVIDIA kernel driver"
  OPTIONS "nouveau enabled"
  IMPORT_TARGETS "drm_nouveau=DRM::nouveau")

cme_port_feature(libdrm radeon
  SUMMARY "the ioctl wrapper for AMD's older kernel driver"
  OPTIONS "radeon enabled"
  IMPORT_TARGETS "drm_radeon=DRM::radeon")

cme_port_feature(libdrm freedreno
  SUMMARY "the ioctl wrapper for Adreno's kernel driver"
  OPTIONS "freedreno enabled"
  IMPORT_TARGETS "drm_freedreno=DRM::freedreno")

cme_port_feature(libdrm etnaviv
  SUMMARY "the ioctl wrapper for Vivante's kernel driver"
  OPTIONS "etnaviv enabled"
  IMPORT_TARGETS "drm_etnaviv=DRM::etnaviv")
