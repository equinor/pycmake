cmake_minimum_required( VERSION 2.0 )
project( pycmake )

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules)

if(PYCMAKE_ENABLE_TESTING)
    add_subdirectory(test)
endif()
