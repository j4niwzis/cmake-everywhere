# vodozemac, Matrix's Olm and Megolm in Rust, for C++: the kazv project's
# bindings (a maintained fork of matrix-org/vodozemac-bindings, whose C++
# part was left pinned to a 2022 vodozemac). Their cpp crate is a staticlib
# with a cxx bridge: Account and Session, GroupSession and
# InboundGroupSession, SAS, pickling.
#
# Built by cargo through the cargo import, the bridge's C++ compiled by this
# build's compiler (cme_cargo_compiler_env). What a consumer includes is
# what cxx-build writes beside the target directory: <vodozemac/src/lib.rs.h>
# and <rust/cxx.h>.
cme_declare_port(
  NAME vodozemac
  PROVIDES vodozemac vodozemac-cpp
  VERSION 1.0.0
  GIT_REPOSITORY https://r.lily-is.land/the-kazv-project/vodozemac-bindings.git
  GIT_TAG 4a22383c32516205d2b4d545fdc95d451acc2818
  LICENSE Apache-2.0
  IMPORT cargo
  CARGO_PACKAGE vodozemac-cpp
  CARGO_INCLUDE cxxbridge
  TARGETS vodozemac::vodozemac
)

# Their Makefile writes src/lib.rs from src/lib.rs.in before cargo builds:
# a Perl script (inject-maybe) wraps each fallible function's result in a
# Maybe the C++ side reads. Done here the same way, by the same script.
function(cme_prepare_vodozemac source)
  find_program(CME_PERL NAMES perl REQUIRED)
  execute_process(
    COMMAND "${CME_PERL}" ./inject-maybe
    INPUT_FILE "${source}/cpp/src/lib.rs.in"
    OUTPUT_FILE "${source}/cpp/src/lib.rs.made"
    ERROR_VARIABLE said
    WORKING_DIRECTORY "${source}/cpp"
    RESULT_VARIABLE code)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR "cmake-everywhere: vodozemac's inject-maybe failed\n${said}")
  endif()
  # Written over only where it changed: cargo rebuilds what a newer lib.rs
  # touches, every configure otherwise.
  file(COPY_FILE "${source}/cpp/src/lib.rs.made" "${source}/cpp/src/lib.rs" ONLY_IF_DIFFERENT)
endfunction()
