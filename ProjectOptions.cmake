include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(finance_dashboard_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(finance_dashboard_setup_options)
  option(finance_dashboard_ENABLE_HARDENING "Enable hardening" ON)
  option(finance_dashboard_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    finance_dashboard_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    finance_dashboard_ENABLE_HARDENING
    OFF)

  finance_dashboard_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR finance_dashboard_PACKAGING_MAINTAINER_MODE)
    option(finance_dashboard_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(finance_dashboard_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(finance_dashboard_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(finance_dashboard_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(finance_dashboard_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(finance_dashboard_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(finance_dashboard_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(finance_dashboard_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(finance_dashboard_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(finance_dashboard_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(finance_dashboard_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(finance_dashboard_ENABLE_PCH "Enable precompiled headers" OFF)
    option(finance_dashboard_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(finance_dashboard_ENABLE_IPO "Enable IPO/LTO" ON)
    option(finance_dashboard_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(finance_dashboard_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(finance_dashboard_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(finance_dashboard_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(finance_dashboard_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(finance_dashboard_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(finance_dashboard_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(finance_dashboard_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(finance_dashboard_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(finance_dashboard_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(finance_dashboard_ENABLE_PCH "Enable precompiled headers" OFF)
    option(finance_dashboard_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      finance_dashboard_ENABLE_IPO
      finance_dashboard_WARNINGS_AS_ERRORS
      finance_dashboard_ENABLE_USER_LINKER
      finance_dashboard_ENABLE_SANITIZER_ADDRESS
      finance_dashboard_ENABLE_SANITIZER_LEAK
      finance_dashboard_ENABLE_SANITIZER_UNDEFINED
      finance_dashboard_ENABLE_SANITIZER_THREAD
      finance_dashboard_ENABLE_SANITIZER_MEMORY
      finance_dashboard_ENABLE_UNITY_BUILD
      finance_dashboard_ENABLE_CLANG_TIDY
      finance_dashboard_ENABLE_CPPCHECK
      finance_dashboard_ENABLE_COVERAGE
      finance_dashboard_ENABLE_PCH
      finance_dashboard_ENABLE_CACHE)
  endif()

  finance_dashboard_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (finance_dashboard_ENABLE_SANITIZER_ADDRESS OR finance_dashboard_ENABLE_SANITIZER_THREAD OR finance_dashboard_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(finance_dashboard_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(finance_dashboard_global_options)
  if(finance_dashboard_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    finance_dashboard_enable_ipo()
  endif()

  finance_dashboard_supports_sanitizers()

  if(finance_dashboard_ENABLE_HARDENING AND finance_dashboard_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR finance_dashboard_ENABLE_SANITIZER_UNDEFINED
       OR finance_dashboard_ENABLE_SANITIZER_ADDRESS
       OR finance_dashboard_ENABLE_SANITIZER_THREAD
       OR finance_dashboard_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${finance_dashboard_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${finance_dashboard_ENABLE_SANITIZER_UNDEFINED}")
    finance_dashboard_enable_hardening(finance_dashboard_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(finance_dashboard_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(finance_dashboard_warnings INTERFACE)
  add_library(finance_dashboard_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  finance_dashboard_set_project_warnings(
    finance_dashboard_warnings
    ${finance_dashboard_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(finance_dashboard_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    finance_dashboard_configure_linker(finance_dashboard_options)
  endif()

  include(cmake/Sanitizers.cmake)
  finance_dashboard_enable_sanitizers(
    finance_dashboard_options
    ${finance_dashboard_ENABLE_SANITIZER_ADDRESS}
    ${finance_dashboard_ENABLE_SANITIZER_LEAK}
    ${finance_dashboard_ENABLE_SANITIZER_UNDEFINED}
    ${finance_dashboard_ENABLE_SANITIZER_THREAD}
    ${finance_dashboard_ENABLE_SANITIZER_MEMORY})

  set_target_properties(finance_dashboard_options PROPERTIES UNITY_BUILD ${finance_dashboard_ENABLE_UNITY_BUILD})

  if(finance_dashboard_ENABLE_PCH)
    target_precompile_headers(
      finance_dashboard_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(finance_dashboard_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    finance_dashboard_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(finance_dashboard_ENABLE_CLANG_TIDY)
    finance_dashboard_enable_clang_tidy(finance_dashboard_options ${finance_dashboard_WARNINGS_AS_ERRORS})
  endif()

  if(finance_dashboard_ENABLE_CPPCHECK)
    finance_dashboard_enable_cppcheck(${finance_dashboard_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(finance_dashboard_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    finance_dashboard_enable_coverage(finance_dashboard_options)
  endif()

  if(finance_dashboard_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(finance_dashboard_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(finance_dashboard_ENABLE_HARDENING AND NOT finance_dashboard_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR finance_dashboard_ENABLE_SANITIZER_UNDEFINED
       OR finance_dashboard_ENABLE_SANITIZER_ADDRESS
       OR finance_dashboard_ENABLE_SANITIZER_THREAD
       OR finance_dashboard_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    finance_dashboard_enable_hardening(finance_dashboard_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
