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
          POLICY_MINIMUM GIT_TAG_TEMPLATE GIT_SHALLOW)
  set(many PROVIDES OPTIONS DEPENDS SYSTEM_PKGCONFIG EXCLUDES LICENSE
           LINK_NAMES TARGETS
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

  if(CME_FETCH_ONLY)
    list(APPEND arguments DOWNLOAD_ONLY YES)
  endif()

  CPMAddPackage(${arguments})

  if(CME_FETCH_ONLY)
    message(STATUS "cmake-everywhere: fetched ${port} ${port_version}")
    cme_note_decision("${port}" "fetched" "${port_version}")
    return()
  endif()

  if(gn_targets)
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

      # A floor learned on an earlier run, so this one does not repeat it.
      if(CME_REQUIRE_${cme_package} AND
         (NOT cme_wanted OR cme_wanted VERSION_LESS CME_REQUIRE_${cme_package}))
        set(cme_wanted "${CME_REQUIRE_${cme_package}}")
      endif()

      get_property(cme_answered GLOBAL PROPERTY CME_ANSWERED_${cme_package})
      if(NOT cme_answered)
        cme_require("${cme_port}" "${cme_wanted}" "${cme_asked_features}"
                    "the project")
        set(cme_answered "port")
        cme_system_allowed(cme_try_system "${cme_package}")
        if(cme_try_system)
          # BYPASS_PROVIDER is what keeps this call from being routed
          # straight back here. It is the one place the keyword is allowed.
          find_package(${cme_package} ${cme_wanted} QUIET GLOBAL
                       BYPASS_PROVIDER)
          if(${cme_package}_FOUND)
            cme_enabled_features(${cme_port} cme_needed)
            cme_system_has_features(cme_usable "${cme_package}" "${cme_port}"
                                    "${cme_needed}")
          else()
            set(cme_usable FALSE)
          endif()
          if(${cme_package}_FOUND AND cme_usable)
            set(cme_answered "system")
            set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${cme_package}
                         "${${cme_package}_VERSION}")
            cme_note_decision("${cme_package}" "system"
                              "${${cme_package}_VERSION}")
          else()
            cme_try_pkgconfig(cme_by_pc "${cme_port}" "${cme_package}"
                              "${cme_wanted}" "${cme_exact}")
            if(cme_by_pc)
              cme_enabled_features(${cme_port} cme_needed)
              cme_system_has_features(cme_usable "${cme_package}"
                                      "${cme_port}" "${cme_needed}")
              if(cme_usable)
                set(cme_answered "pkg-config")
              endif()
            endif()
          endif()
        endif()
        if(cme_answered STREQUAL "port")
          if(CME_SYSTEM STREQUAL "ALWAYS")
            message(FATAL_ERROR
              "cmake-everywhere: CME_SYSTEM is ALWAYS and the system has no "
              "${cme_package}")
          endif()
          cme_build_port("${cme_port}" "${cme_package}" "${cme_wanted}"
                         "${cme_exact}")
        endif()
        set_property(GLOBAL PROPERTY CME_ANSWERED_${cme_package}
                     "${cme_answered}")
      endif()

      # A package is resolved once and cannot be resolved again: whatever was
      # built or found is already part of this configuration. When the
      # registry knew the requirement in advance this never happens -- that
      # is what the constraints are for. What is left is a requirement the
      # registry could not know: one the consuming project makes itself,
      # after the package is already here.
      #
      # So it is written down and the run stops. The next configure starts
      # with the floor raised and resolves it correctly from the beginning.
      # Once per requirement, not once per call: it is in the cache
      # afterwards.
      # The same for a feature asked for after the library is already here.
      # A feature cannot be added to something already built either.
      get_property(cme_built_features GLOBAL PROPERTY
                   CME_BUILT_FEATURES_${cme_port})
      set(cme_missing "")
      foreach(cme_feature IN LISTS cme_asked_features)
        if(NOT cme_feature IN_LIST cme_built_features)
          list(APPEND cme_missing "${cme_feature}")
        endif()
      endforeach()
      if(cme_missing AND cme_answered STREQUAL "port")
        set(cme_learned "${CME_FEATURES_${cme_port}}")
        list(APPEND cme_learned ${cme_missing})
        list(REMOVE_DUPLICATES cme_learned)
        list(JOIN cme_missing ", " cme_listed)
        if("${cme_learned}" STREQUAL "${CME_FEATURES_${cme_port}}")
          message(FATAL_ERROR
            "cmake-everywhere: ${cme_port} is already asked for with "
            "${cme_listed} and was built without. Nothing else can explain "
            "that: look at the port.")
        endif()
        set(CME_FEATURES_${cme_port} "${cme_learned}" CACHE STRING
          "Features wanted from the ${cme_port} port" FORCE)
        cme_note_decision("${cme_package}" "needs feature" "${cme_listed}")
        message(FATAL_ERROR
          "cmake-everywhere: ${cme_package} is already here without "
          "${cme_listed}, and something now asks for it. Written down -- run "
          "cmake again and it will be built with it.")
      endif()

      get_property(cme_have GLOBAL PROPERTY
                   CME_PROVIDED_VERSION_${cme_package})
      if(cme_wanted AND cme_have AND cme_have VERSION_LESS cme_wanted)
        if(CME_REQUIRE_${cme_package} AND
           NOT CME_REQUIRE_${cme_package} VERSION_LESS cme_wanted)
          message(FATAL_ERROR
            "cmake-everywhere: ${cme_package} ${cme_wanted} is already "
            "required and resolved to ${cme_have} anyway. Nothing available "
            "satisfies it: raise the port, or ask for less.")
        endif()
        set(CME_REQUIRE_${cme_package} "${cme_wanted}" CACHE STRING
          "Lowest acceptable ${cme_package}, learned from a later caller"
          FORCE)
        cme_note_decision("${cme_package}" "requires" "${cme_wanted}")
        message(FATAL_ERROR
          "cmake-everywhere: ${cme_package} is here as ${cme_have} and "
          "something now asks for ${cme_wanted}, which is later than anything "
          "the registry was told about. Written down -- run cmake again and "
          "it will be resolved at ${cme_wanted} from the start.")
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
