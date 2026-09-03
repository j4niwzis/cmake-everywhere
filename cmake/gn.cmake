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

# Whether a file called gn is gn.
#
# depot_tools ships a shell script by that name which bootstraps a real one
# on first use, and until it has been bootstrapped it exits saying so. A gn
# that cannot answer --version cannot generate a build either, and finding
# that out from `gn gen` means reading a page of this port's arguments to
# learn something about the tool.
function(cme_gn_works out gn why)
  execute_process(COMMAND "${gn}" --version
                  RESULT_VARIABLE code
                  OUTPUT_VARIABLE output ERROR_VARIABLE output)
  if(code EQUAL 0)
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
    set(${why} "${output}" PARENT_SCOPE)
  endif()
endfunction()

function(cme_gn_find out)
  if(CME_GN)
    set(found "${CME_GN}")
  else()
    find_program(found NAMES gn)
    if(NOT found)
      message(FATAL_ERROR
        "cmake-everywhere: this port is a GN project and gn is not on PATH. "
        "Install it, or pass -DCME_GN=/path/to/gn.")
    endif()
  endif()
  cme_gn_works(usable "${found}" why)
  if(NOT usable)
    message(FATAL_ERROR
      "cmake-everywhere: this port is a GN project and ${found} is not a gn "
      "that runs:\n${why}"
      "Install one, or pass -DCME_GN=/path/to/gn.")
  endif()
  set(${out} "${found}" PARENT_SCOPE)
endfunction()

# The values a port's GN arguments are written in terms of. A port names its
# project's own argument spellings -- one calls the compiler cc, the next
# calls it clang_path -- and asks for these by placeholder, because only this
# side knows what the consumer is building with.
# A placeholder that resolves to nothing is not an empty setting, it is a
# question nobody answered. Passing it on gets an error from the project
# being described, about its own internals, several steps away from the
# reason -- cc="" reaches GN as a compiler it then tries to run.
function(cme_gn_needed name value why)
  if(NOT value)
    message(FATAL_ERROR
      "cmake-everywhere: a port asks for @${name}@ and there is nothing to "
      "put there. ${why}")
  endif()
endfunction()

function(cme_gn_substitute out text)
  set(value "${text}")
  if(value MATCHES "@CC@")
    cme_gn_needed(CC "${CMAKE_C_COMPILER}"
      "No C compiler is configured. A project that says LANGUAGES CXX has "
      "none; most projects described by GN need both, so say LANGUAGES C CXX.")
  endif()
  if(value MATCHES "@CXX@")
    cme_gn_needed(CXX "${CMAKE_CXX_COMPILER}"
      "No C++ compiler is configured. Add CXX to the project's LANGUAGES.")
  endif()
  if(value MATCHES "@AR@")
    cme_gn_needed(AR "${CMAKE_AR}"
      "CMAKE_AR is empty, which happens when no language is enabled at all.")
  endif()
  string(REPLACE "@CC@" "${CMAKE_C_COMPILER}" value "${value}")
  string(REPLACE "@CXX@" "${CMAKE_CXX_COMPILER}" value "${value}")
  string(REPLACE "@AR@" "${CMAKE_AR}" value "${value}")
  # Empty when there is none, which is what a project's own default for this
  # is anyway.
  if(CME_COMPILER_CACHE STREQUAL "OFF")
    string(REPLACE "@CC_WRAPPER@" "" value "${value}")
  else()
    string(REPLACE "@CC_WRAPPER@" "${CME_COMPILER_CACHE}" value "${value}")
  endif()
  string(REPLACE "@SYSROOT@" "${CMAKE_SYSROOT}" value "${value}")
  string(REPLACE "@PREFIX@" "${CMAKE_INSTALL_PREFIX}" value "${value}")
  string(REPLACE "@BUILD_TYPE@" "${CMAKE_BUILD_TYPE}" value "${value}")
  # A GN project has its own name for link-time optimisation and its own
  # default, so the port says which; this only answers whether.
  if(CMAKE_INTERPROCEDURAL_OPTIMIZATION)
    string(REPLACE "@LTO@" "true" value "${value}")
  else()
    string(REPLACE "@LTO@" "false" value "${value}")
  endif()
  string(REPLACE "@SOURCE_DIR@" "${CME_GN_SOURCE_DIR}" value "${value}")
  string(REPLACE "@DEP_INCLUDES@" "${CME_GN_DEP_INCLUDES}" value "${value}")
  # @INCLUDE:port@ -- where one dependency's headers are, as a path. A
  # project that takes an include directory as an argument rather than as a
  # flag needs one of these, and giving it nothing means it keeps its own
  # default, which is usually /usr/include/something.
  while(value MATCHES "@INCLUDE:([A-Za-z0-9_.+-]+)@")
    cme_gn_include_dir(directory "${CMAKE_MATCH_1}")
    string(REPLACE "@INCLUDE:${CMAKE_MATCH_1}@" "${directory}" value "${value}")
  endwhile()
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
function(cme_gn_confirm gn root build name expected)
  # --root, because gn finds the source tree by walking up from where it is
  # run and this is not run from there. And the error is kept: a message that
  # says a command failed without saying what it said is a message that costs
  # somebody the round trip of asking.
  execute_process(
    COMMAND "${gn}" args "${build}" "--root=${root}" "--list=${name}" --short
    WORKING_DIRECTORY "${root}"
    OUTPUT_VARIABLE output ERROR_VARIABLE failure RESULT_VARIABLE code
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: gn cannot report ${name}\n${failure}")
  endif()
  string(REGEX REPLACE "\n.*" "" first "${output}")
  string(STRIP "${first}" first)
  if(NOT first STREQUAL "${name} = ${expected}")
    message(FATAL_ERROR
      "cmake-everywhere: gn reports `${first}`, not `${name} = ${expected}`")
  endif()
endfunction()

# Every port this one depends on, including the ones a feature brought.
function(cme_gn_dependency_ports port out)
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

# Where a port's headers are according to what it built, rather than to what
# it said.
#
# What a port exports is what a Find module would have set, and a library
# that came from the machine exports nothing here: a distribution's
# freetype-config.cmake defines a target and no variables at all, and CMake's
# own FindFreetype sets its variables in the scope of whoever asked. The
# target is the other place the headers are written down, and it is the same
# directory the compiler would be given.
function(cme_gn_target_includes out port)
  set(found "")
  cme_port_field(targets ${port} TARGETS)
  foreach(target IN LISTS targets)
    if(NOT TARGET ${target})
      continue()
    endif()
    get_target_property(aliased ${target} ALIASED_TARGET)
    if(aliased)
      set(target "${aliased}")
    endif()
    get_target_property(directories ${target} INTERFACE_INCLUDE_DIRECTORIES)
    if(NOT directories)
      continue()
    endif()
    foreach(directory IN LISTS directories)
      # A generator expression is not a directory. The one that carries one
      # is $<BUILD_INTERFACE:...>, which is the directory to use while
      # building against the target -- which is what this is.
      if(directory MATCHES "^\\$<BUILD_INTERFACE:(.+)>$")
        set(directory "${CMAKE_MATCH_1}")
      elseif(directory MATCHES "^\\$<")
        continue()
      endif()
      if(IS_DIRECTORY "${directory}")
        list(APPEND found "${directory}")
      endif()
    endforeach()
  endforeach()
  if(found)
    list(REMOVE_DUPLICATES found)
  endif()
  set(${out} "${found}" PARENT_SCOPE)
endfunction()

# Where the libraries this port depends on ended up. A project told to use
# the system's zlib looks for it on the compiler's search path, and a zlib
# this registry built for it is on no such path -- so the port asks for these
# and puts them in the project's own spelling of extra flags.
function(cme_gn_dependency_flags port out_includes out_libdirs)
  set(includes "")
  set(libdirs "")
  cme_gn_dependency_ports(${port} deps)
  foreach(dep IN LISTS deps)
    cme_port_field(names ${dep} PROVIDES)
    list(GET names 0 package)
    string(TOUPPER "${package}" upper)
    get_property(exported GLOBAL PROPERTY CME_EXPORT_${package})
    set(said "")
    while(exported)
      list(POP_FRONT exported name value)
      string(REPLACE "@CME@" ";" value "${value}")
      if(name STREQUAL "${upper}_INCLUDE_DIRS" OR
         name STREQUAL "${package}_INCLUDE_DIRS")
        list(APPEND said ${value})
      elseif(name STREQUAL "${upper}_LIBRARY_DIRS" OR
             name STREQUAL "${package}_LIBRARY_DIRS")
        list(APPEND libdirs ${value})
      endif()
    endwhile()
    if(NOT said)
      cme_gn_target_includes(said ${dep})
    endif()
    list(APPEND includes ${said})
  endforeach()
  if(includes)
    list(REMOVE_DUPLICATES includes)
  endif()
  if(libdirs)
    list(REMOVE_DUPLICATES libdirs)
  endif()
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

# The first include directory of one port, by name.
function(cme_gn_include_dir out port)
  cme_port_field(names ${port} PROVIDES)
  if(NOT names)
    message(FATAL_ERROR
      "cmake-everywhere: a port asks for @INCLUDE:${port}@ and there is no "
      "port called ${port}")
  endif()
  list(GET names 0 package)
  string(TOUPPER "${package}" upper)
  get_property(exported GLOBAL PROPERTY CME_EXPORT_${package})
  set(found "")
  while(exported)
    list(POP_FRONT exported name value)
    string(REPLACE "@CME@" ";" value "${value}")
    if(NOT found AND (name STREQUAL "${upper}_INCLUDE_DIRS" OR
                      name STREQUAL "${package}_INCLUDE_DIRS" OR
                      name STREQUAL "${upper}_INCLUDE_DIR" OR
                      name STREQUAL "${package}_INCLUDE_DIR"))
      list(GET value 0 found)
    endif()
  endwhile()

  if(NOT found)
    cme_gn_target_includes(directories ${port})
    if(directories)
      list(GET directories 0 found)
    endif()
  endif()

  if(NOT found)
    cme_port_field(targets ${port} TARGETS)
    message(FATAL_ERROR
      "cmake-everywhere: @INCLUDE:${port}@ was asked for and ${port} has "
      "not said where its headers are, in ${upper}_INCLUDE_DIRS or on any "
      "of its targets (${targets}).")
  endif()
  set(${out} "${found}" PARENT_SCOPE)
endfunction()

# What a bare library name means here.
#
# A project told to use the system's libpng ends up asking the linker for
# -lpng, and the linker answers with whatever it finds -- which on a machine
# that has libpng installed is the system's copy, headers from this build and
# library from somewhere else. Worse, it is silent.
#
# So a port says what it answers to -- LINK_NAMES "png=PNG::PNG" -- and a
# bare name that matches becomes the target instead. A target is an archive
# with a path, and a path cannot be mistaken for something else.
function(cme_gn_link_map port out)
  set(map "")
  cme_gn_dependency_ports(${port} deps)
  foreach(dep IN LISTS deps)
    cme_port_field(pairs ${dep} LINK_NAMES)
    list(APPEND map ${pairs})
  endforeach()
  set(${out} "${map}" PARENT_SCOPE)
endfunction()

function(cme_gn_resolve_lib out name map)
  foreach(pair IN LISTS map)
    if(NOT pair MATCHES "^([^=]+)=(.+)$")
      continue()
    endif()
    # Read out of the match before anything else is asked. A command's
    # arguments are expanded before it runs, so ${CMAKE_MATCH_1} written
    # inside the same if() as the MATCHES that sets it is the match from the
    # iteration before -- which is how every library name here resolved to
    # the target of the pair after the one that named it. png and jpeg
    # survived that: their ports name two spellings each, both meaning the
    # same target, so the pair after "png=PNG::PNG" is "png16=PNG::PNG".
    # freetype names one, so it resolved to whatever port came next.
    set(key "${CMAKE_MATCH_1}")
    set(value "${CMAKE_MATCH_2}")
    if(key STREQUAL name AND TARGET ${value})
      set(${out} "${value}" PARENT_SCOPE)
      return()
    endif()
  endforeach()
  set(${out} "${name}" PARENT_SCOPE)
endfunction()

# A tree that expects to run gn itself, from a path inside itself. Skia does:
# it normally downloads one into bin/gn, and a step of its own build runs that
# to ask what the build contains. The gn this configure is using is put there
# instead of a second copy being fetched -- as a link, so it is plainly the
# same one.
function(cme_gn_place gn port source)
  cme_port_field(places ${port} GN_IN_TREE)
  foreach(where IN LISTS places)
    if(EXISTS "${source}/${where}")
      continue()
    endif()
    get_filename_component(directory "${source}/${where}" DIRECTORY)
    file(MAKE_DIRECTORY "${directory}")
    file(CREATE_LINK "${gn}" "${source}/${where}" SYMBOLIC RESULT status)
    if(NOT status STREQUAL "0")
      message(FATAL_ERROR
        "cmake-everywhere: ${port} runs gn from ${where} inside its own tree, "
        "and it could not be put there: ${status}")
    endif()
    message(STATUS "cmake-everywhere: ${port} runs gn from ${where}")
  endforeach()
endfunction()

function(cme_gn_generate port source build out_description)
  cme_gn_find(gn)
  cme_gn_place("${gn}" ${port} "${source}")
  set(CME_GN_SOURCE_DIR "${source}")
  cme_gn_dependency_flags(${port} CME_GN_DEP_INCLUDES CME_GN_DEP_LIBDIRS)

  cme_port_field(raw ${port} GN_ARGS)
  # A feature is a set of arguments to the project's own build, so this is
  # where "skia with Vulkan" becomes skia_use_vulkan=true.
  cme_enabled_features(${port} features)
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} GN_ARGS)
    list(APPEND raw ${extra})
  endforeach()
  if(CME_GN_ARGS_${port})
    list(APPEND raw ${CME_GN_ARGS_${port}})
  endif()
  set(arguments "")
  foreach(argument IN LISTS raw)
    cme_gn_substitute(substituted "${argument}")
    list(APPEND arguments "${substituted}")
  endforeach()
  list(JOIN arguments " " argument_line)

  # gn reads what a project is from a dotfile at its root, and when it
  # cannot read it says only that. Every tree that builds with gn has one,
  # so a checkout without it is not that tree -- an extraction that did not
  # finish, or a directory something else has been at.
  if(NOT EXISTS "${source}/.gn")
    message(FATAL_ERROR
      "cmake-everywhere: ${port} is at ${source} and there is no .gn there. "
      "That is the file gn reads a project from, and it is in the archive "
      "this was unpacked from, so what is there is not a whole checkout. "
      "Remove that directory and configure again.")
  endif()

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
  cme_enabled_features(${port} features)
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} GN_CONFIRM)
    list(APPEND confirm ${extra})
  endforeach()
  foreach(pair IN LISTS confirm)
    if(pair MATCHES "^([^=]+)=(.*)$")
      cme_gn_confirm("${gn}" "${source}" "${build}" "${CMAKE_MATCH_1}"
                     "${CMAKE_MATCH_2}")
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
  cme_gn_link_map(${port} link_map)

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
      # A library name is not a compile flag, and it is what a group carries.
      # Skia describes a system library as system("freetype2"), which is a
      # group whose public config holds libs = [ "freetype" ] -- so dropping
      # libs for interface libraries dropped every system library there is,
      # silently, and the link failed at the end with no freetype in it.
      if(${prefix}_LIB_DIRS)
        target_link_directories(${target} ${scope} ${${prefix}_LIB_DIRS})
      endif()
      foreach(library IN LISTS ${prefix}_LIBS)
        cme_gn_resolve_lib(resolved "${library}" "${link_map}")
        if(NOT resolved STREQUAL library)
          message(DEBUG "cmake-everywhere: -l${library} is ${resolved}")
        endif()
        target_link_libraries(${target} ${scope} ${resolved})
      endforeach()

      # The per-file flags are the reason to take GN's word for this: a
      # project like Skia compiles its vector code with flags that differ
      # from one translation unit to the next, and guessing them wrong is a
      # miscompile rather than an error.
      foreach(flag IN LISTS ${prefix}_CFLAGS)
        target_compile_options(${target} ${scope} "SHELL:${flag}")
      endforeach()
      if(NOT kind STREQUAL "INTERFACE_LIBRARY")
        foreach(flag IN LISTS ${prefix}_CFLAGS_C)
          target_compile_options(${target} PRIVATE
            "$<$<COMPILE_LANGUAGE:C>:SHELL:${flag}>")
        endforeach()
        foreach(flag IN LISTS ${prefix}_CFLAGS_CC)
          target_compile_options(${target} PRIVATE
            "$<$<COMPILE_LANGUAGE:CXX>:SHELL:${flag}>")
        endforeach()
      endif()
      if(${prefix}_LDFLAGS AND NOT kind STREQUAL "OBJECT_LIBRARY")
        # On a static library these belong to whoever links it, not to a
        # link step it does not have.
        if(kind STREQUAL "STATIC_LIBRARY" OR kind STREQUAL "INTERFACE_LIBRARY")
          target_link_options(${target} INTERFACE ${${prefix}_LDFLAGS})
        else()
          target_link_options(${target} PRIVATE ${${prefix}_LDFLAGS})
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

    # A GN source_set is not a CMake object library.
    #
    # In GN the objects of a source_set go to whatever finally links,
    # however deep the chain: a static_library that depends on a source_set
    # that depends on another source_set contains all of it. CMake says the
    # opposite in as many words -- the object files of a directly linked
    # object library are used, and "those object files are not transitively
    # propagated to consumers of the left-hand-side target".
    #
    # So Skia's //:skia got the objects of :gpu, which is a source_set, and
    # not those of :gpu_shared one dep further down, and the program ended
    # with undefined references inside Skia to Skia. What a group carries --
    # a system library, in Skia's case freetype -- was lost the same way,
    # for the same distance.
    #
    # Everything under a target that links, through source_sets and groups,
    # is therefore linked into it directly. The walk stops at anything that
    # is an archive of its own, which is linked the ordinary way and brings
    # what is under it along.
    if(kind STREQUAL "STATIC_LIBRARY" OR kind STREQUAL "SHARED_LIBRARY"
       OR kind STREQUAL "EXECUTABLE")
      set(pending "${${prefix}_DEPS}")
      set(seen "")
      while(pending)
        list(POP_FRONT pending current)
        if(current IN_LIST seen)
          continue()
        endif()
        list(APPEND seen "${current}")
        set(under "GN_TARGET_${current}")
        set(under_type "${${under}_TYPE}")
        if(NOT under_type STREQUAL "source_set"
           AND NOT under_type STREQUAL "group")
          continue()
        endif()
        if(TARGET ${port}_${current})
          get_target_property(under_kind ${port}_${current} TYPE)
          if(NOT under_kind STREQUAL "UTILITY")
            target_link_libraries(${target} PRIVATE ${port}_${current})
          endif()
        endif()
        list(APPEND pending ${${under}_DEPS})
      endwhile()
    endif()
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

# What a built copy of a GN project looks like in the store: the archives it
# produced, and a file describing how to use them. The description is written
# while the real targets exist, because that is when what to say is known;
# the archives arrive at the end of the build, and the entry counts as
# present only when they have. An interrupted build therefore leaves an entry
# that is not used rather than one that is half true.
# A GN label as the target name it was imported under. The same rule as
# gn_import.py, because the two have to agree.
function(cme_gn_target_name out label)
  string(REGEX REPLACE "\\(.*$" "" name "${label}")
  string(REGEX REPLACE "^//" "" name "${name}")
  string(REGEX REPLACE "^:" "" name "${name}")
  string(REGEX REPLACE ":" "__" name "${name}")
  string(REGEX REPLACE "[^A-Za-z0-9_]" "_" name "${name}")
  if(NOT name)
    set(name "root")
  endif()
  set(${out} "${name}" PARENT_SCOPE)
endfunction()

function(cme_gn_build port source)
  # Inside the fetched tree because GN speaks in paths relative to its own
  # source root, and a build directory outside it has no spelling there. The
  # store is looked at before this is reached, by whoever asked for the port.
  set(build "${source}/out/cme")
  cme_gn_generate(${port} "${source}" "${build}" description)
  cme_gn_import(${port} "${description}")
  cme_gn_export(${port})
endfunction()
