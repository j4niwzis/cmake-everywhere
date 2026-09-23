# What a store entry keeps of a tree with links in it.
#
#   cmake -P test/store-copy.cmake
#
# An entry is kept to be used where the sources it was built from are not,
# and a header prefix is a link into those sources: Skia's skia/ is a link to
# its checkout's include/. Copied as a link it survives exactly as long as
# the checkout does. This keeps a tree with every kind of link in it, takes
# away everything the links pointed at, and asks what is left.
include("${CMAKE_CURRENT_LIST_DIR}/../cmake/store-copy.cmake")

set(work "${CMAKE_CURRENT_BINARY_DIR}/store-copy-check")
file(REMOVE_RECURSE "${work}")
file(MAKE_DIRECTORY "${work}/source/include/core" "${work}/offered")
file(WRITE "${work}/source/include/core/Canvas.h" "// a header\n")
file(WRITE "${work}/source/include/flat.h" "// flat\n")
file(WRITE "${work}/offered/own.h" "// not a link\n")
# A directory offered under another name, the way cme_header_prefix does it.
file(CREATE_LINK "${work}/source/include" "${work}/offered/named" SYMBOLIC)
# The same, relative.
file(CREATE_LINK "../source/include" "${work}/offered/relative" SYMBOLIC)
# One file.
file(CREATE_LINK "${work}/source/include/flat.h" "${work}/offered/one.h"
     SYMBOLIC)
# And a link to nothing at all.
file(CREATE_LINK "${work}/nowhere" "${work}/offered/gone" SYMBOLIC)

cme_store_copy("${work}/offered" "${work}/entry")
file(REMOVE_RECURSE "${work}/source" "${work}/offered")

set(problems 0)
function(kept path)
  if(IS_SYMLINK "${work}/entry/${path}" OR NOT EXISTS "${work}/entry/${path}")
    message("  not kept as a file: ${path}")
    math(EXPR problems "${problems} + 1")
    set(problems "${problems}" PARENT_SCOPE)
  endif()
endfunction()
kept(own.h)
kept(named/core/Canvas.h)
kept(named/flat.h)
kept(relative/core/Canvas.h)
kept(one.h)
foreach(path named relative)
  if(IS_SYMLINK "${work}/entry/${path}")
    message("  still a link: ${path}")
    math(EXPR problems "${problems} + 1")
  endif()
endforeach()
if(EXISTS "${work}/entry/gone" OR IS_SYMLINK "${work}/entry/gone")
  message("  a link to nothing was kept: gone")
  math(EXPR problems "${problems} + 1")
endif()
file(REMOVE_RECURSE "${work}")

if(problems)
  message(FATAL_ERROR "${problems} things a store entry kept are not there")
endif()
message("  ok    what a store entry keeps of a tree with links in it")
