# Setting up

cmake_minimum_required( VERSION 2.0 )
project( pycmake )

add_subdirectory( cmake )

if(ENABLE_TESTING)
    add_subdirectory(test)
endif()
