# Missing upstream: nothing. Vulkan-Headers is headers and a CMake build
# that installs them, and it is a subdirectory of another build without
# complaint.
#
# Headers, not a loader and not a driver. Skia includes vulkan_core.h from
# its AHardwareBuffer code on Android whether or not it was built with the
# Vulkan backend, and a build that only wanted GL still has to have them.
cme_declare_port(
  NAME vulkan-headers
  PROVIDES VulkanHeaders vulkan-headers Vulkan
  VERSION 1.4.303
  GITHUB_REPOSITORY KhronosGroup/Vulkan-Headers
  GIT_TAG v1.4.303
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE Apache-2.0 MIT
  SYSTEM_PKGCONFIG "vulkan:Vulkan::Headers"
  TARGETS Vulkan::Headers
  CHECK_HEADER vulkan/vulkan_core.h
  OPTIONS
    "VULKAN_HEADERS_ENABLE_MODULE OFF"
    "VULKAN_HEADERS_ENABLE_TESTS OFF"
    "VULKAN_HEADERS_ENABLE_INSTALL OFF"
)

function(cme_adapt_vulkan-headers source binary)
  cme_export_variable(VulkanHeaders VULKAN_HEADERS_INCLUDE_DIRS
                      "${source}/include")
  cme_export_variable(VulkanHeaders Vulkan_INCLUDE_DIRS "${source}/include")
endfunction()
