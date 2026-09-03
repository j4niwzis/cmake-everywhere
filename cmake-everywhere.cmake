# cmake-everywhere: one find_package() call, everything below it resolved.
#
# Included before project() through CMAKE_PROJECT_TOP_LEVEL_INCLUDES, which
# is the only place a dependency provider may be installed. From then on
# every find_package() in the whole configuration -- including the ones a
# third-party project makes inside itself -- is offered to this provider
# first. That is what keeps a consumer's CMakeLists at one call: freetype's
# own find_package(ZLIB) is answered here rather than in the consumer.

cmake_minimum_required(VERSION 3.24)
include_guard(GLOBAL)

set(CME_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "cmake-everywhere root")

# Sources are kept outside the build directory, so a second build directory
# does not fetch Skia's 65 MiB again, and deleting one does not throw the
# fetching away. CPM reads this; a value already set anywhere is left alone.
if(NOT CPM_SOURCE_CACHE AND NOT DEFINED ENV{CPM_SOURCE_CACHE})
  if(DEFINED ENV{XDG_CACHE_HOME})
    set(CPM_SOURCE_CACHE "$ENV{XDG_CACHE_HOME}/cmake-everywhere/sources"
        CACHE PATH "Where fetched sources are kept")
  elseif(DEFINED ENV{HOME})
    set(CPM_SOURCE_CACHE "$ENV{HOME}/.cache/cmake-everywhere/sources"
        CACHE PATH "Where fetched sources are kept")
  endif()
endif()

# Compiling is the expensive part, not fetching. A compiler cache makes a
# second build of the same library a copy rather than a compile, which is the
# difference between a minute and half an hour on something like Skia. Ports
# are given it; the project doing the consuming is left exactly as it
# configured itself.
# Built libraries, kept outside any build directory and found again by what
# they were built from.
#
# The name of an entry is a hash of everything that could have changed the
# result: which library, at which version, from which archive, with which
# features, with which options, by which compiler for which target with which
# flags -- and the same for everything underneath it. Two configurations that
# differ anywhere differ in the name, so a hit is a hit on the same thing
# rather than on the same words.
#
# What must never happen is a hit on something that is not the same. So when
# in doubt an input goes into the hash: a hash that is too specific costs a
# rebuild, and one that is not specific enough costs an afternoon.
# The store is off unless it is asked for. A directory that outlives the
# build, that another build reads from, and that grows without anyone
# deciding to keep it, is not something to switch on for someone by default:
# a wrong reuse is the one failure this mechanism can cause and it is the
# expensive one. Asked for, it is stated in the log.
#
# Three ways to ask, in this order:
#
#   -DCME_STORE=/path      keep them here
#   -DCME_STORE_ENABLED=ON keep them in the default location
#   CME_STORE=/path        the same, from the environment, for a machine
#   CME_STORE=ON           where every build should use one
#
set(CME_STORE "" CACHE PATH
  "Where built libraries are kept between builds, or empty for none")
option(CME_STORE_ENABLED
  "Keep built libraries between builds, in the default location" OFF)
if(NOT CME_STORE AND DEFINED ENV{CME_STORE})
  set(cme_store_env "$ENV{CME_STORE}")
  if(cme_store_env MATCHES "^(1|ON|on|YES|yes|TRUE|true)$")
    set(CME_STORE_ENABLED ON)
  elseif(NOT cme_store_env MATCHES "^(0|OFF|off|NO|no|FALSE|false)$")
    set(CME_STORE "${cme_store_env}" CACHE PATH "" FORCE)
    message(STATUS
      "cmake-everywhere: built libraries are kept in ${CME_STORE}, which "
      "CME_STORE in the environment names")
  endif()
  unset(cme_store_env)
endif()
if(NOT CME_STORE AND CME_STORE_ENABLED)
  if(DEFINED ENV{XDG_CACHE_HOME})
    set(CME_STORE "$ENV{XDG_CACHE_HOME}/cmake-everywhere/store" CACHE PATH "" FORCE)
  elseif(DEFINED ENV{HOME})
    set(CME_STORE "$ENV{HOME}/.cache/cmake-everywhere/store" CACHE PATH "" FORCE)
  else()
    message(WARNING
      "cmake-everywhere: CME_STORE_ENABLED is on and there is no HOME or "
      "XDG_CACHE_HOME to put a store in. Name one with -DCME_STORE=")
  endif()
  if(CME_STORE)
    message(STATUS
      "cmake-everywhere: built libraries are kept in ${CME_STORE}")
  endif()
endif()

# How much of the environment a stored library has to have been built with
# before it may be reused.
#
# Two different things are mixed together in what decides a build. What the
# library *is* -- which library, which version, which sources, which features,
# which options -- is identity, and a difference there is a different library
# whatever the mode. The rest is the machine it was built on, and how much of
# that has to match is a judgement rather than a fact.
#
#   EXACT       everything, down to the exact flags
#   COMPATIBLE  what decides whether two objects can be linked and behave:
#               the compiler and its major version, the target, the sysroot,
#               the toolchain file, position independence, the build type
#   LOOSE       only what makes the objects usable at all: the target and
#               which compiler it was
#
# In every mode the whole environment is recorded and compared, and anything
# that differs is said out loud. A reuse that is not exact is a decision, and
# a decision that nobody is told about is a surprise later.
# Whether an entry has to be usable somewhere else.
#
# An entry points at the headers that were already in a library's source tree
# rather than copying them, which is cheap and true where it was built. A
# store that travels -- to another machine, into a container, between two CI
# jobs -- needs those headers inside it, and pays for them in disk.
set(CME_STORE_PORTABLE OFF CACHE BOOL
  "Copy every header an entry needs into it, so the entry can be used \
somewhere the sources are not")

set(CME_STORE_MATCH "COMPATIBLE" CACHE STRING
  "How closely a stored library has to match: EXACT, COMPATIBLE or LOOSE")
set_property(CACHE CME_STORE_MATCH PROPERTY STRINGS EXACT COMPATIBLE LOOSE)

# Everything about this build that a compiled library could depend on, as
# name and value, so that a difference can be named rather than counted.
# The code that decides what a build contains, as one number.
#
# Everything else in the environment is about the machine and the toolchain,
# and none of it changes when this repository does. So a fix to an importer
# -- one that put objects into an archive they had been missing from -- left
# the name of the result exactly as it was, and the store answered a build
# that had just been fixed with the library from before the fix. The same
# undefined symbols came back, out of a path with `store` in it.
#
# What a port says is already part of the name it is kept under. What reads
# the port is this.
function(cme_recipe_digest out)
  get_property(digest GLOBAL PROPERTY CME_RECIPE_DIGEST)
  if(NOT digest)
    file(GLOB files "${CME_DIR}/cmake-everywhere.cmake"
                    "${CME_DIR}/cmake/*.cmake" "${CME_DIR}/cmake/*.py")
    list(SORT files)
    set(text "")
    foreach(file IN LISTS files)
      file(SHA256 "${file}" one)
      string(APPEND text "${one}")
    endforeach()
    string(SHA256 digest "${text}")
    string(SUBSTRING "${digest}" 0 16 digest)
    set_property(GLOBAL PROPERTY CME_RECIPE_DIGEST "${digest}")
  endif()
  set(${out} "${digest}" PARENT_SCOPE)
endfunction()

function(cme_environment_pairs out)
  set(pairs "")
  foreach(name IN ITEMS
      CMAKE_SYSTEM_NAME CMAKE_SYSTEM_PROCESSOR
      CMAKE_C_COMPILER_ID CMAKE_C_COMPILER_VERSION CMAKE_C_COMPILER
      CMAKE_CXX_COMPILER_ID CMAKE_CXX_COMPILER_VERSION CMAKE_CXX_COMPILER
      CMAKE_CXX_COMPILER_TARGET CMAKE_C_COMPILER_TARGET
      CMAKE_BUILD_TYPE CMAKE_C_FLAGS CMAKE_CXX_FLAGS
      CMAKE_C_FLAGS_RELEASE CMAKE_CXX_FLAGS_RELEASE
      CMAKE_SYSROOT CMAKE_POSITION_INDEPENDENT_CODE
      CMAKE_INTERPROCEDURAL_OPTIMIZATION BUILD_SHARED_LIBS
      CMAKE_CXX_STANDARD CMAKE_OSX_DEPLOYMENT_TARGET CMAKE_OSX_ARCHITECTURES)
    list(APPEND pairs "${name}=${${name}}")
  endforeach()
  # A toolchain file decides most of the above and can decide more, so it
  # counts as a whole rather than by what it happens to set.
  set(toolchain "")
  if(CMAKE_TOOLCHAIN_FILE AND EXISTS "${CMAKE_TOOLCHAIN_FILE}")
    file(SHA256 "${CMAKE_TOOLCHAIN_FILE}" toolchain)
  endif()
  list(APPEND pairs "TOOLCHAIN=${toolchain}")
  cme_recipe_digest(recipe)
  list(APPEND pairs "CME=${recipe}")
  set(${out} "${pairs}" PARENT_SCOPE)
endfunction()

# The compiler's major version. A patch release of the same compiler does not
# make a library it built unusable, and treating it as though it did means
# rebuilding everything on a Tuesday.
function(cme_major out version)
  string(REGEX REPLACE "^([0-9]+).*$" "\\1" major "${version}")
  set(${out} "${major}" PARENT_SCOPE)
endfunction()

# The part of the environment the name is made from, which is the part that
# has to match.
function(cme_environment_key out)
  if(CME_STORE_MATCH STREQUAL "EXACT")
    cme_environment_pairs(pairs)
    list(JOIN pairs "|" text)
    set(${out} "${text}" PARENT_SCOPE)
    return()
  endif()

  cme_major(c_major "${CMAKE_C_COMPILER_VERSION}")
  cme_major(cxx_major "${CMAKE_CXX_COMPILER_VERSION}")
  set(toolchain "")
  if(CMAKE_TOOLCHAIN_FILE AND EXISTS "${CMAKE_TOOLCHAIN_FILE}")
    file(SHA256 "${CMAKE_TOOLCHAIN_FILE}" toolchain)
  endif()

  if(CME_STORE_MATCH STREQUAL "LOOSE")
    set(parts "${CMAKE_SYSTEM_NAME}" "${CMAKE_SYSTEM_PROCESSOR}"
              "${CMAKE_C_COMPILER_ID}" "${CMAKE_CXX_COMPILER_ID}"
              "${CMAKE_CXX_COMPILER_TARGET}" "${CMAKE_SYSROOT}"
              "${CMAKE_INTERPROCEDURAL_OPTIMIZATION}" "${BUILD_SHARED_LIBS}"
              "${toolchain}")
  else()
    set(parts "${CMAKE_SYSTEM_NAME}" "${CMAKE_SYSTEM_PROCESSOR}"
              "${CMAKE_C_COMPILER_ID}" "${c_major}"
              "${CMAKE_CXX_COMPILER_ID}" "${cxx_major}"
              "${CMAKE_CXX_COMPILER_TARGET}" "${CMAKE_C_COMPILER_TARGET}"
              "${CMAKE_SYSROOT}" "${CMAKE_POSITION_INDEPENDENT_CODE}"
              # Objects compiled for link-time optimisation are not the same
              # objects, and a library built one way is not the library built
              # the other -- whatever else matches.
              "${CMAKE_INTERPROCEDURAL_OPTIMIZATION}" "${BUILD_SHARED_LIBS}"
              "${CMAKE_CXX_STANDARD}" "${CMAKE_BUILD_TYPE}"
              "${CMAKE_OSX_DEPLOYMENT_TARGET}" "${CMAKE_OSX_ARCHITECTURES}"
              "${toolchain}")
  endif()
  # In every mode, including the loosest: this is not something about the
  # machine that a build can be forgiving about.
  cme_recipe_digest(recipe)
  list(APPEND parts "${recipe}")
  list(JOIN parts "|" text)
  set(${out} "${CME_STORE_MATCH}|${text}" PARENT_SCOPE)
endfunction()

# What was recorded when this was built against what is true now. Everything
# that differs is named; whether any of it matters was decided by the mode
# when the name was made.
function(cme_store_differences entry)
  if(NOT EXISTS "${entry}/environment.txt")
    return()
  endif()
  file(STRINGS "${entry}/environment.txt" recorded)
  cme_environment_pairs(now)
  set(differences "")
  foreach(pair IN LISTS recorded)
    if(NOT pair MATCHES "^([^=]+)=(.*)$")
      continue()
    endif()
    set(name "${CMAKE_MATCH_1}")
    set(was "${CMAKE_MATCH_2}")
    foreach(current IN LISTS now)
      if(current MATCHES "^${name}=(.*)$")
        if(NOT "${CMAKE_MATCH_1}" STREQUAL "${was}")
          list(APPEND differences "${name}: built with [${was}], now [${CMAKE_MATCH_1}]")
        endif()
        break()
      endif()
    endforeach()
  endforeach()
  if(differences)
    list(LENGTH differences count)
    message(STATUS
      "cmake-everywhere: reusing it across ${count} difference(s), because "
      "CME_STORE_MATCH is ${CME_STORE_MATCH}")
    foreach(difference IN LISTS differences)
      message(STATUS "    ${difference}")
    endforeach()
  endif()
endfunction()

# What the library is, as opposed to what it was built on. A difference here
# is a different library in any mode.
function(cme_identity_key out port version)
  cme_enabled_features(${port} features)
  cme_port_field(options ${port} OPTIONS)
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} OPTIONS)
    list(APPEND options ${extra})
    cme_feature_field(extra ${port} ${feature} GN_ARGS)
    list(APPEND options ${extra})
  endforeach()
  cme_port_field(gn_args ${port} GN_ARGS)
  list(APPEND options ${gn_args} ${CME_OPTIONS_${port}} ${CME_GN_ARGS_${port}})

  # The port file itself: changing what a port does has to change the name of
  # what it produces.
  set(recipe "")
  get_property(port_dir GLOBAL PROPERTY CME_PORT_${port}_DIR)
  if(port_dir)
    file(GLOB files "${port_dir}/*.cmake" "${port_dir}/patches/*")
    foreach(file IN LISTS files)
      file(SHA256 "${file}" digest)
      string(APPEND recipe "${digest}")
    endforeach()
  else()
    # A port a project declared in its own CMakeLists has no file of its own,
    # so what it said is hashed instead. Either way, changing what a port
    # does changes the name of what it produces.
    get_property(recipe GLOBAL PROPERTY CME_PORT_${port}_RECIPE)
  endif()

  # And everything underneath, by the same rule and in full. A version and a
  # feature list is not enough: editing zlib's port changes what zlib is, and
  # everything built against it is something else too.
  set(beneath "")
  cme_gn_dependency_ports_or_depends(${port} deps)
  foreach(dep IN LISTS deps)
    cme_effective_version(${dep} dep_version)
    cme_identity_key(dep_identity ${dep} "${dep_version}")
    list(APPEND beneath "${dep_identity}")
  endforeach()

  list(JOIN options "|" options)
  list(JOIN features "," features)
  list(JOIN beneath "|" beneath)
  set(${out} "${port}|${version}|${features}|${options}|${recipe}|${beneath}"
      PARENT_SCOPE)
endfunction()

# Dependencies of a port, including the ones a feature brought. Named apart
# from the one in gn.cmake because this is asked before a port is known to be
# a GN project at all.
function(cme_gn_dependency_ports_or_depends port out)
  cme_port_field(depends ${port} DEPENDS)
  cme_enabled_features(${port} features)
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} DEPENDS)
    list(APPEND depends ${extra})
  endforeach()
  set(result "")
  foreach(spec IN LISTS depends)
    cme_split_requirement("${spec}" dep unused unused_features)
    list(APPEND result "${dep}")
  endforeach()
  if(result)
    list(REMOVE_DUPLICATES result)
  endif()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

function(cme_store_key out port version)
  cme_identity_key(identity ${port} "${version}")
  cme_environment_key(environment)
  string(SHA256 digest "2|${identity}|${environment}")
  string(SUBSTRING "${digest}" 0 16 digest)
  set(${out} "${digest}" PARENT_SCOPE)
endfunction()

function(cme_store_entry out port version)
  if(NOT CME_STORE)
    set(${out} "" PARENT_SCOPE)
    return()
  endif()
  cme_store_key(key ${port} "${version}")
  set(${out} "${CME_STORE}/${port}/${version}-${key}" PARENT_SCOPE)
endfunction()

# A build with no network. Everything a build reads has to be in the source
# cache already, put there by a run that did have one -- which is what
# tools/prefetch is for. This is not an optimisation: some builders, flatpak
# among them, take the network away on purpose, and a build that quietly
# reaches for it there does not fail, it hangs and then fails obscurely.
option(CME_OFFLINE "Refuse to fetch anything; use what is in the cache" OFF)
if(CME_OFFLINE)
  if(NOT CPM_SOURCE_CACHE)
    message(FATAL_ERROR
      "cmake-everywhere: CME_OFFLINE and no CPM_SOURCE_CACHE. Offline means "
      "reading a cache somebody filled, so there has to be one.")
  endif()
  set(FETCHCONTENT_FULLY_DISCONNECTED ON CACHE BOOL "" FORCE)
  message(STATUS "cmake-everywhere: offline, reading ${CPM_SOURCE_CACHE}")
endif()

# Fetch and stop. Used by tools/prefetch to fill a cache for a build that
# will have no network, and useless for anything else: nothing is built, so
# nothing can be linked.
option(CME_FETCH_ONLY "Fetch what the ports name and build none of it" OFF)

set(CME_COMPILER_CACHE "AUTO" CACHE STRING
  "A compiler cache for ports: AUTO to use ccache when it is there, OFF, or \
the name of one")
if(CME_COMPILER_CACHE STREQUAL "AUTO")
  find_program(CME_CCACHE NAMES ccache sccache)
  if(CME_CCACHE)
    set(CME_COMPILER_CACHE "${CME_CCACHE}" CACHE STRING "" FORCE)
    message(STATUS "cmake-everywhere: ports are compiled through ${CME_CCACHE}")
  else()
    set(CME_COMPILER_CACHE "OFF" CACHE STRING "" FORCE)
  endif()
endif()

# FindBoost is gone, and this answers for Boost.
#
# CMake 3.30 removed FindBoost and warns at every find_package(Boost) until
# the policy is set. Every one of those calls is answered here, by ports,
# and never by FindBoost -- so the warning is about something that cannot
# happen, printed once per call, in a build that may make a hundred of them.
# It is set here rather than left for the project to set, because the project
# is not the one who decided FindBoost would not be used.
if(POLICY CMP0167)
  cmake_policy(SET CMP0167 NEW)
  set(CMAKE_POLICY_DEFAULT_CMP0167 NEW)
endif()

# And the same for a policy warning a port cannot fix. install() DESTINATION
# paths are normalised under CMP0177, and a released library whose
# cmake_minimum_required predates it warns for every install rule it has --
# rules this never runs, because a dependency's install rules are not the
# consumer's. The trees are not ours to correct, so they are configured with
# the answer rather than the question.
if(POLICY CMP0177)
  set(CMAKE_POLICY_DEFAULT_CMP0177 NEW)
endif()

# Every project() call in this configuration reads what the tree it is in
# carries, before its own first line. See cmake/source-ports.cmake.
list(APPEND CMAKE_PROJECT_INCLUDE_BEFORE "${CME_DIR}/cmake/source-ports.cmake")

include("${CME_DIR}/cmake/CPM.cmake")
include("${CME_DIR}/cmake/gn.cmake")
include("${CME_DIR}/cmake/cmakeproject.cmake")
include("${CME_DIR}/cmake/mesonproject.cmake")
include("${CME_DIR}/cmake/configureproject.cmake")

set(CME_REGISTRY "${CME_DIR}/registry" CACHE PATH
  "The ports that come with this. Overlays are searched before it.")

# Ports do not have to be ours, and that is the point.
#
# What makes CPM worth using is not that it is CMake and convenient. It is
# that a library needs nobody's permission: a git URL and a tag are enough,
# the repository already exists, and a project can depend on it this
# afternoon without an index accepting it first. A registry that only worked
# for what it contained would take exactly that away and hand it back as a
# queue.
#
# So there are three places a port comes from, searched in this order:
#
#   the project    -- cme_declare_port() written in your own CMakeLists,
#                     for a library nobody has ported and nobody needs to
#   an overlay     -- a directory of ports, or the URL of a repository of
#                     them, which anyone can publish and anyone can name
#   the registry   -- the ones that come with this
#
# The first one that names a port wins, so an overlay can correct a port
# here without waiting for us, and a project can correct an overlay without
# waiting for it. Nothing has to be merged anywhere for any of it to work.
set(CME_OVERLAYS "" CACHE STRING
  "Directories of ports, or URLs of repositories of them, searched before \
the bundled registry. A URL may end in #ref to pin it to a branch or tag.")
if(DEFINED ENV{XDG_CACHE_HOME})
  set(cme_overlay_default "$ENV{XDG_CACHE_HOME}/cmake-everywhere/overlays")
else()
  set(cme_overlay_default "$ENV{HOME}/.cache/cmake-everywhere/overlays")
endif()
set(CME_OVERLAY_CACHE "${cme_overlay_default}" CACHE PATH
  "Where overlay repositories are cloned")
# An overlay is cloned once and then left alone. A dependency tree that
# quietly changes under a project between two configures of the same source
# is worse than one that is out of date, and out of date is one flag away.
# An overlay pinned with #ref is never refreshed at all: it is pinned.
set(CME_OVERLAY_REFRESH OFF CACHE BOOL
  "Update overlays that were named without a ref before reading them")

# A library that needs libraries nobody has ported has to be able to say so
# itself, or every one of its consumers says it instead. Whatever it says is
# read after it is fetched and before it is configured, which is before its
# own find_package calls happen -- so a project names what it uses, and
# nothing underneath that leaks into it.
#
# A library that uses this already says it, in its own CMakeLists, and needs
# no file: those calls run at the right moment on their own. The file is for
# the ones that have never heard of any of this, and it can be put there by
# whoever declares them, with PORTS_FROM.
set(CME_SOURCE_PORTS ON CACHE BOOL
  "Read the port declarations a fetched source carries")

# And then the same declarations, without the fetching.
#
# Knowing what a library needs by cloning the library is backwards when the
# question is whether this machine already has it. So what a project declares
# is installed beside it, and a prefix that has the library has the
# declarations too: share/cmake-everywhere/ports/<name>/port.cmake. No index,
# no server, no clone -- it arrives with the package it describes.
set(CME_SYSTEM_PORTS ON CACHE BOOL
  "Read port declarations installed in the prefixes")
set(CME_EXPORT_PORTS ON CACHE BOOL
  "Install the ports this project declares, beside this project")
set(CME_EXPORT_DESTINATION "share/cmake-everywhere/ports" CACHE STRING
  "Where a port is installed to, under the prefix")

# What this build resolved to, in a file meant to be committed.
#
# A port that came from somewhere else is code this build reads and a library
# it fetches, and both can change under a project without a line of the
# project changing. So both are written down: the commit a library was
# fetched at, the digest of an archive, and the digest of every port file
# read from an overlay, a prefix, a URL or a library's own tree. On the next
# build they have to still be that, or the build stops and says which one
# moved.
#
# Ports the project itself declares are not in it: they are in the project,
# and the project is what the lock is for.
set(CME_LOCK "${CMAKE_SOURCE_DIR}/cme-lock.json" CACHE FILEPATH
  "Where the resolved commits and digests are kept, or empty for none")
set(CME_LOCK_UPDATE OFF CACHE BOOL
  "Take what this build resolved to as the new lock, for everything")
# Updating one library should not re-pin the others.
#
# A blanket update takes whatever every library happens to be today and
# writes all of it down as intended, in one commit, under the heading of
# updating one thing. Anything that moved underneath -- another library's
# tag repointed, a port file edited in an overlay -- is re-pinned in the same
# breath and reviewed as part of somebody else's change. So an update names
# what it is updating, and everything else is still held to what the lock
# says.
set(CME_RELOCK "" CACHE STRING
  "Ports this build may write new facts about; the rest are held to the lock")
# Writing the lock is its own run, because an ordinary build does not fetch
# what it does not need: a library the system has is never downloaded, and
# one that is already in the store is not either. A lock written by such a
# build is a lock with holes in it, and a build that writes one says which
# holes it left.
#
# This makes a run that has to reach everything: nothing from the system,
# nothing from the store, every library fetched and every port read.
set(CME_LOCK_ALL OFF CACHE BOOL
  "Ignore the system and the store, fetch everything, and write the lock")
if(CME_LOCK_ALL)
  set(CME_SYSTEM "NEVER")
  # Reaching everything and re-pinning everything are two decisions. With
  # CME_RELOCK given, this run fetches all of it -- so the lock comes out
  # whole -- and only the named ports may come out different.
  if(NOT CME_RELOCK)
    set(CME_LOCK_UPDATE ON)
  endif()
endif()

set(CME_UNLOCKED "" CACHE STRING
  "Ports that are deliberately not pinned: a branch you are following, or a \
port you are editing")
set(CME_SYSTEM "AUTO" CACHE STRING
  "AUTO: take a package from the system when it is there and new enough. \
ALWAYS: refuse to build anything, the system must have it. \
NEVER: build everything from source.")
set_property(CACHE CME_SYSTEM PROPERTY STRINGS AUTO ALWAYS NEVER)
set(CME_LOCK_FILE "${CMAKE_BINARY_DIR}/cme-report.txt" CACHE FILEPATH
  "Where the report of what this build decided is written")
set(CME_DEFAULT_FEATURES "" CACHE STRING
  "Features to turn on wherever a library has one by that name, and -name to \
refuse one wherever it appears")
set(CME_ACCEPT_LICENSES "" CACHE STRING
  "Licences a library may be under, or empty for no opinion")
# CMake 4 refuses to configure a project whose cmake_minimum_required asks
# for less than 3.5, and a good many released libraries ask for less than
# that: libogg 1.3.5 asks for 3.0. These are trees this registry did not
# write and cannot correct, and the policies a port is built with are the
# ones the port pins anyway, so the floor is raised for them rather than the
# library being unusable. A port that needs a different floor says so.
set(CME_POLICY_VERSION_MINIMUM "3.5" CACHE STRING
  "Policy floor for ported projects whose own cmake_minimum_required is older")

# ---------------------------------------------------------------- the lock

# Both of the things that are finished at the end of a configuration rather
# than while it runs, because both are about the whole of it.
function(cme_finish)
  cme_finish_exports()
  cme_lock_write()
endfunction()

function(cme_schedule_finish)
  get_property(scheduled GLOBAL PROPERTY CME_FINISH_SCHEDULED)
  if(scheduled)
    return()
  endif()
  set_property(GLOBAL PROPERTY CME_FINISH_SCHEDULED TRUE)
  cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" CALL cme_finish)
endfunction()

# Whether a port is being followed rather than pinned.
#
# The project may say so, on the command line or in the declaration it wrote.
# An overlay it named may say so, because naming the overlay was the
# project's decision too. A library may not say it about itself, and a
# library may not say it about another one: a thing that is being pinned does
# not get to ask not to be. When one tries, it is said out loud rather than
# ignored quietly, and it is pinned anyway.
function(cme_lock_ignored out port)
  if("${port}" IN_LIST CME_UNLOCKED)
    set(${out} TRUE PARENT_SCOPE)
    return()
  endif()
  get_property(said GLOBAL PROPERTY CME_PORT_${port}_UNLOCKED)
  set(${out} "${said}" PARENT_SCOPE)
endfunction()

# Said where a port is declared, or afterwards about one declared in the same
# breath.
#
# The rule is the same for everyone, a project and a library alike: you may
# say it about yourself, and about a port you declared. You may not say it
# about a port somebody else declared -- a library cannot unpin the registry's
# zlib because it happens to use it, and neither can a library it pulled in.
# Anything wider than that is the project's to say on the command line, which
# is where CME_UNLOCKED is.
function(cme_port_unlocked port)
  get_property(origin GLOBAL PROPERTY CME_PORT_ORIGIN)
  if(NOT origin)
    set(origin "the project")
  endif()
  get_property(declared_by GLOBAL PROPERTY CME_PORT_${port}_ORIGIN)
  get_property(speaking_for GLOBAL PROPERTY CME_READING_FOR)
  if(NOT declared_by)
    # Said before the declaration it goes with. Kept, and applied if the same
    # voice does declare it; a file that only asks and never declares has
    # asked about somebody else's port.
    set_property(GLOBAL PROPERTY CME_UNLOCK_ASKED_${port} "${origin}")
    return()
  endif()
  if(NOT declared_by STREQUAL origin AND NOT port STREQUAL speaking_for)
    message(WARNING
      "cmake-everywhere: ${origin} says ${port} should not be pinned, and "
      "${port} was declared by ${declared_by}. A port can be unpinned by "
      "whoever declared it and by the library it is, and by nobody else. "
      "${port} stays pinned; -DCME_UNLOCKED=${port} is this project's to say.")
    return()
  endif()
  set_property(GLOBAL PROPERTY CME_PORT_${port}_UNLOCKED TRUE)
endfunction()

# What a copy that is installed on this machine was built with.
#
# Written into the port that is installed beside a library, by the build that
# installed it. A copy is one version built one way, and the one thing that
# was always guesswork -- whether it has the feature this build needs -- is
# not a guess when the copy says so.
#
# It is honoured only from a port that was read out of a prefix. In a source
# tree the same line is a statement about somebody else's machine.
function(cme_installed_with port)
  cmake_parse_arguments(COPY "" "VERSION" "FEATURES;NEEDED" ${ARGN})
  get_property(origin GLOBAL PROPERTY CME_PORT_ORIGIN)
  if(NOT origin MATCHES "^the system")
    return()
  endif()
  set_property(GLOBAL PROPERTY CME_INSTALLED_FEATURES_${port}
               "${COPY_FEATURES}")
  set_property(GLOBAL PROPERTY CME_INSTALLED_SAID_${port} TRUE)
  set_property(GLOBAL PROPERTY CME_INSTALLED_VERSION_${port} "${COPY_VERSION}")
  set_property(GLOBAL PROPERTY CME_INSTALLED_NEEDED_${port} "${COPY_NEEDED}")
endfunction()

function(cme_lock_read)
  get_property(done GLOBAL PROPERTY CME_LOCK_READ)
  if(done)
    return()
  endif()
  set_property(GLOBAL PROPERTY CME_LOCK_READ TRUE)
  if(NOT CME_LOCK OR NOT EXISTS "${CME_LOCK}")
    return()
  endif()
  file(READ "${CME_LOCK}" text)
  string(JSON count ERROR_VARIABLE bad LENGTH "${text}" ports)
  if(bad)
    message(FATAL_ERROR
      "cmake-everywhere: cannot read ${CME_LOCK}: ${bad}. It is written by "
      "this and meant to be committed; if it has been damaged, delete it and "
      "configure once with -DCME_LOCK_ALL=ON.")
  endif()
  if(count EQUAL 0)
    return()
  endif()
  math(EXPR last "${count} - 1")
  foreach(index RANGE 0 ${last})
    string(JSON port MEMBER "${text}" ports ${index})
    string(JSON entry GET "${text}" ports "${port}")
    string(JSON kinds LENGTH "${entry}")
    if(kinds EQUAL 0)
      continue()
    endif()
    math(EXPR kind_last "${kinds} - 1")
    foreach(at RANGE 0 ${kind_last})
      string(JSON kind MEMBER "${entry}" ${at})
      string(JSON what TYPE "${entry}" "${kind}")
      if(what STREQUAL "ARRAY")
        string(JSON many LENGTH "${entry}" "${kind}")
        if(many EQUAL 0)
          continue()
        endif()
        math(EXPR many_last "${many} - 1")
        foreach(one RANGE 0 ${many_last})
          string(JSON value GET "${entry}" "${kind}" ${one})
          set_property(GLOBAL APPEND PROPERTY CME_LOCKED
                       "${port} ${kind} ${value}")
        endforeach()
      else()
        string(JSON value GET "${entry}" "${kind}")
        set_property(GLOBAL APPEND PROPERTY CME_LOCKED
                     "${port} ${kind} ${value}")
      endif()
    endforeach()
  endforeach()
endfunction()

# One fact about one port: checked against the lock if the lock has an
# opinion about it, and kept so it can be written back out.
function(cme_lock_fact port kind value)
  if(NOT CME_LOCK OR NOT value)
    return()
  endif()
  cme_lock_ignored(followed "${port}")
  if(followed)
    return()
  endif()
  cme_lock_read()
  set(line "${port} ${kind} ${value}")
  get_property(kept GLOBAL PROPERTY CME_LOCK_KEPT)
  if("${line}" IN_LIST kept)
    return()
  endif()
  set_property(GLOBAL APPEND PROPERTY CME_LOCK_KEPT "${line}")
  get_property(locked GLOBAL PROPERTY CME_LOCKED)
  set(said "")
  foreach(other IN LISTS locked)
    if(other MATCHES "^${port} ${kind} (.+)$")
      list(APPEND said "${CMAKE_MATCH_1}")
    endif()
  endforeach()
  if(NOT said)
    return()
  endif()
  if("${value}" IN_LIST said)
    return()
  endif()
  if(CME_LOCK_UPDATE OR "${port}" IN_LIST CME_RELOCK)
    list(JOIN said " or " expected)
    message(STATUS
      "cmake-everywhere: ${port} ${kind} was ${expected} and is now ${value}")
    return()
  endif()
  list(JOIN said " or " expected)

  # A port file that came with the registry changed because the registry
  # did. The lock says which revision of cmake-everywhere wrote it, so that
  # is a fact rather than a guess, and it is a different thing from a port
  # file somebody edited: every port in the registry changed with it.
  if(kind STREQUAL "port" AND CME_VERSION)
    set(was "")
    foreach(other IN LISTS locked)
      if(other MATCHES "^cmake-everywhere version (.+)$")
        set(was "${CMAKE_MATCH_1}")
      endif()
    endforeach()
    if(was AND NOT was STREQUAL "${CME_VERSION}")
      message(FATAL_ERROR
        "cmake-everywhere: ${CME_LOCK} was written against cmake-everywhere "
        "${was}, and this build takes ${CME_VERSION}. Its ports are not the "
        "same files -- ${port} is the first one this build reached.\n"
        "Configure once with -DCME_LOCK_UPDATE=ON to write down what this "
        "revision says, or with -DCME_RELOCK=${port} for that one port. "
        "Nothing else in the lock changes either way: a library is still "
        "held to the commit it is pinned at.")
    endif()
  endif()

  message(FATAL_ERROR
    "cmake-everywhere: ${CME_LOCK} says ${port} ${kind} is ${expected}, and "
    "this build has ${value}.\n"
    "Something that is not in this project changed under it: a library moved, "
    "an archive was replaced, or a port file was edited somewhere else. If "
    "that was meant, configure once with -DCME_RELOCK=${port}, which writes "
    "down the new answer for ${port} and holds everything else to what the "
    "lock already says. If ${port} is one you are deliberately following "
    "rather than pinning, put it in CME_UNLOCKED.")
endfunction()

# The digest of a port file that came from outside this project, recorded
# against the port it declared.
function(cme_lock_port_file port)
  get_property(file GLOBAL PROPERTY CME_PORT_FILE)
  if(NOT file OR NOT EXISTS "${file}")
    return()
  endif()
  file(SHA256 "${file}" digest)
  cme_lock_fact("${port}" "port" "${digest}")
endfunction()

function(cme_lock_write)
  if(NOT CME_LOCK)
    return()
  endif()
  cme_lock_read()
  # What resolved all of this. A project that pins every library it uses and
  # not the thing that reads the pins has written down everything except the
  # part that decides.
  if(CME_VERSION)
    cme_lock_fact("cmake-everywhere" "version" "${CME_VERSION}")
  endif()
  if(CME_FETCHED_SHA256)
    cme_lock_fact("cmake-everywhere" "archive" "${CME_FETCHED_SHA256}")
  endif()
  get_property(kept GLOBAL PROPERTY CME_LOCK_KEPT)
  get_property(locked GLOBAL PROPERTY CME_LOCKED)
  # What was there stays there unless this build learned something else about
  # the same thing. A build that took half its libraries from the system
  # knows nothing about the other half, and a lock that forgot them would
  # pin less every time it was written.
  set(replaced "")
  foreach(line IN LISTS kept)
    string(REGEX REPLACE "^([^ ]+) .*$" "\\1" port "${line}")
    string(REGEX REPLACE "^([^ ]+ [^ ]+) .*$" "\\1" subject "${line}")
    # A fact only supersedes the one in the lock if this run was allowed to
    # write new facts about that port. For everything else the two are the
    # same anyway -- a difference would have stopped the build -- and saying
    # so here is what keeps an update of one library from rewriting the rest.
    if(CME_LOCK_UPDATE OR port IN_LIST CME_RELOCK)
      list(APPEND replaced "${subject}")
    endif()
  endforeach()
  set(all "${kept}")
  foreach(line IN LISTS locked)
    string(REGEX REPLACE "^([^ ]+) .*$" "\\1" port "${line}")
    string(REGEX REPLACE "^([^ ]+ [^ ]+) .*$" "\\1" subject "${line}")
    cme_lock_ignored(followed "${port}")
    if(followed)
      continue()
    endif()
    # A port file is one of several a port can have, so those are added to
    # rather than replaced.
    if(subject IN_LIST replaced AND NOT line MATCHES "^[^ ]+ port ")
      continue()
    endif()
    list(APPEND all "${line}")
  endforeach()
  if(NOT all)
    return()
  endif()

  # What this build could not say anything about, because it never had to
  # look. Said out loud rather than left as a lock that quietly covers less
  # than it appears to.
  get_property(reached GLOBAL PROPERTY CME_LOCK_REACHED)
  get_property(used GLOBAL PROPERTY CME_TOUCHED)
  set(missing "")
  foreach(port IN LISTS used)
    cme_lock_ignored(followed "${port}")
    if(port IN_LIST reached OR followed)
      continue()
    endif()
    set(covered FALSE)
    foreach(line IN LISTS all)
      if(line MATCHES "^${port} ")
        set(covered TRUE)
      endif()
    endforeach()
    if(NOT covered)
      list(APPEND missing "${port}")
    endif()
  endforeach()
  if(missing AND NOT CME_LOCK_ALL)
    list(REMOVE_DUPLICATES missing)
    list(SORT missing)
    list(JOIN missing ", " unsaid)
    message(WARNING
      "cmake-everywhere: the lock does not cover ${unsaid}. This build never "
      "fetched them -- the system or the store answered instead -- so there "
      "is nothing it can honestly write down about them. Configure once with "
      "-DCME_LOCK_ALL=ON, which ignores both and reaches everything, to write "
      "a lock that covers the whole build.")
  endif()
  list(REMOVE_DUPLICATES all)
  list(SORT all)

  # Written as JSON, sorted, one object per port: a lock is read by people
  # reviewing a change to it and by whatever a project already has for
  # reading files, and neither of those should have to learn a format that
  # exists only here.
  set(ports "")
  foreach(line IN LISTS all)
    string(REGEX REPLACE "^([^ ]+) .*$" "\\1" port "${line}")
    list(APPEND ports "${port}")
  endforeach()
  list(REMOVE_DUPLICATES ports)
  list(SORT ports)
  set(objects "")
  foreach(port IN LISTS ports)
    set(kinds "")
    foreach(line IN LISTS all)
      if(line MATCHES "^${port} ([^ ]+) ")
        list(APPEND kinds "${CMAKE_MATCH_1}")
      endif()
    endforeach()
    list(REMOVE_DUPLICATES kinds)
    list(SORT kinds)
    set(fields "")
    foreach(kind IN LISTS kinds)
      set(values "")
      foreach(line IN LISTS all)
        if(line MATCHES "^${port} ${kind} (.+)$")
          list(APPEND values "${CMAKE_MATCH_1}")
        endif()
      endforeach()
      # A kind that can have several values is always an array, whether it
      # has one this time or four. Something reading this should not have to
      # ask what shape a field turned out to be.
      list(LENGTH values many)
      if(kind STREQUAL "port" OR many GREATER 1)
        set(quoted "")
        foreach(value IN LISTS values)
          list(APPEND quoted "        \"${value}\"")
        endforeach()
        list(JOIN quoted ",\n" listed)
        list(APPEND fields "      \"${kind}\": [\n${listed}\n      ]")
      else()
        list(APPEND fields "      \"${kind}\": \"${values}\"")
      endif()
    endforeach()
    list(JOIN fields ",\n" listed)
    list(APPEND objects "    \"${port}\": {\n${listed}\n    }")
  endforeach()
  list(JOIN objects ",\n" listed)
  set(whole "{\n")
  string(APPEND whole
    "  \"about\": \"Written by cmake-everywhere. Commit this file. Every "
    "value is a fact about something outside this project that has to stay "
    "true: the commit a library was fetched at, the digest of an archive, "
    "and the digest of a port file read from somewhere else. Configure with "
    "-DCME_LOCK_ALL=ON to write it again.\",\n")
  string(APPEND whole "  \"lock\": 1,\n  \"ports\": {\n${listed}\n  }\n}\n")
  set(before "")
  if(EXISTS "${CME_LOCK}")
    file(READ "${CME_LOCK}" before)
  endif()
  if(NOT before STREQUAL whole)
    file(WRITE "${CME_LOCK}" "${whole}")
    message(STATUS "cmake-everywhere: ${CME_LOCK} written")
  endif()
endfunction()

# ---------------------------------------------------------------- registry

# Where an overlay's ports are on this machine. A directory is read where it
# is; a URL is cloned once into the overlay cache.
function(cme_overlay_directory out spec)
  if(IS_DIRECTORY "${spec}")
    set(${out} "${spec}" PARENT_SCOPE)
    return()
  endif()
  set(url "${spec}")
  set(ref "")
  if(url MATCHES "^(.+)#([^#]+)$")
    set(url "${CMAKE_MATCH_1}")
    set(ref "${CMAKE_MATCH_2}")
  endif()
  if(NOT url MATCHES "^(https?://|git://|ssh://|file://|git@)")
    message(FATAL_ERROR
      "cmake-everywhere: the overlay \"${spec}\" is not a directory that "
      "exists and not a URL. An overlay is either a path to a directory of "
      "ports or the URL of a repository of them, optionally #ref.")
  endif()
  find_package(Git QUIET BYPASS_PROVIDER)
  if(NOT GIT_FOUND)
    message(FATAL_ERROR
      "cmake-everywhere: the overlay ${url} has to be cloned and there is no "
      "git on this machine.")
  endif()
  string(SHA256 key "${url}#${ref}")
  string(SUBSTRING "${key}" 0 16 key)
  get_filename_component(leaf "${url}" NAME_WE)
  set(dir "${CME_OVERLAY_CACHE}/${leaf}-${key}")
  if(NOT IS_DIRECTORY "${dir}/.git")
    file(MAKE_DIRECTORY "${CME_OVERLAY_CACHE}")
    set(clone clone --depth 1)
    if(ref)
      list(APPEND clone --branch "${ref}")
    endif()
    message(STATUS "cmake-everywhere: cloning the overlay ${spec}")
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" ${clone} "${url}" "${dir}"
      RESULT_VARIABLE code OUTPUT_VARIABLE said ERROR_VARIABLE said)
    if(NOT code EQUAL 0)
      file(REMOVE_RECURSE "${dir}")
      message(FATAL_ERROR
        "cmake-everywhere: cannot clone the overlay ${spec}:\n${said}")
    endif()
  elseif(CME_OVERLAY_REFRESH AND NOT ref)
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" pull --ff-only
      WORKING_DIRECTORY "${dir}"
      RESULT_VARIABLE code OUTPUT_VARIABLE said ERROR_VARIABLE said)
    if(NOT code EQUAL 0)
      message(FATAL_ERROR
        "cmake-everywhere: cannot update the overlay ${spec}:\n${said}")
    endif()
  endif()
  set(${out} "${dir}" PARENT_SCOPE)
endfunction()

# One value, as it has to be written back into a file that will be read as
# CMake again.
function(cme_quote out value)
  string(REPLACE "\\" "\\\\" value "${value}")
  string(REPLACE "\"" "\\\"" value "${value}")
  set(${out} "${value}" PARENT_SCOPE)
endfunction()

# What a project declared, said again in the file that is installed beside
# it. Features and rules are separate calls made after the port, so they are
# appended to what the port wrote.
function(cme_export_line port text)
  get_property(exported GLOBAL PROPERTY CME_EXPORTED_${port})
  if(exported)
    file(APPEND "${exported}" "${text}\n")
  endif()
endfunction()

# A port file from a URL: one file, from anywhere, with nothing around it.
#
#   cme_port_from_url(https://example.invalid/ports/hello.cmake
#                     SHA256 3f2a...)
#
# The digest is required, because this is code the build reads from a machine
# that is not yours. UNVERIFIED takes it anyway, and is meant to be written
# once while working something out and then removed: the file is fetched
# again on a machine that has not seen it, and nothing says it is the same
# file. Either way it is written into the lock, so a file that changes under
# a project stops the build.
function(cme_port_from_url url)
  cmake_parse_arguments(FROM "UNVERIFIED" "SHA256;NAME" "" ${ARGN})
  if(NOT FROM_SHA256 AND NOT FROM_UNVERIFIED)
    message(FATAL_ERROR
      "cmake-everywhere: cme_port_from_url(${url}) has no SHA256. That file "
      "is CMake this build will read, from somewhere that is not this "
      "project. Give its digest, or say UNVERIFIED and mean it.")
  endif()
  set(name "${FROM_NAME}")
  if(NOT name)
    get_filename_component(name "${url}" NAME)
  endif()
  string(SHA256 key "${url}")
  string(SUBSTRING "${key}" 0 16 key)
  set(file "${CME_OVERLAY_CACHE}/from-url/${key}-${name}")
  if(NOT EXISTS "${file}")
    file(MAKE_DIRECTORY "${CME_OVERLAY_CACHE}/from-url")
    if(FROM_SHA256)
      file(DOWNLOAD "${url}" "${file}" STATUS told
           EXPECTED_HASH SHA256=${FROM_SHA256})
    else()
      file(DOWNLOAD "${url}" "${file}" STATUS told)
    endif()
    list(GET told 0 code)
    if(NOT code EQUAL 0)
      list(GET told 1 said)
      file(REMOVE "${file}")
      message(FATAL_ERROR
        "cmake-everywhere: cannot read the port at ${url}: ${said}")
    endif()
  elseif(FROM_SHA256)
    file(SHA256 "${file}" digest)
    if(NOT digest STREQUAL FROM_SHA256)
      file(REMOVE "${file}")
      message(FATAL_ERROR
        "cmake-everywhere: the copy of ${url} kept at ${file} is not the file "
        "that was asked for. It has been removed; configure again.")
    endif()
  endif()
  set_property(GLOBAL PROPERTY CME_PORT_ORIGIN "the file at ${url}")
  set_property(GLOBAL PROPERTY CME_PORT_DIRECTORY "")
  set_property(GLOBAL PROPERTY CME_PORT_FILE "${file}")
  include("${file}")
  set_property(GLOBAL PROPERTY CME_PORT_ORIGIN "")
  set_property(GLOBAL PROPERTY CME_PORT_FILE "")
  message(STATUS "cmake-everywhere: read the port at ${url}")
endfunction()

# Where a port's source is, said apart from what the port is.
#
# A library describing itself knows its name, its version, its licence, its
# features and what it needs. It does not know where it is: the URL in its
# own CMakeLists is right until somebody forks it, mirrors it, or builds it
# from a tarball, and then it is a lie that is committed. Where to get it is
# whoever wants it from source's to say -- a project, an overlay, a registry
# -- and a port with nothing to say about it is a perfectly good port for a
# library that is installed.
#
#   cme_port_source(hello GITHUB_REPOSITORY me/hello GIT_TAG v1.4.0)
#
# Field by field, and the first to say wins, the same as everything else.
function(cme_port_source port)
  set(fields GIT_REPOSITORY GITHUB_REPOSITORY GITLAB_REPOSITORY GIT_TAG
             GIT_TAG_TEMPLATE GIT_SHALLOW URL URL_HASH SOURCE_SUBDIR VERSION
             SOURCE_FROM)
  cmake_parse_arguments(SOURCE "" "${fields}" "" ${ARGN})
  if(SOURCE_UNPARSED_ARGUMENTS)
    list(JOIN SOURCE_UNPARSED_ARGUMENTS " " extra)
    message(FATAL_ERROR
      "cmake-everywhere: cme_port_source(${port} ...) says ${extra}, and it "
      "only says where a port comes from.")
  endif()
  set(said "cme_port_source(${port}")
  foreach(field IN LISTS fields)
    if("${SOURCE_${field}}" STREQUAL "")
      continue()
    endif()
    get_property(fixed GLOBAL PROPERTY CME_PORT_${port}_FIXED)
    if(NOT field IN_LIST fixed)
      set_property(GLOBAL PROPERTY CME_PORT_${port}_${field}
                   "${SOURCE_${field}}")
      set_property(GLOBAL APPEND PROPERTY CME_PORT_${port}_FIXED "${field}")
      set_property(GLOBAL APPEND_STRING PROPERTY CME_PORT_${port}_RECIPE
                   "source ${field}=${SOURCE_${field}};")
    endif()
    cme_quote(value "${SOURCE_${field}}")
    string(APPEND said " ${field} \"${value}\"")
  endforeach()
  cme_export_line(${port} "${said})")
endfunction()

# What a port needs, added to what it already said it needs. Written by hand
# when a port here is short of something, and written by this when a project
# is installed: what a library asked for while it was built is what it needs,
# and that is a better list than one kept by hand.
function(cme_port_needs port)
  get_property(existing GLOBAL PROPERTY CME_PORT_${port}_DEPENDS)
  foreach(spec IN LISTS ARGN)
    if(NOT spec IN_LIST existing)
      list(APPEND existing "${spec}")
    endif()
  endforeach()
  set_property(GLOBAL PROPERTY CME_PORT_${port}_DEPENDS "${existing}")
  set_property(GLOBAL APPEND_STRING PROPERTY CME_PORT_${port}_RECIPE
               "needs ${ARGN};")
endfunction()

# The members of a family that the installed copy has no separate name for.
#
# A distribution ships Boost as one package, and its CMake config answers
# for the pieces that were compiled: there is a boost_json-config.cmake and
# there is no boost_asio-config.cmake, because asio is headers and there is
# nothing to configure. So asking for asio as a component is asking the
# installed copy for a word it does not have, and it answers no about all
# of Boost -- which is why only the compiled pieces are asked for.
#
# What is left is a member whose headers are there, in the copy that was
# found, with nothing defining the target a consumer writes. That target is
# those headers: the port says which member it is, the family says what an
# installed copy calls its headers, and the two are put together here
# rather than the build ending with "Boost::asio was not found".
function(cme_system_header_members port package features)
  cme_port_field(headers ${port} SYSTEM_HEADER_TARGET)
  if(NOT headers OR NOT TARGET ${headers})
    return()
  endif()
  set(made "")
  foreach(feature IN LISTS features)
    cme_feature_field(separate ${port} ${feature} SYSTEM_COMPONENT)
    if(separate)
      # Compiled, so the installed copy either has it as a component or
      # does not have it at all. Not something headers can stand in for.
      continue()
    endif()
    cme_feature_field(depends ${port} ${feature} DEPENDS)
    foreach(spec IN LISTS depends)
      cme_split_requirement("${spec}" member unused unused_features)
      cme_port_field(targets ${member} TARGETS)
      foreach(target IN LISTS targets)
        if(TARGET ${target})
          continue()
        endif()
        add_library(${target} INTERFACE IMPORTED GLOBAL)
        set_property(TARGET ${target} APPEND PROPERTY
                     INTERFACE_LINK_LIBRARIES ${headers})
        list(APPEND made "${target}")
      endforeach()
    endforeach()
  endforeach()
  if(made)
    list(REMOVE_DUPLICATES made)
    list(JOIN made ", " listed)
    message(STATUS
      "cmake-everywhere: the ${package} installed here has no separate "
      "target for ${listed}, which are headers in it, so they are its "
      "headers (${headers})")
  endif()
endfunction()

# What the port promises, made out of what the machine defined.
#
# A config file a distribution ships defines the targets its upstream
# exports, under upstream's names: glfw3Config.cmake defines glfw. A port
# promises a name of its own -- the one it tells consumers to write -- and
# for a library built here the adapter makes it. Nothing makes it for a
# library that was found, and the port already says what a bare name means,
# so that is what it is made from.
function(cme_alias_system_targets port)
  cme_port_field(names ${port} LINK_NAMES)
  foreach(pair IN LISTS names)
    if(NOT pair MATCHES "^([^=]+)=(.+)$")
      continue()
    endif()
    set(from "${CMAKE_MATCH_1}")
    set(to "${CMAKE_MATCH_2}")
    if(TARGET ${to} OR NOT TARGET ${from})
      continue()
    endif()
    # An alias of an alias is refused, so what the other one points at is
    # what this one points at.
    get_target_property(behind ${from} ALIASED_TARGET)
    if(behind)
      set(from "${behind}")
    endif()
    add_library(${to} ALIAS ${from})
  endforeach()
endfunction()

# Whether what a port promised is there, after it was answered.
#
# A consumer writes the name the port promises, and a name that nothing
# defines is not refused where it is written -- CMake gets to the end of
# the configure and says the target was not found, with no word about which
# library it belongs to or where it came from.
function(cme_check_promised port package how)
  cme_port_field(promised ${port} TARGETS)
  set(missing "")
  foreach(target IN LISTS promised)
    if(NOT TARGET ${target})
      list(APPEND missing "${target}")
    endif()
  endforeach()
  if(NOT missing)
    return()
  endif()
  list(JOIN missing ", " listed)
  message(WARNING
    "cmake-everywhere: ${package} was answered ${how}, and ${listed} -- "
    "which the ${port} port says it produces -- is not defined. Something "
    "that links it will be told at the end of the configure that a target "
    "was not found. What the copy on this machine defines and what this "
    "port promises are not the same names, and the port has to say so in "
    "LINK_NAMES.")
endfunction()

# A name the copy being built here will define, that is already taken.
#
# The machine's copy is looked for first, and finding one defines the
# targets its config file declares -- under the names upstream uses, since
# it is the same upstream. When that copy is then refused, for a feature it
# was not built with, those definitions stay: nothing removes a target in
# CMake. add_subdirectory then says "cannot create target glfw because an
# imported target with the same name already exists", once per line of the
# library's own CMakeLists, about the library rather than about the
# decision that led there.
function(cme_note_name_clash port package)
  cme_port_field(names ${port} LINK_NAMES)
  set(clashing "")
  foreach(pair IN LISTS names)
    if(NOT pair MATCHES "^([^=]+)=")
      continue()
    endif()
    set(name "${CMAKE_MATCH_1}")
    if(NOT TARGET ${name})
      continue()
    endif()
    get_target_property(imported ${name} IMPORTED)
    if(imported)
      list(APPEND clashing "${name}")
    endif()
  endforeach()
  if(NOT clashing)
    return()
  endif()
  list(JOIN clashing ", " listed)
  string(TOUPPER "${package}" upper)
  # Fatal, because what follows is not a build that might work. The library
  # is about to be added as a subdirectory, its first add_library will be
  # refused, and every command that would have configured that target then
  # fails on its own -- thirty errors about IMPORTED targets, none of which
  # names the copy on this machine or the decision that was made about it.
  # This says both, once, before any of that.
  message(FATAL_ERROR
    "cmake-everywhere: ${package} is built here, and ${listed} is already "
    "an imported target -- the copy on this machine was looked at, refused, "
    "and what it defined cannot be undefined. CMake will not create "
    "${listed} a second time. Configure with -DCME_SYSTEM_${upper}=OFF so "
    "that copy is not looked at, or with what it is missing installed so it "
    "can be used.")
endfunction()

# A port describes one library: where it comes from, what it needs, and what
# find_package names it answers to. Ports only declare; nothing is fetched
# until something asks for it.
function(cme_declare_port)
  set(one NAME VERSION GIT_REPOSITORY GITHUB_REPOSITORY GITLAB_REPOSITORY
          GIT_TAG URL URL_HASH SOURCE_SUBDIR OVERLAY SYSTEM_PACKAGE
          POLICY_MINIMUM GIT_TAG_TEMPLATE GIT_SHALLOW EXTERNAL IMPORT
          PORTS_FROM UNLOCKED FAMILY VIRTUAL SOURCE_FROM SOURCE_ONLY
          CHECK_HEADER ARRANGEMENT SYSTEM_HEADER_TARGET CONFIGURE
          INSTALLED_INCLUDE)
  set(many PROVIDES OPTIONS DEPENDS SYSTEM_PKGCONFIG PKGCONFIG_NAMES
           EXCLUDES LICENSE
           LINK_NAMES TARGETS SYSTEMS
           GN_ARGS GN_TARGETS GN_CONFIRM GN_IN_TREE IMPORT_TARGETS
           CONFIGURE_ARGS CONFIGURE_CROSS INSTALLED_TARGETS PATCHES)
  cmake_parse_arguments(PORT "" "${one}" "${many}" ${ARGN})
  if(NOT PORT_NAME)
    message(FATAL_ERROR "cmake-everywhere: a port with no NAME")
  endif()
  if(NOT PORT_PROVIDES)
    set(PORT_PROVIDES "${PORT_NAME}")
  endif()
  # A project declaring itself has already said its version once.
  if(NOT PORT_VERSION AND PROJECT_NAME AND PORT_NAME STREQUAL PROJECT_NAME
     AND PROJECT_VERSION)
    set(PORT_VERSION "${PROJECT_VERSION}")
  endif()
  # The first place that names a port is the place it comes from. A project
  # declares before anything is loaded, overlays are loaded before the
  # registry, so this ordering is what lets either of them correct what is
  # below without arranging anything with anybody.
  get_property(known GLOBAL PROPERTY CME_PORTS)
  get_property(origin GLOBAL PROPERTY CME_PORT_ORIGIN)
  if(NOT origin)
    set(origin "the project")
  endif()
  # Two sides know two different things about the same library, and both are
  # right. A project knows where to get it, because it chose it; the library
  # knows what it is, what it needs and what it is licensed under, because it
  # is the library. Neither list is complete and neither should overwrite the
  # other, so a second declaration of a port fills in what the first did not
  # say and changes nothing that it did.
  set(merging FALSE)
  if("${PORT_NAME}" IN_LIST known)
    set(merging TRUE)
    get_property(first GLOBAL PROPERTY CME_PORT_${PORT_NAME}_ORIGIN)
    message(STATUS
      "cmake-everywhere: ${PORT_NAME} comes from ${first}; ${origin} only "
      "fills in what it did not say")
  endif()
  get_property(directory GLOBAL PROPERTY CME_PORT_DIRECTORY)
  if(NOT merging)
    set_property(GLOBAL PROPERTY CME_PORT_${PORT_NAME}_ORIGIN "${origin}")
  endif()
  # A port that came from somewhere else is code this build reads, and it can
  # be edited where it lives without a line of this project changing.
  if(NOT origin STREQUAL "the project")
    cme_lock_port_file("${PORT_NAME}")
  endif()
  get_property(asked GLOBAL PROPERTY CME_UNLOCK_ASKED_${PORT_NAME})
  if(PORT_UNLOCKED OR (asked AND asked STREQUAL origin))
    set_property(GLOBAL PROPERTY CME_PORT_${PORT_NAME}_UNLOCKED TRUE)
  endif()
  get_property(known_directory GLOBAL PROPERTY CME_PORT_${PORT_NAME}_DIR)
  if(directory AND NOT known_directory)
    # The adapters and the overlay of a port live beside its port.cmake, so a
    # declaration that has a directory brings one even when it is not first.
    set_property(GLOBAL PROPERTY CME_PORT_${PORT_NAME}_DIR "${directory}")
  endif()
  # What the port said, for a port that has no file of its own to hash.
  set(recipe "")
  foreach(field IN LISTS one many)
    string(APPEND recipe "${field}=${PORT_${field}};")
  endforeach()
  # Appended rather than set: every declaration that contributed to a port is
  # part of what the port is, and so part of the name its build is kept under.
  set_property(GLOBAL APPEND_STRING PROPERTY CME_PORT_${PORT_NAME}_RECIPE
               "${recipe}")

  # Written out and installed, when this is the project's own declaration.
  #
  # Not when it came from an overlay, the registry, or a library this build
  # fetched: those are somebody else's to publish. This is the project saying
  # what it needed, so that whoever installs the project gets to know it
  # without fetching the project.
  if(CME_EXPORT_PORTS AND NOT merging AND origin STREQUAL "the project"
     AND CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    if(PORT_OVERLAY)
      message(STATUS
        "cmake-everywhere: ${PORT_NAME} is not exported: its OVERLAY "
        "${PORT_OVERLAY} is a directory beside a port file, and a port "
        "declared in a CMakeLists has no directory")
    else()
      set(exported "${CMAKE_BINARY_DIR}/cme-ports/${PORT_NAME}/port.cmake")
      set(text "# Written by cmake-everywhere from the declaration in\n")
      string(APPEND text "# ${CMAKE_CURRENT_SOURCE_DIR}.\n#\n")
      string(APPEND text
        "# A VERSION here is the version of the copy this was installed "
        "beside.\n# It is what is here, not what this library can be: with "
        "GIT_TAG_TEMPLATE\n# or a port of your own, another version of it is "
        "a build away.\ncme_declare_port(\n")
      foreach(field IN LISTS one)
        if(NOT "${PORT_${field}}" STREQUAL "")
          cme_quote(value "${PORT_${field}}")
          string(APPEND text "  ${field} \"${value}\"\n")
        endif()
      endforeach()
      foreach(field IN LISTS many)
        if(PORT_${field})
          set(items "")
          foreach(item IN LISTS PORT_${field})
            cme_quote(value "${item}")
            string(APPEND items " \"${value}\"")
          endforeach()
          string(APPEND text "  ${field}${items}\n")
        endif()
      endforeach()
      string(APPEND text ")\n")
      file(WRITE "${exported}" "${text}")
      set_property(GLOBAL PROPERTY CME_EXPORTED_${PORT_NAME} "${exported}")
      set_property(GLOBAL APPEND PROPERTY CME_EXPORTING "${PORT_NAME}")
      install(FILES "${exported}"
              DESTINATION "${CME_EXPORT_DESTINATION}/${PORT_NAME}")
      # The install rule is made now, when the path is known. What goes in
      # the file is finished at the end of the configuration, when what this
      # project actually asked for is known.
      cme_schedule_finish()
    endif()
  endif()

  get_property(fixed GLOBAL PROPERTY CME_PORT_${PORT_NAME}_FIXED)
  foreach(field IN LISTS one many)
    # Not what cme_port_source already said, and not what an earlier
    # declaration said either.
    if(field IN_LIST fixed)
      continue()
    endif()
    if(merging)
      get_property(said GLOBAL PROPERTY CME_PORT_${PORT_NAME}_${field})
      set(overrules FALSE)
      # Two things are declared by the same command and are not the same
      # kind of thing. Where a library is, and which library it is, are the
      # project's: it chose it. What this tree turns out to be -- which
      # version it is and what it is licensed under -- is the tree's, and a
      # project that named a tag and guessed at the rest guessed. So a
      # library speaking about itself overrules a description of it.
      get_property(speaking_for GLOBAL PROPERTY CME_READING_FOR)
      if(speaking_for STREQUAL PORT_NAME AND field MATCHES "^(VERSION|LICENSE)$"
         AND NOT "${PORT_${field}}" STREQUAL ""
         AND NOT "${said}" STREQUAL "${PORT_${field}}")
        set(overrules TRUE)
        message(STATUS
          "cmake-everywhere: ${PORT_NAME} was declared with ${field} ${said} "
          "and the tree that was fetched says ${PORT_${field}}; the tree is "
          "what is being built")
      endif()
      if(NOT overrules)
        if(NOT "${said}" STREQUAL "" OR "${PORT_${field}}" STREQUAL "")
          continue()
        endif()
      endif()
    endif()
    set_property(GLOBAL PROPERTY CME_PORT_${PORT_NAME}_${field}
      "${PORT_${field}}")
    # A version out of a description that was installed beside a library is
    # the version of that copy. It is remembered as such, because it must
    # never be the reason something is not built.
    if(field STREQUAL "VERSION" AND origin MATCHES "^the system")
      set_property(GLOBAL PROPERTY CME_PORT_${PORT_NAME}_VERSION_INSTALLED
                   TRUE)
    endif()
  endforeach()
  if(NOT merging)
    set_property(GLOBAL APPEND PROPERTY CME_PORTS "${PORT_NAME}")
  endif()
  # The name a project writes in find_package() is not the name the library
  # calls itself: FLAC, Ogg and SndFile are all spelled several ways.
  foreach(name IN LISTS PORT_PROVIDES)
    set_property(GLOBAL PROPERTY CME_PROVIDER_${name} "${PORT_NAME}")
  endforeach()

  # More declarations, attached to a library by whoever declared it -- for a
  # library that needs libraries nobody has ported and has never heard of any
  # of this. The path is the declaring side's own, because that is whose file
  # it is: a library that wants to carry its own puts it in the tree under
  # the name cmake/source-ports.cmake looks for, and says nothing.
  if(PORT_PORTS_FROM)
    set(attached "${PORT_PORTS_FROM}")
    if(NOT IS_ABSOLUTE "${attached}")
      set(attached "${CMAKE_CURRENT_SOURCE_DIR}/${attached}")
    endif()
    if(NOT EXISTS "${attached}")
      message(FATAL_ERROR
        "cmake-everywhere: the ${PORT_NAME} port says its other declarations "
        "are in ${PORT_PORTS_FROM}, and there is no such file at ${attached}.")
    endif()
    include("${attached}")
  endif()
endfunction()

# What a library can optionally be. A feature is not a group of libraries --
# that was a bad idea and it is gone -- it is one capability of one library,
# with the arguments that turn it on and whatever else it then needs:
#
#   cme_port_feature(skia vulkan
#     GN_ARGS "skia_use_vulkan=true"
#     SUMMARY "the Vulkan backend")
#
# Features are additive and they compose by union, the way versions compose
# by maximum: if anything in the build needs skia with Vulkan, the one Skia
# in the build has Vulkan.
function(cme_port_feature port feature)
  cmake_parse_arguments(FEATURE "" "SUMMARY"
    "GN_ARGS;GN_CONFIRM;OPTIONS;DEPENDS;IMPLIES;CONFLICTS;EXCLUDES;SYSTEM_HEADERS;SYSTEM_SYMBOLS;SYSTEM_COMPONENT;CONFIGURE_ARGS;DEFAULT"
    ${ARGN})
  set_property(GLOBAL APPEND PROPERTY CME_PORT_${port}_FEATURES "${feature}")
  set_property(GLOBAL APPEND_STRING PROPERTY CME_PORT_${port}_RECIPE
    "feature ${feature}=${ARGN};")
  set(said "cme_port_feature(${port} ${feature}")
  foreach(item IN LISTS ARGN)
    cme_quote(value "${item}")
    string(APPEND said " \"${value}\"")
  endforeach()
  cme_export_line(${port} "${said})")
  foreach(field GN_ARGS GN_CONFIRM OPTIONS DEPENDS SUMMARY IMPLIES CONFLICTS
                EXCLUDES SYSTEM_HEADERS SYSTEM_SYMBOLS SYSTEM_COMPONENT
                CONFIGURE_ARGS
                DEFAULT)
    set_property(GLOBAL PROPERTY CME_FEATURE_${port}_${feature}_${field}
      "${FEATURE_${field}}")
  endforeach()
endfunction()

function(cme_feature_field out port feature field)
  get_property(value GLOBAL PROPERTY CME_FEATURE_${port}_${feature}_${field})
  set(${out} "${value}" PARENT_SCOPE)
endfunction()

# The features a project wants from a library it did not write the
# find_package call for:
#
#   cme_features(skia vulkan pdf)
#
# find_package(Skia COMPONENTS vulkan) says the same thing and is understood
# too. Skia has no find_package convention to obey -- nobody wrote one -- so
# both spellings are ours.
function(cme_features port)
  set(chosen "${CME_FEATURES_${port}}")
  set(refused "${CME_FEATURES_OFF_${port}}")
  foreach(name IN LISTS ARGN)
    if(name MATCHES "^-(.+)$")
      list(APPEND refused "${CMAKE_MATCH_1}")
    else()
      list(APPEND chosen "${name}")
    endif()
  endforeach()
  if(chosen)
    list(REMOVE_DUPLICATES chosen)
  endif()
  if(refused)
    list(REMOVE_DUPLICATES refused)
  endif()
  foreach(name IN LISTS chosen)
    if(name IN_LIST refused)
      message(FATAL_ERROR
        "cmake-everywhere: ${port} is asked for ${name} and refused ${name} "
        "in the same breath.")
    endif()
  endforeach()
  set(CME_FEATURES_${port} "${chosen}" CACHE STRING
    "Features wanted from the ${port} port" FORCE)
  set(CME_FEATURES_OFF_${port} "${refused}" CACHE STRING
    "Features refused from the ${port} port" FORCE)
endfunction()

# A named set of decisions, kept as a file of cme_features calls beside the
# registry. A project states one instead of restating the same twenty lines.
function(cme_profile name)
  set(file "${CME_REGISTRY}/../profiles/${name}.cmake")
  if(NOT EXISTS "${file}")
    file(GLOB available "${CME_REGISTRY}/../profiles/*.cmake")
    set(names "")
    foreach(one IN LISTS available)
      get_filename_component(one "${one}" NAME_WE)
      list(APPEND names "${one}")
    endforeach()
    message(FATAL_ERROR
      "cmake-everywhere: there is no profile called ${name}. There is: ${names}")
  endif()
  include("${file}")
endfunction()

# Whether policy says this feature may not be on. A project that asks a
# library for something directly outranks a blanket rule about every library.
function(cme_feature_refused out port feature)
  set(result FALSE)
  if("-${feature}" IN_LIST CME_DEFAULT_FEATURES)
    set(result TRUE)
  endif()
  if(feature IN_LIST CME_FEATURES_${port})
    set(result FALSE)
  endif()
  if(feature IN_LIST CME_FEATURES_OFF_${port})
    set(result TRUE)
  endif()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# A rule about a whole library rather than about one feature:
#
#   cme_port_rule(skia AT_MOST_ONE_OF fontconfig fontmgr-directory)
#   cme_port_rule(skia AT_LEAST_ONE_OF gl vulkan)
#   cme_port_rule(skia EXACTLY_ONE_OF a b c)
#   cme_port_rule(skia WITHOUT zlib DEPENDS miniz)
#   cme_port_rule(skia WITH gl AT_LEAST_ONE_OF egl x11)
#
# The counted ones cannot all be checked at the same moment: that a feature
# is missing is only true once nothing more can ask for it, so those are
# checked when the library is about to be built, while the ones that can only
# be broken by adding are checked as the graph is walked.
function(cme_port_rule port kind)
  get_property(rules GLOBAL PROPERTY CME_RULES_${port})
  list(LENGTH rules index)
  set_property(GLOBAL APPEND PROPERTY CME_RULES_${port} "${kind}")
  set_property(GLOBAL PROPERTY CME_RULE_${port}_${index} "${ARGN}")
  set(said "cme_port_rule(${port} ${kind}")
  foreach(item IN LISTS ARGN)
    cme_quote(value "${item}")
    string(APPEND said " \"${value}\"")
  endforeach()
  cme_export_line(${port} "${said})")
endfunction()

function(cme_port_field out port field)
  get_property(value GLOBAL PROPERTY CME_PORT_${port}_${field})
  set(${out} "${value}" PARENT_SCOPE)
endfunction()

# What a package must look like once it is there: besides the namespaced
# target other projects link, the plain variables the old Find modules set,
# because a third-party CMakeLists written before imported targets reads
# those and nothing else. Replayed into the scope of every later
# find_package of the same package, not only the first.
#
# A value that is itself a list would come apart in the property it is kept
# in, so it is stored with its separators encoded.
function(cme_export_variable package name value)
  string(REPLACE ";" "@CME@" encoded "${value}")
  set_property(GLOBAL APPEND PROPERTY CME_EXPORT_${package}
    "${name}" "${encoded}")
endfunction()

# Options for a library that is about to be compiled, from the project doing
# the compiling. Set before the find_package that first asks for it, in the
# same file that installs the provider:
#
#   cme_options(flac "WITH_OGG OFF")
#
# They are appended after the port's own, so they win. A package taken from
# the system is taken as it is: nothing here can change how it was built, and
# saying so is better than appearing to.
function(cme_options port)
  set(CME_OPTIONS_${port} "${ARGN}" CACHE STRING
    "Extra build options for the ${port} port" FORCE)
endfunction()

# One version of a library, as an archive with a digest of it.
#
#   cme_port_version(skia 153
#     URL "https://.../9d07e5ba.tar.gz"
#     SHA512 9c1682...)
#
# A port that lists versions this way is fetched by download rather than by
# clone, and what arrives is checked. Which also means a version that is not
# listed cannot be conjured: there is no digest for it.
function(cme_port_version port version)
  cmake_parse_arguments(SOURCE "" "URL;SHA512;SHA256" "" ${ARGN})
  if(NOT SOURCE_URL)
    message(FATAL_ERROR "cmake-everywhere: ${port} ${version} has no URL")
  endif()
  if(NOT SOURCE_SHA512 AND NOT SOURCE_SHA256)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} ${version} has no digest. An archive nobody "
      "checked is an archive nobody knows.")
  endif()
  set_property(GLOBAL APPEND PROPERTY CME_PORT_${port}_VERSIONS "${version}")
  set_property(GLOBAL PROPERTY CME_SOURCE_${port}_${version}_URL "${SOURCE_URL}")
  if(SOURCE_SHA512)
    set_property(GLOBAL PROPERTY CME_SOURCE_${port}_${version}_HASH
                 "SHA512=${SOURCE_SHA512}")
  else()
    set_property(GLOBAL PROPERTY CME_SOURCE_${port}_${version}_HASH
                 "SHA256=${SOURCE_SHA256}")
  endif()
endfunction()

# Build a different version of a library than the port pins:
#
#   cme_version(flac 1.5.0)
#
# The port has to say how a version becomes a tag -- GIT_TAG_TEMPLATE, since
# one project tags v1.3.5 and the next tags 1.4.3 -- or there is nothing to
# check out and the request is refused rather than quietly ignored.
function(cme_version port version)
  set(CME_VERSION_${port} "${version}" CACHE STRING
    "Version of the ${port} port to build" FORCE)
endfunction()

# Include directories for a build tree, for the libraries that attach none to
# their targets and expect their install to do it.
#
# BUILD_INTERFACE is not decoration: a plain absolute path inside the build
# tree in INTERFACE_INCLUDE_DIRECTORIES is an error for any target that is
# exported, since that path means nothing on another machine.
function(cme_build_includes target)
  if(NOT TARGET ${target})
    message(FATAL_ERROR "cmake-everywhere: ${target} was not built")
  endif()
  foreach(directory IN LISTS ARGN)
    target_include_directories(${target} PUBLIC
      "$<BUILD_INTERFACE:${directory}>")
  endforeach()
endfunction()

# A library built by a CMake of its own, configured and installed rather than
# added to this build.
#
# Some libraries refuse to be a subdirectory. libjpeg-turbo says so in as many
# words and stops: an upstream build system cannot anticipate every downstream
# one, and it would rather not try. That is a fair position and it needs a
# different mechanism, not an argument.
#
# So the library is configured, built and installed on its own, into the
# store when there is one, and what comes back is an install prefix -- which
# is also why the result survives to the next build for free.
function(cme_build_external port package version entry)
  if(EXISTS "${entry}/complete")
    message(STATUS "cmake-everywhere: ${port} ${version} is already built")
    cme_store_differences("${entry}")
    return()
  endif()
  if(CME_OFFLINE)
    # It would only be reached if the sources are there, but building is a
    # separate question from fetching and this says which one failed.
    message(STATUS "cmake-everywhere: building ${port} ${version} offline")
  endif()

  set(build "${CMAKE_BINARY_DIR}/_cme/${port}")
  set(arguments
    "-S" "${${port}_SOURCE_DIR}" "-B" "${build}" "-G" "${CMAKE_GENERATOR}"
    "-DCMAKE_INSTALL_PREFIX=${entry}"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    "-DBUILD_SHARED_LIBS=OFF")
  # Everything that decides what the objects are has to reach the other
  # invocation, or it is a different library to the one this build wanted.
  foreach(name CMAKE_TOOLCHAIN_FILE CMAKE_BUILD_TYPE CMAKE_C_COMPILER
               CMAKE_CXX_COMPILER CMAKE_C_FLAGS CMAKE_CXX_FLAGS CMAKE_SYSROOT
               CMAKE_MAKE_PROGRAM CMAKE_PREFIX_PATH CMAKE_CXX_STANDARD
               CMAKE_INTERPROCEDURAL_OPTIMIZATION)
    if(${name})
      list(APPEND arguments "-D${name}=${${name}}")
    endif()
  endforeach()
  if(NOT CME_COMPILER_CACHE STREQUAL "OFF")
    list(APPEND arguments
      "-DCMAKE_C_COMPILER_LAUNCHER=${CME_COMPILER_CACHE}"
      "-DCMAKE_CXX_COMPILER_LAUNCHER=${CME_COMPILER_CACHE}")
  endif()
  cme_enabled_features(${port} features)
  cme_port_field(options ${port} OPTIONS)
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} OPTIONS)
    list(APPEND options ${extra})
  endforeach()
  list(APPEND options ${CME_OPTIONS_${port}})
  foreach(option IN LISTS options)
    string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\1" name "${option}")
    string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\2" value "${option}")
    list(APPEND arguments "-D${name}=${value}")
  endforeach()

  message(STATUS "cmake-everywhere: building ${port} ${version} on its own")
  execute_process(COMMAND ${CMAKE_COMMAND} ${arguments}
                  RESULT_VARIABLE code OUTPUT_VARIABLE output
                  ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: configuring ${port} on its own failed\n${output}")
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${build}" --parallel --target install
    RESULT_VARIABLE code OUTPUT_VARIABLE output ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: building ${port} on its own failed\n${output}")
  endif()

  cme_environment_pairs(pairs)
  list(JOIN pairs "\n" recorded)
  file(WRITE "${entry}/environment.txt" "${recorded}\n")
  file(TOUCH "${entry}/complete")
  cme_note_decision("${port}" "built alone" "${version}")
endfunction()

# A library that was installed somewhere, as a target.
function(cme_installed_library alias prefix library)
  if(TARGET ${alias})
    return()
  endif()
  file(GLOB found "${prefix}/lib/${library}" "${prefix}/lib64/${library}"
                  "${prefix}/lib/*/${library}")
  if(NOT found)
    message(FATAL_ERROR
      "cmake-everywhere: ${library} is not in ${prefix} after installing it")
  endif()
  list(GET found 0 found)
  add_library(${alias} STATIC IMPORTED GLOBAL)
  set_target_properties(${alias} PROPERTIES
    IMPORTED_LOCATION "${found}"
    INTERFACE_INCLUDE_DIRECTORIES "${prefix}/include")
endfunction()

# ------------------------------------------------------------------ store

# Whether a target was made by this port, and so has to be kept, or comes
# from somewhere else and only has to be named.
#
# Two shapes of port produce targets two ways. A GN project is imported under
# names that begin with the port; a CMake project is added as a subdirectory,
# and its targets are the ones whose source directory is inside its checkout.
function(cme_store_owns out port target)
  set(${out} FALSE PARENT_SCOPE)
  if(target MATCHES "^${port}_")
    set(${out} TRUE PARENT_SCOPE)
    return()
  endif()
  get_target_property(where ${target} SOURCE_DIR)
  if(where AND ${port}_SOURCE_DIR AND
     where MATCHES "^${${port}_SOURCE_DIR}")
    set(${out} TRUE PARENT_SCOPE)
  endif()
endfunction()

# Everything an exported target actually needs, by walking what it links.
#
# A static library does not contain the other static libraries it links, and
# an interface library contains nothing at all. Keeping only the archive with
# the name on it keeps a piece, and the entry then fails either with a target
# that is not there or, later and worse, with undefined symbols.
#
# Object libraries are not collected: their objects are already inside the
# archive of whatever linked them.
function(cme_store_flatten port target out_archives out_links)
  set(archives "${${out_archives}}")
  set(links "${${out_links}}")
  get_target_property(public_linked ${target} INTERFACE_LINK_LIBRARIES)
  get_target_property(private_linked ${target} LINK_LIBRARIES)
  foreach(name public_linked private_linked)
    if("${${name}}" STREQUAL "${name}-NOTFOUND")
      set(${name} "")
    endif()
  endforeach()
  foreach(item IN LISTS public_linked private_linked)
    string(REGEX REPLACE "^\\$<LINK_ONLY:(.*)>$" "\\1" item "${item}")
    if(NOT item)
      continue()
    endif()
    if(NOT TARGET ${item})
      if(NOT item IN_LIST links)
        list(APPEND links "${item}")
      endif()
      continue()
    endif()
    get_target_property(aliased ${item} ALIASED_TARGET)
    if(aliased)
      set(item "${aliased}")
    endif()
    cme_store_owns(mine ${port} ${item})
    if(NOT mine)
      # Another library in the registry, or something the consumer has.
      # Named rather than kept, and resolved again by whoever reads this.
      if(NOT item IN_LIST links)
        list(APPEND links "${item}")
      endif()
      continue()
    endif()
    if(item IN_LIST archives)
      continue()
    endif()
    get_target_property(kind ${item} TYPE)
    if(kind STREQUAL "STATIC_LIBRARY")
      list(APPEND archives "${item}")
    endif()
    if(kind STREQUAL "STATIC_LIBRARY" OR kind STREQUAL "OBJECT_LIBRARY"
       OR kind STREQUAL "INTERFACE_LIBRARY")
      set(${out_archives} "${archives}" PARENT_SCOPE)
      set(${out_links} "${links}" PARENT_SCOPE)
      cme_store_flatten(${port} ${item} ${out_archives} ${out_links})
      set(archives "${${out_archives}}")
      set(links "${${out_links}}")
    endif()
  endforeach()
  set(${out_archives} "${archives}" PARENT_SCOPE)
  set(${out_links} "${links}" PARENT_SCOPE)
endfunction()

# An include directory that is inside this build is a directory the next
# build will not have: it is where a library's configure step wrote the
# header it generated -- zconf.h, pnglibconf.h. The headers are copied beside
# the archives and the path is rewritten to point there.
#
# Only what exists now is copied. A header a library generates while building
# rather than while configuring is not here yet, and a port whose library
# does that cannot be kept this way; it says so rather than keeping half.
function(cme_store_keep_headers out ok port entry directories)
  set(result "")
  set(${ok} TRUE PARENT_SCOPE)
  # Across both calls for one entry, because they write into the same
  # directory: two calls each starting at zero would put two different
  # include directories into generated/0 and mix them.
  get_property(index GLOBAL PROPERTY CME_STORE_INDEX_${port})
  if(NOT index)
    set(index 0)
  endif()
  foreach(directory IN LISTS directories)
    string(REGEX REPLACE "^\\$<BUILD_INTERFACE:(.*)>$" "\\1" directory
           "${directory}")
    # What a library says about where its headers will be once it is
    # installed is about an install that is not going to happen: nothing
    # here installs a dependency. Kept as it stands, that path is checked on
    # the way back in, is never there, and the entry is rebuilt every time
    # -- which is how freetype and libpng were stored and never used.
    if(directory MATCHES "^\\$<INSTALL_INTERFACE:")
      continue()
    endif()
    if(NOT directory MATCHES "^${CMAKE_BINARY_DIR}" AND NOT CME_STORE_PORTABLE)
      list(APPEND result "${directory}")
      continue()
    endif()
    set(inside FALSE)
    if(directory MATCHES "^${CMAKE_BINARY_DIR}")
      set(inside TRUE)
    endif()
    set(later FALSE)
    if(NOT IS_DIRECTORY "${directory}")
      if(NOT inside)
        # Not a directory to copy: a generator expression this cannot read,
        # or a path that is already gone. Kept as it stands, and checked when
        # the entry is read.
        list(APPEND result "${directory}")
        continue()
      endif()
      set(later TRUE)
    else()
      file(GLOB_RECURSE headers "${directory}/*")
      if(NOT headers AND inside)
        set(later TRUE)
      endif()
    endif()
    if(later)
      # The library writes its headers while it builds rather than while it
      # configures -- libsndfile makes its include directory, mpg123 fills
      # one -- so there is nothing to copy at this moment and there will be
      # something to copy at the next one. The copy is put where the archives
      # are copied, which is after the build.
      #
      # Recording the path instead, which is what happened before, keeps an
      # entry that names a directory inside a build tree: true on the machine
      # that wrote it and gone by the next build, so the entry is a miss
      # every time and the library is rebuilt every time while a new copy of
      # it is written into the store.
      set_property(GLOBAL APPEND PROPERTY CME_STORE_LATE_${port}
                   "${directory}" "${entry}/generated/${index}")
      list(APPEND result "\${CMAKE_CURRENT_LIST_DIR}/generated/${index}")
      math(EXPR index "${index} + 1")
      set_property(GLOBAL PROPERTY CME_STORE_INDEX_${port} "${index}")
      continue()
    endif()
    # All of it, rather than the extensions somebody thought of.
    #
    # An include directory is a directory of things a compiler may be told to
    # include, and what those are called is the library's business: Boost
    # writes .ipp beside .hpp, libstdc++ writes .tcc, and the C++ standard
    # library headers have no extension at all. A list of patterns here is a
    # list of the ways this has been wrong so far -- .ipp was the first, and
    # it failed as a missing file in a copy that looked complete.
    #
    # Module interface units come with it, which is what a consumer's build
    # needs to make its own BMI. A binary module interface is not kept and
    # could not be: CMake can install one and nothing consumes it, and
    # reusing one is left to a future that needs help from compilers.
    set(kept "${entry}/generated/${index}")
    file(COPY "${directory}/" DESTINATION "${kept}"
         PATTERN "CMakeFiles" EXCLUDE PATTERN ".git" EXCLUDE)
    list(APPEND result "\${CMAKE_CURRENT_LIST_DIR}/generated/${index}")
    math(EXPR index "${index} + 1")
    set_property(GLOBAL PROPERTY CME_STORE_INDEX_${port} "${index}")
  endforeach()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# What a built library looks like in the store: its archives, and a file
# saying what it is. Written while the real targets exist, because that is
# when what to say is known. The archives are copied when the build has made
# them and the stamp is written last, so an interrupted build leaves an entry
# that is ignored rather than one that is half true.
function(cme_store_write port package entry)
  cme_port_field(aliases ${port} TARGETS)
  if(NOT aliases)
    message(STATUS
      "cmake-everywhere: ${port} is not kept: it does not say what it produces")
    return()
  endif()
  # Filled under a name nobody reads and moved into place in one step at the
  # end. A reader cannot tell a directory being written from a finished one,
  # and a rename is the only way to say "now".
  set_property(GLOBAL PROPERTY CME_STORE_LATE_${port} "")
  set_property(GLOBAL PROPERTY CME_STORE_INDEX_${port} 0)
  string(RANDOM LENGTH 8 ALPHABET "abcdefghijklmnopqrstuvwxyz0123456789" tag)
  get_filename_component(parent "${entry}" DIRECTORY)
  get_filename_component(leaf "${entry}" NAME)
  set(building "${parent}/.building-${leaf}-${tag}")
  file(REMOVE_RECURSE "${building}")
  file(MAKE_DIRECTORY "${building}/lib")
  set(text "# Written by cmake-everywhere. Do not edit; the name is a hash.\n")
  # An entry keeps the headers a library wrote while configuring, and points
  # at the ones that were already in its source tree rather than copying
  # them. That is cheap and it is true on the machine that built it -- and a
  # store handed to another machine, or to another job, may not have those
  # sources. So the entry says which directories it is relying on, and checks
  # them before it defines anything: a missing one is a miss, and a miss is a
  # rebuild rather than an imported target pointing into nothing.
  set(outside "")
  set(main "")
  set(everything "")
  foreach(alias IN LISTS aliases)
    if(NOT TARGET ${alias})
      message(STATUS
        "cmake-everywhere: ${port} is not kept: it says it produces ${alias} "
        "and that is not a target")
      file(REMOVE_RECURSE "${building}")
      return()
    endif()
    get_target_property(target ${alias} ALIASED_TARGET)
    if(NOT target)
      set(target "${alias}")
    endif()
    get_target_property(kind ${target} TYPE)
    if(NOT kind STREQUAL "STATIC_LIBRARY")
      # Only an archive can be kept and used again. Anything else -- an
      # interface library, a shared object -- is left to be built.
      message(STATUS
        "cmake-everywhere: ${port} is not kept: ${alias} is a ${kind}")
      file(REMOVE_RECURSE "${building}")
      return()
    endif()
    if(NOT main)
      set(main "${target}")
    endif()

    get_target_property(includes ${target} INTERFACE_INCLUDE_DIRECTORIES)
    get_target_property(defines ${target} INTERFACE_COMPILE_DEFINITIONS)
    get_target_property(options ${target} INTERFACE_COMPILE_OPTIONS)
    foreach(name includes defines options)
      if("${${name}}" STREQUAL "${name}-NOTFOUND")
        set(${name} "")
      endif()
    endforeach()
    cme_store_keep_headers(includes kept ${port} "${building}" "${includes}")
    if(NOT kept)
      file(REMOVE_RECURSE "${building}")
      return()
    endif()
    foreach(directory IN LISTS includes)
      if(NOT directory MATCHES "^\\\${CMAKE_CURRENT_LIST_DIR}")
        list(APPEND outside "${directory}")
      endif()
    endforeach()

    set(archives "${target}")
    set(links "")
    cme_store_flatten(${port} ${target} archives links)
    set(rest "")
    foreach(archive IN LISTS archives)
      if(NOT archive STREQUAL target)
        list(APPEND rest "\${CMAKE_CURRENT_LIST_DIR}/lib/lib${archive}.a")
      endif()
    endforeach()
    list(APPEND rest ${links})
    list(JOIN rest ";" rest)
    list(JOIN includes ";" includes)
    list(JOIN defines ";" defines)
    list(JOIN options ";" options)

    # A name that is somebody else's target has to be somebody else's target
    # again when this is read back. The entry says which package makes it and
    # asks for it -- through the provider, so another port in the registry is
    # built or found, and something the consumer's CMake knows about, like
    # Threads::Threads, is found by its own find module.
    #
    # Without this the entry sets a link interface naming a target that does
    # not exist, and the failure is at generate time in a file whose name is
    # a hash, about a target the project never mentioned.
    foreach(item IN LISTS rest)
      if(NOT item MATCHES "^([A-Za-z0-9_.+-]+)::")
        continue()
      endif()
      string(APPEND text
        "if(NOT TARGET ${item})\n"
        "  find_package(${CMAKE_MATCH_1} QUIET)\n"
        "endif()\n"
        "if(NOT TARGET ${item})\n"
        "  message(FATAL_ERROR\n"
        "    \"cmake-everywhere: ${port} was built against ${item}, and this "
        "build has no target by that name. find_package(${CMAKE_MATCH_1}) "
        "did not make one.\")\n"
        "endif()\n")
    endforeach()

    string(APPEND text
      "add_library(${alias} STATIC IMPORTED GLOBAL)\n"
      "set_target_properties(${alias} PROPERTIES\n"
      "  IMPORTED_LOCATION \"\${CMAKE_CURRENT_LIST_DIR}/lib/lib${target}.a\"\n"
      "  INTERFACE_INCLUDE_DIRECTORIES \"${includes}\"\n"
      "  INTERFACE_LINK_LIBRARIES \"${rest}\"\n"
      "  INTERFACE_COMPILE_OPTIONS \"${options}\"\n"
      "  INTERFACE_COMPILE_DEFINITIONS \"${defines}\")\n")

    # And the name the library calls itself, once the target it points at
    # exists. Boost.Filesystem puts $<TARGET_PROPERTY:boost_filesystem,TYPE>
    # in its own compile definitions, and on a hit that target does not
    # exist: only the namespaced name does, which is the one a consumer
    # writes and not the one the library wrote about itself.
    if(NOT target STREQUAL alias)
      string(APPEND text
        "if(NOT TARGET ${target})\n"
        "  add_library(${target} ALIAS ${alias})\n"
        "endif()\n")
    endif()

    list(APPEND everything ${archives})
  endforeach()

  # The variables a consumer reads are part of what the library is, and the
  # adapter that made them will not run next time.
  get_property(exported GLOBAL PROPERTY CME_EXPORT_${package})
  string(APPEND text "\nset(CME_STORED_EXPORT \"\")\n")
  while(exported)
    list(POP_FRONT exported name value)
    string(REPLACE "@CME@" ";" value "${value}")
    cme_store_keep_headers(value kept ${port} "${building}" "${value}")
    if(NOT kept)
      file(REMOVE_RECURSE "${building}")
      return()
    endif()
    list(JOIN value ";" value)
    string(REPLACE ";" "@CME@" value "${value}")
    string(APPEND text
      "list(APPEND CME_STORED_EXPORT \"${name}\" \"${value}\")\n")
  endwhile()
  string(APPEND text
    "set_property(GLOBAL PROPERTY CME_EXPORT_${package} \"\${CME_STORED_EXPORT}\")\n")

  if(outside)
    list(REMOVE_DUPLICATES outside)
    set(guard "")
    foreach(directory IN LISTS outside)
      string(APPEND guard
        "if(NOT EXISTS \"${directory}\")\n"
        "  message(STATUS\n"
        "    \"cmake-everywhere: ${port} was kept beside ${directory}, and "
        "that is not here now\")\n"
        "  set(CME_STORE_INCOMPLETE TRUE)\n"
        "  return()\n"
        "endif()\n")
    endforeach()
    set(text "${guard}${text}")
  endif()

  # A target of our own rather than a step after theirs: a POST_BUILD command
  # may only be attached to a target created in the same directory, and a
  # library added as a subdirectory is not.
  #
  # The copying is one command list ending in the stamp, so the stamp cannot
  # appear before the archives it claims are there.
  set(keeping "")
  if(everything)
    list(REMOVE_DUPLICATES everything)
  endif()
  foreach(archive IN LISTS everything)
    list(APPEND keeping COMMAND ${CMAKE_COMMAND} -E copy_if_different
         "$<TARGET_FILE:${archive}>" "${building}/lib/lib${archive}.a")
  endforeach()
  # The headers that did not exist when this entry was described. If one of
  # them is still not there after the build, the entry is not published: the
  # script says so and leaves a mark that store-finish reads.
  get_property(late GLOBAL PROPERTY CME_STORE_LATE_${port})
  while(late)
    list(POP_FRONT late from to)
    list(APPEND keeping COMMAND ${CMAKE_COMMAND} "-Dfrom=${from}" "-Dto=${to}"
         -P "${CME_DIR}/cmake/store-headers.cmake")
  endwhile()
  add_custom_target(cme_store_${port} ALL
    ${keeping}
    COMMAND ${CMAKE_COMMAND} "-Dfrom=${building}" "-Dto=${entry}"
            -P "${CME_DIR}/cmake/store-finish.cmake"
    COMMENT "cmake-everywhere: keeping ${port} in the store"
    VERBATIM)
  add_dependencies(cme_store_${port} ${everything})
  file(WRITE "${building}/use.cmake" "${text}")
  list(LENGTH everything count)
  message(STATUS
    "cmake-everywhere: ${port} will be kept as ${entry} (${count} archive(s))")
  cme_environment_pairs(pairs)
  list(JOIN pairs "\n" recorded)
  file(WRITE "${building}/environment.txt" "${recorded}\n")
endfunction()

# Headers under a name they are not under in the source tree.
#
# A library's include directory in its own checkout and the same directory
# once it is installed are often not the same shape. Opus keeps its headers
# flat, at include/opus.h, and everything that consumes an installed Opus
# writes <opus/opus.h>. Skia includes itself by a path that says nothing
# about whose headers they are.
#
# Rather than copy or rewrite anything, the directory is offered a second
# time under the name consumers use, as a link, and the directory holding
# that link is what goes on the interface. Both spellings then work and the
# checkout is untouched.
function(cme_header_prefix out name directory)
  set(root "${CMAKE_BINARY_DIR}/cme-include")
  file(MAKE_DIRECTORY "${root}")
  if(NOT EXISTS "${root}/${name}")
    file(CREATE_LINK "${directory}" "${root}/${name}" SYMBOLIC RESULT status)
    if(NOT status STREQUAL "0")
      message(FATAL_ERROR
        "cmake-everywhere: cannot offer ${directory} as ${name}: ${status}")
    endif()
  endif()
  set(${out} "${root}" PARENT_SCOPE)
endfunction()

# An alias so that whatever the upstream calls its target -- zlibstatic,
# png_static, FLAC -- can be linked under the name its consumers expect.
function(cme_alias alias target)
  if(TARGET ${alias})
    return()
  endif()
  if(NOT TARGET ${target})
    message(FATAL_ERROR
      "cmake-everywhere: ${target} was not built, so ${alias} cannot exist")
  endif()
  # An executable is aliased with add_executable and a library with
  # add_library, and using the wrong one is an error rather than a
  # conversion. A port can produce either: wayland's scanner is a program
  # its consumers run to generate their own protocol bindings.
  get_target_property(kind ${target} TYPE)
  if(kind STREQUAL "EXECUTABLE")
    add_executable(${alias} ALIAS ${target})
    return()
  endif()
  add_library(${alias} ALIAS ${target})
endfunction()

function(cme_include_ports where origin)
  file(GLOB ports "${where}/*/port.cmake")
  foreach(port IN LISTS ports)
    get_filename_component(directory "${port}" DIRECTORY)
    set_property(GLOBAL PROPERTY CME_PORT_ORIGIN "${origin}")
    set_property(GLOBAL PROPERTY CME_PORT_DIRECTORY "${directory}")
    set_property(GLOBAL PROPERTY CME_PORT_FILE "${port}")
    include("${port}")
  endforeach()
  set_property(GLOBAL PROPERTY CME_PORT_ORIGIN "")
  set_property(GLOBAL PROPERTY CME_PORT_DIRECTORY "")
  set_property(GLOBAL PROPERTY CME_PORT_FILE "")
endfunction()

# Every prefix this configuration would look in, that has ports in it.
function(cme_system_port_directories out)
  set(prefixes "")
  foreach(list IN ITEMS CMAKE_PREFIX_PATH CMAKE_SYSTEM_PREFIX_PATH)
    list(APPEND prefixes ${${list}})
  endforeach()
  if(DEFINED ENV{CMAKE_PREFIX_PATH})
    file(TO_CMAKE_PATH "$ENV{CMAKE_PREFIX_PATH}" from_environment)
    list(APPEND prefixes ${from_environment})
  endif()
  list(APPEND prefixes "${CMAKE_STAGING_PREFIX}" "${CMAKE_INSTALL_PREFIX}")
  set(found "")
  foreach(prefix IN LISTS prefixes)
    if(prefix AND IS_DIRECTORY "${prefix}/${CME_EXPORT_DESTINATION}")
      list(APPEND found "${prefix}/${CME_EXPORT_DESTINATION}")
    endif()
  endforeach()
  if(found)
    list(REMOVE_DUPLICATES found)
  endif()
  set(${out} "${found}" PARENT_SCOPE)
endfunction()

# Every find_package this build answered, and the directory it was asked
# from. A library's dependencies are what it asked for while it was built,
# which is a truer list than one kept by hand in a port.
function(cme_note_ask port)
  if(NOT CME_EXPORT_PORTS)
    return()
  endif()
  set_property(GLOBAL APPEND PROPERTY CME_ASK_DIRS
               "${CMAKE_CURRENT_SOURCE_DIR}")
  set_property(GLOBAL APPEND PROPERTY CME_ASK_PORTS "${port}")
endfunction()

# Called at the end of the top-level directory, when everything that was
# going to ask has asked.
function(cme_finish_exports)
  get_property(names GLOBAL PROPERTY CME_EXPORTING)
  get_property(dirs GLOBAL PROPERTY CME_ASK_DIRS)
  get_property(asked GLOBAL PROPERTY CME_ASK_PORTS)
  foreach(name IN LISTS names)
    # What was needed here, which is only knowable for something this build
    # actually configured.
    if(name STREQUAL PROJECT_NAME)
      set(home "${CMAKE_SOURCE_DIR}")
    else()
      get_property(home GLOBAL PROPERTY CME_TREE_${name})
    endif()
    set(needs "")
    if(home)
      set(index 0)
      foreach(directory IN LISTS dirs)
        list(GET asked ${index} port)
        math(EXPR index "${index} + 1")
        cmake_path(IS_PREFIX home "${directory}" NORMALIZE inside)
        if(inside AND NOT port STREQUAL name AND NOT port IN_LIST needs)
          list(APPEND needs "${port}")
        endif()
      endforeach()
    endif()

    # Every exported port says what the copy beside it is: the version that
    # was built, the features it was built with, and what it needed to be
    # built that way. A machine that has the library then knows whether it
    # has the library this build needs, instead of a build looking for a
    # symbol and hoping the feature adds one.
    cme_enabled_features(${name} built_with)
    cme_port_field(built_version ${name} VERSION)
    set(copy "cme_installed_with(${name}")
    if(built_version)
      cme_quote(value "${built_version}")
      string(APPEND copy " VERSION \"${value}\"")
    endif()
    foreach(kind FEATURES NEEDED)
      if(kind STREQUAL "FEATURES")
        set(items "${built_with}")
      else()
        set(items "${needs}")
      endif()
      if(NOT items)
        continue()
      endif()
      string(APPEND copy " ${kind}")
      foreach(item IN LISTS items)
        cme_quote(value "${item}")
        string(APPEND copy " \"${value}\"")
      endforeach()
    endforeach()
    cme_export_line(${name} "${copy})")

    # And what the library needs, which is a different statement and a
    # narrower one. What it needed here is what it needed with these features
    # on; declaring that as what the library needs would make the next
    # project build a dependency it never asked for. So it is declared only
    # when nothing was on, and otherwise it stays where it belongs, in the
    # line above, as a fact about this copy.
    if(NOT needs)
      continue()
    endif()
    if(built_with)
      list(JOIN built_with ", " listed_on)
      message(STATUS
        "cmake-everywhere: ${name} was built with ${listed_on}, so what it "
        "needed is written as this copy's rather than as the library's")
      continue()
    endif()
    set(said "cme_port_needs(${name}")
    foreach(item IN LISTS needs)
      cme_quote(value "${item}")
      string(APPEND said " \"${value}\"")
    endforeach()
    cme_export_line(${name} "${said})")
    list(JOIN needs " " listed_needs)
    message(STATUS
      "cmake-everywhere: ${name} needs ${listed_needs}, and its exported port "
      "now says so")
  endforeach()
endfunction()

# Which port answers for a pkg-config module.
#
# The ports already say it, the other way round: SYSTEM_PKGCONFIG is how a
# port says which modules a machine may have it as. Read backwards it says
# which port a module is, and that is what a pkg_check_modules call needs.
#
# Those are two questions, and a port can answer one and not the other.
# "Which module names mean this library" is a fact about the library;
# "which of them may answer for it" is a judgement about copies of it this
# build did not make. Skia is where they came apart: what an installed Skia
# was compiled with cannot be read from a .pc file and its features are
# exactly that, so the port refuses to take a system copy -- and it is
# still the port that the module `skia` means. PKGCONFIG_NAMES says the
# first without the second.
function(cme_pkgconfig_port out module)
  set(${out} "" PARENT_SCOPE)
  # The ports have to be read before they can be asked, and nothing has
  # necessarily read them yet: they are loaded by the first find_package
  # that reaches the provider, and find_package(PkgConfig) is answered
  # before that -- it is the call that installs this. A project whose first
  # question is a pkg-config one therefore asked an empty registry, was told
  # no port answers for zlib, and went to pkg-config. It linked, because the
  # machine has zlib, which is why this stood.
  cme_load_registry()
  get_property(names GLOBAL PROPERTY CME_PORTS)
  foreach(port IN LISTS names)
    cme_port_field(named ${port} PKGCONFIG_NAMES)
    if(module IN_LIST named)
      set(${out} "${port}" PARENT_SCOPE)
      return()
    endif()
    cme_port_field(mapping ${port} SYSTEM_PKGCONFIG)
    foreach(pair IN LISTS mapping)
      if(pair MATCHES "^([^:]+):(.+)$")
        set(named "${CMAKE_MATCH_1}")
      else()
        set(named "${pair}")
      endif()
      # An entry can name several modules that are the same library, and
      # a call asking for any one of them is asking for this port.
      string(REPLACE "|" ";" alternatives "${named}")
      if(module IN_LIST alternatives)
        set(${out} "${port}" PARENT_SCOPE)
        return()
      endif()
    endforeach()
  endforeach()
endfunction()

# pkg_check_modules, answered the same way find_package is.
#
# A dependency provider is offered find_package and nothing else, so a
# project -- or a library this build added -- that asks pkg-config instead
# goes straight past all of this: it finds the system's copy or it finds
# nothing, and nothing here hears the question. That is a hole of the same
# shape as a system config file resolving its own components, which this
# already closes.
#
# CMake lets a command be redefined, and the one that was there stays
# reachable with an underscore, so the real pkg_check_modules is still what
# answers everything this cannot.
#
# Only a REQUIRED call is answered here. Without REQUIRED the question is
# "does this machine have it", and a build that answered that by building
# the library would be answering a different question: an optional
# dependency would become a compulsory download.
# A function rather than a macro, and that is not a style choice.
#
# A macro's body is re-scanned with the macro's own arguments substituted
# into it, and a macro defined inside a macro is defined out of that
# substituted text: the ${ARGN} of the inner one was replaced by the empty
# ARGN of the outer one before it ever existed. Every call then arrived with
# no arguments at all, and the real pkg_check_modules said so -- "invoked
# with incorrect arguments" -- from a line that plainly passes it several.
# A function's body is not substituted, so what is defined inside one is
# what was written.
# Installed again on every find_package(PkgConfig), and that is not
# belt-and-braces either.
#
# FindPkgConfig is a find module, and a find module is read again every time
# it is found: the second find_package(PkgConfig) in a build re-runs the
# file, which defines pkg_check_modules again -- over this one. skiff asks
# for PkgConfig itself, so from that point on every pkg-config question in
# the build went to pkg-config, and the client linked the Skia built here
# while skiff linked the machine's. Installing once was installing until
# somebody else asked the same question.
#
# Redefining it again is what undoes that, and it nests correctly: each
# definition leaves the one before it reachable with an underscore, so the
# real one is still what answers everything this cannot.
function(cme_install_pkgconfig_override)
  if(COMMAND pkg_check_modules)

    # A macro rather than a function, because everything a caller of
    # pkg_check_modules reads afterwards is a variable it expects in its own
    # scope, and a macro is already there. It costs the use of return(),
    # which in a macro would return from whoever called it.
    macro(pkg_check_modules cme_pkg_prefix)
      set(cme_pkg_wanted "")
      set(cme_pkg_rest "")
      set(cme_pkg_required FALSE)
      set(cme_pkg_imported FALSE)
      foreach(cme_pkg_argument IN ITEMS ${ARGN})
        if(cme_pkg_argument STREQUAL "REQUIRED")
          set(cme_pkg_required TRUE)
        elseif(cme_pkg_argument STREQUAL "IMPORTED_TARGET")
          set(cme_pkg_imported TRUE)
        elseif(NOT cme_pkg_argument MATCHES
               "^(QUIET|GLOBAL|NO_CMAKE_PATH|NO_CMAKE_ENVIRONMENT_PATH)$")
          list(APPEND cme_pkg_wanted "${cme_pkg_argument}")
        endif()
        list(APPEND cme_pkg_rest "${cme_pkg_argument}")
      endforeach()

      # Only a REQUIRED call. Without it the question is "does this machine
      # have it", and answering that by building the library answers a
      # different one: an optional dependency would become a compulsory
      # download.
      set(cme_pkg_ports "")
      set(cme_pkg_ours ${cme_pkg_required})
      foreach(cme_pkg_spec IN LISTS cme_pkg_wanted)
        # "zlib >= 1.2" and "zlib>=1.2" are both spellings pkg-config takes.
        string(REGEX REPLACE "[ ]*[<>=]+.*$" "" cme_pkg_module "${cme_pkg_spec}")
        cme_pkgconfig_port(cme_pkg_port "${cme_pkg_module}")
        if(cme_pkg_port)
          list(APPEND cme_pkg_ports "${cme_pkg_port}")
        else()
          set(cme_pkg_ours FALSE)
        endif()
      endforeach()

      if(NOT cme_pkg_ours)
        _pkg_check_modules(${cme_pkg_prefix} ${cme_pkg_rest})
      else()
        set(cme_pkg_targets "")
        set(cme_pkg_version "")
        foreach(cme_pkg_port IN LISTS cme_pkg_ports)
          cme_port_field(cme_pkg_names ${cme_pkg_port} PROVIDES)
          list(GET cme_pkg_names 0 cme_pkg_package)
          find_package(${cme_pkg_package} REQUIRED QUIET)
          cme_port_field(cme_pkg_theirs ${cme_pkg_port} TARGETS)
          foreach(cme_pkg_one IN LISTS cme_pkg_theirs)
            if(TARGET ${cme_pkg_one})
              list(APPEND cme_pkg_targets "${cme_pkg_one}")
            endif()
          endforeach()
          get_property(cme_pkg_at GLOBAL PROPERTY
                       CME_PROVIDED_VERSION_${cme_pkg_package})
          if(cme_pkg_at AND NOT cme_pkg_version)
            set(cme_pkg_version "${cme_pkg_at}")
          endif()
        endforeach()
        if(cme_pkg_targets)
          list(REMOVE_DUPLICATES cme_pkg_targets)
        endif()

        # What a caller reads afterwards. The include directories and the
        # link flags are on the targets, which is why these are empty rather
        # than missing: a caller that adds them adds nothing, and a caller
        # that checks them sees the shape it expects.
        set(${cme_pkg_prefix}_FOUND TRUE)
        set(${cme_pkg_prefix}_LIBRARIES ${cme_pkg_targets})
        set(${cme_pkg_prefix}_LINK_LIBRARIES ${cme_pkg_targets})
        set(${cme_pkg_prefix}_LDFLAGS ${cme_pkg_targets})
        set(${cme_pkg_prefix}_STATIC_LDFLAGS ${cme_pkg_targets})
        set(${cme_pkg_prefix}_STATIC_LIBRARIES ${cme_pkg_targets})
        set(${cme_pkg_prefix}_INCLUDE_DIRS "")
        set(${cme_pkg_prefix}_STATIC_INCLUDE_DIRS "")
        set(${cme_pkg_prefix}_LIBRARY_DIRS "")
        set(${cme_pkg_prefix}_CFLAGS_OTHER "")
        set(${cme_pkg_prefix}_STATIC_CFLAGS_OTHER "")
        set(${cme_pkg_prefix}_VERSION "${cme_pkg_version}")
        if(cme_pkg_imported AND NOT TARGET PkgConfig::${cme_pkg_prefix})
          add_library(PkgConfig::${cme_pkg_prefix} INTERFACE IMPORTED GLOBAL)
          if(cme_pkg_targets)
            set_property(TARGET PkgConfig::${cme_pkg_prefix} PROPERTY
                         INTERFACE_LINK_LIBRARIES ${cme_pkg_targets})
          endif()
        endif()
        list(JOIN cme_pkg_wanted ", " cme_pkg_listed)
        message(STATUS
          "cmake-everywhere: ${cme_pkg_listed} was asked for through "
          "pkg-config, and is answered the way find_package would be")
      endif()
    endmacro()
  endif()
endfunction()

function(cme_load_registry)
  get_property(loaded GLOBAL PROPERTY CME_REGISTRY_LOADED)
  if(loaded)
    return()
  endif()
  set_property(GLOBAL PROPERTY CME_REGISTRY_LOADED TRUE)
  foreach(spec IN LISTS CME_OVERLAYS)
    cme_overlay_directory(directory "${spec}")
    file(GLOB found "${directory}/*/port.cmake")
    if(NOT found)
      message(FATAL_ERROR
        "cmake-everywhere: the overlay ${spec} has no <name>/port.cmake "
        "under ${directory}. An overlay is laid out the way the registry "
        "is: one directory per port, with a port.cmake in it.")
    endif()
    cme_include_ports("${directory}" "the overlay ${spec}")
  endforeach()
  if(CME_SYSTEM_PORTS)
    cme_system_port_directories(prefixes)
    foreach(directory IN LISTS prefixes)
      cme_include_ports("${directory}" "the system, in ${directory}")
    endforeach()
  endif()
  cme_include_ports("${CME_REGISTRY}" "the registry")
  get_property(names GLOBAL PROPERTY CME_PORTS)
  list(LENGTH names count)
  message(STATUS "cmake-everywhere: ${count} ports")
endfunction()

# ---------------------------------------------------------------- resolving

function(cme_note_decision package how detail)
  set_property(GLOBAL APPEND PROPERTY CME_DECISIONS "${package} ${how} ${detail}")
  get_property(all GLOBAL PROPERTY CME_DECISIONS)
  list(JOIN all "\n" text)
  file(WRITE "${CME_LOCK_FILE}" "${text}\n")
endfunction()

function(cme_system_allowed out package)
  string(TOUPPER "${package}" upper)
  if(DEFINED CME_SYSTEM_${upper})
    set(${out} "${CME_SYSTEM_${upper}}" PARENT_SCOPE)
    return()
  endif()
  if(CME_SYSTEM STREQUAL "NEVER")
    set(${out} OFF PARENT_SCOPE)
  else()
    set(${out} ON PARENT_SCOPE)
  endif()
endfunction()

# A dependency may carry a floor: "ogg>=1.3" means this port does not work
# with anything older. Constraints are data in the registry, so the whole
# graph can be read before a single add_subdirectory has run.
# "ogg", "ogg>=1.3", "skia[vulkan]", "skia[vulkan,pdf]>=2" -- a dependency
# says which version it needs and which features it needs it to have.
function(cme_split_requirement spec out_name out_version out_features)
  set(rest "${spec}")
  set(features "")
  if(rest MATCHES "^([^[]+)\\[([^]]*)\\](.*)$")
    set(rest "${CMAKE_MATCH_1}${CMAKE_MATCH_3}")
    string(REPLACE "," ";" features "${CMAKE_MATCH_2}")
  endif()
  if(rest MATCHES "^([^><=]+)>=(.+)$")
    set(${out_name} "${CMAKE_MATCH_1}" PARENT_SCOPE)
    set(${out_version} "${CMAKE_MATCH_2}" PARENT_SCOPE)
  else()
    set(${out_name} "${rest}" PARENT_SCOPE)
    set(${out_version} "" PARENT_SCOPE)
  endif()
  set(${out_features} "${features}" PARENT_SCOPE)
endfunction()

# Walks the graph raising the floor on every port in it. This is the whole
# point of the constraints being data: a version asked for by something deep
# in the graph is known before the shallow end is built, so nothing has to be
# built twice and nothing ends up older than something else needed.
# Who asked for what. A conflict between two features is only useful to read
# if it says which two things wanted them, and by the time it is found the
# call that started it is several levels up.
function(cme_remember_why port feature reason)
  get_property(known GLOBAL PROPERTY CME_WHY_${port}_${feature})
  if(NOT known)
    set_property(GLOBAL PROPERTY CME_WHY_${port}_${feature} "${reason}")
  endif()
endfunction()

function(cme_why out port feature)
  get_property(reason GLOBAL PROPERTY CME_WHY_${port}_${feature})
  if(NOT reason)
    set(reason "something in the build")
  endif()
  set(${out} "${reason}" PARENT_SCOPE)
endfunction()

# A feature that turns on others: egl is gl reached differently, and
# fontconfig is not fontconfig without freetype under it. Applied
# transitively, because an implication can imply.
function(cme_expand_implications port features out)
  set(result "${features}")
  set(pending "${features}")
  while(pending)
    list(POP_FRONT pending feature)
    cme_feature_field(implied ${port} ${feature} IMPLIES)
    foreach(other IN LISTS implied)
      if(NOT other IN_LIST result)
        list(APPEND result "${other}")
        list(APPEND pending "${other}")
        cme_why(reason ${port} ${feature})
        cme_remember_why(${port} ${other} "${port}[${feature}], from ${reason}")
      endif()
    endforeach()
  endwhile()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# Two features of one library that cannot both be on. Checked as they are
# gathered rather than at the end, so the error can name the two things that
# asked rather than the state they left behind.
function(cme_check_feature_conflicts port)
  cme_enabled_features(${port} enabled)
  foreach(feature IN LISTS enabled)
    cme_feature_field(against ${port} ${feature} CONFLICTS)
    foreach(other IN LISTS against)
      if(other IN_LIST enabled)
        cme_why(first ${port} ${feature})
        cme_why(second ${port} ${other})
        message(FATAL_ERROR
          "cmake-everywhere: ${port} cannot have both ${feature} and "
          "${other}.\n"
          "  ${feature} was asked for by ${first}\n"
          "  ${other} was asked for by ${second}")
      endif()
    endforeach()
  endforeach()
endfunction()

# A library, or a feature of one, that must not be in the build at all when
# this one is. Registered when it is learned and checked from both ends,
# because the two sides can arrive in either order.
function(cme_register_exclusions port features)
  cme_port_field(excluded ${port} EXCLUDES)
  set(reasons "${port}")
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} EXCLUDES)
    foreach(spec IN LISTS extra)
      list(APPEND excluded "${spec}")
      set(reasons "${reasons};${port}[${feature}]")
    endforeach()
  endforeach()
  set(index 0)
  foreach(spec IN LISTS excluded)
    list(LENGTH reasons count)
    if(index LESS count)
      list(GET reasons ${index} by)
    else()
      set(by "${port}")
    endif()
    math(EXPR index "${index} + 1")
    set_property(GLOBAL APPEND PROPERTY CME_EXCLUSIONS "${by}|${spec}")
  endforeach()
  cme_check_exclusions()
endfunction()

function(cme_check_exclusions)
  get_property(exclusions GLOBAL PROPERTY CME_EXCLUSIONS)
  foreach(entry IN LISTS exclusions)
    if(NOT entry MATCHES "^([^|]+)\\|(.+)$")
      continue()
    endif()
    set(by "${CMAKE_MATCH_1}")
    cme_split_requirement("${CMAKE_MATCH_2}" name unused wanted_features)
    get_property(required GLOBAL PROPERTY CME_REQUIREMENTS_VISITED_${name})
    if(NOT required)
      continue()
    endif()
    if(wanted_features)
      cme_enabled_features(${name} enabled)
      set(hit FALSE)
      foreach(feature IN LISTS wanted_features)
        if(feature IN_LIST enabled)
          set(hit TRUE)
          set(named "${name}[${feature}]")
        endif()
      endforeach()
      if(NOT hit)
        continue()
      endif()
    else()
      set(named "${name}")
    endif()
    cme_why(reason ${name} "")
    message(FATAL_ERROR
      "cmake-everywhere: ${by} cannot be in a build with ${named}, and both "
      "are.\n"
      "  ${named} was asked for by ${reason}")
  endforeach()
endfunction()

# The rules that can only be broken by turning something on. Checked while
# the graph is being walked, so the error names what asked.
function(cme_check_open_rules port)
  cme_enabled_features(${port} enabled)
  get_property(kinds GLOBAL PROPERTY CME_RULES_${port})
  set(index 0)
  foreach(kind IN LISTS kinds)
    get_property(members GLOBAL PROPERTY CME_RULE_${port}_${index})
    math(EXPR index "${index} + 1")
    if(NOT kind STREQUAL "AT_MOST_ONE_OF" AND NOT kind STREQUAL "EXACTLY_ONE_OF")
      continue()
    endif()
    set(on "")
    foreach(feature IN LISTS members)
      if(feature IN_LIST enabled)
        list(APPEND on "${feature}")
      endif()
    endforeach()
    list(LENGTH on count)
    if(count GREATER 1)
      set(lines "")
      foreach(feature IN LISTS on)
        cme_why(reason ${port} ${feature})
        string(APPEND lines "\n  ${feature} was asked for by ${reason}")
      endforeach()
      list(JOIN members ", " listed)
      message(FATAL_ERROR
        "cmake-everywhere: ${port} can have at most one of ${listed}, and it "
        "has ${count}.${lines}")
    endif()
  endforeach()
endfunction()

# The rules that can only be broken by leaving something out, which is not
# known until nothing more can ask.
function(cme_check_closed_rules port)
  cme_enabled_features(${port} enabled)
  get_property(kinds GLOBAL PROPERTY CME_RULES_${port})
  set(index 0)
  foreach(kind IN LISTS kinds)
    get_property(members GLOBAL PROPERTY CME_RULE_${port}_${index})
    math(EXPR index "${index} + 1")
    # A feature that needs one of several others, and only when it is on
    # itself. Skia's GL backend is the case: it has to be told how to reach
    # GL -- EGL or GLX -- and with neither, Skia's own build quietly ends
    # the chain at GrGLMakeNativeInterface_none.cpp, which returns nothing.
    if(kind STREQUAL "WITH")
      set(rest "${members}")
      list(POP_FRONT rest trigger word)
      if(NOT trigger IN_LIST enabled OR NOT word STREQUAL "AT_LEAST_ONE_OF")
        continue()
      endif()
      set(on "")
      foreach(feature IN LISTS rest)
        if(feature IN_LIST enabled)
          list(APPEND on "${feature}")
        endif()
      endforeach()
      if(NOT on)
        list(JOIN rest ", " listed)
        message(FATAL_ERROR
          "cmake-everywhere: ${port}'s ${trigger} needs one of ${listed}, "
          "and this build asked for none of them. Ask for one with "
          "find_package COMPONENTS, or cme_features.")
      endif()
      continue()
    endif()
    if(NOT kind STREQUAL "AT_LEAST_ONE_OF" AND NOT kind STREQUAL "EXACTLY_ONE_OF")
      continue()
    endif()
    set(on "")
    foreach(feature IN LISTS members)
      if(feature IN_LIST enabled)
        list(APPEND on "${feature}")
      endif()
    endforeach()
    if(NOT on)
      list(JOIN members ", " listed)
      message(FATAL_ERROR
        "cmake-everywhere: ${port} needs one of ${listed} and has none of "
        "them. Ask for one with find_package COMPONENTS, or cme_features.")
    endif()
  endforeach()
endfunction()

# A dependency that exists because a feature is off rather than on.
function(cme_absent_dependencies port out)
  cme_enabled_features(${port} enabled)
  get_property(kinds GLOBAL PROPERTY CME_RULES_${port})
  set(index 0)
  set(result "")
  foreach(kind IN LISTS kinds)
    get_property(members GLOBAL PROPERTY CME_RULE_${port}_${index})
    math(EXPR index "${index} + 1")
    if(NOT kind STREQUAL "WITHOUT")
      continue()
    endif()
    # WITHOUT <feature> DEPENDS <spec>...
    list(GET members 0 feature)
    if(feature IN_LIST enabled)
      continue()
    endif()
    list(FIND members "DEPENDS" at)
    if(at LESS 0)
      continue()
    endif()
    math(EXPR at "${at} + 1")
    list(LENGTH members count)
    while(at LESS count)
      list(GET members ${at} spec)
      list(APPEND result "${spec}")
      math(EXPR at "${at} + 1")
    endwhile()
  endforeach()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# What a library is under, and whether this build will have it.
function(cme_check_licence port reason)
  if(NOT CME_ACCEPT_LICENSES)
    return()
  endif()
  cme_port_field(licence ${port} LICENSE)
  if(NOT licence)
    message(FATAL_ERROR
      "cmake-everywhere: this build only accepts ${CME_ACCEPT_LICENSES}, and "
      "the ${port} port does not say what it is under. Add LICENSE to it.")
  endif()
  foreach(one IN LISTS licence)
    if(NOT one IN_LIST CME_ACCEPT_LICENSES)
      message(FATAL_ERROR
        "cmake-everywhere: ${port} is ${one} and this build accepts only "
        "${CME_ACCEPT_LICENSES}. It was asked for by ${reason}.")
    endif()
  endforeach()
endfunction()

function(cme_require port version features reason)
  cme_port_field(exists ${port} PROVIDES)
  if(NOT exists)
    message(FATAL_ERROR
      "cmake-everywhere: ${reason} needs ${port}, and there is no port called "
      "that in ${CME_REGISTRY}.")
  endif()
  get_property(have GLOBAL PROPERTY CME_REQUIRED_VERSION_${port})
  get_property(visited GLOBAL PROPERTY CME_REQUIREMENTS_VISITED_${port})
  cme_remember_why(${port} "" "${reason}")
  set_property(GLOBAL APPEND PROPERTY CME_TOUCHED "${port}")
  cme_schedule_finish()
  if(version AND (NOT have OR have VERSION_LESS version))
    set_property(GLOBAL PROPERTY CME_REQUIRED_VERSION_${port} "${version}")
    # A raised floor has to be pushed down again: what this port needs may
    # need more of something else at the new version.
    set(visited FALSE)
  endif()
  # The same for features, and for the same reason: a feature can bring
  # dependencies of its own, and those have to be walked too.
  cme_port_field(declared ${port} FEATURES)
  # cme_features() is called before the registry is loaded, so its names can
  # only be checked here.
  foreach(feature IN LISTS CME_FEATURES_${port} CME_FEATURES_OFF_${port})
    if(NOT feature IN_LIST declared)
      message(FATAL_ERROR
        "cmake-everywhere: this build names a feature ${feature} for ${port}, "
        "and the port has none by that name. It has: ${declared}")
    endif()
  endforeach()
  get_property(known GLOBAL PROPERTY CME_REQUIRED_FEATURES_${port})
  foreach(feature IN LISTS features)
    if(NOT feature IN_LIST declared)
      message(FATAL_ERROR
        "cmake-everywhere: ${reason} asks ${port} for a feature called "
        "${feature}, and the port has none by that name. It has: ${declared}")
    endif()
    cme_feature_refused(refused ${port} ${feature})
    if(refused)
      message(FATAL_ERROR
        "cmake-everywhere: ${reason} needs ${port} with ${feature}, and this "
        "build refuses ${feature}. One of the two has to give: ask for it, or "
        "stop needing it.")
    endif()
    cme_remember_why(${port} ${feature} "${reason}")
  endforeach()
  # What is going to be on, which is what was asked for here, what the
  # project asked for by variable, and everything those imply, as far as the
  # chain goes. Checked against the refusals here rather than before the
  # expanding: a feature reached through two links is as much a feature this
  # build will have as one that was named, and refusing it while asking for
  # something that needs it is the same contradiction either way.
  list(APPEND features ${CME_FEATURES_${port}})
  cme_expand_implications(${port} "${features}" features)
  foreach(feature IN LISTS features)
    cme_feature_refused(refused ${port} ${feature})
    if(refused)
      cme_why(chain ${port} ${feature})
      message(FATAL_ERROR
        "cmake-everywhere: ${port} is asked for with ${feature} -- by "
        "${chain} -- and this build refuses ${feature}. One of the two has "
        "to give: ask for it, or stop needing it.")
    endif()
  endforeach()
  foreach(feature IN LISTS features)
    if(NOT feature IN_LIST known)
      list(APPEND known "${feature}")
      set(visited FALSE)
    endif()
  endforeach()
  set_property(GLOBAL PROPERTY CME_REQUIRED_FEATURES_${port} "${known}")
  if(visited)
    return()
  endif()
  set_property(GLOBAL PROPERTY CME_REQUIREMENTS_VISITED_${port} TRUE)

  cme_port_field(systems ${port} SYSTEMS)
  if(systems AND NOT CMAKE_SYSTEM_NAME IN_LIST systems)
    message(FATAL_ERROR
      "cmake-everywhere: ${reason} needs ${port}, and ${port} is only for "
      "${systems}. This is ${CMAKE_SYSTEM_NAME}.")
  endif()
  cme_check_licence(${port} "${reason}")
  cme_enabled_features(${port} enabled)
  cme_check_feature_conflicts(${port})
  cme_check_open_rules(${port})
  cme_register_exclusions(${port} "${enabled}")

  cme_port_field(depends ${port} DEPENDS)
  cme_absent_dependencies(${port} absent)
  list(APPEND depends ${absent})
  set(reasons "")
  foreach(spec IN LISTS depends)
    list(APPEND reasons "${port}")
  endforeach()
  foreach(feature IN LISTS enabled)
    cme_feature_field(extra ${port} ${feature} DEPENDS)
    foreach(spec IN LISTS extra)
      list(APPEND depends "${spec}")
      list(APPEND reasons "${port}[${feature}]")
    endforeach()
  endforeach()
  set(index 0)
  foreach(spec IN LISTS depends)
    list(GET reasons ${index} by)
    math(EXPR index "${index} + 1")
    cme_split_requirement("${spec}" name wanted wanted_features)
    cme_require("${name}" "${wanted}" "${wanted_features}" "${by}")
  endforeach()
endfunction()

# Everything asked of this port by anything, plus whatever the project asked
# for directly.
function(cme_enabled_features port out)
  get_property(enabled GLOBAL PROPERTY CME_REQUIRED_FEATURES_${port})
  list(APPEND enabled ${CME_FEATURES_${port}})
  # A feature the library says is on unless somebody says otherwise, and one
  # a project wants wherever it exists.
  cme_port_field(declared ${port} FEATURES)
  foreach(feature IN LISTS declared)
    cme_feature_field(default ${port} ${feature} DEFAULT)
    if(default OR feature IN_LIST CME_DEFAULT_FEATURES)
      list(APPEND enabled "${feature}")
    endif()
  endforeach()
  # What those imply, which until now was expanded only for the features a
  # find_package call named. A feature asked for by cme_features(), by
  # -DCME_FEATURES_<port>=, or one the port has on by default, implies
  # exactly the same things -- and did not bring them, so a library was on
  # without what it is built on being on, and a rule about the two of them
  # was checked against a set that was never assembled.
  cme_expand_implications(${port} "${enabled}" enabled)
  set(result "")
  foreach(feature IN LISTS enabled)
    # An empty item is not a feature. A list of two of them is still a list,
    # and if(list) is true for it -- which is how "built with , so what it
    # needed is not written down" came to be printed about a library with no
    # features at all.
    if(NOT feature)
      continue()
    endif()
    cme_feature_refused(refused ${port} ${feature})
    if(NOT refused)
      list(APPEND result "${feature}")
    endif()
  endforeach()
  if(result)
    list(REMOVE_DUPLICATES result)
    list(SORT result)
  endif()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# The features somebody asked for, as opposed to the ones the port has on
# unless told otherwise.
#
# The difference matters for a copy of a library that is already on the
# machine. A feature that was asked for is a requirement: a copy without it
# is the wrong copy. A feature that is merely on by default says what to
# build when there is nothing to take -- glfw builds both backends because
# both are useful, not because a program needs both -- and judging an
# installed copy by it rejects every copy a distribution ships.
function(cme_requested_features port out)
  get_property(enabled GLOBAL PROPERTY CME_REQUIRED_FEATURES_${port})
  list(APPEND enabled ${CME_FEATURES_${port}})
  cme_port_field(declared ${port} FEATURES)
  foreach(feature IN LISTS declared)
    if(feature IN_LIST CME_DEFAULT_FEATURES)
      list(APPEND enabled "${feature}")
    endif()
  endforeach()
  cme_expand_implications(${port} "${enabled}" enabled)
  set(result "")
  foreach(feature IN LISTS enabled)
    if(NOT feature)
      continue()
    endif()
    cme_feature_refused(refused ${port} ${feature})
    if(NOT refused)
      list(APPEND result "${feature}")
    endif()
  endforeach()
  if(result)
    list(REMOVE_DUPLICATES result)
    list(SORT result)
  endif()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# Whether a set of features satisfies what the port says a build of it must
# have. Only the rules that state a minimum: a copy with too few backends is
# not a copy this build can use, and a copy with more of something than a
# rule allows is somebody else's build being generous.
function(cme_rules_allow ok why port present)
  set(${ok} TRUE PARENT_SCOPE)
  set(${why} "" PARENT_SCOPE)
  get_property(rules GLOBAL PROPERTY CME_RULES_${port})
  set(index 0)
  foreach(kind IN LISTS rules)
    get_property(items GLOBAL PROPERTY CME_RULE_${port}_${index})
    math(EXPR index "${index} + 1")
    if(NOT kind STREQUAL "AT_LEAST_ONE_OF" AND NOT kind STREQUAL "EXACTLY_ONE_OF")
      continue()
    endif()
    set(count 0)
    foreach(item IN LISTS items)
      if(item IN_LIST present)
        math(EXPR count "${count} + 1")
      endif()
    endforeach()
    if(count EQUAL 0)
      list(JOIN items ", " listed)
      set(${ok} FALSE PARENT_SCOPE)
      set(${why} "it has none of ${listed}" PARENT_SCOPE)
      return()
    endif()
  endforeach()
endfunction()

# The version this port is going to be built at: what it pins, unless
# something needs more, unless the project said otherwise.
function(cme_effective_version port out)
  cme_port_field(result ${port} VERSION)
  if(CME_VERSION_${port})
    set(result "${CME_VERSION_${port}}")
  else()
    get_property(required GLOBAL PROPERTY CME_REQUIRED_VERSION_${port})
    if(required AND result VERSION_LESS required)
      set(result "${required}")
    endif()
  endif()
  set(${out} "${result}" PARENT_SCOPE)
endfunction()

# A system copy is a copy somebody else built, and what they built it with is
# not written anywhere a build system can read. What can be read is whether
# the result has the thing in it: a header that only exists when a feature was
# on, a symbol that is only compiled when it was. A feature says what to look
# for, and a system copy that does not have it is not rejected loudly -- it
# simply is not the copy this build can use, and the port is built instead.
# What to do about the features a system copy turned out not to have, when
# nobody asked for them. The port's rules are what a build of this library
# must satisfy, so they are what an installed one is judged by.
function(cme_system_rules_or_build out package port present absent)
  cme_rules_allow(ok why ${port} "${present}")
  if(NOT ok)
    list(JOIN absent ", " listed)
    message(STATUS
      "cmake-everywhere: the ${package} installed here is missing ${listed} "
      "and ${why}, so it is built here instead")
    set(${out} FALSE PARENT_SCOPE)
    return()
  endif()
  if(absent)
    list(JOIN absent ", " listed)
    list(JOIN present ", " kept)
    if(NOT kept)
      set(kept "nothing")
    endif()
    message(STATUS
      "cmake-everywhere: the ${package} installed here has no ${listed}, "
      "which nothing asked for; it is used with ${kept}")
  endif()
  set(${out} TRUE PARENT_SCOPE)
endfunction()

function(cme_system_has_features out package port features)
  set(${out} TRUE PARENT_SCOPE)
  # If the copy says what it was built with, that is the answer. Looking for
  # a symbol is what you do when nobody will tell you: it can only find what
  # a feature happens to add to the interface, and a feature that changes
  # behaviour without adding a symbol is invisible to it.
  cme_requested_features(${port} asked)
  get_property(said GLOBAL PROPERTY CME_INSTALLED_SAID_${port})
  if(said)
    get_property(has GLOBAL PROPERTY CME_INSTALLED_FEATURES_${port})
    set(present "")
    set(absent "")
    foreach(feature IN LISTS features)
      if(feature IN_LIST has)
        list(APPEND present "${feature}")
      elseif(feature IN_LIST asked)
        list(JOIN has ", " listed)
        if(NOT listed)
          set(listed "nothing")
        endif()
        message(STATUS
          "cmake-everywhere: the ${package} installed here was built with "
          "${listed}, and this build asked for ${feature}, so it is built "
          "here instead")
        set(${out} FALSE PARENT_SCOPE)
        return()
      else()
        list(APPEND absent "${feature}")
      endif()
    endforeach()
    cme_system_rules_or_build("${out}" "${package}" ${port} "${present}"
                              "${absent}")
    # The helper answered into this scope; the caller is one further out.
    set(${out} "${${out}}" PARENT_SCOPE)
    return()
  endif()
  set(includes "${${package}_INCLUDE_DIRS}")
  if(NOT includes)
    set(includes "${${package}_INCLUDE_DIR}")
  endif()
  set(libraries "${${package}_LIBRARIES}")
  if(NOT libraries)
    set(libraries "${${package}_LIBRARY}")
  endif()
  if(NOT libraries)
    # A config file a distribution ships defines a target and sets no
    # variables, so the target is the only way to link what was found --
    # and a check that links nothing answers no about every symbol.
    #
    # Both names it can be under: what the port promises its consumers, and
    # what upstream calls it, which is the name a config file installed by
    # that upstream defines.
    cme_port_field(targets ${port} TARGETS)
    cme_port_field(names ${port} LINK_NAMES)
    foreach(pair IN LISTS names)
      if(pair MATCHES "^([^=]+)=")
        list(APPEND targets "${CMAKE_MATCH_1}")
      endif()
    endforeach()
    foreach(target IN LISTS targets)
      if(TARGET ${target})
        list(APPEND libraries ${target})
      endif()
    endforeach()
  endif()
  include(CheckIncludeFile)
  include(CheckSymbolExists)
  include(CheckFunctionExists)
  set(CMAKE_REQUIRED_INCLUDES "${includes}")
  set(CMAKE_REQUIRED_LIBRARIES "${libraries}")
  set(CMAKE_REQUIRED_QUIET TRUE)
  set(present "")
  set(absent "")
  foreach(feature IN LISTS features)
    set(have TRUE)
    cme_feature_field(headers ${port} ${feature} SYSTEM_HEADERS)
    foreach(header IN LISTS headers)
      string(MAKE_C_IDENTIFIER "cme_${package}_${header}" variable)
      check_include_file("${header}" ${variable})
      if(NOT ${variable})
        message(STATUS
          "cmake-everywhere: the system ${package} has no ${header}, so it "
          "was not built with ${feature}")
        set(have FALSE)
      endif()
    endforeach()
    # "symbol:header" looks for a symbol the way a program would use it,
    # through the header that declares it. A bare "symbol" looks for it in
    # the library alone -- which is the question when the declaration is
    # somewhere a check cannot reach: glfwGetX11Display is declared in
    # glfw3native.h behind a macro, and that header includes Xlib.h, so
    # asking for it through a header asks the machine for X11's headers
    # rather than about the library that was found.
    cme_feature_field(symbols ${port} ${feature} SYSTEM_SYMBOLS)
    foreach(pair IN LISTS symbols)
      if(pair MATCHES "^([^:]+):(.+)$")
        set(symbol "${CMAKE_MATCH_1}")
        set(header "${CMAKE_MATCH_2}")
      else()
        set(symbol "${pair}")
        set(header "")
      endif()
      string(MAKE_C_IDENTIFIER "cme_${package}_${symbol}" variable)
      if(header)
        check_symbol_exists("${symbol}" "${header}" ${variable})
      else()
        check_function_exists("${symbol}" ${variable})
      endif()
      if(NOT ${variable})
        message(STATUS
          "cmake-everywhere: the system ${package} has no ${symbol}, "
          "so it was not built with ${feature}")
        set(have FALSE)
      endif()
    endforeach()
    if(have)
      list(APPEND present "${feature}")
    elseif(feature IN_LIST asked)
      # Asked for, so this is the wrong copy and there is nothing to weigh.
      message(STATUS
        "cmake-everywhere: ${feature} was asked for, so the ${package} "
        "installed here is not used")
      set(${out} FALSE PARENT_SCOPE)
      return()
    else()
      list(APPEND absent "${feature}")
    endif()
  endforeach()
  cme_system_rules_or_build("${out}" "${package}" ${port} "${present}"
                            "${absent}")
  set(${out} "${${out}}" PARENT_SCOPE)
endfunction()

# Most distributions ship a .pc file and no CMake config at all, and CMake
# has no FindOgg, FindVorbis, FindFLAC or FindSndFile of its own. So a
# find_package for any of them fails on a machine that has the library
# installed, and the port would be built for nothing. A port that says
# SYSTEM_PKGCONFIG names the modules to ask pkg-config for instead, and the
# target each one answers to. Every entry has to be found, because a library
# that is there in parts is not there; several names in one entry, separated
# by |, are one library under different names and the first that answers is
# the answer.
function(cme_try_pkgconfig found port package version exact)
  set(${found} FALSE PARENT_SCOPE)
  cme_port_field(mapping ${port} SYSTEM_PKGCONFIG)
  if(NOT mapping)
    return()
  endif()
  find_package(PkgConfig QUIET)
  if(NOT PKG_CONFIG_FOUND)
    return()
  endif()

  set(index 0)
  set(aliases "")
  set(includes "")
  set(imported "")
  foreach(pair IN LISTS mapping)
    # "module:Namespace::target", split at the first colon because the
    # target name has two of its own.
    if(pair MATCHES "^([^:]+):(.+)$")
      set(module "${CMAKE_MATCH_1}")
      set(alias "${CMAKE_MATCH_2}")
    else()
      set(module "${pair}")
      set(alias "")
    endif()
    # Several modules in one entry, separated by |, are the same library
    # under different names: sd-bus is carried by basu, by libelogind and
    # by libsystemd, and a machine that has any one of them has it. They
    # are asked about in the order the port wrote them, and the first one
    # that answers is the answer -- which is how a port names the smallest
    # of them first and the largest last.
    string(REPLACE "|" ";" alternatives "${module}")
    set(prefix CME_PC_${port}_${index})
    set(${prefix}_FOUND FALSE)
    foreach(alternative IN LISTS alternatives)
      set(query "${alternative}")
      if(version AND index EQUAL 0)
        if(exact)
          set(query "${alternative} = ${version}")
        else()
          set(query "${alternative} >= ${version}")
        endif()
      endif()
      pkg_check_modules(${prefix} QUIET IMPORTED_TARGET GLOBAL "${query}")
      if(${prefix}_FOUND)
        break()
      endif()
    endforeach()
    if(NOT ${prefix}_FOUND)
      return()
    endif()
    if(alias AND NOT TARGET ${alias})
      add_library(${alias} ALIAS PkgConfig::${prefix})
    endif()
    if(alias)
      list(APPEND aliases "${alias}")
    endif()
    list(APPEND includes ${${prefix}_INCLUDE_DIRS})
    list(APPEND imported "PkgConfig::${prefix}")
    math(EXPR index "${index} + 1")
  endforeach()

  string(TOUPPER "${package}" upper)
  list(REMOVE_DUPLICATES includes)
  cme_export_variable(${package} ${package}_FOUND TRUE)
  cme_export_variable(${package} ${upper}_FOUND TRUE)
  cme_export_variable(${package} ${upper}_LIBRARIES "${aliases}")
  cme_export_variable(${package} ${upper}_LIBRARY "${aliases}")
  cme_export_variable(${package} ${upper}_INCLUDE_DIRS "${includes}")
  cme_export_variable(${package} ${upper}_INCLUDE_DIR "${includes}")
  cme_export_variable(${package} ${upper}_VERSION "${CME_PC_${port}_0_VERSION}")
  set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${package}
               "${CME_PC_${port}_0_VERSION}")
  cme_note_decision("${package}" "pkg-config" "${CME_PC_${port}_0_VERSION}")

  # What the port has to say about the machine's copy.
  #
  # cme_adapt_<port> is about a tree this build fetched and is not called
  # for a library that was already there -- there is nothing to adapt. But
  # an installed library can still be arranged differently from what a
  # consumer writes, and the port is the only place that knows: an entry
  # that names several modules means one of them answered, and they do not
  # all install their headers under the same name.
  if(COMMAND cme_adapt_${port}_system)
    cmake_language(CALL cme_adapt_${port}_system "${includes}" "${imported}")
  endif()
  set(${found} TRUE PARENT_SCOPE)
endfunction()

# What a project changes in a library it did not write.
#
# Sometimes a library is wrong about the machine and says so in code rather
# than in an option: mpg123 asks CMake whether the host has a floating point
# unit and compiles for the answer, in a cross build, from a query that
# looks at the wrong machine and answers no on aarch64. Nothing a port can
# pass fixes a line that runs unconditionally.
#
# So a port may carry patches, beside it, and they are applied to the tree
# after it is fetched. Three things make that safe to do in a cache several
# projects share:
#
# The patches are part of what the port is, so what they produce is kept
# under a different name in the store -- cme_identity_key reads every file
# beside the port, and a patch is one.
#
# The tree records what was applied to it. A tree patched by one set and
# then asked for by a build carrying another is not quietly re-patched: it
# stops, because the answer to "what is in this directory" would otherwise
# depend on which build ran first.
#
# And a patch that does not apply is an error rather than a warning. A
# library that moved on is a port that has to be looked at.
function(cme_apply_patches port source)
  cme_port_field(patches ${port} PATCHES)
  if(NOT patches)
    return()
  endif()
  get_property(port_dir GLOBAL PROPERTY CME_PORT_${port}_DIR)
  set(digests "")
  set(files "")
  foreach(name IN LISTS patches)
    set(file "${name}")
    if(NOT IS_ABSOLUTE "${file}")
      set(file "${port_dir}/${name}")
    endif()
    if(NOT EXISTS "${file}")
      message(FATAL_ERROR
        "cmake-everywhere: ${port} says it carries the patch ${name}, and "
        "there is no such file at ${file}")
    endif()
    file(SHA256 "${file}" digest)
    list(APPEND files "${file}")
    list(APPEND digests "${digest}")
    cme_lock_fact("${port}" "patch" "${digest}")
  endforeach()
  list(JOIN digests " " applied)

  set(marker "${source}/.cme-patched")
  if(EXISTS "${marker}")
    file(READ "${marker}" already)
    string(STRIP "${already}" already)
    if(already STREQUAL applied)
      return()
    endif()
    message(FATAL_ERROR
      "cmake-everywhere: ${source} was patched by another set of patches "
      "than the ones ${port} carries now. That directory is shared between "
      "builds, so it is not patched again: remove it and configure again.")
  endif()

  find_program(CME_PATCH NAMES patch)
  if(NOT CME_PATCH)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} carries patches and there is no patch "
      "program here to apply them with")
  endif()
  foreach(file IN LISTS files)
    execute_process(COMMAND "${CME_PATCH}" -p1 --forward -i "${file}"
                    WORKING_DIRECTORY "${source}"
                    RESULT_VARIABLE code
                    OUTPUT_VARIABLE output ERROR_VARIABLE output)
    if(NOT code EQUAL 0)
      message(FATAL_ERROR
        "cmake-everywhere: ${file} does not apply to ${source}\n${output}")
    endif()
    get_filename_component(shown "${file}" NAME)
    message(STATUS "cmake-everywhere: ${port} is patched by ${shown}")
  endforeach()
  file(WRITE "${marker}" "${applied}\n")
endfunction()

# What a library says about itself, out of its own tree.
#
# This is the port, as far as the library is concerned: its version, its
# licence, its features, what it needs. Read after fetching and before
# anything is decided, because a consumer is only expected to know two things
# about a library nobody has ported -- its name, and where it is.
function(cme_source_ports port source)
  if(NOT CME_SOURCE_PORTS OR NOT source)
    return()
  endif()
  foreach(name "cme-port.cmake" "cme-ports.cmake" ".cme/port.cmake"
               ".cme/ports.cmake")
    set(file "${source}/${name}")
    if(NOT EXISTS "${file}")
      continue()
    endif()
    get_property(read GLOBAL PROPERTY CME_READ_PORTS)
    if("${file}" IN_LIST read)
      continue()
    endif()
    set_property(GLOBAL APPEND PROPERTY CME_READ_PORTS "${file}")
    get_filename_component(directory "${file}" DIRECTORY)
    set_property(GLOBAL PROPERTY CME_PORT_ORIGIN "the ${port} library itself")
    set_property(GLOBAL PROPERTY CME_PORT_DIRECTORY "${directory}")
    set_property(GLOBAL PROPERTY CME_PORT_FILE "${file}")
    set_property(GLOBAL PROPERTY CME_READING_FOR "${port}")
    include("${file}")
    set_property(GLOBAL PROPERTY CME_READING_FOR "")
    set_property(GLOBAL PROPERTY CME_PORT_ORIGIN "")
    set_property(GLOBAL PROPERTY CME_PORT_DIRECTORY "")
    set_property(GLOBAL PROPERTY CME_PORT_FILE "")
    message(STATUS "cmake-everywhere: ${port} carries ${name}")
  endforeach()
endfunction()

# Everything a port says it needs, asked for. Asked again once a library has
# described itself, because that is when a library nobody had ported says
# what it needs.
function(cme_resolve_depends port)
  cme_enabled_features(${port} features)
  cme_port_field(depends ${port} DEPENDS)
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} DEPENDS)
    list(APPEND depends ${extra})
  endforeach()
  foreach(spec IN LISTS depends)
    cme_split_requirement("${spec}" dep wanted wanted_features)
    cme_port_field(names ${dep} PROVIDES)
    if(NOT names)
      message(FATAL_ERROR
        "cmake-everywhere: ${port} needs ${dep}, and nothing has declared a "
        "port called that.")
    endif()
    list(GET names 0 first)
    if(wanted_features)
      find_package(${first} ${wanted} QUIET REQUIRED
                   COMPONENTS ${wanted_features})
    else()
      find_package(${first} ${wanted} QUIET REQUIRED)
    endif()
  endforeach()
endfunction()

function(cme_store_hit out port package version features)
  set(${out} FALSE PARENT_SCOPE)
  if(CME_FETCH_ONLY OR CME_LOCK_ALL)
    return()
  endif()
  cme_store_entry(entry ${port} "${version}")
  if(NOT entry OR NOT EXISTS "${entry}/complete"
     OR NOT EXISTS "${entry}/use.cmake")
    return()
  endif()
  # Read before it is believed: the entry checks the directories it was kept
  # beside and stops before defining anything if one of them is gone.
  set(CME_STORE_INCOMPLETE FALSE)
  include("${entry}/use.cmake")
  if(CME_STORE_INCOMPLETE)
    message(STATUS
      "cmake-everywhere: ${port} ${version} is in the store and not usable "
      "here, so it is built")
    return()
  endif()
  message(STATUS "cmake-everywhere: ${port} ${version} is already built")
  cme_store_differences("${entry}")
  set_property(GLOBAL PROPERTY CME_BUILT_FEATURES_${port} "${features}")
  set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${package} "${version}")
  cme_note_decision("${port}" "store" "${version}")
  set(${out} TRUE PARENT_SCOPE)
endfunction()

# Builds one port and everything it needs. Called from the provider, so the
# nested find_package() calls the port's own CMakeLists makes come back
# through the provider and are answered from what is already here.
function(cme_build_port port package version exact)
  get_property(done GLOBAL PROPERTY CME_BUILT_${port})
  if(done)
    return()
  endif()
  # Marked before the dependencies rather than after: a port that ends up
  # needing itself would otherwise never stop.
  set_property(GLOBAL PROPERTY CME_BUILT_${port} TRUE)

  cme_check_closed_rules(${port})
  cme_enabled_features(${port} features)
  if(features)
    list(JOIN features ", " listed)
    message(STATUS "cmake-everywhere: ${port} with ${listed}")
  endif()

  cme_resolve_depends(${port})

  cme_port_field(source_subdir ${port} SOURCE_SUBDIR)
  cme_port_field(overlay ${port} OVERLAY)
  cme_port_field(options ${port} OPTIONS)
  cme_port_field(port_version ${port} VERSION)
  cme_port_field(port_tag ${port} GIT_TAG)

  # A version asked for is a version the port has to be able to produce.
  # Building 1.3.5 because that is what the port happens to pin, while
  # something asked for 1.4, is the kind of quiet wrong answer that turns up
  # much later as a missing symbol.
  cme_port_field(pinned ${port} VERSION)
  cme_effective_version(${port} port_version)
  get_property(listed GLOBAL PROPERTY CME_PORT_${port}_VERSIONS)
  if(listed AND NOT port_version IN_LIST listed)
    list(JOIN listed ", " available)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} ${port_version} is not one of the versions "
      "this port has an archive and a digest for. It has: ${available}")
  endif()
  get_property(installed_version GLOBAL PROPERTY
               CME_PORT_${port}_VERSION_INSTALLED)
  if(listed)
    # A listed version is fetched and checked, so there is no tag to work out.
  elseif(NOT port_version VERSION_EQUAL pinned)
    cme_port_field(template ${port} GIT_TAG_TEMPLATE)
    if(NOT template AND installed_version AND port_tag)
      # The version came from a copy installed on this machine and something
      # wants more than that copy is. That the copy will not do is why we are
      # here; it says nothing about the library, and a tag was given. So it
      # is fetched, and what it turns out to be is checked afterwards against
      # what the library says it is.
      message(STATUS
        "cmake-everywhere: the ${port} installed here is ${pinned} and "
        "${port_version} is wanted, so ${port_tag} is fetched instead")
    elseif(NOT template)
      message(FATAL_ERROR
        "cmake-everywhere: ${port} is pinned at ${pinned} and something needs "
        "${port_version}, but the port does not say how a version becomes a "
        "tag. Add GIT_TAG_TEMPLATE to registry/${port}/port.cmake.")
    endif()
    if(template)
      string(REPLACE "." "_" underscored "${port_version}")
      string(REPLACE "." "-" dashed "${port_version}")
      string(REPLACE "@VERSION@" "${port_version}" port_tag "${template}")
      string(REPLACE "@VERSION_UNDERSCORE@" "${underscored}" port_tag
             "${port_tag}")
      string(REPLACE "@VERSION_DASH@" "${dashed}" port_tag "${port_tag}")
      message(STATUS
        "cmake-everywhere: ${port} at ${port_version} rather than the pinned "
        "${pinned}")
    endif()
  endif()
  if(version AND port_version VERSION_LESS version)
    # An installed port was written by a copy of the library, and a copy is
    # one version built one way. That it cannot give what is asked for means
    # the copy cannot, and says nothing about the library.
    get_property(described GLOBAL PROPERTY CME_PORT_${port}_ORIGIN)
    set(aside "")
    if(described MATCHES "^the system")
      set(aside
          "\nThat description came from a copy of the library installed on "
          "this machine, which is one version built one way. Add "
          "GIT_TAG_TEMPLATE to say how a version of it becomes a tag, or "
          "declare the port in this project.")
    endif()
    message(FATAL_ERROR
      "cmake-everywhere: something asks for ${package} ${version} and ${port} "
      "resolved to ${port_version}.${aside}")
  endif()
  if(exact AND NOT port_version VERSION_EQUAL version)
    message(FATAL_ERROR
      "cmake-everywhere: ${package} was asked for as exactly ${version} and "
      "the ${port} port is ${port_version}.")
  endif()
  set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${package}
               "${port_version}")

  # EXCLUDE_FROM_ALL: "Any install rules defined in the subdirectory or below
  # will be ignored when installing the parent directory." A dependency this
  # registry built is part of the consumer's build, not part of what the
  # consumer installs -- and a project whose install(EXPORT) names a target
  # from another port would otherwise fail at generate time, because that
  # target is in no export set of its own.
  #
  # SYSTEM: their headers are not yours, so their warnings are not yours.
  set(arguments NAME ${port} EXCLUDE_FROM_ALL YES SYSTEM YES)
  if(listed)
    get_property(url GLOBAL PROPERTY CME_SOURCE_${port}_${port_version}_URL)
    get_property(hash GLOBAL PROPERTY CME_SOURCE_${port}_${port_version}_HASH)
    list(APPEND arguments URL "${url}" URL_HASH "${hash}")
  else()
    foreach(field GIT_REPOSITORY GITHUB_REPOSITORY GITLAB_REPOSITORY
                  URL URL_HASH GIT_SHALLOW)
      cme_port_field(value ${port} ${field})
      if(value)
        list(APPEND arguments ${field} "${value}")
      endif()
    endforeach()
    if(port_tag)
      list(APPEND arguments GIT_TAG "${port_tag}")
      # One commit rather than every commit, unless the port said
      # otherwise. Nothing here reads a library's history: what is wanted is
      # the tree at one revision, and Boost is a hundred and fifty
      # repositories of history that is downloaded, written to disk and
      # never opened.
      #
      # Only for a name -- a tag or a branch. A raw commit can be fetched
      # shallowly from a server that allows it and not from one that does
      # not, and a clone that fails is worse than a clone that is large.
      cme_port_field(shallow ${port} GIT_SHALLOW)
      if(NOT shallow AND NOT port_tag MATCHES "^[0-9a-f][0-9a-f][0-9a-f][0-9a-f]+$")
        list(APPEND arguments GIT_SHALLOW ON)
      endif()
    endif()
  endif()
  if(port_version)
    list(APPEND arguments VERSION "${port_version}")
  endif()
  cme_port_field(gn_targets ${port} GN_TARGETS)
  if(overlay OR gn_targets)
    # Nothing is configured from the upstream tree. Either it has no CMake at
    # all and the overlay in this registry is the project that builds it, or
    # it is a GN project and GN is asked to describe it.
    list(APPEND arguments DOWNLOAD_ONLY YES)
  else()
    if(source_subdir)
      list(APPEND arguments SOURCE_SUBDIR "${source_subdir}")
    endif()
    if(options)
      list(APPEND arguments OPTIONS ${options})
    endif()
  endif()
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} OPTIONS)
    if(extra AND NOT overlay AND NOT gn_targets)
      list(APPEND arguments OPTIONS ${extra})
    endif()
    list(APPEND options ${extra})
  endforeach()
  if(CME_OPTIONS_${port})
    list(APPEND arguments OPTIONS ${CME_OPTIONS_${port}})
    list(APPEND options ${CME_OPTIONS_${port}})
  endif()

  # EXCLUDE_FROM_ALL stops a dependency's install rules from running, but
  # CMake still checks an install(EXPORT) while generating, and one that names
  # a target from another port fails there over an install that was never
  # going to happen. Several projects take the same four switches -- zlib
  # started it and libpng and freetype followed -- and a project that has
  # never heard of them ignores them.
  if(NOT CME_COMPILER_CACHE STREQUAL "OFF")
    set(CMAKE_C_COMPILER_LAUNCHER "${CME_COMPILER_CACHE}")
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CME_COMPILER_CACHE}")
  endif()

  # A port is an archive, and it is compiled so that it can go into anything.
  #
  # Not because static is better, but because that is the only shape this can
  # keep and hand back: a store entry is archives, and a shared library is a
  # file that has to be found again at run time by something that installs
  # it, which this does not do. Some libraries decide otherwise for
  # themselves -- libzip turns BUILD_SHARED_LIBS on in its own CMakeLists --
  # so it is said here rather than left to each of them.
  #
  # Position independent whatever the consumer is doing, since a consumer
  # that is building a shared library out of these needs it and one that is
  # not loses nothing by it. Without it the answer is a relocation error from
  # the linker naming a symbol in zlib, which says nothing about any of this.
  set(BUILD_SHARED_LIBS OFF)
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)

  # A dependency's tests are not the consumer's, and they are not merely
  # unwanted: a library's test directory is written for the build its authors
  # run it in, so it reaches for modules that live in that build. Boost.Locale
  # includes BoostTestJamfile, which is in the superproject nobody added here,
  # and the error is about a missing CMake module rather than about anything
  # to do with the library being built.
  #
  # A normal variable, so it stands for the trees added below and leaves the
  # consumer's own testing exactly as the consumer set it.
  set(BUILD_TESTING OFF)

  set(SKIP_INSTALL_ALL ON)
  set(SKIP_INSTALL_HEADERS ON)
  set(SKIP_INSTALL_LIBRARIES ON)
  set(SKIP_INSTALL_FILES ON)

  # Read by cmake_minimum_required in the tree about to be added. A normal
  # variable, so it reaches that tree and stops at the end of this call.
  cme_port_field(policy ${port} POLICY_MINIMUM)
  if(NOT policy)
    set(policy "${CME_POLICY_VERSION_MINIMUM}")
  endif()
  if(policy)
    set(CMAKE_POLICY_VERSION_MINIMUM "${policy}")
  endif()

  # Built before, with everything the same: no fetch, no configure, no
  # compiling. The entry says what the library is and where its archives are.
  #
  # Asked twice, because a library that describes itself is described after
  # it has been fetched, and what it says is part of what it is. The first
  # ask is what keeps a build with a warm store from downloading anything at
  # all; the second is for a port that was only a name and a URL until the
  # tree arrived.
  cme_store_hit(hit ${port} "${package}" "${port_version}" "${features}")
  if(hit)
    return()
  endif()

  if(CME_LOCK AND NOT DEFINED GIT_EXECUTABLE)
    find_package(Git QUIET BYPASS_PROVIDER)
  endif()
  cme_port_field(external ${port} EXTERNAL)
  cme_port_field(imported ${port} IMPORT)
  cme_port_field(configure ${port} CONFIGURE)
  # Fetched and no more. What a library says about itself is in the tree, and
  # nothing can be decided about the library before it has been read -- which
  # means the tree cannot be configured by the same call that brings it.
  list(APPEND arguments DOWNLOAD_ONLY YES)

  # Asked here rather than earlier: a port with nowhere to fetch from is
  # a perfectly good port for a library the system has, or one that is
  # already in the store. It is a problem at the moment of fetching.
  #
  # A port can describe a library without saying where it is -- a library
  # describing itself has no business claiming a URL. That is fine until
  # something has to fetch it, which is here.
  cme_port_field(sources_inside ${port} SOURCE_FROM)
  if(NOT listed AND NOT sources_inside)
    set(coordinates FALSE)
    foreach(field GIT_REPOSITORY GITHUB_REPOSITORY GITLAB_REPOSITORY URL)
      cme_port_field(value ${port} ${field})
      if(value)
        set(coordinates TRUE)
      endif()
    endforeach()
    if(NOT coordinates)
      get_property(origin GLOBAL PROPERTY CME_PORT_${port}_ORIGIN)
      message(FATAL_ERROR
        "cmake-everywhere: ${package} has to be built, and nothing says "
        "where ${port} comes from. The port was declared by ${origin}, which "
        "described the library without claiming to know where it is -- that "
        "is the right thing for a library to do about itself. Whoever wants "
        "it from source says where:\n"
        "  cme_port_source(${port} GIT_REPOSITORY <url> GIT_TAG <tag>)")
    endif()
  endif()
  cme_source_from(inside ${port})
  if(inside)
    set(${port}_SOURCE_DIR "${inside}")
    set(${port}_BINARY_DIR "${CMAKE_BINARY_DIR}/_cme/${port}")
    cme_lock_fact("${port}" "source" "inside ${port_version}")
  else()
    CPMAddPackage(${arguments})
  endif()
  set_property(GLOBAL PROPERTY CME_TREE_${port} "${${port}_SOURCE_DIR}")
  cme_apply_patches(${port} "${${port}_SOURCE_DIR}")

  # What was actually fetched, rather than what was asked for. A tag moves,
  # a branch certainly moves, and an archive at a URL can be replaced; the
  # commit and the digest are what a build can be held to.
  # Where it came from, beside what came. A lock that says which commit and
  # not which repository is half an answer, and the other half is what
  # anything reading the lock -- a mirror, a distribution's packaging, a
  # sandboxed build that has to fetch beforehand -- needs first.
  foreach(field GIT_REPOSITORY GITHUB_REPOSITORY GITLAB_REPOSITORY URL)
    cme_port_field(where ${port} ${field})
    if(where)
      if(field STREQUAL "GITHUB_REPOSITORY")
        set(where "https://github.com/${where}.git")
      elseif(field STREQUAL "GITLAB_REPOSITORY")
        set(where "https://gitlab.com/${where}.git")
      endif()
      cme_lock_fact("${port}" "url" "${where}")
    endif()
  endforeach()
  if(listed)
    get_property(url GLOBAL PROPERTY CME_SOURCE_${port}_${port_version}_URL)
    get_property(hash GLOBAL PROPERTY CME_SOURCE_${port}_${port_version}_HASH)
    cme_lock_fact("${port}" "url" "${url}")
    cme_lock_fact("${port}" "archive" "${hash}")
  else()
    cme_port_field(url ${port} URL)
    cme_port_field(url_hash ${port} URL_HASH)
    if(url_hash)
      cme_lock_fact("${port}" "archive" "${url_hash}")
    elseif(NOT url AND GIT_EXECUTABLE)
      execute_process(
        COMMAND "${GIT_EXECUTABLE}" -C "${${port}_SOURCE_DIR}" rev-parse HEAD
        OUTPUT_VARIABLE fetched OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET RESULT_VARIABLE told)
      if(told EQUAL 0)
        cme_lock_fact("${port}" "commit" "${fetched}")
      endif()
    endif()
  endif()
  set_property(GLOBAL APPEND PROPERTY CME_LOCK_REACHED "${port}")

  # And now the library speaks for itself.
  #
  # A consumer is expected to know two things about a library nobody has
  # ported: its name, and where it is. Everything else -- what version this
  # is, what it is licensed under, what it can optionally be, what it needs
  # -- the library knows, and says here. What the consumer already said
  # stands: it chose the library, so it decides which one.
  get_property(before GLOBAL PROPERTY CME_PORT_${port}_RECIPE)
  cme_source_ports(${port} "${${port}_SOURCE_DIR}")
  get_property(after GLOBAL PROPERTY CME_PORT_${port}_RECIPE)
  if(NOT "${before}" STREQUAL "${after}")
    # Decided again, against a description that did not exist a moment ago.
    cme_check_closed_rules(${port})
    cme_check_licence(${port} "${port}")
    # A version the consumer did not state, because a consumer that names a
    # library and where it is has not said which version this is. The library
    # has.
    cme_port_field(said_version ${port} VERSION)
    if(said_version AND NOT said_version VERSION_EQUAL "${port_version}")
      # The tree says which version it is, and it is the tree that is being
      # built. A number settled before it arrived -- a project's guess, or
      # the version of a copy installed on this machine -- was about
      # something else.
      set(port_version "${said_version}")
      set_property(GLOBAL PROPERTY CME_PORT_${port}_VERSION_INSTALLED FALSE)
      set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${package}
                   "${port_version}")
      # Asked again now that it is the library answering rather than a guess
      # about it. Refusing here costs a fetch and is the truth; refusing
      # before the fetch would have been a guess made from somebody else's
      # build.
      if(version AND port_version VERSION_LESS version)
        message(FATAL_ERROR
          "cmake-everywhere: something asks for ${package} ${version}, and "
          "what was fetched says it is ${port_version}. Nothing here is "
          "${version}: the copy on this machine was not, and neither is the "
          "tree that was fetched.")
      endif()
    endif()
    cme_resolve_depends(${port})
    cme_enabled_features(${port} features)
    cme_port_field(options ${port} OPTIONS)
    foreach(feature IN LISTS features)
      cme_feature_field(extra ${port} ${feature} OPTIONS)
      list(APPEND options ${extra})
    endforeach()
    if(CME_OPTIONS_${port})
      list(APPEND options ${CME_OPTIONS_${port}})
    endif()
    if(features)
      list(JOIN features ", " listed_features)
      message(STATUS "cmake-everywhere: ${port} with ${listed_features}")
    endif()
    cme_store_hit(hit ${port} "${package}" "${port_version}" "${features}")
    if(hit)
      return()
    endif()
  endif()

  # Written down after the library has spoken and not before: a project that
  # says a name and a URL has not said which version this is, and the answer
  # arrives with the tree.
  cme_lock_fact("${port}" "version" "${port_version}")

  # The name the result is kept under, worked out here rather than before the
  # fetch: what a library said about itself is part of what it is, and what a
  # thing is decides where it is kept.
  cme_store_entry(entry ${port} "${port_version}")

  if(CME_FETCH_ONLY)
    message(STATUS "cmake-everywhere: fetched ${port} ${port_version}")
    cme_note_decision("${port}" "fetched" "${port_version}")
    return()
  endif()

  if(imported)
    if(imported STREQUAL "cmake")
      cme_cmake_build(${port} "${${port}_SOURCE_DIR}")
    elseif(imported STREQUAL "meson")
      cme_meson_build(${port} "${${port}_SOURCE_DIR}")
    elseif(imported STREQUAL "make")
      cme_configure_make_build(${port} "${${port}_SOURCE_DIR}")
    else()
      message(FATAL_ERROR
        "cmake-everywhere: ${port} says IMPORT ${imported}, and what can be "
        "imported that way is cmake, meson or make")
    endif()
  elseif(external)
    cme_store_entry(entry ${port} "${port_version}")
    if(NOT entry)
      set(entry "${CMAKE_BINARY_DIR}/_cme/${port}-installed")
    endif()
    cme_build_external(${port} "${package}" "${port_version}" "${entry}")
    set(CME_INSTALLED_${port} "${entry}" CACHE INTERNAL "" FORCE)
  elseif(configure)
    # A project with a configure script of its own cannot be asked what it
    # would build, so it is built its own way into a prefix and what comes
    # out is what the port says comes out.
    cme_store_entry(entry ${port} "${port_version}")
    if(NOT entry)
      set(entry "${CMAKE_BINARY_DIR}/_cme/${port}-installed")
    endif()
    cme_configure_build(${port} "${${port}_SOURCE_DIR}" "${entry}")
    set(CME_INSTALLED_${port} "${entry}" CACHE INTERNAL "" FORCE)
  elseif(gn_targets)
    cme_gn_build(${port} "${${port}_SOURCE_DIR}")
  elseif(overlay)
    set(CME_UPSTREAM_SOURCE_DIR "${${port}_SOURCE_DIR}")
    set(CME_UPSTREAM_VERSION "${port_version}")
    foreach(option IN LISTS options)
      # OPTIONS are "NAME VALUE" pairs, the same spelling CPM uses.
      string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\1" name "${option}")
      string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\2" value "${option}")
      set(${name} "${value}")
    endforeach()
    get_property(port_dir GLOBAL PROPERTY CME_PORT_${port}_DIR)
    if(NOT port_dir)
      message(FATAL_ERROR
        "cmake-everywhere: the ${port} port asks for the OVERLAY ${overlay} "
        "and was declared without a directory, so there is nowhere to look "
        "for it. A port with an OVERLAY has to be a port.cmake in a "
        "directory.")
    endif()
    add_subdirectory("${port_dir}/${overlay}"
                     "${CMAKE_BINARY_DIR}/_cme/${port}")
  else()
    # The tree, added the way CPM would have added it if it had been allowed
    # to do both at once.
    #
    # EXCLUDE_FROM_ALL: "Any install rules defined in the subdirectory or
    # below will be ignored when installing the parent directory." A
    # dependency this built is part of the consumer's build, not part of what
    # the consumer installs. SYSTEM: their headers are not yours, so their
    # warnings are not yours.
    foreach(option IN LISTS options)
      string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\1" name "${option}")
      string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\2" value "${option}")
      set(${name} "${value}")
    endforeach()
    set(tree "${${port}_SOURCE_DIR}")
    if(source_subdir)
      set(tree "${tree}/${source_subdir}")
    endif()
    set(built "${${port}_BINARY_DIR}")
    if(NOT built)
      set(built "${CMAKE_BINARY_DIR}/_cme/${port}")
    endif()
    cme_note_name_clash(${port} "${package}")
    if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.25)
      add_subdirectory("${tree}" "${built}" EXCLUDE_FROM_ALL SYSTEM)
    else()
      add_subdirectory("${tree}" "${built}" EXCLUDE_FROM_ALL)
    endif()
  endif()

  # The port says what the result has to look like. Everything upstream calls
  # its targets by its own names, and this is where they get the names their
  # consumers use.
  if(COMMAND cme_adapt_${port})
    cmake_language(CALL cme_adapt_${port} "${${port}_SOURCE_DIR}"
                   "${${port}_BINARY_DIR}")
  endif()
  # Said by the core rather than by each adapter: the port names the version
  # once, and this is the same number.
  string(TOUPPER "${package}" upper)
  cme_export_variable(${package} ${package}_VERSION "${port_version}")
  cme_export_variable(${package} ${upper}_VERSION "${port_version}")
  set_property(GLOBAL PROPERTY CME_BUILT_FEATURES_${port} "${features}")
  if(entry AND NOT external)
    cme_store_write(${port} "${package}" "${entry}")
  endif()
  list(JOIN features "," listed)
  cme_note_decision("${port}" "built" "${port_version} [${listed}]")
endfunction()

# ---------------------------------------------------------------- provider

# What was decided and why, for a project that wants to read it rather than
# infer it from how long the build took. Call it at the end of the top-level
# CMakeLists; the same text is written to the lock file.
function(cme_report)
  get_property(touched GLOBAL PROPERTY CME_TOUCHED)
  if(NOT touched)
    return()
  endif()
  list(REMOVE_DUPLICATES touched)
  list(SORT touched)
  set(text "")
  foreach(port IN LISTS touched)
    cme_port_field(names ${port} PROVIDES)
    list(GET names 0 package)
    get_property(how GLOBAL PROPERTY CME_ANSWERED_${package})
    get_property(version GLOBAL PROPERTY CME_PROVIDED_VERSION_${package})
    if(NOT how)
      set(how "not reached")
    endif()
    cme_why(reason ${port} "")
    get_property(origin GLOBAL PROPERTY CME_PORT_${port}_ORIGIN)
    if(NOT origin)
      set(origin "nowhere")
    endif()
    string(APPEND text
      "${port} ${version} from ${how}, asked for by ${reason}, "
      "ported by ${origin}\n")
    cme_port_field(declared ${port} FEATURES)
    cme_enabled_features(${port} enabled)
    foreach(feature IN LISTS declared)
      cme_feature_field(summary ${port} ${feature} SUMMARY)
      if(feature IN_LIST enabled)
        cme_why(why ${port} ${feature})
        string(APPEND text
          "    on  ${feature} -- ${summary} (${why})\n")
      else()
        cme_feature_refused(refused ${port} ${feature})
        if(refused)
          string(APPEND text "    no  ${feature} -- refused\n")
        else()
          # A feature nobody asked for, whose library is in the build for a
          # reason of its own: something else needs it, and needing is what
          # a port's DEPENDS says while asking is what a feature says. They
          # are two true statements about one graph, and printing only "off"
          # here reads as "not here" while the library is right there.
          set(anyway "")
          cme_feature_field(depends ${port} ${feature} DEPENDS)
          foreach(spec IN LISTS depends)
            cme_split_requirement("${spec}" dep wanted wanted_features)
            if(NOT anyway AND dep IN_LIST touched)
              cme_why(who ${dep} "")
              set(anyway "${dep} is in this build, asked for by ${who}")
            endif()
          endforeach()
          if(anyway)
            string(APPEND text
              "    --  ${feature} -- not asked for, and ${anyway}\n")
          else()
            string(APPEND text "    off ${feature} -- ${summary}\n")
          endif()
        endif()
      endif()
    endforeach()
  endforeach()
  message(STATUS "cmake-everywhere:\n${text}")
  file(WRITE "${CME_LOCK_FILE}.report" "${text}")
endfunction()

# Deciding how a package is going to be answered, once.
#
# A function rather than part of the macro below, and that is the whole
# reason it exists. The macro has no scope of its own: its variables are the
# caller's. And the system search here reads somebody else's config file,
# which is free to call find_package itself -- which comes straight back into
# the provider, which is the same macro, which overwrites the variables of
# the call still in progress. That is what it did: the port being resolved
# became the empty string half way through, for whichever package expat's
# config happened to look for.
#
# Inside a function the nested call has its own scope and cannot reach this
# one.
# Libraries that are one release cut into many pieces.
#
# Boost is 158 repositories out of one tarball, ICU is three libraries that
# must agree, Qt is dozens. Taking one of them from the system and the next
# from a source tree gives a build two versions of one library, with headers
# from one and symbols from the other, and the failure turns up as a
# constructor that reads the wrong offset. There is no diagnosing that from
# the message.
#
# So a port can name a family, and the first member to be answered decides
# for the rest: from the system, or built, and at which version. A member
# that cannot be had the same way as the first is an error naming both,
# rather than a build that mixes them.
function(cme_family_answer out port)
  cme_port_field(family ${port} FAMILY)
  set(${out} "" PARENT_SCOPE)
  if(NOT family)
    return()
  endif()
  get_property(answer GLOBAL PROPERTY CME_FAMILY_${family}_ANSWER)
  set(${out} "${answer}" PARENT_SCOPE)
endfunction()

function(cme_family_settled port package how)
  cme_port_field(family ${port} FAMILY)
  if(NOT family)
    return()
  endif()
  get_property(answer GLOBAL PROPERTY CME_FAMILY_${family}_ANSWER)
  if(answer)
    return()
  endif()
  get_property(chosen GLOBAL PROPERTY CME_PROVIDED_VERSION_${package})
  set_property(GLOBAL PROPERTY CME_FAMILY_${family}_ANSWER "${how}")
  set_property(GLOBAL PROPERTY CME_FAMILY_${family}_VERSION "${chosen}")
  set_property(GLOBAL PROPERTY CME_FAMILY_${family}_FIRST "${port}")
  if(how STREQUAL "system")
    set(prose "the system")
  else()
    set(prose "here, from source")
  endif()
  message(STATUS
    "cmake-everywhere: ${family} comes from ${prose} at ${chosen}, decided "
    "by ${port}; every ${family} port in this build is answered the same way")
endfunction()

# The tree another port's sources are inside.
#
# A release that is cut into many repositories is also published as one
# archive, and taking a hundred and fifty-seven repositories to build twenty
# of them is a great deal of waiting for the same bytes. A port can say that
# its sources are a directory inside another port's, and then the archive is
# fetched once and every member is a subdirectory of it.
#
# The port named here is fetched and never built: it is a download, not a
# library.
function(cme_source_from out port)
  cme_port_field(from ${port} SOURCE_FROM)
  set(${out} "" PARENT_SCOPE)
  if(NOT from)
    return()
  endif()
  get_property(root GLOBAL PROPERTY CME_FETCHED_${from})
  if(root)
    set(${out} "${root}" PARENT_SCOPE)
    return()
  endif()
  cme_port_field(names ${from} PROVIDES)
  if(NOT names)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} says its sources are inside ${from}, and "
      "there is no port called that.")
  endif()
  set(arguments NAME ${from} DOWNLOAD_ONLY YES)
  foreach(field GIT_REPOSITORY GITHUB_REPOSITORY GITLAB_REPOSITORY URL
                URL_HASH GIT_TAG GIT_SHALLOW VERSION)
    cme_port_field(value ${from} ${field})
    if(value)
      list(APPEND arguments ${field} "${value}")
    endif()
  endforeach()
  CPMAddPackage(${arguments})
  set_property(GLOBAL PROPERTY CME_FETCHED_${from} "${${from}_SOURCE_DIR}")
  cme_port_field(hash ${from} URL_HASH)
  cme_lock_fact("${from}" "archive" "${hash}")
  message(STATUS
    "cmake-everywhere: ${from} is fetched once and every port inside it is a "
    "directory of ${${from}_SOURCE_DIR}")
  set(${out} "${${from}_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

# A port that is a name for other ports and builds nothing itself.
function(cme_build_virtual port package)
  cme_port_field(names ${port} TARGETS)
  cme_port_field(port_version ${port} VERSION)
  cme_resolve_depends(${port})
  # A name for other ports is whatever those turned out to be. On a machine
  # that has the library installed they are the installed one, and saying the
  # version this port pins would be reporting a number nothing in the build
  # is at.
  cme_port_field(family ${port} FAMILY)
  if(family)
    get_property(settled GLOBAL PROPERTY CME_FAMILY_${family}_VERSION)
    if(settled)
      set(port_version "${settled}")
    endif()
  endif()
  cme_enabled_features(${port} features)
  set(parts "")
  foreach(feature IN LISTS features)
    cme_feature_field(depends ${port} ${feature} DEPENDS)
    foreach(spec IN LISTS depends)
      cme_split_requirement("${spec}" dep wanted wanted_features)
      cme_port_field(theirs ${dep} TARGETS)
      foreach(one IN LISTS theirs)
        if(TARGET ${one})
          list(APPEND parts "${one}")
        endif()
      endforeach()
    endforeach()
  endforeach()
  foreach(name IN LISTS names)
    if(NOT TARGET ${name})
      add_library(${name} INTERFACE IMPORTED GLOBAL)
      if(parts)
        list(REMOVE_DUPLICATES parts)
        set_property(TARGET ${name} PROPERTY INTERFACE_LINK_LIBRARIES ${parts})
      endif()
    endif()
  endforeach()
  set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${package} "${port_version}")
  # What it was answered with, which is what a later caller asking for more
  # is compared against. Without this every caller after the first is told
  # the components it asked for are not here, and told to run cmake again --
  # which would not help, because they were here the first time.
  set_property(GLOBAL PROPERTY CME_BUILT_FEATURES_${port} "${features}")

  # What the pieces are and where they came from, for the adapter: a port
  # that builds nothing has no source directory of its own, and everything a
  # consumer reads about it is made out of its parts.
  set(trees "")
  foreach(feature IN LISTS features)
    cme_feature_field(depends ${port} ${feature} DEPENDS)
    foreach(spec IN LISTS depends)
      cme_split_requirement("${spec}" dep wanted wanted_features)
      get_property(tree GLOBAL PROPERTY CME_TREE_${dep})
      if(tree)
        list(APPEND trees "${tree}")
      endif()
    endforeach()
  endforeach()
  if(trees)
    list(REMOVE_DUPLICATES trees)
  endif()
  set_property(GLOBAL PROPERTY CME_VIRTUAL_PARTS_${port} "${parts}")
  set_property(GLOBAL PROPERTY CME_VIRTUAL_TREES_${port} "${trees}")
  if(COMMAND cme_adapt_${port})
    cmake_language(CALL cme_adapt_${port} "" "")
  endif()

  # Nothing was fetched and nothing can be pinned, which is not a hole in the
  # lock: there is nothing here to move.
  set_property(GLOBAL APPEND PROPERTY CME_LOCK_REACHED "${port}")
  list(JOIN features ", " listed)
  if(NOT listed)
    set(listed "nothing")
  endif()
  cme_note_decision("${port}" "as a name for" "${listed}")
endfunction()

function(cme_resolve package port version exact features out_answer)
  # A floor learned on an earlier run, so this one does not repeat it.
  if(CME_REQUIRE_${package} AND
     (NOT version OR version VERSION_LESS CME_REQUIRE_${package}))
    set(version "${CME_REQUIRE_${package}}")
  endif()

  cme_require("${port}" "${version}" "${features}" "the project")

  # What the rest of this library was answered with, if it has a rest.
  cme_family_answer(family_answer "${port}")
  cme_port_field(family ${port} FAMILY)
  if(family_answer STREQUAL "built")
    get_property(chosen GLOBAL PROPERTY CME_FAMILY_${family}_VERSION)
    if(chosen AND NOT CME_VERSION_${port})
      set(CME_VERSION_${port} "${chosen}" CACHE STRING
          "The version of ${port}, which is the version the rest of ${family} \
is being built at" FORCE)
    endif()
  endif()

  # Read here rather than inside the branch below, because a build that
  # never looks at the system still has to know what kind of port this is.
  cme_port_field(virtual ${port} VIRTUAL)

  cme_system_allowed(try_system "${package}")
  if(family_answer STREQUAL "built")
    # The rest of this library is being built, so this piece is too. A
    # system copy of one piece beside a built copy of another is two
    # versions of one library in one build.
    set(try_system FALSE)
  endif()
  if(try_system)
    # BYPASS_PROVIDER is what keeps this call from being routed straight back
    # here. It is the one place the keyword is allowed.
    # The name a distribution's CMake config uses, when it is not the name
    # projects write in find_package. Nothing in the registry needs it yet;
    # a port declared in a project may.
    cme_port_field(as ${port} SYSTEM_PACKAGE)
    if(NOT as)
      set(as "${package}")
    endif()
    # A port that is a name for other ports asks for those by name, because
    # that is how a machine has the library: a distribution ships Boost as
    # one package with one config that answers for every component, not as a
    # hundred and fifty-eight installable pieces. Asking without them would
    # take the headers and miss that the compiled parts are there too.
    set(asking "")
    if(virtual)
      # Only the pieces a machine has as pieces. Boost's header-only
      # libraries are not components to a distribution -- Ubuntu ships no
      # boost_align-config.cmake and never will, because there is nothing to
      # configure -- so asking for them is asking the installed copy for
      # something it has no word for, and being told no about all of it.
      cme_enabled_features(${port} wanted)
      foreach(cme_feature IN LISTS wanted)
        cme_feature_field(separate ${port} ${cme_feature} SYSTEM_COMPONENT)
        if(separate)
          list(APPEND asking "${cme_feature}")
        endif()
      endforeach()
    endif()
    set_property(GLOBAL PROPERTY CME_INSIDE_SYSTEM TRUE)
    if(asking)
      find_package(${as} ${version} QUIET GLOBAL BYPASS_PROVIDER
                   COMPONENTS ${asking})
    else()
      find_package(${as} ${version} QUIET GLOBAL BYPASS_PROVIDER)
    endif()
    set_property(GLOBAL PROPERTY CME_INSIDE_SYSTEM FALSE)
    if(NOT ${as} STREQUAL "${package}" AND ${as}_FOUND)
      set(${package}_FOUND TRUE)
      set(${package}_VERSION "${${as}_VERSION}")
    endif()
    if(${package}_FOUND)
      cme_enabled_features(${port} needed)
      cme_system_has_features(usable "${package}" "${port}" "${needed}")
      if(usable)
        set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${package}
                     "${${package}_VERSION}")
        cme_alias_system_targets("${port}")
        if(virtual)
          cme_system_header_members("${port}" "${package}" "${needed}")
        endif()
        cme_check_promised("${port}" "${package}" "by the system")
        cme_note_decision("${package}" "system" "${${package}_VERSION}")
        cme_family_settled("${port}" "${package}" "system")
        set(${out_answer} "system" PARENT_SCOPE)
        return()
      endif()
    endif()
    cme_try_pkgconfig(by_pkgconfig "${port}" "${package}" "${version}"
                      "${exact}")
    if(by_pkgconfig)
      cme_enabled_features(${port} needed)
      cme_system_has_features(usable "${package}" "${port}" "${needed}")
      if(usable)
        cme_alias_system_targets("${port}")
        cme_check_promised("${port}" "${package}" "through pkg-config")
        cme_family_settled("${port}" "${package}" "system")
        set(${out_answer} "pkg-config" PARENT_SCOPE)
        return()
      endif()
    endif()
  endif()

  if(virtual)
    # Nothing installed answers for it, so it is what it is: a name for the
    # ports beside it, each of which is asked the same question in turn.
    cme_build_virtual("${port}" "${package}")
    set(${out_answer} "port" PARENT_SCOPE)
    return()
  endif()

  if(CME_SYSTEM STREQUAL "ALWAYS")
    message(FATAL_ERROR
      "cmake-everywhere: CME_SYSTEM is ALWAYS and the system has no "
      "${package}")
  endif()
  if(family_answer STREQUAL "system")
    get_property(first GLOBAL PROPERTY CME_FAMILY_${family}_FIRST)
    get_property(chosen GLOBAL PROPERTY CME_FAMILY_${family}_VERSION)
    message(FATAL_ERROR
      "cmake-everywhere: ${first} was taken from the system at ${chosen}, so "
      "the rest of ${family} has to come from there too, and this machine "
      "has no ${package} that will do. Building this one beside a system "
      "copy of the others would put two versions of ${family} in one build: "
      "headers from one and symbols from the other.\n"
      "Either install it, or build the whole of ${family} here with "
      "-DCME_SYSTEM_${package}=OFF on every one of them, or the simple way, "
      "-DCME_SYSTEM=NEVER.")
  endif()
  cme_build_port("${port}" "${package}" "${version}" "${exact}")
  cme_family_settled("${port}" "${package}" "built")
  set(${out_answer} "port" PARENT_SCOPE)
endfunction()

# What a later caller asks for, against what is already here. Neither a
# version nor a feature can be added to something already built, so the
# request is written down and the run stops: the next configure starts with
# it and resolves correctly from the beginning.
function(cme_check_late package port version features)
  get_property(built_features GLOBAL PROPERTY CME_BUILT_FEATURES_${port})
  get_property(answered GLOBAL PROPERTY CME_ANSWERED_${package})
  set(missing "")
  foreach(feature IN LISTS features)
    if(NOT feature IN_LIST built_features)
      list(APPEND missing "${feature}")
    endif()
  endforeach()
  if(missing AND answered STREQUAL "port")
    set(learned "${CME_FEATURES_${port}}")
    list(APPEND learned ${missing})
    list(REMOVE_DUPLICATES learned)
    list(JOIN missing ", " listed)
    if("${learned}" STREQUAL "${CME_FEATURES_${port}}")
      message(FATAL_ERROR
        "cmake-everywhere: ${port} is already asked for with ${listed} and "
        "was built without. Nothing else can explain that: look at the port.")
    endif()
    set(CME_FEATURES_${port} "${learned}" CACHE STRING
      "Features wanted from the ${port} port" FORCE)
    cme_note_decision("${package}" "needs feature" "${listed}")
    message(FATAL_ERROR
      "cmake-everywhere: rerun -- ${package} is already here without "
      "${listed}, and something now asks for it. Written down: run cmake "
      "again and it will be built with it, or use tools/configure, which "
      "does that for you.")
  endif()

  get_property(have GLOBAL PROPERTY CME_PROVIDED_VERSION_${package})
  if(version AND have AND have VERSION_LESS version)
    if(CME_REQUIRE_${package} AND
       NOT CME_REQUIRE_${package} VERSION_LESS version)
      message(FATAL_ERROR
        "cmake-everywhere: ${package} ${version} is already required and "
        "resolved to ${have} anyway. Nothing available satisfies it: raise "
        "the port, or ask for less.")
    endif()
    set(CME_REQUIRE_${package} "${version}" CACHE STRING
      "Lowest acceptable ${package}, learned from a later caller" FORCE)
    cme_note_decision("${package}" "requires" "${version}")
    message(FATAL_ERROR
      "cmake-everywhere: rerun -- ${package} is here as ${have} and something "
      "now asks for ${version}, which is later than anything this was told "
      "about. Written down: run cmake again and it will be resolved at "
      "${version} from the start, or use tools/configure, which does that "
      "for you.")
  endif()
endfunction()

# The provider itself, which has to be a macro: what it sets -- <Pkg>_FOUND
# and the variables a Find module would have set -- belongs to whoever called
# find_package, and a function would have to know their names to pass them
# back. So it stays small, and everything that could re-enter is in the
# functions above.
macro(cme_provider cme_method cme_package)

  # A config file the system installed resolves its own pieces by calling
  # find_package again, and those calls arrive here. They must not: a copy
  # of a library that somebody else built was built against the rest of what
  # is installed, and answering one of its pieces with something built here
  # puts two versions of one library in one build -- the same mix a family
  # exists to prevent, arriving through the back door.
  #
  # So while a system copy is being looked for, this steps aside and lets
  # CMake search the way it would without a provider.
  get_property(cme_bypassing GLOBAL PROPERTY CME_INSIDE_SYSTEM)
  # FindPkgConfig defines pkg_check_modules when it is included, and it is
  # included by find_package(PkgConfig) -- which comes through here. So this
  # is the moment the real one exists and can be stepped in front of; doing
  # it any earlier would be undone by the module itself a moment later.
  #
  # A branch rather than an early return: this is a macro, and a return in a
  # macro returns from whoever called it, which here is somebody else's
  # CMakeLists in the middle of its own work.
  if("${cme_method}" STREQUAL "FIND_PACKAGE"
     AND "${cme_package}" STREQUAL "PkgConfig" AND NOT cme_bypassing)
    find_package(PkgConfig ${ARGN} BYPASS_PROVIDER)
    cme_install_pkgconfig_override()
  elseif("${cme_method}" STREQUAL "FIND_PACKAGE" AND NOT cme_bypassing)
    cme_load_registry()
    get_property(cme_port GLOBAL PROPERTY CME_PROVIDER_${cme_package})
    if(cme_port)
      set(cme_wanted "")
      set(cme_exact FALSE)
      set(cme_components FALSE)
      set(cme_asked_features "")
      foreach(cme_argument IN ITEMS ${ARGN})
        if("${cme_argument}" STREQUAL "COMPONENTS" OR
           "${cme_argument}" STREQUAL "OPTIONAL_COMPONENTS")
          set(cme_components TRUE)
        elseif("${cme_argument}" MATCHES
               "^(REQUIRED|QUIET|EXACT|CONFIG|MODULE|NO_MODULE|GLOBAL|REGISTRY_VIEW|NAMES|BYPASS_PROVIDER)$")
          set(cme_components FALSE)
          if("${cme_argument}" STREQUAL "EXACT")
            set(cme_exact TRUE)
          endif()
        elseif(cme_components)
          # A third-party project asking for COMPONENTS means its own
          # components: libsndfile asks Vorbis for Enc and File, which are
          # not features of anything here. Only a name this port declares is
          # read as a feature; the rest are answered as present, because a
          # port that provides the library provides all of it.
          cme_port_field(cme_declared "${cme_port}" FEATURES)
          if("${cme_argument}" IN_LIST cme_declared)
            list(APPEND cme_asked_features "${cme_argument}")
          else()
            set(${cme_package}_${cme_argument}_FOUND TRUE)
          endif()
        elseif("${cme_argument}" MATCHES "^[0-9]+(\\.[0-9]+)*$" AND NOT cme_wanted)
          set(cme_wanted "${cme_argument}")
        endif()
      endforeach()

      cme_note_ask("${cme_port}")
      get_property(cme_answered GLOBAL PROPERTY CME_ANSWERED_${cme_package})
      if(NOT cme_answered)
        cme_resolve("${cme_package}" "${cme_port}" "${cme_wanted}"
                    "${cme_exact}" "${cme_asked_features}" cme_answered)
        set_property(GLOBAL PROPERTY CME_ANSWERED_${cme_package}
                     "${cme_answered}")
      else()
        cme_check_late("${cme_package}" "${cme_port}" "${cme_wanted}"
                       "${cme_asked_features}")
      endif()

      if(cme_answered STREQUAL "system")
        # Asked again for each caller rather than remembered: a Find module
        # sets its variables in the scope it is called from, and the third
        # project to ask needs them as much as the first. After the first
        # time the answer is in the cache and this costs nothing.
        find_package(${cme_package} ${cme_wanted} QUIET GLOBAL BYPASS_PROVIDER)
      else()
        get_property(cme_exported GLOBAL PROPERTY CME_EXPORT_${cme_package})
        while(cme_exported)
          list(POP_FRONT cme_exported cme_name cme_value)
          string(REPLACE "@CME@" ";" cme_value "${cme_value}")
          set(${cme_name} "${cme_value}")
        endwhile()
        set(${cme_package}_FOUND TRUE)
      endif()
    endif()
  endif()
endmacro()

cmake_language(SET_DEPENDENCY_PROVIDER cme_provider
               SUPPORTED_METHODS FIND_PACKAGE)
