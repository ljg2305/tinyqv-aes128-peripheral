# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from tqv import TinyQV

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 0

@cocotb.test()
async def test_aes128_sub_bytes(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk_i, 100, units="ns")
    cocotb.start_soon(clock.start())

    dut.start_i.value = 0
    dut.data_i.value = 0

    # reset 
    dut.rst_n_i.value = 0
    await ClockCycles(dut.clk_i, 1)
    dut.rst_n_i.value = 1
    await ClockCycles(dut.clk_i, 1)

    dut.data_i.value = 0x03020100030201000302010003020100
    dut.start_i.value = 1
    await ClockCycles(dut.clk_i, 1)
    dut.start_i.value = 0

    await ClockCycles(dut.clk_i, 600)

    
    with open('temp_case.sv','w') as f:
        for i in range(0,256):
            f.writelines("%s\n"%(hex(i)))
