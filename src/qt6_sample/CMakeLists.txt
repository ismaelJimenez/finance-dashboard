# Ensure proper system headers are found on macOS
if(APPLE)
    execute_process(COMMAND xcrun --show-sdk-path OUTPUT_VARIABLE CMAKE_OSX_SYSROOT OUTPUT_STRIP_TRAILING_WHITESPACE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.15" CACHE STRING "Minimum OS X deployment version")
endif()

find_package(Qt6 REQUIRED COMPONENTS Widgets)
qt_standard_project_setup()

qt_add_executable(qt6_hello_world 
    main.cpp
)

target_link_libraries(
  qt6_hello_world
  PRIVATE Qt6::Widgets)

set_target_properties(qt6_hello_world PROPERTIES
    WIN32_EXECUTABLE ON
    MACOSX_BUNDLE ON
    CXX_CLANG_TIDY "clang-tidy;-checks=-misc-include-cleaner"
)