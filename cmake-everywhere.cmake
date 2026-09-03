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
set(CME_STORE "" CACHE PATH
  "Where built libraries are kept between builds, or empty for none")
if(NOT CME_STORE AND NOT CME_STORE_DISABLED)
  if(DEFINED ENV{XDG_CACHE_HOME})
    set(CME_STORE "$ENV{XDG_CACHE_HOME}/cmake-everywhere/store" CACHE PATH "" FORCE)
  elseif(DEFINED ENV{HOME})
    set(CME_STORE "$ENV{HOME}/.cache/cmake-everywhere/store" CACHE PATH "" FORCE)
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
set(CME_STORE_MATCH "COMPATIBLE" CACHE STRING
  "How closely a stored library has to match: EXACT, COMPATIBLE or LOOSE")
set_property(CACHE CME_STORE_MATCH PROPERTY STRINGS EXACT COMPATIBLE LOOSE)

# Everything about this build that a compiled library could depend on, as
# name and value, so that a difference can be named rather than counted.
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
  file(GLOB files "${CME_REGISTRY}/${port}/*.cmake")
  foreach(file IN LISTS files)
    file(SHA256 "${file}" digest)
    string(APPEND recipe "${digest}")
  endforeach()

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

include("${CME_DIR}/cmake/CPM.cmake")
include("${CME_DIR}/cmake/gn.cmake")

set(CME_REGISTRY "${CME_DIR}/registry" CACHE PATH
  "Where the ports are. Point this at your own directory to add ports.")
set(CME_SYSTEM "AUTO" CACHE STRING
  "AUTO: take a package from the system when it is there and new enough. \
ALWAYS: refuse to build anything, the system must have it. \
NEVER: build everything from source.")
set_property(CACHE CME_SYSTEM PROPERTY STRINGS AUTO ALWAYS NEVER)
set(CME_LOCK_FILE "${CMAKE_BINARY_DIR}/cme-lock.txt" CACHE FILEPATH
  "Where the resolved decisions are written")
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

# ---------------------------------------------------------------- registry

# A port describes one library: where it comes from, what it needs, and what
# find_package names it answers to. Ports only declare; nothing is fetched
# until something asks for it.
function(cme_declare_port)
  set(one NAME VERSION GIT_REPOSITORY GITHUB_REPOSITORY GITLAB_REPOSITORY
          GIT_TAG URL URL_HASH SOURCE_SUBDIR OVERLAY SYSTEM_PACKAGE
          POLICY_MINIMUM GIT_TAG_TEMPLATE GIT_SHALLOW EXTERNAL)
  set(many PROVIDES OPTIONS DEPENDS SYSTEM_PKGCONFIG EXCLUDES LICENSE
           LINK_NAMES TARGETS SYSTEMS
           GN_ARGS GN_TARGETS GN_CONFIRM GN_IN_TREE)
  cmake_parse_arguments(PORT "" "${one}" "${many}" ${ARGN})
  if(NOT PORT_NAME)
    message(FATAL_ERROR "cmake-everywhere: a port with no NAME")
  endif()
  if(NOT PORT_PROVIDES)
    set(PORT_PROVIDES "${PORT_NAME}")
  endif()
  foreach(field IN LISTS one many)
    set_property(GLOBAL PROPERTY CME_PORT_${PORT_NAME}_${field}
      "${PORT_${field}}")
  endforeach()
  set_property(GLOBAL APPEND PROPERTY CME_PORTS "${PORT_NAME}")
  # The name a project writes in find_package() is not the name the library
  # calls itself: FLAC, Ogg and SndFile are all spelled several ways.
  foreach(name IN LISTS PORT_PROVIDES)
    set_property(GLOBAL PROPERTY CME_PROVIDER_${name} "${PORT_NAME}")
  endforeach()
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
    "GN_ARGS;GN_CONFIRM;OPTIONS;DEPENDS;IMPLIES;CONFLICTS;EXCLUDES;SYSTEM_HEADERS;SYSTEM_SYMBOLS;DEFAULT"
    ${ARGN})
  set_property(GLOBAL APPEND PROPERTY CME_PORT_${port}_FEATURES "${feature}")
  foreach(field GN_ARGS GN_CONFIRM OPTIONS DEPENDS SUMMARY IMPLIES CONFLICTS
                EXCLUDES SYSTEM_HEADERS SYSTEM_SYMBOLS DEFAULT)
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
  set(index 0)
  foreach(directory IN LISTS directories)
    string(REGEX REPLACE "^\\$<BUILD_INTERFACE:(.*)>$" "\\1" directory
           "${directory}")
    if(NOT directory MATCHES "^${CMAKE_BINARY_DIR}")
      list(APPEND result "${directory}")
      continue()
    endif()
    file(GLOB_RECURSE headers "${directory}/*.h" "${directory}/*.hpp"
                              "${directory}/*.hh" "${directory}/*.inc")
    if(NOT headers)
      # Nothing there yet, which means this library writes its headers while
      # it builds rather than while it configures. Keeping the rest would
      # keep a library that cannot be compiled against.
      message(STATUS
        "cmake-everywhere: ${port} is not kept: ${directory} has no headers "
        "yet, so it makes them while building")
      set(${ok} FALSE PARENT_SCOPE)
      return()
    endif()
    set(kept "${entry}/generated/${index}")
    file(COPY "${directory}/" DESTINATION "${kept}"
         FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp" PATTERN "*.hh"
                        PATTERN "*.inc")
    list(APPEND result "\${CMAKE_CURRENT_LIST_DIR}/generated/${index}")
    math(EXPR index "${index} + 1")
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
  string(RANDOM LENGTH 8 ALPHABET "abcdefghijklmnopqrstuvwxyz0123456789" tag)
  get_filename_component(parent "${entry}" DIRECTORY)
  get_filename_component(leaf "${entry}" NAME)
  set(building "${parent}/.building-${leaf}-${tag}")
  file(REMOVE_RECURSE "${building}")
  file(MAKE_DIRECTORY "${building}/lib")
  set(text "# Written by cmake-everywhere. Do not edit; the name is a hash.\n")
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

    string(APPEND text
      "add_library(${alias} STATIC IMPORTED GLOBAL)\n"
      "set_target_properties(${alias} PROPERTIES\n"
      "  IMPORTED_LOCATION \"\${CMAKE_CURRENT_LIST_DIR}/lib/lib${target}.a\"\n"
      "  INTERFACE_INCLUDE_DIRECTORIES \"${includes}\"\n"
      "  INTERFACE_LINK_LIBRARIES \"${rest}\"\n"
      "  INTERFACE_COMPILE_OPTIONS \"${options}\"\n"
      "  INTERFACE_COMPILE_DEFINITIONS \"${defines}\")\n")

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
  add_library(${alias} ALIAS ${target})
endfunction()

function(cme_load_registry)
  get_property(loaded GLOBAL PROPERTY CME_REGISTRY_LOADED)
  if(loaded)
    return()
  endif()
  file(GLOB ports "${CME_REGISTRY}/*/port.cmake")
  foreach(port IN LISTS ports)
    include("${port}")
  endforeach()
  set_property(GLOBAL PROPERTY CME_REGISTRY_LOADED TRUE)
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
  cme_expand_implications(${port} "${features}" features)
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
  set(result "")
  foreach(feature IN LISTS enabled)
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
function(cme_system_has_features out package port features)
  set(${out} TRUE PARENT_SCOPE)
  set(includes "${${package}_INCLUDE_DIRS}")
  if(NOT includes)
    set(includes "${${package}_INCLUDE_DIR}")
  endif()
  set(libraries "${${package}_LIBRARIES}")
  if(NOT libraries)
    set(libraries "${${package}_LIBRARY}")
  endif()
  include(CheckIncludeFile)
  include(CheckSymbolExists)
  set(CMAKE_REQUIRED_INCLUDES "${includes}")
  set(CMAKE_REQUIRED_LIBRARIES "${libraries}")
  set(CMAKE_REQUIRED_QUIET TRUE)
  foreach(feature IN LISTS features)
    cme_feature_field(headers ${port} ${feature} SYSTEM_HEADERS)
    foreach(header IN LISTS headers)
      string(MAKE_C_IDENTIFIER "cme_${package}_${header}" variable)
      check_include_file("${header}" ${variable})
      if(NOT ${variable})
        message(STATUS
          "cmake-everywhere: the system ${package} has no ${header}, so it "
          "was not built with ${feature}")
        set(${out} FALSE PARENT_SCOPE)
        return()
      endif()
    endforeach()
    # "symbol:header", because a symbol cannot be looked for without one.
    cme_feature_field(symbols ${port} ${feature} SYSTEM_SYMBOLS)
    foreach(pair IN LISTS symbols)
      if(NOT pair MATCHES "^([^:]+):(.+)$")
        message(FATAL_ERROR
          "cmake-everywhere: ${port}'s ${feature} says SYSTEM_SYMBOLS "
          "${pair}, which is not <symbol>:<header>")
      endif()
      string(MAKE_C_IDENTIFIER "cme_${package}_${CMAKE_MATCH_1}" variable)
      check_symbol_exists("${CMAKE_MATCH_1}" "${CMAKE_MATCH_2}" ${variable})
      if(NOT ${variable})
        message(STATUS
          "cmake-everywhere: the system ${package} has no ${CMAKE_MATCH_1}, "
          "so it was not built with ${feature}")
        set(${out} FALSE PARENT_SCOPE)
        return()
      endif()
    endforeach()
  endforeach()
endfunction()

# Most distributions ship a .pc file and no CMake config at all, and CMake
# has no FindOgg, FindVorbis, FindFLAC or FindSndFile of its own. So a
# find_package for any of them fails on a machine that has the library
# installed, and the port would be built for nothing. A port that says
# SYSTEM_PKGCONFIG names the modules to ask pkg-config for instead, and the
# target each one answers to.
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
    set(query "${module}")
    if(version AND index EQUAL 0)
      if(exact)
        set(query "${module} = ${version}")
      else()
        set(query "${module} >= ${version}")
      endif()
    endif()
    set(prefix CME_PC_${port}_${index})
    pkg_check_modules(${prefix} QUIET IMPORTED_TARGET GLOBAL "${query}")
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
  set(${found} TRUE PARENT_SCOPE)
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

  cme_port_field(depends ${port} DEPENDS)
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} DEPENDS)
    list(APPEND depends ${extra})
  endforeach()
  foreach(spec IN LISTS depends)
    cme_split_requirement("${spec}" dep wanted wanted_features)
    cme_port_field(names ${dep} PROVIDES)
    list(GET names 0 first)
    if(wanted_features)
      find_package(${first} ${wanted} QUIET REQUIRED
                   COMPONENTS ${wanted_features})
    else()
      find_package(${first} ${wanted} QUIET REQUIRED)
    endif()
  endforeach()

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
  if(listed)
    # A listed version is fetched and checked, so there is no tag to work out.
  elseif(NOT port_version VERSION_EQUAL pinned)
    cme_port_field(template ${port} GIT_TAG_TEMPLATE)
    if(NOT template)
      message(FATAL_ERROR
        "cmake-everywhere: ${port} is pinned at ${pinned} and something needs "
        "${port_version}, but the port does not say how a version becomes a "
        "tag. Add GIT_TAG_TEMPLATE to registry/${port}/port.cmake.")
    endif()
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
  if(version AND port_version VERSION_LESS version)
    message(FATAL_ERROR
      "cmake-everywhere: something asks for ${package} ${version} and ${port} "
      "resolved to ${port_version}.")
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
  cme_store_entry(entry ${port} "${port_version}")
  if(entry AND EXISTS "${entry}/complete" AND EXISTS "${entry}/use.cmake"
     AND NOT CME_FETCH_ONLY)
    message(STATUS "cmake-everywhere: ${port} ${port_version} is already built")
    cme_store_differences("${entry}")
    include("${entry}/use.cmake")
    set_property(GLOBAL PROPERTY CME_BUILT_FEATURES_${port} "${features}")
    set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${package}
                 "${port_version}")
    cme_note_decision("${port}" "store" "${port_version}")
    return()
  endif()

  cme_port_field(external ${port} EXTERNAL)
  if(CME_FETCH_ONLY OR external)
    list(APPEND arguments DOWNLOAD_ONLY YES)
  endif()

  CPMAddPackage(${arguments})

  if(CME_FETCH_ONLY)
    message(STATUS "cmake-everywhere: fetched ${port} ${port_version}")
    cme_note_decision("${port}" "fetched" "${port_version}")
    return()
  endif()

  if(external)
    cme_store_entry(entry ${port} "${port_version}")
    if(NOT entry)
      set(entry "${CMAKE_BINARY_DIR}/_cme/${port}-installed")
    endif()
    cme_build_external(${port} "${package}" "${port_version}" "${entry}")
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
    add_subdirectory("${CME_REGISTRY}/${port}/${overlay}"
                     "${CMAKE_BINARY_DIR}/_cme/${port}")
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
    string(APPEND text "${port} ${version} from ${how}, asked for by ${reason}\n")
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
          string(APPEND text "    off ${feature} -- ${summary}\n")
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
function(cme_resolve package port version exact features out_answer)
  # A floor learned on an earlier run, so this one does not repeat it.
  if(CME_REQUIRE_${package} AND
     (NOT version OR version VERSION_LESS CME_REQUIRE_${package}))
    set(version "${CME_REQUIRE_${package}}")
  endif()

  cme_require("${port}" "${version}" "${features}" "the project")

  cme_system_allowed(try_system "${package}")
  if(try_system)
    # BYPASS_PROVIDER is what keeps this call from being routed straight back
    # here. It is the one place the keyword is allowed.
    find_package(${package} ${version} QUIET GLOBAL BYPASS_PROVIDER)
    if(${package}_FOUND)
      cme_enabled_features(${port} needed)
      cme_system_has_features(usable "${package}" "${port}" "${needed}")
      if(usable)
        set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${package}
                     "${${package}_VERSION}")
        cme_note_decision("${package}" "system" "${${package}_VERSION}")
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
        set(${out_answer} "pkg-config" PARENT_SCOPE)
        return()
      endif()
    endif()
  endif()

  if(CME_SYSTEM STREQUAL "ALWAYS")
    message(FATAL_ERROR
      "cmake-everywhere: CME_SYSTEM is ALWAYS and the system has no "
      "${package}")
  endif()
  cme_build_port("${port}" "${package}" "${version}" "${exact}")
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
      "cmake-everywhere: ${package} is already here without ${listed}, and "
      "something now asks for it. Written down -- run cmake again and it "
      "will be built with it.")
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
      "cmake-everywhere: ${package} is here as ${have} and something now asks "
      "for ${version}, which is later than anything the registry was told "
      "about. Written down -- run cmake again and it will be resolved at "
      "${version} from the start.")
  endif()
endfunction()

# The provider itself, which has to be a macro: what it sets -- <Pkg>_FOUND
# and the variables a Find module would have set -- belongs to whoever called
# find_package, and a function would have to know their names to pass them
# back. So it stays small, and everything that could re-enter is in the
# functions above.
macro(cme_provider cme_method cme_package)
  if("${cme_method}" STREQUAL "FIND_PACKAGE")
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
