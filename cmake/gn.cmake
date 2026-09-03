# Building a GN project as CMake targets.
#
# Nothing here knows what Skia is. GN is run once, at configure time, purely
# to describe the build: which sources, which defines, which per-file
# compiler flags, which generated files, with the project's own hundred build
# arguments already evaluated by the thing that understands them. That
# description becomes ordinary CMake targets, compiled by the consumer's
# generator alongside everything else.
#
# The alternative -- reading the project's source lists and re-stating its
# conditions in CMake by hand -- is the same work again, done worse, once per
# release.

include_guard(GLOBAL)

set(CME_GN "" CACHE FILEPATH "The gn executable, when it is not on PATH")

function(cme_gn_find out)
  if(CME_GN)
    set(${out} "${CME_GN}" PARENT_SCOPE)
    return()
  endif()
  find_program(found NAMES gn)
  if(NOT found)
    message(FATAL_ERROR
      "cmake-everywhere: this port is a GN project and gn is not on PATH. "
      "Install it, or pass -DCME_GN=/path/to/gn.")
  endif()
  set(${out} "${found}" PARENT_SCOPE)
endfunction()

# The values a port's GN arguments are written in terms of. A port names its
# project's own argument spellings -- one calls the compiler cc, the next
# calls it clang_path -- and asks for these by placeholder, because only this
# side knows what the consumer is building with.
function(cme_gn_substitute out text)
  set(value "${text}")
  string(REPLACE "@CC@" "${CMAKE_C_COMPILER}" value "${value}")
  string(REPLACE "@CXX@" "${CMAKE_CXX_COMPILER}" value "${value}")
  string(REPLACE "@AR@" "${CMAKE_AR}" value "${value}")
  string(REPLACE "@SYSROOT@" "${CMAKE_SYSROOT}" value "${value}")
  string(REPLACE "@PREFIX@" "${CMAKE_INSTALL_PREFIX}" value "${value}")
  string(REPLACE "@BUILD_TYPE@" "${CMAKE_BUILD_TYPE}" value "${value}")
  string(REPLACE "@SOURCE_DIR@" "${CME_GN_SOURCE_DIR}" value "${value}")
  string(REPLACE "@DEP_INCLUDES@" "${CME_GN_DEP_INCLUDES}" value "${value}")
  string(REPLACE "@DEP_LIBDIRS@" "${CME_GN_DEP_LIBDIRS}" value "${value}")
  # GN spells architectures its own way and so does everyone else.
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
    set(cpu "arm64")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
    set(cpu "x64")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(i.86|x86)$")
    set(cpu "x86")
  elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^arm")
    set(cpu "arm")
  else()
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" cpu)
  endif()
  string(REPLACE "@TARGET_CPU@" "${cpu}" value "${value}")
  if(ANDROID)
    set(os "android")
  elseif(APPLE)
    set(os "mac")
  elseif(WIN32)
    set(os "win")
  else()
    set(os "linux")
  endif()
  string(REPLACE "@TARGET_OS@" "${os}" value "${value}")
  set(${out} "${value}" PARENT_SCOPE)
endfunction()

# Confirms what an argument came out as rather than what was asked for. An
# argument that is misspelled, overridden or shadowed reads correctly in the
# command line that set it and wrongly in the build.
function(cme_gn_confirm gn build name expected)
  execute_process(
    COMMAND "${gn}" args "${build}" "--list=${name}" --short
    OUTPUT_VARIABLE output RESULT_VARIABLE code
    OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR "cmake-everywhere: gn cannot report ${name}")
  endif()
  string(REGEX REPLACE "\n.*" "" first "${output}")
  string(STRIP "${first}" first)
  if(NOT first STREQUAL "${name} = ${expected}")
    message(FATAL_ERROR
      "cmake-everywhere: gn reports `${first}`, not `${name} = ${expected}`")
  endif()
endfunction()

# Where the libraries this port depends on ended up. A GN project told to use
# the system's zlib looks for it on the compiler's search path, and a zlib
# this registry built for it is on no such path -- so the port asks for these
# and puts them in the project's own spelling of extra flags.
function(cme_gn_dependency_flags port out_includes out_libdirs)
  set(includes "")
  set(libdirs "")
  cme_port_field(depends ${port} DEPENDS)
  foreach(spec IN LISTS depends)
    cme_split_requirement("${spec}" dep unused)
    cme_port_field(names ${dep} PROVIDES)
    list(GET names 0 package)
    string(TOUPPER "${package}" upper)
    get_property(exported GLOBAL PROPERTY CME_EXPORT_${package})
    while(exported)
      list(POP_FRONT exported name value)
      string(REPLACE "@CME@" ";" value "${value}")
      if(name STREQUAL "${upper}_INCLUDE_DIRS" OR
         name STREQUAL "${package}_INCLUDE_DIRS")
        list(APPEND includes ${value})
      endif()
    endwhile()
  endforeach()
  list(REMOVE_DUPLICATES includes)
  set(quoted_includes "")
  foreach(directory IN LISTS includes)
    list(APPEND quoted_includes "\"-I${directory}\"")
  endforeach()
  list(JOIN quoted_includes "," quoted_includes)
  set(quoted_libdirs "")
  foreach(directory IN LISTS libdirs)
    list(APPEND quoted_libdirs "\"-L${directory}\"")
  endforeach()
  list(JOIN quoted_libdirs "," quoted_libdirs)
  set(${out_includes} "${quoted_includes}" PARENT_SCOPE)
  set(${out_libdirs} "${quoted_libdirs}" PARENT_SCOPE)
endfunction()

function(cme_gn_generate port source build out_description)
  cme_gn_find(gn)
  set(CME_GN_SOURCE_DIR "${source}")
  cme_gn_dependency_flags(${port} CME_GN_DEP_INCLUDES CME_GN_DEP_LIBDIRS)

  cme_port_field(raw ${port} GN_ARGS)
  if(CME_GN_ARGS_${port})
    list(APPEND raw ${CME_GN_ARGS_${port}})
  endif()
  set(arguments "")
  foreach(argument IN LISTS raw)
    cme_gn_substitute(substituted "${argument}")
    list(APPEND arguments "${substituted}")
  endforeach()
  list(JOIN arguments " " argument_line)

  file(MAKE_DIRECTORY "${build}")
  message(STATUS "cmake-everywhere: gn gen for ${port}")
  execute_process(
    COMMAND "${gn}" gen "${build}" "--root=${source}"
            "--args=${argument_line}" --ide=json
            --json-file-name=project.json
    RESULT_VARIABLE code OUTPUT_VARIABLE output ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR "cmake-everywhere: gn gen failed for ${port}\n"
                        "  args: ${argument_line}\n${output}")
  endif()

  cme_port_field(confirm ${port} GN_CONFIRM)
  foreach(pair IN LISTS confirm)
    if(pair MATCHES "^([^=]+)=(.*)$")
      cme_gn_confirm("${gn}" "${build}" "${CMAKE_MATCH_1}" "${CMAKE_MATCH_2}")
    endif()
  endforeach()

  find_package(Python3 QUIET COMPONENTS Interpreter)
  if(NOT Python3_EXECUTABLE)
    set(Python3_EXECUTABLE python3)
  endif()
  set(description "${build}/gn-targets.cmake")
  execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${CME_DIR}/cmake/gn_import.py"
            "${build}/project.json" "${build}" "${description}"
    RESULT_VARIABLE code ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR "cmake-everywhere: cannot read gn's description of "
                        "${port}\n${output}")
  endif()
  message(STATUS "cmake-everywhere: ${output}")
  set(${out_description} "${description}" PARENT_SCOPE)
endfunction()

# Everything GN said, as targets. Two passes: a target has to exist before
# anything can be made to depend on it, and the order in the description is
# alphabetical rather than topological.
function(cme_gn_import port description)
  include("${description}")

  set(made "")
  foreach(name IN LISTS GN_TARGET_NAMES)
    set(prefix "GN_TARGET_${name}")
    set(target "${port}_${name}")
    set(type "${${prefix}_TYPE}")
    set(sources "${${prefix}_SOURCES}")

    # A GN source list carries headers as well, and a target of only headers
    # is not a target CMake will make.
    set(compiled "")
    foreach(file IN LISTS sources)
      if(file MATCHES "\\.(c|cc|cpp|cxx|m|mm|S|s|asm)$")
        list(APPEND compiled "${file}")
      endif()
    endforeach()

    if(type STREQUAL "static_library" OR type STREQUAL "shared_library")
      if(compiled)
        add_library(${target} STATIC ${compiled})
      else()
        add_library(${target} INTERFACE)
      endif()
    elseif(type STREQUAL "source_set")
      if(compiled)
        add_library(${target} OBJECT ${compiled})
      else()
        add_library(${target} INTERFACE)
      endif()
    elseif(type STREQUAL "group")
      add_library(${target} INTERFACE)
    elseif(type STREQUAL "executable")
      # Built only if something needs it, which is how a code generator that
      # the build runs gets built and nothing else does.
      if(compiled)
        add_executable(${target} EXCLUDE_FROM_ALL ${compiled})
      else()
        continue()
      endif()
    elseif(type STREQUAL "action" OR type STREQUAL "action_foreach"
           OR type STREQUAL "copy")
      if(NOT ${prefix}_OUTPUTS)
        continue()
      endif()
      if(${prefix}_SCRIPT)
        find_package(Python3 QUIET COMPONENTS Interpreter)
        if(NOT Python3_EXECUTABLE)
          set(Python3_EXECUTABLE python3)
        endif()
        # GN rebases a script's arguments against the build directory, so
        # that is where it has to run.
        add_custom_command(
          OUTPUT ${${prefix}_OUTPUTS}
          COMMAND "${Python3_EXECUTABLE}" "${${prefix}_SCRIPT}"
                  ${${prefix}_ARGS}
          DEPENDS ${${prefix}_SCRIPT} ${${prefix}_INPUTS} ${sources}
          WORKING_DIRECTORY "${GN_BUILD_DIR}"
          COMMENT "${port}: ${${prefix}_LABEL}"
          VERBATIM)
      else()
        add_custom_command(
          OUTPUT ${${prefix}_OUTPUTS}
          COMMAND ${CMAKE_COMMAND} -E copy ${sources} ${${prefix}_OUTPUTS}
          DEPENDS ${sources}
          COMMENT "${port}: ${${prefix}_LABEL}"
          VERBATIM)
      endif()
      add_custom_target(${target} DEPENDS ${${prefix}_OUTPUTS})
    else()
      message(DEBUG "cmake-everywhere: ${${prefix}_LABEL} is a ${type}")
      continue()
    endif()
    list(APPEND made "${name}")
  endforeach()

  foreach(name IN LISTS made)
    set(prefix "GN_TARGET_${name}")
    set(target "${port}_${name}")
    set(type "${${prefix}_TYPE}")
    get_target_property(kind ${target} TYPE)

    if(NOT kind STREQUAL "UTILITY")
      set(scope PRIVATE)
      if(kind STREQUAL "INTERFACE_LIBRARY")
        set(scope INTERFACE)
      endif()
      foreach(directory IN LISTS ${prefix}_INCLUDE_DIRS)
        target_include_directories(${target} ${scope}
          "$<BUILD_INTERFACE:${directory}>")
      endforeach()
      if(${prefix}_DEFINES)
        target_compile_definitions(${target} ${scope} ${${prefix}_DEFINES})
      endif()
      if(NOT kind STREQUAL "INTERFACE_LIBRARY")
        # The per-file flags are the reason to take GN's word for this: a
        # project like Skia compiles its vector code with flags that differ
        # from one translation unit to the next, and guessing them wrong is a
        # miscompile rather than an error.
        foreach(flag IN LISTS ${prefix}_CFLAGS)
          target_compile_options(${target} PRIVATE "SHELL:${flag}")
        endforeach()
        foreach(flag IN LISTS ${prefix}_CFLAGS_C)
          target_compile_options(${target} PRIVATE
            "$<$<COMPILE_LANGUAGE:C>:SHELL:${flag}>")
        endforeach()
        foreach(flag IN LISTS ${prefix}_CFLAGS_CC)
          target_compile_options(${target} PRIVATE
            "$<$<COMPILE_LANGUAGE:CXX>:SHELL:${flag}>")
        endforeach()
        if(${prefix}_LDFLAGS AND NOT kind STREQUAL "OBJECT_LIBRARY"
           AND NOT kind STREQUAL "STATIC_LIBRARY")
          target_link_options(${target} PRIVATE ${${prefix}_LDFLAGS})
        endif()
        if(${prefix}_LIB_DIRS)
          target_link_directories(${target} ${scope} ${${prefix}_LIB_DIRS})
        endif()
        if(${prefix}_LIBS)
          target_link_libraries(${target} ${scope} ${${prefix}_LIBS})
        endif()
      endif()
    endif()

    foreach(dep IN LISTS ${prefix}_DEPS)
      set(other "${port}_${dep}")
      if(NOT TARGET ${other})
        continue()
      endif()
      get_target_property(other_kind ${other} TYPE)
      if(kind STREQUAL "UTILITY" OR other_kind STREQUAL "UTILITY")
        add_dependencies(${target} ${other})
      elseif(kind STREQUAL "INTERFACE_LIBRARY")
        target_link_libraries(${target} INTERFACE ${other})
      else()
        target_link_libraries(${target} PRIVATE ${other})
      endif()
    endforeach()
  endforeach()
endfunction()

# What the port promises its consumers: "//:skia=Skia::skia".
function(cme_gn_export port)
  cme_port_field(exports ${port} GN_TARGETS)
  foreach(pair IN LISTS exports)
    if(NOT pair MATCHES "^([^=]+)=(.+)$")
      message(FATAL_ERROR
        "cmake-everywhere: ${port} exports `${pair}`, which is not "
        "<gn label>=<CMake target>")
    endif()
    set(label "${CMAKE_MATCH_1}")
    set(alias "${CMAKE_MATCH_2}")
    string(REGEX REPLACE "^//" "" name "${label}")
    string(REGEX REPLACE "^:" "" name "${name}")
    string(REGEX REPLACE ":" "__" name "${name}")
    string(REGEX REPLACE "[^A-Za-z0-9_]" "_" name "${name}")
    if(NOT name)
      set(name "root")
    endif()
    if(NOT TARGET ${port}_${name})
      message(FATAL_ERROR
        "cmake-everywhere: ${port} says it exports ${label}, and gn's "
        "description has no such target")
    endif()
    cme_alias(${alias} ${port}_${name})
  endforeach()
endfunction()

function(cme_gn_build port source)
  # Inside the fetched tree because GN speaks in paths relative to its own
  # source root, and a build directory outside it has no spelling there.
  set(build "${source}/out/cme")
  cme_gn_generate(${port} "${source}" "${build}" description)
  cme_gn_import(${port} "${description}")
  cme_gn_export(${port})
endfunction()
