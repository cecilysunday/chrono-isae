#--------------------------------------------------------------
# 
# CMake configuration file to build an external 
# project depending on Chrono and on optional Chrono modules.
# 
#--------------------------------------------------------------
 
cmake_minimum_required(VERSION 3.1)

#--------------------------------------------------------------
# Modify the project names to be included in the build
#--------------------------------------------------------------

SET(TESTS
  benchmark
  impact
  penetrometer
  rundrum
  setbox
  setcyl
  setdrum
  )

#--------------------------------------------------------------
# Add the executable from your project and specify all C++ 
# files in your project.
#
# Note that here we define a macro CHRONO_DATA_DIR which will
# contain the path to the Chrono data directory, either in its
# source tree (if using a build version of Chrono), or in its
# install tree (if using an installed version of Chrono). 
#
#
# Link to Chrono libraries and dependency libraries
#--------------------------------------------------------------

foreach(PROGRAM ${TESTS})

  message(STATUS "...add ${PROGRAM}")

  add_executable(${PROGRAM}  "${PROGRAM}.cpp")
  source_group(""  FILES "${PROGRAM}.cpp")

  set_target_properties(${PROGRAM} PROPERTIES
    COMPILE_FLAGS "${COMPILE_FLAGS} ${EXTRA_COMPILE_FLAGS}"
    COMPILE_DEFINITIONS "CHRONO_DATA_DIR=\"${CHRONO_DATA_DIR}\"; SOURCE_DIR=\"${CMAKE_CURRENT_SOURCE_DIR}\"; PROJECT_DATA_DIR=\"${PROJECT_DATA_DIR}\"; PROJECT_CONFIG_DIR=\"${PROJECT_CONFIG_DIR}\""
    LINK_FLAGS "${COMPILE_FLAGS} ${CHRONO_LINKER_FLAGS}"
  )

  target_include_directories(${PROGRAM} PRIVATE ${CHRONO_INCLUDE_DIRS} ${PROJ_SHARED_INCLUDES})
  target_link_libraries(${PROGRAM} ${CHRONO_LIBRARIES} Shared)

endforeach(PROGRAM)
