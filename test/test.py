# SPDX-FileCopyrightText: © 2025 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import os
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from aes_support_funcs import *
from Crypto.Cipher import AES

from tqv import TinyQV

# When submitting your design, change this to the peripheral number
# in peripherals.v.  e.g. if your design is i_user_peri05, set this to 5.
# The peripheral number is not used by the test harness.
PERIPHERAL_NUM = 0

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Interact with your design's registers through this TinyQV class.
    # This will allow the same test to be run when your design is integrated
    # with TinyQV - the implementation of this class will be replaces with a
    # different version that uses Risc-V instructions instead of the SPI test
    # harness interface to read and write the registers.
    tqv = TinyQV(dut, PERIPHERAL_NUM)

    # Reset
    await tqv.reset()

    random.seed(10)
    for i in range(1):

        ## ENCRYPT 
        #key  = os.urandom(16).hex()
        key = bytes(random.randrange(0, 256) for _ in range(16)).hex()
        print(key)
        key_ba = bytearray.fromhex(key)
        reg_offset = 0x04
        for word in range(4):
            key_slice = word*8
            reg_data = int(key[key_slice:key_slice+8],16)
            reg_addr = (3-word)*4 + reg_offset
            await tqv.write_word_reg(reg_addr, reg_data)

        #data  = os.urandom(16).hex()
        data = bytes(random.randrange(0, 256) for _ in range(16)).hex()
        print(data)
        data_ba = bytearray.fromhex(data)
        reg_offset = 0x14
        for word in range(4):
            data_slice = word*8
            reg_data = int(data[data_slice:data_slice+8],16)
            reg_addr = (3-word)*4 + reg_offset
            await tqv.write_word_reg(reg_addr, reg_data)

        cipher = AES.new(key_ba, AES.MODE_ECB)
        expected_result = cipher.encrypt(data_ba)
        expected_out = aes_encryption(data_ba, key_ba)

        await tqv.write_word_reg(0, 0x000000001)
        # Wait for two clock cycles to see the output values, because ui_in is synchronized over two clocks,
        # and a further clock is required for the output to propagate.
        await ClockCycles(dut.clk, 3)

        done = 0 
        while done == 0:
            await ClockCycles(dut.clk, 100)
            status =  await tqv.read_word_reg(0x24)
            done = status & 2

        reg_offset = 0x28
        result = "" 
        for word in range(4):
            result_slice = word*8
            reg_addr = (3-word)*4 + reg_offset
            result_word = await tqv.read_word_reg(reg_addr)
            result += f"{result_word:08x}"


        print(expected_result.hex())
        print(result)
        if (expected_result.hex() != result): 
            print("ERROR: %s not equal to %s"%(expected_result.hex(),result))
        assert expected_result.hex() == result



        # DECRYPT 
        await tqv.write_word_reg(0, 0x000000003)

        await ClockCycles(dut.clk, 9000)

        #done = 0 
        #while done == 0:
        #    await ClockCycles(dut.clk, 100)
        #    status =  await tqv.read_word_reg(0x24)
        #    done = status & 2





