# The allocator as sources, because that is what asks for it.
#
# A Vulkan program allocates memory itself: the driver hands out whole
# VkDeviceMemory blocks and there is a small limit on how many, so something
# has to suballocate. This library is what everyone uses for that, and it is
# a single header compiled by whoever includes it.
#
# What needs it here is Skia, which will not build a Vulkan backend without
# one: it compiles this header into itself with its own settings -- the
# Vulkan version it locks its API to, whether the mutex is the standard
# library's -- and offers the result behind its own allocator interface. A
# built copy of this library cannot answer that, because there is nothing to
# build: the whole of it is a header, and which build of it a program has is
# decided by the defines in effect where that header was included.
#
# So the port's result is the tree. The skia port says
#
#   TREES "third_party/externals/vulkanmemoryallocator=vulkan-memory-allocator-sources"
#
# and the sources arrive the way every other source here arrives, as an
# archive with a digest of it.
#
# The commit Skia names rather than the release before it: what this has to
# match is the tree Skia's own build expects, and Skia pins a commit.
cme_declare_port(
  NAME vulkan-memory-allocator-sources
  PROVIDES vulkan-memory-allocator-sources
  VERSION 3.4.0
  URL "https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/archive/eb744ea7a2b17040121b4bbb4d6f9e8a77e3cae7.tar.gz"
  URL_HASH "SHA256=882fcdc62506062c8f7b1e05194ac9d71b7df52ddf10d51d6bd31ce1eb8717a2"
  LICENSE MIT
  # There is nothing to build and nothing to find installed. A machine that
  # has vk_mem_alloc.h in /usr/include has the header, not a build of it, and
  # what the consumer needs is to compile it themselves.
  SOURCE_ONLY YES
)
