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
    for i in range(12):

        interrupt_en = 1; 

        ## ENCRYPT 
        # WRITE KEY
        key = bytes(random.randrange(0, 256) for _ in range(16)).hex()
        print("KEY: %s"%key)
        key_ba = bytearray.fromhex(key)
        reg_offset = 0x04
        for word in range(4):
            key_slice = word*8
            reg_data = int(key[key_slice:key_slice+8],16)
            reg_addr = (3-word)*4 + reg_offset
            await tqv.write_word_reg(reg_addr, reg_data)

        # WRITE DATA
        data = bytes(random.randrange(0, 256) for _ in range(16)).hex()
        data_ba = bytearray.fromhex(data)
        reg_offset = 0x14
        for word in range(4):
            data_slice = word*8
            reg_data = int(data[data_slice:data_slice+8],16)
            reg_addr = (3-word)*4 + reg_offset
            await tqv.write_word_reg(reg_addr, reg_data)

        # CALCULATE EXPECTED 
        cipher = AES.new(key_ba, AES.MODE_ECB)
        expected_result = cipher.encrypt(data_ba)

        # START ENCRYPT 
        # start by writing 1 to addr 0 
        reg_data = ctrl_reg(start=1,op=0,interrupt_en=interrupt_en)
        print(reg_data)
        await tqv.write_word_reg(0, reg_data)
        await ClockCycles(dut.clk, 3)

        # AWAIT RESULT 
        done = 0 
        while done == 0:
            await ClockCycles(dut.clk, 100)
            status =  await tqv.read_word_reg(0x24)
            done = status & 2

        # READ RESULT 
        reg_offset = 0x28
        result = "" 
        for word in range(4):
            result_slice = word*8
            reg_addr = (3-word)*4 + reg_offset
            result_word = await tqv.read_word_reg(reg_addr)
            result += f"{result_word:08x}"


        # CHECK RESULT 
        print("encrypt expected: %s"%expected_result.hex())
        print("encrypt result  : %s"%result)
        if (expected_result.hex() != result): 
            print("ERROR: %s not equal to %s"%(expected_result.hex(),result))
        assert expected_result.hex() == result

        # CHECK INTERRUPT  
        assert await tqv.is_interrupt_asserted()
        # Interrupt doesn't clear
        await ClockCycles(dut.clk, 10)
        assert await tqv.is_interrupt_asserted()
        # Write bottom bit of address 8 high to clear
        ctrl_read  = await tqv.read_word_reg(0)
        clear_data = ctrl_read | (1<<7) 
        await tqv.write_byte_reg(0, clear_data)
        assert not await tqv.is_interrupt_asserted()


        ## DECRYPT 

        # WRITE DATA
        data = expected_result.hex()
        data_ba = bytearray.fromhex(data)
        reg_offset = 0x14
        for word in range(4):
            data_slice = word*8
            reg_data = int(data[data_slice:data_slice+8],16)
            reg_addr = (3-word)*4 + reg_offset
            await tqv.write_word_reg(reg_addr, reg_data)


        # START DECRYPT 
        # start by writing 1 and set op to 1 to addr 0 
        reg_data = ctrl_reg(start=1,op=1,interrupt_en=interrupt_en)
        await tqv.write_word_reg(0, reg_data)

        # CALCULATE EXPECTED 
        expected_result = cipher.decrypt(data_ba)
        await ClockCycles(dut.clk, 3)

        # AWAIT RESULT 
        done = 0 
        while done == 0:
            await ClockCycles(dut.clk, 100)
            status =  await tqv.read_word_reg(0x24)
            done = status & 2

        # READ RESULT 
        reg_offset = 0x28
        result = "" 
        for word in range(4):
            result_slice = word*8
            reg_addr = (3-word)*4 + reg_offset
            result_word = await tqv.read_word_reg(reg_addr)
            result += f"{result_word:08x}"


        # CHECK RESULT 
        print("decrypt expected: %s"%expected_result.hex())
        print("decrypt result  : %s"%result)
        if (expected_result.hex() != result): 
            print("ERROR: %s not equal to %s"%(expected_result.hex(),result))
        assert expected_result.hex() == result

        # CHECK INTERRUPT  
        assert await tqv.is_interrupt_asserted()
        # Interrupt doesn't clear
        await ClockCycles(dut.clk, 10)
        assert await tqv.is_interrupt_asserted()
        # Write bottom bit of address 8 high to clear
        ctrl_read  = await tqv.read_word_reg(0)
        clear_data = ctrl_read | (1<<7) 
        await tqv.write_byte_reg(0, clear_data)
        assert not await tqv.is_interrupt_asserted()

def ctrl_reg(start=None,op=None,interrupt_en=None,reg_data=0):
    # bit 0 
    if start != None: 
        reg_data = reg_data | start
    # bit 1 to 2 
    if op != None: 
        #mask op bits 
        mask = 0b11111111111111111111111111111001 
        reg_data = reg_data & mask
        reg_data = reg_data | (op << 1)
    #bit 3
    if interrupt_en != None: 
        #mask op bits 
        mask = 0b11111111111111111111111111110111 
        reg_data = reg_data & mask
        reg_data = reg_data | (interrupt_en << 3)

    return reg_data
