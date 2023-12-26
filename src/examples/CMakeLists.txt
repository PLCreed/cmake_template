if(NOT OPTION_BUILD_EXAMPLES)
    return()
endif()

# Example applications
add_subdirectory(cmd_example)
add_subdirectory(gui_example)