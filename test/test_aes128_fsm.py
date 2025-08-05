# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

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

    #dut.data_i.value = 0x0F0E0D0C0B0A09080706050403020100
    dut.data_i.value = 0x03020100030201000302010003020100
    dut.key_i.value = 0x2b7e151628aed2a6abf7976676151301
    plaintext = bytearray.fromhex('03020100030201000302010003020100')
    key = bytearray.fromhex('2b7e151628aed2a6abf7976676151301')
    ciphertext = aes_encryption(plaintext, key)
    dut.op_i.value = 0

    dut.start_i.value = 1
    await ClockCycles(dut.clk_i, 1)
    dut.start_i.value = 0

    await ClockCycles(dut.clk_i, 8000)

    print(ciphertext.hex())
    
    with open('temp_case.sv','w') as f:
        for i in range(0,256):
            f.writelines("%s\n"%(hex(i)))
