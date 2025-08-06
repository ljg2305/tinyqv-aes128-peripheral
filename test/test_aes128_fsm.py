# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.triggers import RisingEdge

from tqv import TinyQV

from aes_support_funcs import *

@cocotb.test()
async def test_aes128_sub_bytes(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk_i, 100, units="ns")
    cocotb.start_soon(clock.start())

    dut.start_i.value = 0
    dut.data_i.value = 0
    dut.key_i.value = 0

    # reset 
    dut.rst_n_i.value = 0
    await ClockCycles(dut.clk_i, 1)
    dut.rst_n_i.value = 1
    await ClockCycles(dut.clk_i, 1)

    for i in range(32):
        # generate random input 
        key  = os.urandom(16).hex()
        dut.key_i.value = int(key,16)
        key_ba = bytearray.fromhex(key)
        data = os.urandom(16).hex()
        dut.data_i.value = int(data,16)
        data_ba = bytearray.fromhex(data)

        expected_out = aes_encryption(data_ba, key_ba)
        dut.op_i.value = 0

        dut.start_i.value = 1
        await ClockCycles(dut.clk_i, 1)
        dut.start_i.value = 0

        #Wait for valid signal 
        await RisingEdge(dut.valid_o) 
        await ClockCycles(dut.clk_i, 1)
        result_int = dut.result_o.value.integer  # Get the integer value
        result_bytes = result_int.to_bytes(16, byteorder='big')  # 16 bytes for 128-bit key
        result_out = bytearray(result_bytes)


        print(expected_out.hex()) 
        print(result_out.hex()) 
        if (expected_out != result_out): 
            print("ERROR: %s not equal to %s")


    await ClockCycles(dut.clk_i, 80)
    print("done")
    await ClockCycles(dut.clk_i, 8000)

    
    with open('temp_case.sv','w') as f:
        for i in range(0,256):
            f.writelines("%s\n"%(hex(i)))
