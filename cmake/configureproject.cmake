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
  # Including what the build type adds: the tuning a project asked for is in
  # the per-configuration flags, and a library built without them is built
  # differently from everything that links it.
  string(TOUPPER "${CMAKE_BUILD_TYPE}" cme_configuration)
  set(c_flags "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${cme_configuration}}")
  set(cxx_flags "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${cme_configuration}}")
  # What linking here takes, which is the compile flags as well as the link
  # ones: a toolchain says where its runtime is with -resource-dir and hands
  # the linker its builtins by path, and both of those are compiler driver
  # flags that a link needs as much as a compile. Without them the first
  # program a configure script builds does not link, and what it reports is
  # a compiler that cannot create an executable.
  set(link_flags
      "${c_flags} ${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_EXE_LINKER_FLAGS_${cme_configuration}}")
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

# Where the libraries this port was built against are, for a script that
# looks for them on the machine.
#
# FFmpeg asked for libx264 the only way its configure knows -- pkg-config,
# or a header and a library on the compiler's own paths -- and a library
# this build just built is on neither. What answers that is the same thing
# the GN ports are handed: the include and library directories of what this
# port depends on, as flags.
function(cme_configure_dependency_flags port out_cflags out_ldflags)
  cme_gn_dependency_ports(${port} cme_deps)
  set(cme_includes "")
  set(cme_libdirs "")
  foreach(cme_dep IN LISTS cme_deps)
    cme_port_field(cme_names ${cme_dep} PROVIDES)
    list(GET cme_names 0 cme_package)
    string(TOUPPER "${cme_package}" cme_upper)
    get_property(cme_exported GLOBAL PROPERTY CME_EXPORT_${cme_package})
    while(cme_exported)
      list(POP_FRONT cme_exported cme_name cme_value)
      string(REPLACE "@CME@" ";" cme_value "${cme_value}")
      if(cme_name STREQUAL "${cme_upper}_INCLUDE_DIRS" OR
         cme_name STREQUAL "${cme_package}_INCLUDE_DIRS")
        list(APPEND cme_includes ${cme_value})
      endif()
    endwhile()
    cme_port_field(cme_targets ${cme_dep} TARGETS)
    foreach(cme_target IN LISTS cme_targets)
      if(NOT TARGET ${cme_target})
        continue()
      endif()
      get_target_property(cme_aliased ${cme_target} ALIASED_TARGET)
      if(cme_aliased)
        set(cme_target "${cme_aliased}")
      endif()
      get_target_property(cme_kind ${cme_target} TYPE)
      if(cme_kind STREQUAL "STATIC_LIBRARY" OR cme_kind STREQUAL "SHARED_LIBRARY")
        # Where the archive will be, which is where this build puts what it
        # builds rather than anywhere a script would look.
        list(APPEND cme_libdirs "$<TARGET_FILE_DIR:${cme_target}>")
      endif()
      get_target_property(cme_dirs ${cme_target} INTERFACE_INCLUDE_DIRECTORIES)
      foreach(cme_dir IN LISTS cme_dirs)
        if(cme_dir MATCHES "^\\$<BUILD_INTERFACE:(.+)>$")
          list(APPEND cme_includes "${CMAKE_MATCH_1}")
        elseif(NOT cme_dir MATCHES "^\\$<")
          list(APPEND cme_includes "${cme_dir}")
        endif()
      endforeach()
    endforeach()
  endforeach()
  if(cme_includes)
    list(REMOVE_DUPLICATES cme_includes)
  endif()
  if(cme_libdirs)
    list(REMOVE_DUPLICATES cme_libdirs)
  endif()
  set(cme_said "")
  foreach(cme_dir IN LISTS cme_includes)
    string(APPEND cme_said " -I${cme_dir}")
  endforeach()
  set(${out_cflags} "${cme_said}" PARENT_SCOPE)
  set(cme_said "")
  foreach(cme_dir IN LISTS cme_libdirs)
    string(APPEND cme_said " -L${cme_dir}")
  endforeach()
  set(${out_ldflags} "${cme_said}" PARENT_SCOPE)
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
  # The flags the assembler takes, which is a different question.
  #
  # Where a project's assembly is .S files -- arm and aarch64 in both x264
  # and FFmpeg -- the assembler is the C compiler, and it needs everything
  # the C compiler needs: without the target its NEON check assembles for
  # this machine and the project concludes the CPU has no NEON. Where the
  # assembly is .asm the assembler is nasm, which takes none of that: hand
  # it -fPIC -Wall and it fails its own check and the project reports the
  # version of nasm it just found as too old.
  set(cme_as_flags "")
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm|aarch64|ARM|AARCH64)")
    set(cme_as_flags "${cme_c_flags}")
  endif()
  string(REPLACE "@ASFLAGS@" "${cme_as_flags}" value "${value}")
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
  if(value MATCHES "@DEPENDS_(C|LD)FLAGS@")
    cme_configure_dependency_flags(${port} cme_dep_cflags cme_dep_ldflags)
    string(REPLACE "@DEPENDS_CFLAGS@" "${cme_dep_cflags}" value "${value}")
    string(REPLACE "@DEPENDS_LDFLAGS@" "${cme_dep_ldflags}" value "${value}")
  endif()
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

  # Where the libraries this port was built against say what they are.
  #
  # A configure script looks for a library with pkg-config, and a library
  # this build installed a moment ago is in a prefix of its own that nothing
  # on this machine knows about. Its .pc file is in there, correct and
  # unread; naming the directory is all it takes.
  cme_gn_dependency_ports(${port} cme_deps)
  set(cme_pkg_dirs "")
  foreach(cme_dep IN LISTS cme_deps)
    if(CME_INSTALLED_${cme_dep})
      foreach(cme_where "lib/pkgconfig" "lib64/pkgconfig" "share/pkgconfig")
        if(IS_DIRECTORY "${CME_INSTALLED_${cme_dep}}/${cme_where}")
          list(APPEND cme_pkg_dirs "${CME_INSTALLED_${cme_dep}}/${cme_where}")
        endif()
      endforeach()
    endif()
  endforeach()
  if(cme_pkg_dirs)
    list(JOIN cme_pkg_dirs ":" cme_pkg_path)
    if(DEFINED ENV{PKG_CONFIG_PATH} AND NOT "$ENV{PKG_CONFIG_PATH}" STREQUAL "")
      set(cme_pkg_path "${cme_pkg_path}:$ENV{PKG_CONFIG_PATH}")
    endif()
    list(APPEND environment "PKG_CONFIG_PATH=${cme_pkg_path}")
    message(STATUS
      "cmake-everywhere: ${port} is told where ${cme_pkg_path} is")
  endif()

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
# What a released archive already contains, said to be newer than what would
# regenerate it.
#
# An autotools release carries its configure script and the Makefile.in
# files; the sources they were generated from are in it too, and an archive
# unpacks with whatever timestamps it feels like. Where a .ac or .am file
# lands a second newer than what it generates, make decides the generated
# file is stale and runs autoconf -- which a machine that only builds
# software does not have, and should not need.
#
# So the generated files are touched in the order they depend on each other.
# It is the oldest trick in the autotools book and it is what every
# distribution's build does.
function(cme_configure_settle source)
  foreach(pattern "configure.ac" "configure.in" "*.am" "acinclude.m4")
    file(GLOB_RECURSE found "${source}/${pattern}")
    foreach(file IN LISTS found)
      file(TOUCH_NOCREATE "${file}")
    endforeach()
  endforeach()
  foreach(pattern "aclocal.m4" "configure" "*.in")
    file(GLOB_RECURSE found "${source}/${pattern}")
    foreach(file IN LISTS found)
      file(TOUCH_NOCREATE "${file}")
    endforeach()
  endforeach()
endfunction()

function(cme_configure_build port source entry)
  if(EXISTS "${entry}/complete")
    message(STATUS "cmake-everywhere: ${port} is already built")
    cme_configure_export(${port} "${entry}")
    return()
  endif()
  set(build "${CMAKE_BINARY_DIR}/_cme/${port}-build")
  cme_configure_settle("${source}")
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
