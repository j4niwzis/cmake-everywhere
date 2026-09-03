# Building a CMake project that will not be a subdirectory.
#
# Some libraries refuse to be added to another build, and libjpeg-turbo says
# so in as many words. The answer is not to argue with it and not to build it
# somewhere else and link the result: it is configured on its own, asked what
# it would build, and that is built here -- in the consumer's graph, with the
# consumer's generator, in parallel with everything else.
#
# The same shape as cmake/gn.cmake, and for the same reason: a build system
# describes a build far better than it can be guessed at.

include_guard(GLOBAL)

# Where the project is configured so that it can be asked. Nothing is built
# there; it exists to hold the answer and the headers the answer refers to.
function(cme_cmake_probe port source out_build)
  set(build "${CMAKE_BINARY_DIR}/_cme/${port}-probe")
  file(MAKE_DIRECTORY "${build}/.cmake/api/v1/query")
  # Asking is a file with the name of the question in it.
  file(TOUCH "${build}/.cmake/api/v1/query/codemodel-v2")

  set(arguments "-S" "${source}" "-B" "${build}" "-G" "${CMAKE_GENERATOR}")
  foreach(name CMAKE_TOOLCHAIN_FILE CMAKE_BUILD_TYPE CMAKE_C_COMPILER
               CMAKE_CXX_COMPILER CMAKE_C_FLAGS CMAKE_CXX_FLAGS CMAKE_SYSROOT
               CMAKE_MAKE_PROGRAM CMAKE_PREFIX_PATH CMAKE_CXX_STANDARD
               CMAKE_INTERPROCEDURAL_OPTIMIZATION)
    if(${name})
      list(APPEND arguments "-D${name}=${${name}}")
    endif()
  endforeach()
  list(APPEND arguments "-DBUILD_SHARED_LIBS=OFF"
                        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON")

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

  message(STATUS "cmake-everywhere: asking ${port} what it would build")
  execute_process(COMMAND ${CMAKE_COMMAND} ${arguments}
                  RESULT_VARIABLE code OUTPUT_VARIABLE output
                  ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: configuring ${port} to ask it failed\n${output}")
  endif()
  set(${out_build} "${build}" PARENT_SCOPE)
endfunction()

# The answer, as CMake data.
function(cme_cmake_describe port build out_description)
  find_package(Python3 QUIET COMPONENTS Interpreter)
  if(NOT Python3_EXECUTABLE)
    set(Python3_EXECUTABLE python3)
  endif()
  set(description "${build}/cme-targets.cmake")
  execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${CME_DIR}/cmake/cmake_import.py"
            "${build}" "${${port}_SOURCE_DIR}" "${description}"
    RESULT_VARIABLE code ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: cannot read what ${port} said\n${output}")
  endif()
  message(STATUS "cmake-everywhere: ${output}")
  set(${out_description} "${description}" PARENT_SCOPE)
endfunction()

# A link fragment as a target, when it names a file another target makes.
function(cme_cmake_resolve_link out port fragment paths owners)
  set(${out} "" PARENT_SCOPE)
  # A fragment can be a path, or -l, or a flag. Only the first two are links.
  string(STRIP "${fragment}" fragment)
  if(NOT fragment)
    return()
  endif()
  list(FIND paths "${fragment}" at)
  if(at GREATER_EQUAL 0)
    list(GET owners ${at} owner)
    set(${out} "${port}_${owner}" PARENT_SCOPE)
    return()
  endif()
  if(fragment MATCHES "^-l(.+)$")
    set(${out} "${CMAKE_MATCH_1}" PARENT_SCOPE)
    return()
  endif()
  if(fragment MATCHES "^-")
    return()
  endif()
  set(${out} "${fragment}" PARENT_SCOPE)
endfunction()

function(cme_cmake_import port description)
  include("${description}")

  cme_gn_link_map(${port} link_map)

  if(CMAKE_IMPORT_GENERATED_BY_TOOLS)
    list(JOIN CMAKE_IMPORT_GENERATED_BY_TOOLS ", " tools)
    message(STATUS
      "cmake-everywhere: ${port} generates part of itself with ${tools}, "
      "which is built here and run from where this build puts it")
  endif()

  # Every generated header, made before anything is compiled.
  #
  # A generated source is already a source of the target that compiles it,
  # so the graph waits for it. A generated header is a source of nothing:
  # the compile that includes it finds it or does not, depending on the
  # order two independent things happened in. One target that makes all of
  # them, that every imported target depends on, is what makes that order
  # the same every time.
  #
  # Only headers, because a command whose output nothing reads is a command
  # that does not have to run: several of libjpeg-turbo's make test images
  # with tools it builds for its own tests.
  set(generated "")
  if(CMAKE_IMPORT_COMMANDS GREATER 0)
    math(EXPR last "${CMAKE_IMPORT_COMMANDS} - 1")
    foreach(index RANGE ${last})
      foreach(output IN LISTS CMAKE_IMPORT_COMMAND${index}_OUTPUTS)
        if(output MATCHES "\\.(h|hh|hpp|hxx|inc|ipp|def)$")
          list(APPEND generated "${output}")
        endif()
      endforeach()
    endforeach()
  endif()
  if(generated)
    add_custom_target(${port}_generated DEPENDS ${generated})
  endif()

  # What cannot wait for what it makes.
  #
  # The barrier is every generated header, and everything imported waits
  # for it -- except the tool that writes them and everything that tool is
  # built from. Those are what the barrier waits for, and a thing cannot be
  # both sides of that: wayland-scanner is built from wayland-util, the
  # barrier is what wayland-scanner produces, and asking wayland-util to
  # wait for the barrier is a cycle CMake refuses to generate.
  set(making "${CMAKE_IMPORT_GENERATED_BY_TOOLS}")
  set(pending "${making}")
  while(pending)
    list(POP_FRONT pending one)
    string(REGEX REPLACE "[^A-Za-z0-9_]" "_" key "${one}")
    set(under "${CMAKE_IMPORT_${key}_DEPENDS}")
    foreach(fragment IN LISTS CMAKE_IMPORT_${key}_LINK)
      list(FIND CMAKE_IMPORT_ARTIFACT_PATHS "${fragment}" at)
      if(at GREATER_EQUAL 0)
        list(GET CMAKE_IMPORT_ARTIFACT_OWNERS ${at} owner)
        list(APPEND under "${owner}")
      endif()
    endforeach()
    foreach(dep IN LISTS under)
      if(NOT dep IN_LIST making)
        list(APPEND making "${dep}")
        list(APPEND pending "${dep}")
      endif()
    endforeach()
  endwhile()

  set(made "")
  foreach(name IN LISTS CMAKE_IMPORT_TARGETS)
    string(REGEX REPLACE "[^A-Za-z0-9_]" "_" key "${name}")
    set(prefix "CMAKE_IMPORT_${key}")
    set(target "${port}_${name}")
    set(type "${${prefix}_TYPE}")
    set(sources "${${prefix}_SOURCES}")

    # Assembly, given to the compiler this project gives it to.
    #
    # CMake picks a language by extension, so a .S among the sources is a
    # target compiled with a language the consumer never enabled, and the
    # generate step stops:
    #
    #   Missing variable is: CMAKE_ASM_COMPILE_OBJECT
    #
    # What the project's own build does -- and what the command lines read a
    # moment ago say -- is hand it to the C compiler, which knows an
    # assembler file when it sees one and preprocesses the capital-S ones.
    # Said here, on the files themselves, because a consumer cannot enable a
    # language for a library it has not looked inside.
    foreach(cme_source IN LISTS sources)
      if(cme_source MATCHES "[.]S$")
        # Given to the C compiler, and told what it is. Saying only the
        # language makes CMake write -x c, and then the C parser reads
        # ".arch armv8-a" and says what a C parser says about it: "expected
        # identifier or '('". The -x that comes last is the one that counts,
        # and this one is the source's own.
        set_source_files_properties("${cme_source}" PROPERTIES
          LANGUAGE C COMPILE_OPTIONS "-x;assembler-with-cpp")
      elseif(cme_source MATCHES "[.]s$")
        # The lower-case one is assembly that has already been through the
        # preprocessor, and saying so is how it stays that way.
        set_source_files_properties("${cme_source}" PROPERTIES
          LANGUAGE C COMPILE_OPTIONS "-x;assembler")
      endif()
    endforeach()

    if(type STREQUAL "STATIC_LIBRARY" OR type STREQUAL "SHARED_LIBRARY"
       OR type STREQUAL "MODULE_LIBRARY")
      if(NOT sources)
        continue()
      endif()
      add_library(${target} STATIC ${sources})
    elseif(type STREQUAL "OBJECT_LIBRARY")
      if(NOT sources)
        continue()
      endif()
      add_library(${target} OBJECT ${sources})
    elseif(type STREQUAL "EXECUTABLE")
      if(NOT sources)
        continue()
      endif()
      # Built only if something needs it, which is how a generator this
      # project runs gets built and nothing else does.
      add_executable(${target} EXCLUDE_FROM_ALL ${sources})
    elseif(type STREQUAL "INTERFACE_LIBRARY")
      add_library(${target} INTERFACE)
    else()
      continue()
    endif()
    list(APPEND made "${name}")
  endforeach()

  # The commands, after the targets they may run.
  #
  # A command that runs a tool this project builds is rewritten to run
  # the target that builds it, and a target has to exist before anything
  # can be said about it -- which is why this is here and not before the
  # loop above. Nothing else depends on the order: a source that is
  # generated is resolved against the commands of its directory when the
  # build files are written, not when it is named.
  #
  # Each is run the way the generator would have run it -- through a shell,
  # from the directory it was written for -- because that is what it was
  # written to be. Reproducing it any other way is guessing.
  if(CMAKE_IMPORT_COMMANDS GREATER 0)
    math(EXPR last "${CMAKE_IMPORT_COMMANDS} - 1")
    foreach(index RANGE ${last})
      set(outputs "${CMAKE_IMPORT_COMMAND${index}_OUTPUTS}")
      set(line "${CMAKE_IMPORT_COMMAND${index}_LINE}")
      if(NOT outputs OR NOT line)
        continue()
      endif()
      set(comment "${CMAKE_IMPORT_COMMAND${index}_DESC}")
      if(NOT comment)
        set(comment "${port}: generating")
      endif()

      # A command that runs a tool the project builds itself.
      #
      # wayland generates its protocol headers with wayland-scanner, which
      # is a target in the same project; Skia and half the world do the
      # same. The command names that tool by the path it would have had in
      # the build directory the description came from, where nothing is
      # built -- so the command as written runs a file that does not exist.
      # The tool is built here, under a name of this build's choosing, and
      # where that lands is only known when the build files are written:
      # which is what $<TARGET_FILE:...> is for.
      set(needs "")
      foreach(artifact IN LISTS CMAKE_IMPORT_ARTIFACT_PATHS)
        # Looked for as text rather than as a pattern: a path is not a
        # regular expression, and one with a + or a . in it is a different
        # one once it is read as one. What follows the match has to end it,
        # so that a target called foo does not match the path of foobar.
        string(FIND "${line}" "${artifact}" at_pos)
        if(at_pos LESS 0)
          continue()
        endif()
        string(LENGTH "${artifact}" artifact_length)
        string(LENGTH "${line}" line_length)
        math(EXPR after "${at_pos} + ${artifact_length}")
        if(after LESS line_length)
          string(SUBSTRING "${line}" ${after} 1 next)
          if(NOT next MATCHES "[ '\"]")
            continue()
          endif()
        endif()
        list(FIND CMAKE_IMPORT_ARTIFACT_PATHS "${artifact}" at)
        list(GET CMAKE_IMPORT_ARTIFACT_OWNERS ${at} owner)
        if(NOT TARGET ${port}_${owner})
          continue()
        endif()
        string(REPLACE "${artifact}" "$<TARGET_FILE:${port}_${owner}>"
               line "${line}")
        list(APPEND needs "${port}_${owner}")
      endforeach()
      if(needs)
        list(REMOVE_DUPLICATES needs)
      endif()

      # And the same file taken out of what the command waits for. It is
      # named there too, as the path in the directory the description came
      # from, and nothing makes a file at that path here: the target does,
      # somewhere else, which is what `needs` says.
      set(inputs "")
      foreach(input IN LISTS CMAKE_IMPORT_COMMAND${index}_INPUTS)
        list(FIND CMAKE_IMPORT_ARTIFACT_PATHS "${input}" at)
        if(at GREATER_EQUAL 0)
          list(GET CMAKE_IMPORT_ARTIFACT_OWNERS ${at} owner)
          if(TARGET ${port}_${owner})
            continue()
          endif()
        endif()
        list(APPEND inputs "${input}")
      endforeach()

      add_custom_command(
        OUTPUT ${outputs}
        COMMAND /bin/sh -c "${line}"
        DEPENDS ${inputs} ${needs}
        WORKING_DIRECTORY "${CMAKE_IMPORT_BUILD}"
        COMMENT "${comment}"
        VERBATIM)
    endforeach()
  endif()


  foreach(name IN LISTS made)
    string(REGEX REPLACE "[^A-Za-z0-9_]" "_" key "${name}")
    set(prefix "CMAKE_IMPORT_${key}")
    set(target "${port}_${name}")
    get_target_property(kind ${target} TYPE)

    # Flags belong to the target, not to the files.
    #
    # A source property in CMake belongs to a file in a directory, not to a
    # file in a target, and libjpeg-turbo compiles the same sources in
    # several targets with different defines -- one for eight-bit samples,
    # one for twelve, one for sixteen. Setting them per source put all three
    # on every file at once.
    #
    # So each group's flags go on the target that reported them, guarded by
    # the language when there is more than one. Within a target the groups
    # differ by language and not by file; when they do not, that is said out
    # loud rather than flattened silently.
    set(seen_languages "")
    math(EXPR last_group "${${prefix}_GROUPS} - 1")
    if(${prefix}_GROUPS GREATER 0)
      foreach(group RANGE ${last_group})
        set(language "${${prefix}_GROUP${group}_LANGUAGE}")
        if(language IN_LIST seen_languages)
          message(WARNING
            "cmake-everywhere: ${port}'s ${name} compiles ${language} more "
            "than one way, and this keeps only the union of the flags")
        endif()
        list(APPEND seen_languages "${language}")

        # A fragment can hold several flags in one string, and passing it on
        # as one is how -O3 -DNDEBUG became a single argument that no
        # compiler could read.
        set(flags "")
        foreach(fragment IN LISTS ${prefix}_GROUP${group}_FLAGS)
          separate_arguments(pieces UNIX_COMMAND "${fragment}")
          list(APPEND flags ${pieces})
        endforeach()

        if(kind STREQUAL "INTERFACE_LIBRARY")
          set(scope INTERFACE)
        else()
          set(scope PRIVATE)
        endif()
        foreach(flag IN LISTS flags)
          target_compile_options(${target} ${scope}
            "$<$<COMPILE_LANGUAGE:${language}>:SHELL:${flag}>")
        endforeach()
        foreach(define IN LISTS ${prefix}_GROUP${group}_DEFINES)
          target_compile_definitions(${target} ${scope}
            "$<$<COMPILE_LANGUAGE:${language}>:${define}>")
        endforeach()
        foreach(directory IN LISTS ${prefix}_GROUP${group}_INCLUDES)
          target_include_directories(${target} ${scope}
            "$<BUILD_INTERFACE:${directory}>")
        endforeach()
      endforeach()
    endif()

    if(kind STREQUAL "INTERFACE_LIBRARY")
      set(link_scope INTERFACE)
    else()
      set(link_scope PRIVATE)
    endif()
    # What it links, and what is known about the order.
    #
    # A description that says LINK_GROUP says which libraries belong
    # together and not what order the linker has to see them in -- meson
    # states what a static library is built against nowhere, so an archive
    # that needs a symbol from another archive can arrive after it. The
    # linker is told to rescan the set instead of being told an order that
    # was guessed. Whether it can is CMake's answer, not ours.
    set(grouped "")
    foreach(fragment IN LISTS ${prefix}_LINK)
      cme_cmake_resolve_link(resolved ${port} "${fragment}"
                             "${CMAKE_IMPORT_ARTIFACT_PATHS}"
                             "${CMAKE_IMPORT_ARTIFACT_OWNERS}")
      if(NOT resolved)
        continue()
      endif()
      if(NOT TARGET ${resolved})
        cme_gn_resolve_lib(resolved "${resolved}" "${link_map}")
      endif()
      if(${prefix}_LINK_GROUP AND TARGET ${resolved})
        list(APPEND grouped ${resolved})
      else()
        target_link_libraries(${target} ${link_scope} ${resolved})
      endif()
    endforeach()
    if(grouped)
      list(REMOVE_DUPLICATES grouped)
      list(LENGTH grouped count)
      set(feature "${${prefix}_LINK_GROUP}")
      if(count GREATER 1 AND CMAKE_LINK_GROUP_USING_${feature}_SUPPORTED)
        list(JOIN grouped "," inside)
        target_link_libraries(${target} ${link_scope}
                              "$<LINK_GROUP:${feature},${inside}>")
      else()
        target_link_libraries(${target} ${link_scope} ${grouped})
      endif()
    endif()

    if(generated AND NOT kind STREQUAL "INTERFACE_LIBRARY"
       AND NOT name IN_LIST making)
      add_dependencies(${target} ${port}_generated)
    endif()

    foreach(dependency IN LISTS ${prefix}_DEPENDS)
      set(other "${port}_${dependency}")
      if(NOT TARGET ${other})
        continue()
      endif()
      get_target_property(other_kind ${other} TYPE)
      # An object library is put into what depends on it, not linked to it.
      #
      # libjpeg-turbo compiles its NEON dispatch and its twelve-bit variant
      # as object libraries and writes $<TARGET_OBJECTS:...> into the
      # sources of the archive; the description lists them as targets of
      # their own and as dependencies. An order-only dependency builds them
      # and puts nothing anywhere, so the archive came out without
      # jsimd_idct_islow or j12init_1pass_quantizer in it, and said so at
      # the end of a link.
      if(other_kind STREQUAL "OBJECT_LIBRARY"
         AND NOT kind STREQUAL "INTERFACE_LIBRARY"
         AND NOT kind STREQUAL "OBJECT_LIBRARY")
        target_sources(${target} PRIVATE "$<TARGET_OBJECTS:${other}>")
      endif()
      add_dependencies(${target} ${other})
    endforeach()
  endforeach()
endfunction()

# What the port promises its consumers: "jpeg-static=JPEG::JPEG".
function(cme_cmake_export port)
  cme_port_field(exports ${port} IMPORT_TARGETS)
  foreach(pair IN LISTS exports)
    if(NOT pair MATCHES "^([^=]+)=(.+)$")
      message(FATAL_ERROR
        "cmake-everywhere: ${port} exports `${pair}`, which is not "
        "<target>=<CMake target>")
    endif()
    set(target "${port}_${CMAKE_MATCH_1}")
    if(NOT TARGET ${target})
      message(FATAL_ERROR
        "cmake-everywhere: ${port} says it produces ${CMAKE_MATCH_1}, and "
        "what it described has no such target")
    endif()
    cme_alias(${CMAKE_MATCH_2} ${target})
  endforeach()
endfunction()

function(cme_cmake_build port source)
  cme_cmake_probe(${port} "${source}" build)
  cme_cmake_describe(${port} "${build}" description)
  cme_cmake_import(${port} "${description}")
  cme_cmake_export(${port})
endfunction()
