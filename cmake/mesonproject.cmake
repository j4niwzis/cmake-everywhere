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
  foreach(option IN LISTS options)
    string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\1" name "${option}")
    string(REGEX REPLACE "^([^ ]+) +(.*)$" "\\2" value "${option}")
    list(APPEND arguments "-D${name}=${value}")
  endforeach()

  message(STATUS "cmake-everywhere: asking ${port} what it would build")
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env "NINJA=${CME_NINJA}"
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
