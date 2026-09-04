# A project that builds with Meson, built here instead.
#
# The same shape as cmakeproject.cmake: configure it somewhere on its own,
# ask it what it would build, and make those targets in this build with
# these flags. The asking is `meson setup`, which writes the answer into
# meson-info; the reading is meson_import.py, which writes the same
# description cmakeproject.cmake reads, so the targets are made in one
# place for both.
#
# What this buys is that basu, wayland and everything else in that world
# become ordinary ports: fetched, built with this toolchain, and linked
# into this build, without being installed first.

# Meson's spelling of a list of strings.
function(cme_meson_list out)
  set(pieces "")
  foreach(value IN LISTS ARGN)
    string(REPLACE "\\" "\\\\" value "${value}")
    string(REPLACE "'" "\\'" value "${value}")
    list(APPEND pieces "'${value}'")
  endforeach()
  list(JOIN pieces ", " joined)
  set(${out} "[${joined}]" PARENT_SCOPE)
endfunction()

# Meson's spelling of the machine being built for.
#
# CMAKE_SYSTEM_PROCESSOR is what the toolchain file said, and Meson wants
# the family it belongs to. A processor with no known family is passed
# through: being wrong loudly beats being wrong quietly.
function(cme_meson_cpu_family out processor)
  string(TOLOWER "${processor}" processor)
  if(processor MATCHES "^(x86_64|amd64)$")
    set(family "x86_64")
  elseif(processor MATCHES "^(i[3-6]86|x86)$")
    set(family "x86")
  elseif(processor MATCHES "^(aarch64|arm64)$")
    set(family "aarch64")
  elseif(processor MATCHES "^arm")
    set(family "arm")
  elseif(processor MATCHES "^(riscv64)$")
    set(family "riscv64")
  elseif(processor MATCHES "^(ppc64le|powerpc64le)$")
    set(family "ppc64")
  else()
    set(family "${processor}")
  endif()
  set(${out} "${family}" PARENT_SCOPE)
endfunction()

# The toolchain, as Meson reads it.
#
# Everything CMake was told to build with is written down here, because a
# port built with a different compiler than the project that uses it is not
# the same port. When CMake is cross-compiling this is a cross file, which
# is also where Meson learns which machine it is building for; otherwise it
# is a native file.
function(cme_meson_machine_file port out_file out_kind)
  set(lines "# Written by cmake-everywhere from this build's toolchain.\n")
  string(APPEND lines "\n[binaries]\n")

  if(CMAKE_C_COMPILER)
    cme_meson_list(value "${CMAKE_C_COMPILER}")
    string(APPEND lines "c = ${value}\n")
  endif()
  if(CMAKE_CXX_COMPILER)
    cme_meson_list(value "${CMAKE_CXX_COMPILER}")
    string(APPEND lines "cpp = ${value}\n")
  endif()
  if(CMAKE_AR)
    cme_meson_list(value "${CMAKE_AR}")
    string(APPEND lines "ar = ${value}\n")
  endif()
  if(CMAKE_STRIP)
    cme_meson_list(value "${CMAKE_STRIP}")
    string(APPEND lines "strip = ${value}\n")
  endif()
  find_program(CME_PKG_CONFIG NAMES pkg-config pkgconf)
  if(CME_PKG_CONFIG)
    cme_meson_list(value "${CME_PKG_CONFIG}")
    string(APPEND lines "pkg-config = ${value}\n")
  endif()

  set(c_args "")
  set(cpp_args "")
  set(link_args "")
  if(CMAKE_C_FLAGS)
    separate_arguments(c_args UNIX_COMMAND "${CMAKE_C_FLAGS}")
  endif()
  if(CMAKE_CXX_FLAGS)
    separate_arguments(cpp_args UNIX_COMMAND "${CMAKE_CXX_FLAGS}")
  endif()
  # What linking here takes, which is not the same as what compiling takes.
  #
  # Meson decides whether a compiler supports a flag by compiling a program
  # and linking it, so a build whose link needs saying -- another linker,
  # another runtime library, no shared libraries at all -- answers "no" to
  # every question when it is not told. What that looks like is a compiler
  # that does not support -Wno-unused-parameter, and then a header that does
  # not define a constant it plainly defines.
  if(CMAKE_EXE_LINKER_FLAGS)
    separate_arguments(cme_linker UNIX_COMMAND "${CMAKE_EXE_LINKER_FLAGS}")
    list(APPEND link_args ${cme_linker})
  endif()
  if(CMAKE_SYSROOT)
    list(APPEND c_args "--sysroot=${CMAKE_SYSROOT}")
    list(APPEND cpp_args "--sysroot=${CMAKE_SYSROOT}")
    list(APPEND link_args "--sysroot=${CMAKE_SYSROOT}")
  endif()

  string(APPEND lines "\n[built-in options]\n")
  cme_meson_list(value ${c_args})
  string(APPEND lines "c_args = ${value}\n")
  cme_meson_list(value ${cpp_args})
  string(APPEND lines "cpp_args = ${value}\n")
  cme_meson_list(value ${link_args})
  string(APPEND lines "c_link_args = ${value}\n")
  string(APPEND lines "cpp_link_args = ${value}\n")

  set(kind "native")
  if(CMAKE_CROSSCOMPILING)
    set(kind "cross")
    string(TOLOWER "${CMAKE_SYSTEM_NAME}" system)
    cme_meson_cpu_family(family "${CMAKE_SYSTEM_PROCESSOR}")
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" cpu)
    # CMake has no variable for endianness of the machine it builds for,
    # and every processor family above is little-endian in the spellings
    # that reach here.
    string(APPEND lines "\n[host_machine]\n")
    string(APPEND lines "system = '${system}'\n")
    string(APPEND lines "cpu_family = '${family}'\n")
    string(APPEND lines "cpu = '${cpu}'\n")
    string(APPEND lines "endian = 'little'\n")
  endif()

  set(file "${CMAKE_BINARY_DIR}/_cme/${port}-${kind}.ini")
  file(WRITE "${file}" "${lines}")
  set(${out_file} "${file}" PARENT_SCOPE)
  set(${out_kind} "${kind}" PARENT_SCOPE)
endfunction()

# What this port is built against, in the only language meson asks in.
#
# A meson project resolves its own dependencies -- dependency('libffi'),
# dependency('expat') -- and it asks pkg-config, not this. So a port built
# here against another port built here would have been compiled against
# whatever the machine happened to have, or told there is nothing at all.
#
# The same answer as the GN ports get, in a different spelling: there the
# include directories of a dependency go into the project's own extra_cflags
# and its libraries are resolved from the names it links; here a .pc file is
# written for each name a dependency port answers to, and meson is pointed
# at the directory holding them before anything the machine has.
#
# What is in that file is the include directories and the bare names the
# dependency answers to -- "-lexpat" -- and not paths to archives. The name
# is the same thing a GN project puts in libs and a Makefile puts on a link
# line, and it is resolved the same way at the end: LINK_NAMES turns it into
# the target that was actually built. A path written here would be a second
# statement of where a library is, in a file, next to the one the graph
# already has.
function(cme_meson_dependency_pkgconfig port out)
  set(directory "${CMAKE_BINARY_DIR}/_cme/${port}-pc")
  file(MAKE_DIRECTORY "${directory}")
  cme_gn_dependency_ports(${port} deps)
  set(written "")
  foreach(dep IN LISTS deps)
    # Every name the dependency answers to, which is what the port already
    # says for the sake of pkg_check_modules calls that come this way.
    cme_port_field(names ${dep} PKGCONFIG_NAMES)
    cme_port_field(mapping ${dep} SYSTEM_PKGCONFIG)
    foreach(pair IN LISTS mapping)
      if(pair MATCHES "^([^:]+):")
        set(module "${CMAKE_MATCH_1}")
      else()
        set(module "${pair}")
      endif()
      string(REPLACE "|" ";" alternatives "${module}")
      list(APPEND names ${alternatives})
    endforeach()
    if(NOT names)
      continue()
    endif()
    list(REMOVE_DUPLICATES names)

    cme_gn_target_includes(includes ${dep})
    set(flags "")
    foreach(one IN LISTS includes)
      string(APPEND flags " -I${one}")
    endforeach()
    set(libs "")
    cme_port_field(link ${dep} LINK_NAMES)
    foreach(pair IN LISTS link)
      if(pair MATCHES "^([^=]+)=")
        string(APPEND libs " -l${CMAKE_MATCH_1}")
      endif()
    endforeach()
    cme_effective_version(${dep} dep_version)
    if(NOT dep_version)
      set(dep_version "0")
    endif()
    foreach(module IN LISTS names)
      file(WRITE "${directory}/${module}.pc"
           "# Written by cmake-everywhere for ${port}, about ${dep}.\n"
           "Name: ${module}\n"
           "Description: ${dep}, as this build has it\n"
           "Version: ${dep_version}\n"
           "Cflags:${flags}\n"
           "Libs:${libs}\n")
      list(APPEND written "${module}")
    endforeach()
  endforeach()
  if(written)
    list(JOIN written ", " listed)
    message(STATUS
      "cmake-everywhere: ${port} is offered ${listed} as this build has "
      "them, before anything the machine has")
  endif()
  set(${out} "${directory}" PARENT_SCOPE)
endfunction()

# Where the project is configured so that it can be asked. Nothing is built
# there; it exists to hold the answer and the files the answer refers to --
# Meson writes config headers at setup time, and every target compiled here
# includes them from there.
function(cme_meson_probe port source out_build)
  find_program(CME_MESON NAMES meson)
  if(NOT CME_MESON)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} builds with meson, and there is no meson "
      "here to ask. Install it, or give the port a system package to find.")
  endif()
  find_program(CME_NINJA NAMES ninja ninja-build)
  if(NOT CME_NINJA AND CMAKE_MAKE_PROGRAM MATCHES "ninja")
    set(CME_NINJA "${CMAKE_MAKE_PROGRAM}")
  endif()
  if(NOT CME_NINJA)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} builds with meson, and meson writes down "
      "what it would build with ninja, which is not here")
  endif()

  set(build "${CMAKE_BINARY_DIR}/_cme/${port}-probe")
  cme_meson_machine_file(${port} machine kind)

  set(arguments "setup" "${build}" "${source}"
                "--backend" "ninja"
                "--default-library" "static"
                "--wrap-mode" "nodownload"
                "--${kind}-file" "${machine}")
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    list(APPEND arguments "--buildtype" "debug")
  elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    list(APPEND arguments "--buildtype" "debugoptimized")
  elseif(CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
    list(APPEND arguments "--buildtype" "minsize")
  elseif(CMAKE_BUILD_TYPE)
    list(APPEND arguments "--buildtype" "release")
  endif()
  if(EXISTS "${build}/meson-private/coredata.dat")
    list(APPEND arguments "--reconfigure")
  endif()

  cme_enabled_features(${port} features)
  cme_port_field(options ${port} OPTIONS)
  foreach(feature IN LISTS features)
    cme_feature_field(extra ${port} ${feature} OPTIONS)
    list(APPEND options ${extra})
  endforeach()
  list(APPEND options ${CME_OPTIONS_${port}})
  # An option a feature adds to rather than sets.
  #
  # Meson has options that are lists, and the ones that matter here are the
  # lists of drivers: every driver is a feature, and each of them has to end
  # up in the same option. Setting it once per feature would leave whichever
  # feature came last, so a value written "+name" is appended to what is
  # already there rather than replacing it -- which is what a list option
  # means, said in the only place that knows all the features that are on.
  set(names "")
  set(values "")
  foreach(option IN LISTS options)
    string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\1" name "${option}")
    string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\2" value "${option}")
    list(FIND names "${name}" at)
    if(value MATCHES "^\\+(.*)$" AND at GREATER_EQUAL 0)
      list(GET values ${at} before)
      if(before STREQUAL "" OR before STREQUAL "''")
        list(REMOVE_AT values ${at})
        list(INSERT values ${at} "${CMAKE_MATCH_1}")
      else()
        list(REMOVE_AT values ${at})
        list(INSERT values ${at} "${before},${CMAKE_MATCH_1}")
      endif()
    elseif(value MATCHES "^\\+(.*)$")
      list(APPEND names "${name}")
      list(APPEND values "${CMAKE_MATCH_1}")
    elseif(at GREATER_EQUAL 0)
      list(REMOVE_AT values ${at})
      list(INSERT values ${at} "${value}")
    else()
      list(APPEND names "${name}")
      list(APPEND values "${value}")
    endif()
  endforeach()
  set(index 0)
  foreach(name IN LISTS names)
    list(GET values ${index} value)
    math(EXPR index "${index} + 1")
    list(APPEND arguments "-D${name}=${value}")
  endforeach()

  cme_meson_dependency_pkgconfig(${port} pkgconfig)
  set(path "${pkgconfig}")
  if(DEFINED ENV{PKG_CONFIG_PATH})
    set(path "${pkgconfig}:$ENV{PKG_CONFIG_PATH}")
  endif()
  # And what a dependency built into a prefix put there: its own .pc files,
  # written by its install rather than by this, and its programs. Mesa asks
  # llvm-config what to link, and finds it on PATH or not at all.
  cme_dependency_prefixes(${port} prefix_pkgconfig prefix_programs)
  foreach(one IN LISTS prefix_pkgconfig)
    set(path "${path}:${one}")
  endforeach()
  set(program_path "$ENV{PATH}")
  foreach(one IN LISTS prefix_programs)
    set(program_path "${one}:${program_path}")
  endforeach()

  message(STATUS "cmake-everywhere: asking ${port} what it would build")
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env "NINJA=${CME_NINJA}"
            "PKG_CONFIG_PATH=${path}"
            "PATH=${program_path}"
            "${CME_MESON}" ${arguments}
    RESULT_VARIABLE code OUTPUT_VARIABLE output ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    # Meson says why in its log, and the message on the terminal is often
    # only the last line of it.
    set(log "")
    if(EXISTS "${build}/meson-logs/meson-log.txt")
      file(READ "${build}/meson-logs/meson-log.txt" log)
      string(LENGTH "${log}" length)
      if(length GREATER 4000)
        math(EXPR from "${length} - 4000")
        string(SUBSTRING "${log}" ${from} -1 log)
      endif()
      set(log "\n--- meson-log.txt ---\n${log}")
    endif()
    message(FATAL_ERROR
      "cmake-everywhere: configuring ${port} to ask it failed\n${output}${log}")
  endif()
  set(${out_build} "${build}" PARENT_SCOPE)
endfunction()

# The answer, as CMake data.
function(cme_meson_describe port build out_description)
  find_package(Python3 QUIET COMPONENTS Interpreter)
  if(NOT Python3_EXECUTABLE)
    set(Python3_EXECUTABLE python3)
  endif()
  set(description "${build}/cme-targets.cmake")
  execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${CME_DIR}/cmake/meson_import.py"
            "${CME_MESON}" "${build}" "${${port}_SOURCE_DIR}" "${description}"
    RESULT_VARIABLE code ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: cannot read what ${port} said\n${output}")
  endif()
  message(STATUS "cmake-everywhere: ${output}")
  set(${out_description} "${description}" PARENT_SCOPE)
endfunction()

function(cme_meson_build port source)
  cme_meson_probe(${port} "${source}" build)
  cme_meson_describe(${port} "${build}" description)
  cme_cmake_import(${port} "${description}")
  cme_cmake_export(${port})
endfunction()
