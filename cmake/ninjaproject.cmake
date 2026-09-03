# A project built with another toolchain, whose steps are steps of this one.
#
# The instance that forces it is a program the build itself has to run: a
# generator, a table writer, the thing that writes an APK's classes.dex.
# It has to run on the machine doing the building while everything around it
# is compiled for somewhere else, and a CMake target cannot be it, because a
# build tree has one compiler.
#
# The answer here is the same one this repository gives everywhere else: ask
# the other build what it would do, and do that. It is configured with its own
# toolchain for Ninja, and cmake/ninja_import.py turns the ninja file that
# comes out into commands of this build -- each carrying the compiler it
# names, which is why the other project may be gcc while this one is clang,
# and for another machine entirely.
#
# What that costs: the description is read when this build is configured.
# Editing which modules a source imports, or adding a file, changes the
# description, and the build has to be configured again to see it -- the same
# bargain as every other import here.

include_guard(GLOBAL)

# The compiler of the machine doing the building, when it is not the one this
# build is aimed at. Unset means whichever one CMake finds for itself.
#
# A string rather than a file path, because a compiler may be named rather
# than pointed at -- "clang++-22" is what a machine calls it, and CMake looks
# such a name up on PATH. A cache entry of type FILEPATH does not leave it a
# name: it makes it absolute against wherever the build happens to be, and
# then CMake is told to compile with a file that was never there.
set(CME_BUILD_MACHINE_C_COMPILER "" CACHE STRING
    "C compiler for programs this build runs rather than ships")
set(CME_BUILD_MACHINE_CXX_COMPILER "" CACHE STRING
    "C++ compiler for programs this build runs rather than ships")
set(CME_BUILD_MACHINE_C_FLAGS "" CACHE STRING
    "Flags for programs this build runs rather than ships")
set(CME_BUILD_MACHINE_CXX_FLAGS "" CACHE STRING
    "Flags for programs this build runs rather than ships")

function(cme_build_machine_build port source)
  find_program(CME_NINJA NAMES ninja ninja-build)
  if(NOT CME_NINJA)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} is a program for the machine doing the "
      "building, and what it would run is read out of a ninja file. There "
      "is no ninja here.")
  endif()
  find_program(CME_SHELL NAMES sh)
  if(NOT CME_SHELL)
    message(FATAL_ERROR
      "cmake-everywhere: a command out of a ninja file is a line for a "
      "shell, and there is no sh here.")
  endif()
  find_package(Python3 REQUIRED COMPONENTS Interpreter)

  set(build "${CMAKE_BINARY_DIR}/_cme/${port}-for-this-machine")
  set(arguments "-S" "${source}" "-B" "${build}" "-G" "Ninja"
                "-DCMAKE_BUILD_TYPE=Release"
                "-DCMAKE_MAKE_PROGRAM=${CME_NINJA}")
  # Nothing about the machine being built for is passed on: no toolchain
  # file, no sysroot, no cross compiler, no flags naming another
  # architecture. That is the whole point of this path.
  foreach(name C CXX)
    if(CME_BUILD_MACHINE_${name}_COMPILER)
      list(APPEND arguments
           "-DCMAKE_${name}_COMPILER=${CME_BUILD_MACHINE_${name}_COMPILER}")
    endif()
    if(CME_BUILD_MACHINE_${name}_FLAGS)
      list(APPEND arguments
           "-DCMAKE_${name}_FLAGS=${CME_BUILD_MACHINE_${name}_FLAGS}")
    endif()
  endforeach()
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

  message(STATUS
    "cmake-everywhere: asking ${port} what it would build on this machine")
  execute_process(COMMAND ${CMAKE_COMMAND} ${arguments}
                  RESULT_VARIABLE code OUTPUT_VARIABLE output
                  ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: configuring ${port} for this machine failed\n"
      "${output}")
  endif()

  # What is wanted out of it: the programs the port says it produces.
  cme_port_field(programs ${port} PROGRAMS)
  set(wanted "")
  foreach(pair IN LISTS programs)
    if(NOT pair MATCHES "^([^=]+)=(.+)$")
      message(FATAL_ERROR
        "cmake-everywhere: ${port} says PROGRAMS `${pair}`, which is not "
        "<program>=<target>")
    endif()
    list(APPEND wanted --want "${CMAKE_MATCH_1}")
  endforeach()

  set(description "${build}/cme-steps.cmake")
  execute_process(
    COMMAND "${Python3_EXECUTABLE}" "${CME_DIR}/cmake/ninja_import.py"
            --build "${build}" --out "${description}" --port "${port}"
            --ninja "${CME_NINJA}" ${wanted}
    RESULT_VARIABLE code ERROR_VARIABLE output)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR
      "cmake-everywhere: cannot read what ${port} would run\n${output}")
  endif()
  include("${description}")

  # The programs, as targets a consumer names, and as files a consumer's
  # command depends on: an imported executable is not built by anything, so
  # what waits for it waits for the file.
  foreach(pair IN LISTS programs)
    string(REGEX MATCH "^([^=]+)=(.+)$" ignored "${pair}")
    set(program "${CMAKE_MATCH_1}")
    set(alias "${CMAKE_MATCH_2}")
    set(where "")
    foreach(candidate IN LISTS CME_NINJA_OUTPUTS)
      get_filename_component(name "${candidate}" NAME)
      if(name STREQUAL program)
        set(where "${candidate}")
        break()
      endif()
    endforeach()
    if(NOT where)
      message(FATAL_ERROR
        "cmake-everywhere: ${port} says it produces ${program}, and nothing "
        "in what it would build is called that")
    endif()
    if(NOT TARGET ${alias})
      add_executable(${alias} IMPORTED GLOBAL)
      set_target_properties(${alias} PROPERTIES IMPORTED_LOCATION "${where}")
    endif()
    string(REPLACE "::" "_" flat "${alias}")
    cme_export_variable("${port}" "${port}_PROGRAM" "${where}")
  endforeach()

  # One name for all of it, for a build that wants to say "and this too".
  if(CME_NINJA_OUTPUTS)
    add_custom_target(${port}-programs DEPENDS ${CME_NINJA_OUTPUTS})
  endif()
endfunction()
