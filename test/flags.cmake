# What the store makes of a set of flags.
#
#   cmake -P test/flags.cmake
#
# The question this answers is when two builds are the same build. A library
# compiled at -O2 and one compiled at -O3 are not interchangeable, and
# neither are one with link-time optimisation and one without -- so those
# have to come out different here. Order, repetition and warnings have to
# come out the same, or every build that spells its flags in another order
# rebuilds the world.
include("${CMAKE_CURRENT_LIST_DIR}/../cmake-everywhere.cmake" OPTIONAL
        RESULT_VARIABLE included)

set(problems 0)

function(same first second)
  cme_significant_flags(one "${first}")
  cme_significant_flags(two "${second}")
  if(NOT one STREQUAL two)
    message("  these should be one library and are not:")
    message("    [${first}] -> [${one}]")
    message("    [${second}] -> [${two}]")
    math(EXPR problems "${problems} + 1")
    set(problems "${problems}" PARENT_SCOPE)
  endif()
endfunction()

function(different first second)
  cme_significant_flags(one "${first}")
  cme_significant_flags(two "${second}")
  if(one STREQUAL two)
    message("  these should be two libraries and are not:")
    message("    [${first}] and [${second}] are both [${one}]")
    math(EXPR problems "${problems} + 1")
    set(problems "${problems}" PARENT_SCOPE)
  endif()
endfunction()

# The same build, written differently.
same("-O2 -DNDEBUG" "-DNDEBUG -O2")
same("-O2 -DNDEBUG" "-O2 -DNDEBUG -Wall -Wextra -Wno-unused")
same("-O2 -DNDEBUG" "-O1 -O2 -DNDEBUG")
same("-O2" "-O2 -MD -MF thing.d -MT thing.o")
same("-O2 -isystem /a -isystem /b" "-O2 -isystem /b -isystem /a")
same("-O2 -DFOO" "-O2 -D FOO")
same("-O1" "-O")
same("-O2 -fomit-frame-pointer -fno-omit-frame-pointer"
     "-O2 -fno-omit-frame-pointer")

# Not the same build, however it is written.
different("-O2" "-O3")
different("-O2" "-Os")
different("-O2 -DNDEBUG" "-O2")
different("-O2 -flto=full" "-O2")
different("-O2 -flto=full" "-O2 -flto=thin")
different("-O2 -flto=full" "-O2 -flto=full -fno-lto")
different("-O2 -march=x86-64-v3" "-O2")
different("-O2 -fvisibility=hidden" "-O2 -fvisibility=default")

# What the compiler says its level already turns on.
#
# With that answer, a flag the level sets the same way says nothing and two
# builds that differ only by it are one library. Without it -- clang, which
# has no such answer to give -- every flag counts, which is the safe way to
# be wrong.
set(CME_OPTIMISATION_DEFAULTS "tree-vectorize=enabled;unroll-loops=disabled")
same("-O3 -ftree-vectorize" "-O3")
same("-O3 -fno-unroll-loops" "-O3")
different("-O3 -funroll-loops" "-O3")
different("-O3 -fno-tree-vectorize" "-O3")
set(CME_OPTIMISATION_DEFAULTS "")
different("-O3 -ftree-vectorize" "-O3")

if(problems GREATER 0)
  message(FATAL_ERROR "${problems} answers about flags are wrong")
endif()
message("  ok    what the store makes of a set of flags")
