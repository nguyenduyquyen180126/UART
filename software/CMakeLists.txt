cmake_minimum_required(VERSION 3.14)

# Nios V HAL requires the enhanced ISR API. The optional JTAG console is
# accessed directly by the application, so HAL must not enable its RX IRQ.
add_compile_definitions(ALT_ENHANCED_INTERRUPT_API_PRESENT ALTERA_AVALON_JTAG_UART_SMALL)
add_subdirectory(bsp bsp)

include(bsp/toolchain.cmake)

project(app)

enable_language(ASM)
enable_language(C)
enable_language(CXX)

set(APP_SOURCE "${CMAKE_CURRENT_LIST_DIR}/../main.c" CACHE FILEPATH "Firmware source")
add_executable(app.elf)
target_compile_options(app.elf PRIVATE -Wall -Wextra)

target_sources(app.elf
    PRIVATE
        ${APP_SOURCE}
        uart_irq.c
        uart_config.c
)

target_include_directories(app.elf
    PRIVATE ${CMAKE_CURRENT_LIST_DIR}
    PUBLIC
)

target_link_libraries(app.elf
    PRIVATE
        -T "${BspLinkerScript}" -nostdlib -Wl,--gc-sections
        "${ExtraArchiveLibraries}"
        -Wl,--start-group "${BspLibraryName}" -lc_nano -lgcc -lm -Wl,--end-group
)

# Create objdump from ELF.
set(objdump app.elf.objdump)
add_custom_command(
    OUTPUT "${objdump}"
    DEPENDS app.elf
    COMMAND "${ToolchainObjdump}" "${ToolchainObjdumpFlags}" app.elf >
            "${objdump}"
    COMMENT "Creating ${objdump}."
    VERBATIM
)
add_custom_target(create-objdump ALL DEPENDS "${objdump}")

# Report space free for stack + heap. Note that the file below is never created
# so the report is always output on build.
set(stack_report_file app.elf.stack_report)
add_custom_command(
    OUTPUT "${stack_report_file}"
    DEPENDS app.elf
    COMMAND niosv-stack-report -p "${ToolchainPrefix}" app.elf
    COMMENT "Reporting memory available for stack + heap in app.elf."
    VERBATIM
)
add_custom_target(niosv-stack-report ALL DEPENDS "${stack_report_file}")

# Generate HEX file(s) from app.elf using elf2hex tool.
# Note : If ECC Full is enabled, width of 39 is set for NiosV TCM. Otherwise, 32.
add_custom_command(
    OUTPUT "onchip_memory2_0.hex"
    DEPENDS app.elf
    COMMAND elf2hex app.elf -o onchip_memory2_0.hex -b 0x00000000 -w 32 -e 0x0000FFFF -r 4
    COMMENT "Creating onchip_memory2_0.hex."
    VERBATIM
)
add_custom_target(create-hex ALL DEPENDS "onchip_memory2_0.hex")
