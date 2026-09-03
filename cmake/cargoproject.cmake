# A library written in Rust, built here and linked like any other.
#
# The fourth kind, after CMake, Meson and a configure script of its own. What
# makes Rust different is not the language: cargo is both the build system
# and the package manager, so a crate states its dependencies in its own
# registry rather than in this one. A port pins a checkout that carries a
# Cargo.lock, and that lock is what says which versions are built -- the same
# role this registry's lock plays for everything else.
#
# Cargo is asked what it would do and then steps out of the way. `cargo build
# --build-plan` answers with one entry per invocation of rustc: the program,
# its arguments, its environment, where to run it, what it produces and which
# invocations must come first. Each becomes a command in this build's graph,
# so the compiling happens where every other compilation happens, in one
# scheduler with one job pool, and a source file that changes rebuilds what
# depends on it and nothing else.
#
# That flag is unstable and, unlike --unit-graph, undocumented: cargo's own
# message points at rust-lang/cargo#5579 and the unstable book does not
# mention it. So it is asked for, and a cargo that will not answer is not an
# error -- it builds the crate itself and this build collects the result,
# with a line saying so, because losing the incrementality quietly would be
# worse than losing it.

include_guard(GLOBAL)

# Which machine, in the spelling rustc uses.
#
# Rust names a target as architecture-vendor-system-abi, and so does clang,
# but not with the same words: aarch64-linux-android is the same on both
# sides, while what a compiler calls x86_64-pc-linux-gnu is
# x86_64-unknown-linux-gnu there. A build that is not cross-compiling says
# nothing and lets cargo use the machine it is on.
function(cme_cargo_triple out)
  set(${out} "" PARENT_SCOPE)
  if(NOT CMAKE_CROSSCOMPILING)
    return()
  endif()
  string(TOLOWER "${CMAKE_SYSTEM_NAME}" system)
  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" processor)
  if(processor MATCHES "^(x86_64|amd64)$")
    set(architecture "x86_64")
  elseif(processor MATCHES "^(aarch64|arm64)$")
    set(architecture "aarch64")
  elseif(processor MATCHES "^(armv7|armv7a|arm)$")
    set(architecture "armv7")
  elseif(processor MATCHES "^(i[3-6]86|x86)$")
    set(architecture "i686")
  elseif(processor MATCHES "^riscv64")
    set(architecture "riscv64gc")
  else()
    set(architecture "${processor}")
  endif()
  if(system STREQUAL "android")
    set(triple "${architecture}-linux-android")
    if(architecture STREQUAL "armv7")
      set(triple "armv7-linux-androideabi")
    endif()
  elseif(system STREQUAL "linux")
    set(triple "${architecture}-unknown-linux-gnu")
  elseif(system STREQUAL "darwin")
    set(triple "${architecture}-apple-darwin")
  elseif(system STREQUAL "windows")
    set(triple "${architecture}-pc-windows-msvc")
  elseif(system STREQUAL "emscripten")
    set(triple "wasm32-unknown-emscripten")
  else()
    message(FATAL_ERROR
      "cmake-everywhere: nothing here knows what rustc calls ${system} on "
      "${processor}. A port that needs it says so in CARGO_TARGET.")
  endif()
  set(${out} "${triple}" PARENT_SCOPE)
endfunction()

# What a static Rust library needs beside it.
#
# It carries none of it: libc, the unwinder, pthreads and whatever its crates
# reached for are the caller's problem, and a link without them fails on
# symbols that belong to neither side. rustc is the only thing that knows the
# list, and it will print it for any staticlib -- so it is asked once, about
# an empty crate built the same way, which is the part of the answer that
# comes from the toolchain. What a crate itself adds arrives as -l flags in
# the plan, and is read from there.
function(cme_cargo_toolchain_libraries out work target)
  set(${out} "" PARENT_SCOPE)
  find_program(CME_RUSTC NAMES rustc)
  if(NOT CME_RUSTC)
    return()
  endif()
  set(probe "${work}/what-rust-needs.rs")
  file(WRITE "${probe}" "#![crate_type=\"staticlib\"]\n")
  set(arguments "${probe}" --crate-name cme_probe
      --out-dir "${work}/probe" --print native-static-libs)
  if(target)
    list(APPEND arguments --target "${target}")
  endif()
  file(MAKE_DIRECTORY "${work}/probe")
  execute_process(COMMAND "${CME_RUSTC}" ${arguments}
                  OUTPUT_VARIABLE ignored
                  ERROR_VARIABLE said
                  RESULT_VARIABLE code)
  if(NOT code EQUAL 0)
    return()
  endif()
  set(libraries "")
  string(REGEX MATCH "native-static-libs:[^\n]*" line "${said}")
  if(line)
    string(REPLACE "native-static-libs:" "" line "${line}")
    separate_arguments(words UNIX_COMMAND "${line}")
    foreach(word IN LISTS words)
      if(word MATCHES "^-l(.+)$")
        list(APPEND libraries "${CMAKE_MATCH_1}")
      elseif(word MATCHES "^-")
        list(APPEND libraries "${word}")
      endif()
    endforeach()
  endif()
  if(libraries)
    list(REMOVE_DUPLICATES libraries)
  endif()
  set(${out} "${libraries}" PARENT_SCOPE)
endfunction()

# The arguments every cargo command here shares.
function(cme_cargo_arguments out port source)
  cme_port_field(package ${port} CARGO_PACKAGE)
  cme_port_field(features ${port} CARGO_FEATURES)
  cme_port_field(no_default ${port} CARGO_NO_DEFAULT_FEATURES)
  cme_port_field(manifest ${port} CARGO_MANIFEST)
  cme_port_field(target ${port} CARGO_TARGET)
  if(NOT target)
    cme_cargo_triple(target)
  endif()
  if(NOT manifest)
    set(manifest "Cargo.toml")
  endif()
  set(arguments --release --locked
      --manifest-path "${source}/${manifest}")
  if(package)
    list(APPEND arguments --package "${package}")
  endif()
  if(features)
    list(JOIN features "," joined)
    list(APPEND arguments --features "${joined}")
  endif()
  if(no_default)
    list(APPEND arguments --no-default-features)
  endif()
  if(target)
    list(APPEND arguments --target "${target}")
  endif()
  # A build that may not fetch is told so rather than left to discover it.
  if(CME_OFFLINE)
    list(APPEND arguments --offline)
  endif()
  set(${out} "${arguments}" PARENT_SCOPE)
  set(CME_CARGO_TRIPLE "${target}" PARENT_SCOPE)
endfunction()

# Build the crate, and make what came out a target of this build.
function(cme_cargo_build port source)
  find_program(CME_CARGO NAMES cargo)
  if(NOT CME_CARGO)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} is a Rust library and there is no cargo "
      "here to build it with. Rust is not assumed: a machine with no Rust "
      "toolchain cannot build a Rust library, and saying so is better than "
      "a compiler error three minutes in.")
  endif()

  set(work "${CMAKE_BINARY_DIR}/_cme/${port}-cargo")
  file(MAKE_DIRECTORY "${work}")
  cme_cargo_arguments(common ${port} "${source}")
  list(APPEND common --target-dir "${work}/target")

  # Ask what it would do.
  #
  # RUSTC_BOOTSTRAP is what lets a released cargo answer an unstable
  # question, and it is set for this one command and no other: nothing is
  # compiled here, so nothing is compiled with a toolchain pretending to be
  # a different one. A cargo that refuses anyway leaves the plan empty and
  # the build falls back below.
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env RUSTC_BOOTSTRAP=1
            "${CME_CARGO}" build ${common} -Z unstable-options --build-plan
    WORKING_DIRECTORY "${source}"
    OUTPUT_FILE "${work}/plan.json"
    ERROR_VARIABLE refused
    RESULT_VARIABLE asked)

  find_package(Python3 REQUIRED COMPONENTS Interpreter)
  set(described FALSE)
  if(asked EQUAL 0)
    set(ninja FALSE)
    if(CMAKE_GENERATOR MATCHES "Ninja")
      set(ninja TRUE)
    endif()
    set(convert "${Python3_EXECUTABLE}" "${CME_DIR}/cmake/cargo_plan.py"
        --plan "${work}/plan.json" --out "${work}/plan.cmake"
        --stamp "${work}/ran")
    # Cargo names the compiler "rustc" and finds it on a PATH of its own
    # making; this build runs the one that was found here, by its path.
    find_program(CME_RUSTC NAMES rustc)
    if(CME_RUSTC)
      list(APPEND convert --rustc "${CME_RUSTC}")
    endif()
    if(ninja)
      list(APPEND convert --ninja
           --python "${Python3_EXECUTABLE}"
           --rewriter "${CME_DIR}/cmake/cargo_depfile.py")
    endif()
    execute_process(COMMAND ${convert}
                    RESULT_VARIABLE converted
                    ERROR_VARIABLE conversion_trouble)
    if(converted EQUAL 0)
      set(described TRUE)
    else()
      message(STATUS
        "cmake-everywhere: ${port} described a build this cannot read "
        "(${conversion_trouble}); cargo will build it instead")
    endif()
  else()
    message(STATUS
      "cmake-everywhere: this cargo will not say what it would do, so it "
      "builds ${port} itself and this build collects the result. What is "
      "lost is rebuilding one crate when one file changes.")
  endif()

  cme_port_targets(names ${port})
  cme_cargo_toolchain_libraries(needed "${work}" "${CME_CARGO_TRIPLE}")

  if(described)
    include("${work}/plan.cmake")
    # One target for the whole crate graph, so that anything linking a
    # library built here waits for the commands that produce it.
    add_custom_target(${port}-rust DEPENDS ${CME_CARGO_OUTPUTS})
    set(libraries ${CME_CARGO_LIBRARIES})
  else()
    # Cargo drives. What it built is read from its own report rather than
    # looked for in likely places.
    execute_process(
      COMMAND "${CME_CARGO}" build ${common} --message-format json
      WORKING_DIRECTORY "${source}"
      OUTPUT_FILE "${work}/build.json"
      ERROR_VARIABLE trouble
      RESULT_VARIABLE code)
    if(NOT code EQUAL 0)
      message(FATAL_ERROR
        "cmake-everywhere: cargo could not build ${port}\n${trouble}")
    endif()
    execute_process(
      COMMAND "${Python3_EXECUTABLE}" "${CME_DIR}/cmake/cargo_import.py"
              --build-log "${work}/build.json" --out "${work}/built.cmake"
      RESULT_VARIABLE read_code ERROR_VARIABLE read_trouble)
    if(NOT read_code EQUAL 0)
      message(FATAL_ERROR
        "cmake-everywhere: cargo built ${port} and what it built could not "
        "be read\n${read_trouble}")
    endif()
    include("${work}/built.cmake")
    set(libraries "")
    list(LENGTH CME_CARGO_ARTIFACTS pairs)
    if(pairs GREATER 0)
      math(EXPR last "${pairs} / 2 - 1")
      foreach(at RANGE ${last})
        math(EXPR path_at "${at} * 2 + 1")
        list(GET CME_CARGO_ARTIFACTS ${path_at} one)
        list(APPEND libraries "${one}")
      endforeach()
    endif()
    add_custom_target(${port}-rust)
  endif()

  if(NOT libraries)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} is a Rust library and what cargo describes "
      "contains no static library to link. A crate that is built here has "
      "to say crate-type = [\"staticlib\"].")
  endif()

  # One imported target per library, named the way the port says. A crate
  # whose name is not the target's is the ordinary case, so the port's
  # TARGETS and what came out are matched in order.
  set(at 0)
  foreach(library IN LISTS libraries)
    set(named "${port}")
    list(LENGTH names count)
    if(at LESS count)
      list(GET names ${at} named)
    endif()
    math(EXPR at "${at} + 1")
    if(TARGET ${named})
      continue()
    endif()
    add_library(${named} STATIC IMPORTED GLOBAL)
    set_target_properties(${named} PROPERTIES IMPORTED_LOCATION "${library}")
    add_dependencies(${named} ${port}-rust)
    if(needed)
      set_property(TARGET ${named} APPEND PROPERTY
                   INTERFACE_LINK_LIBRARIES ${needed})
    endif()
    cme_port_field(headers ${port} CARGO_INCLUDE)
    if(headers)
      set_property(TARGET ${named} APPEND PROPERTY
                   INTERFACE_INCLUDE_DIRECTORIES "${work}/target/${headers}")
    endif()
    message(STATUS "cmake-everywhere: ${port} produces ${named}")
  endforeach()
endfunction()
