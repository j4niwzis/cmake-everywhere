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
include("${CME_DIR}/cmake/CPM.cmake")

set(CME_REGISTRY "${CME_DIR}/registry" CACHE PATH
  "Where the ports are. Point this at your own directory to add ports.")
set(CME_SYSTEM "AUTO" CACHE STRING
  "AUTO: take a package from the system when it is there and new enough. \
ALWAYS: refuse to build anything, the system must have it. \
NEVER: build everything from source.")
set_property(CACHE CME_SYSTEM PROPERTY STRINGS AUTO ALWAYS NEVER)
set(CME_LOCK_FILE "${CMAKE_BINARY_DIR}/cme-lock.txt" CACHE FILEPATH
  "Where the resolved decisions are written")
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
          POLICY_MINIMUM GIT_TAG_TEMPLATE)
  set(many PROVIDES OPTIONS DEPENDS SYSTEM_PKGCONFIG)
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

  cme_port_field(depends ${port} DEPENDS)
  foreach(dep IN LISTS depends)
    cme_port_field(names ${dep} PROVIDES)
    list(GET names 0 first)
    find_package(${first} QUIET REQUIRED)
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
  if(CME_VERSION_${port})
    cme_port_field(template ${port} GIT_TAG_TEMPLATE)
    if(NOT template)
      message(FATAL_ERROR
        "cmake-everywhere: asked to build ${port} ${CME_VERSION_${port}}, but "
        "the port does not say how a version becomes a tag. Add "
        "GIT_TAG_TEMPLATE to registry/${port}/port.cmake.")
    endif()
    set(port_version "${CME_VERSION_${port}}")
    string(REPLACE "@VERSION@" "${port_version}" port_tag "${template}")
    message(STATUS "cmake-everywhere: ${port} at ${port_version} (asked for)")
  endif()
  if(version AND port_version VERSION_LESS version)
    message(FATAL_ERROR
      "cmake-everywhere: something asks for ${package} ${version} and the "
      "${port} port is ${port_version}. Raise VERSION in "
      "registry/${port}/port.cmake, or set CME_VERSION_${port} to a version "
      "the port can check out.")
  endif()
  if(exact AND NOT port_version VERSION_EQUAL version)
    message(FATAL_ERROR
      "cmake-everywhere: ${package} was asked for as exactly ${version} and "
      "the ${port} port is ${port_version}.")
  endif()
  set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${package}
               "${port_version}")

  set(arguments NAME ${port})
  foreach(field GIT_REPOSITORY GITHUB_REPOSITORY GITLAB_REPOSITORY
                URL URL_HASH)
    cme_port_field(value ${port} ${field})
    if(value)
      list(APPEND arguments ${field} "${value}")
    endif()
  endforeach()
  if(port_tag)
    list(APPEND arguments GIT_TAG "${port_tag}")
  endif()
  if(port_version)
    list(APPEND arguments VERSION "${port_version}")
  endif()
  if(overlay)
    # The upstream has no CMake of its own, so nothing is configured from its
    # tree: it is downloaded and the overlay in this registry is the project
    # that builds it. Nothing is written into the fetched sources.
    list(APPEND arguments DOWNLOAD_ONLY YES)
  else()
    if(source_subdir)
      list(APPEND arguments SOURCE_SUBDIR "${source_subdir}")
    endif()
    if(options)
      list(APPEND arguments OPTIONS ${options})
    endif()
  endif()
  if(CME_OPTIONS_${port})
    list(APPEND arguments OPTIONS ${CME_OPTIONS_${port}})
    list(APPEND options ${CME_OPTIONS_${port}})
  endif()

  # Read by cmake_minimum_required in the tree about to be added. A normal
  # variable, so it reaches that tree and stops at the end of this call.
  cme_port_field(policy ${port} POLICY_MINIMUM)
  if(NOT policy)
    set(policy "${CME_POLICY_VERSION_MINIMUM}")
  endif()
  if(policy)
    set(CMAKE_POLICY_VERSION_MINIMUM "${policy}")
  endif()

  CPMAddPackage(${arguments})

  if(overlay)
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
  cme_note_decision("${port}" "built" "${port_version}")
endfunction()

# ---------------------------------------------------------------- provider

macro(cme_provider cme_method cme_package)
  if("${cme_method}" STREQUAL "FIND_PACKAGE")
    cme_load_registry()
    get_property(cme_port GLOBAL PROPERTY CME_PROVIDER_${cme_package})
    if(cme_port)
      set(cme_wanted "")
      set(cme_exact FALSE)
      foreach(cme_argument IN ITEMS ${ARGN})
        if("${cme_argument}" MATCHES "^[0-9]+(\\.[0-9]+)*$" AND NOT cme_wanted)
          set(cme_wanted "${cme_argument}")
        elseif("${cme_argument}" STREQUAL "EXACT")
          set(cme_exact TRUE)
        endif()
      endforeach()

      get_property(cme_answered GLOBAL PROPERTY CME_ANSWERED_${cme_package})
      if(NOT cme_answered)
        set(cme_answered "port")
        cme_system_allowed(cme_try_system "${cme_package}")
        if(cme_try_system)
          # BYPASS_PROVIDER is what keeps this call from being routed
          # straight back here. It is the one place the keyword is allowed.
          find_package(${cme_package} ${cme_wanted} QUIET GLOBAL
                       BYPASS_PROVIDER)
          if(${cme_package}_FOUND)
            set(cme_answered "system")
            set_property(GLOBAL PROPERTY CME_PROVIDED_VERSION_${cme_package}
                         "${${cme_package}_VERSION}")
            cme_note_decision("${cme_package}" "system"
                              "${${cme_package}_VERSION}")
          else()
            cme_try_pkgconfig(cme_by_pc "${cme_port}" "${cme_package}"
                              "${cme_wanted}" "${cme_exact}")
            if(cme_by_pc)
              set(cme_answered "pkg-config")
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
      # built or found is already in the build. So a later caller asking for
      # more than that is told, rather than linked against something older
      # than it asked for.
      get_property(cme_have GLOBAL PROPERTY
                   CME_PROVIDED_VERSION_${cme_package})
      if(cme_wanted AND cme_have AND cme_have VERSION_LESS cme_wanted)
        message(FATAL_ERROR
          "cmake-everywhere: ${cme_package} is already here as ${cme_have} and "
          "something now asks for ${cme_wanted}. Raise the port, or the "
          "version the earlier caller asked for.")
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
