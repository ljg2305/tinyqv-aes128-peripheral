# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.triggers import RisingEdge


from Crypto.Cipher import AES

from aes_support_funcs import *

@cocotb.test()
async def test_aes128_sub_bytes(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk_i, 100, units="ns")
    cocotb.start_soon(clock.start())

    dut.start_i.value = 0
    dut.key_i.value = 0
    dut.key_req_i.value = 0

    # reset 
    dut.rst_n_i.value = 0
    await ClockCycles(dut.clk_i, 1)
    dut.rst_n_i.value = 1
    await ClockCycles(dut.clk_i, 1)

    dut.key_i.value = 0x2b7e151628aed2a6abf7976676151301
    key = bytearray.fromhex('2b7e151628aed2a6abf7976676151301')

    key_schedule = key_expansion(key)

    dut.start_i.value = 1
    await ClockCycles(dut.clk_i, 1)
    dut.start_i.value = 0
    
    for round in range(11):

        #Wait for valid signal 
        await RisingEdge(dut.valid_o) 
        await ClockCycles(dut.clk_i, 1)
        key_int = dut.key_big_end_o.value.integer  # Get the integer value
        key_bytes = key_int.to_bytes(16, byteorder='big')  # 16 bytes for 128-bit key
        round_key_out = bytearray(key_bytes)

        round_key = key_schedule[round]
        rk = bytearray()
        for r in range(4):
            for c in range(4):
                rk.append(round_key[r][c])
        print("Expected:  %s"%rk.hex())
        print("Simulated: %s"%round_key_out.hex())
        if (rk != round_key_out):
            print("ERROR: key mismatch")


        await ClockCycles(dut.clk_i, 1)
        dut.key_req_i.value = 1
        await ClockCycles(dut.clk_i, 1)
        dut.key_req_i.value = 0

    await ClockCycles(dut.clk_i, 80)
    print("done")

    
    with open('temp_case.sv','w') as f:
        for i in range(0,256):
            f.writelines("%s\n"%(hex(i)))
