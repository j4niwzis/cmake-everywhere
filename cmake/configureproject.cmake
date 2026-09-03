# A project that builds with its own configure script.
#
# The third kind, after "it is CMake" and "it can be described". FFmpeg has
# a configure script it wrote itself, libffi has autotools, and neither can
# be asked what it would build: there is no File API, no introspection, no
# JSON. What there is, is an install prefix -- so the project is built its
# own way, into a directory of this build's choosing, and what comes out is
# stated by the port as imported targets.
#
# That makes it the least of the three. Nothing here compiles in your graph,
# nothing takes your per-file flags, and a rebuild is the project's own idea
# of one. It is used where the alternative is not using the library.

include_guard(GLOBAL)

# The flags this build would compile with, as the strings a configure script
# reads them from.
function(cme_configure_environment out)
  set(pairs "")
  if(CMAKE_C_COMPILER)
    list(APPEND pairs "CC=${CMAKE_C_COMPILER}")
  endif()
  if(CMAKE_CXX_COMPILER)
    list(APPEND pairs "CXX=${CMAKE_CXX_COMPILER}")
  endif()
  set(c_flags "${CMAKE_C_FLAGS}")
  set(cxx_flags "${CMAKE_CXX_FLAGS}")
  # What linking here takes, which is the compile flags as well as the link
  # ones: a toolchain says where its runtime is with -resource-dir and hands
  # the linker its builtins by path, and both of those are compiler driver
  # flags that a link needs as much as a compile. Without them the first
  # program a configure script builds does not link, and what it reports is
  # a compiler that cannot create an executable.
  set(link_flags "${CMAKE_C_FLAGS} ${CMAKE_EXE_LINKER_FLAGS}")
  # Which machine this compiler is aimed at.
  #
  # CMake keeps that in CMAKE_C_COMPILER_TARGET and puts --target= on every
  # command line it writes itself. A script that is handed a compiler and a
  # set of flags writes its own command lines, so a triple that is not in
  # the flags is a triple that project never hears about: its first test
  # program is built for this machine, against a sysroot for another, and
  # what it reports is a compiler that cannot create an executable.
  if(CMAKE_C_COMPILER_TARGET)
    string(APPEND c_flags " --target=${CMAKE_C_COMPILER_TARGET}")
    string(APPEND link_flags " --target=${CMAKE_C_COMPILER_TARGET}")
  endif()
  if(CMAKE_CXX_COMPILER_TARGET)
    string(APPEND cxx_flags " --target=${CMAKE_CXX_COMPILER_TARGET}")
  endif()
  if(CMAKE_POSITION_INDEPENDENT_CODE)
    string(APPEND c_flags " -fPIC")
    string(APPEND cxx_flags " -fPIC")
  endif()
  if(CMAKE_SYSROOT)
    string(APPEND c_flags " --sysroot=${CMAKE_SYSROOT}")
    string(APPEND cxx_flags " --sysroot=${CMAKE_SYSROOT}")
    string(APPEND link_flags " --sysroot=${CMAKE_SYSROOT}")
  endif()
  list(APPEND pairs "CFLAGS=${c_flags}" "CXXFLAGS=${cxx_flags}"
                    "LDFLAGS=${link_flags}")
  set(${out} "${pairs}" PARENT_SCOPE)
endfunction()

# What a configure argument is written in terms of.
#
# The same idea as the GN ports: the port names its project's own spelling
# -- one wants --host, the next wants --arch and --target-os -- and asks for
# the values by placeholder, because only this side knows what the consumer
# is building with. A placeholder nothing can fill is not an empty string,
# it is a question nobody answered, so it stops here rather than reaching a
# shell script as an empty argument.
function(cme_configure_substitute out port value)
  string(TOLOWER "${CMAKE_SYSTEM_NAME}" system)
  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" processor)
  set(triple "${CMAKE_CXX_COMPILER_TARGET}")
  if(NOT triple)
    set(triple "${CMAKE_C_COMPILER_TARGET}")
  endif()
  # The flags this build compiles with, for a script that does not read
  # them from the environment. FFmpeg's configure says so outright: what is
  # in CFLAGS is ignored and --extra-cflags is where flags go. In a cross
  # build those flags are not decoration -- the target and the sysroot are
  # in them -- so without this its first test program does not link and the
  # script reports a compiler that cannot make an executable.
  cme_configure_environment(cme_said)
  set(cme_c_flags "")
  set(cme_cxx_flags "")
  set(cme_link_flags "")
  foreach(cme_pair IN LISTS cme_said)
    if(cme_pair MATCHES "^CFLAGS=(.*)$")
      set(cme_c_flags "${CMAKE_MATCH_1}")
    elseif(cme_pair MATCHES "^CXXFLAGS=(.*)$")
      set(cme_cxx_flags "${CMAKE_MATCH_1}")
    elseif(cme_pair MATCHES "^LDFLAGS=(.*)$")
      set(cme_link_flags "${CMAKE_MATCH_1}")
    endif()
  endforeach()
  string(REPLACE "@CFLAGS@" "${cme_c_flags}" value "${value}")
  string(REPLACE "@CXXFLAGS@" "${cme_cxx_flags}" value "${value}")
  string(REPLACE "@LDFLAGS@" "${cme_link_flags}" value "${value}")
  # And the tools that go with that compiler. A host ar can put aarch64
  # objects in an archive and a host strip cannot read one.
  string(REPLACE "@AR@" "${CMAKE_AR}" value "${value}")
  string(REPLACE "@RANLIB@" "${CMAKE_RANLIB}" value "${value}")
  string(REPLACE "@NM@" "${CMAKE_NM}" value "${value}")
  string(REPLACE "@STRIP@" "${CMAKE_STRIP}" value "${value}")
  string(REPLACE "@CC@" "${CMAKE_C_COMPILER}" value "${value}")
  string(REPLACE "@CXX@" "${CMAKE_CXX_COMPILER}" value "${value}")
  string(REPLACE "@SYSROOT@" "${CMAKE_SYSROOT}" value "${value}")
  string(REPLACE "@TRIPLE@" "${triple}" value "${value}")
  string(REPLACE "@TARGET_CPU@" "${processor}" value "${value}")
  string(REPLACE "@TARGET_OS_LOWER@" "${system}" value "${value}")
  string(REPLACE "@CROSS_PREFIX@" "${CME_CROSS_PREFIX}" value "${value}")
  # The compiler of the machine doing the building, for a project that needs
  # one during a cross build: FFmpeg compiles and runs generators of its own
  # to write tables. Its default is gcc, and a machine that has a compiler
  # but not that one is a configure that stops with "Host compiler lacks C11
  # support" -- a true sentence about a compiler that is not there.
  set(cme_build_machine_cc "${CME_BUILD_MACHINE_C_COMPILER}")
  if(NOT cme_build_machine_cc)
    set(cme_build_machine_cc "cc")
  endif()
  string(REPLACE "@BUILD_MACHINE_CC@" "${cme_build_machine_cc}" value
         "${value}")
  if(value MATCHES "@([A-Z_]+)@")
    message(FATAL_ERROR
      "cmake-everywhere: ${port} asks for @${CMAKE_MATCH_1}@ in a configure "
      "argument and nothing here answers it. A cross build has to be told "
      "what to tell the script; CME_CROSS_PREFIX is where the prefix of a "
      "toolchain goes.")
  endif()
  set(${out} "${value}" PARENT_SCOPE)
endfunction()

# What the port says comes out, as targets pointing into the prefix.
function(cme_configure_export port entry)
  cme_port_field(includes ${port} INSTALLED_INCLUDE)
  if(NOT includes)
    set(includes "include")
  endif()
  cme_port_field(exports ${port} INSTALLED_TARGETS)
  foreach(pair IN LISTS exports)
    if(NOT pair MATCHES "^([^=]+)=(.+)$")
      message(FATAL_ERROR
        "cmake-everywhere: ${port} says INSTALLED_TARGETS `${pair}`, which "
        "is not <path in the prefix>=<CMake target>")
    endif()
    set(file "${entry}/${CMAKE_MATCH_1}")
    set(target "${CMAKE_MATCH_2}")
    if(NOT EXISTS "${file}")
      message(FATAL_ERROR
        "cmake-everywhere: ${port} says it installs ${CMAKE_MATCH_1}, and "
        "after building it there is no such file in ${entry}")
    endif()
    if(TARGET ${target})
      continue()
    endif()
    add_library(${target} STATIC IMPORTED GLOBAL)
    set_target_properties(${target} PROPERTIES IMPORTED_LOCATION "${file}")
    foreach(one IN LISTS includes)
      set_property(TARGET ${target} APPEND PROPERTY
                   INTERFACE_INCLUDE_DIRECTORIES "${entry}/${one}")
    endforeach()
  endforeach()
endfunction()

# What make would do, as CMake targets.
#
# The configure script still runs -- it is what writes config.h and decides
# what this build of the project is -- and then make is asked what it would
# do rather than told to do it. Every compile it prints becomes a source in
# this build's graph, with the flags it printed, compiled by this build's
# generator: ninja, in parallel with everything else, through the compiler
# cache, rebuilt when the file changes and not when make thinks so.
#
# A command that is not a compile or an archive is not guessed at. It is
# counted and said out loud, and a project whose build is more than
# compiles and archives is one to build with CONFIGURE instead.
function(cme_configure_import port build)
  find_program(CME_MAKE NAMES gmake make)
  if(NOT CME_MAKE)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} is built by make, and what it would do is "
      "read by running it. There is no make here.")
  endif()
  find_package(Python3 QUIET COMPONENTS Interpreter)
  if(NOT Python3_EXECUTABLE)
    set(Python3_EXECUTABLE python3)
  endif()
  set(dry "${build}/cme-make-dry-run.txt")
  execute_process(
    COMMAND "${CME_MAKE}" "-n" "--no-print-directory" "V=1"
    WORKING_DIRECTORY "${build}"
    RESULT_VARIABLE code OUTPUT_FILE "${dry}" ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: asking ${port}'s make what it would do failed\n"
      "${output}")
  endif()
  set(description "${build}/cme-targets.cmake")
  execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${CME_DIR}/cmake/make_import.py"
            "${dry}" "${build}" "${description}"
    RESULT_VARIABLE code ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: cannot read what ${port}'s make said\n${output}")
  endif()
  message(STATUS "cmake-everywhere: ${output}")
  cme_cmake_import(${port} "${description}")
  cme_cmake_export(${port})
endfunction()

# The configure step, which is what writes config.h: the same for a project
# that is then made and installed and one whose make is read instead.
function(cme_configure_configure port source build prefix)
  if(CMAKE_CROSSCOMPILING)
    cme_port_field(cross ${port} CONFIGURE_CROSS)
    if(NOT cross)
      message(FATAL_ERROR
        "cmake-everywhere: ${port} builds with its own configure script and "
        "this build is a cross build. How to tell that script which machine "
        "it is building for is the script's own business, so the port has "
        "to say it in CONFIGURE_CROSS.")
    endif()
  endif()

  cme_port_field(script ${port} CONFIGURE)
  if(script STREQUAL "YES" OR NOT script)
    set(script "configure")
  endif()
  if(NOT EXISTS "${source}/${script}")
    message(FATAL_ERROR
      "cmake-everywhere: ${port} says it is built by ${script}, and there is "
      "no such file in ${source}")
  endif()

  file(MAKE_DIRECTORY "${build}")

  cme_port_field(arguments ${port} CONFIGURE_ARGS)
  cme_enabled_features(${port} features)
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} CONFIGURE_ARGS)
    list(APPEND arguments ${extra})
  endforeach()
  if(CMAKE_CROSSCOMPILING)
    cme_port_field(cross ${port} CONFIGURE_CROSS)
    list(APPEND arguments ${cross})
  endif()
  set(filled "")
  foreach(argument IN LISTS arguments)
    cme_configure_substitute(one ${port} "${argument}")
    list(APPEND filled "${one}")
  endforeach()
  set(arguments "${filled}")
  cme_configure_environment(environment)

  message(STATUS "cmake-everywhere: building ${port} with its own configure")
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env ${environment}
            "${source}/${script}" "--prefix=${prefix}" ${arguments}
    WORKING_DIRECTORY "${build}"
    RESULT_VARIABLE code OUTPUT_VARIABLE output ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    # What the script wrote down, which is where the reason is. "unable to
    # create an executable file" is the summary; the command it ran and what
    # the compiler said about it are in the log.
    set(cme_said "")
    foreach(cme_log "${build}/config.log" "${build}/ffbuild/config.log")
      if(EXISTS "${cme_log}")
        # The beginning and the end of it. Autotools puts what failed at
        # the end of its log; FFmpeg puts the command it ran and what the
        # compiler said at the beginning and then dumps every variable it
        # knows, so the end of that one is an alphabet of settings.
        file(STRINGS "${cme_log}" cme_lines)
        list(LENGTH cme_lines cme_count)
        set(cme_head "${cme_lines}")
        if(cme_count GREATER 40)
          list(SUBLIST cme_lines 0 40 cme_head)
        endif()
        list(JOIN cme_head "\n" cme_head)
        math(EXPR cme_from "${cme_count} - 20")
        if(cme_from LESS 0)
          set(cme_from 0)
        endif()
        list(SUBLIST cme_lines ${cme_from} -1 cme_lines)
        list(JOIN cme_lines "\n" cme_tail)
        string(APPEND cme_said
               "\nthe first of ${cme_log}:\n${cme_head}"
               "\nand the last of it:\n${cme_tail}")
      endif()
    endforeach()
    message(FATAL_ERROR
      "cmake-everywhere: ${port}'s configure failed\n${output}${cme_said}")
  endif()
endfunction()

# Configured, made and installed: the whole project as its own build sees
# it, with an archive at the end that this build imports as a file.
function(cme_configure_build port source entry)
  if(EXISTS "${entry}/complete")
    message(STATUS "cmake-everywhere: ${port} is already built")
    cme_configure_export(${port} "${entry}")
    return()
  endif()
  set(build "${CMAKE_BINARY_DIR}/_cme/${port}-build")
  cme_configure_configure(${port} "${source}" "${build}" "${entry}")

  find_program(CME_MAKE NAMES gmake make)
  if(NOT CME_MAKE)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} builds with make, and there is none here")
  endif()
  include(ProcessorCount)
  ProcessorCount(cores)
  if(cores EQUAL 0)
    set(cores 1)
  endif()
  foreach(what "" "install")
    execute_process(COMMAND "${CME_MAKE}" "-j${cores}" ${what}
                    WORKING_DIRECTORY "${build}"
                    RESULT_VARIABLE code
                    OUTPUT_VARIABLE output ERROR_VARIABLE output)
    if(NOT code EQUAL 0)
      message(FATAL_ERROR
        "cmake-everywhere: making ${port} ${what} failed\n${output}")
    endif()
  endforeach()

  cme_environment_pairs(pairs)
  list(JOIN pairs "\n" recorded)
  file(WRITE "${entry}/environment.txt" "${recorded}\n")
  file(TOUCH "${entry}/complete")
  cme_configure_export(${port} "${entry}")
  cme_note_decision("${port}" "built by its own configure" "")
endfunction()

# Configured, and then asked what it would make.
function(cme_configure_make_build port source)
  set(build "${CMAKE_BINARY_DIR}/_cme/${port}-build")
  cme_configure_configure(${port} "${source}" "${build}"
                          "${CMAKE_BINARY_DIR}/_cme/${port}-unused-prefix")
  cme_configure_import(${port} "${build}")
endfunction()
