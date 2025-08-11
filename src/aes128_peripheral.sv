/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.
module aes128_peripheral (
    input logic        clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input logic        rst_n,        // Reset_n - low to reset.

    input logic  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output logic [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input logic [5:0]   address,      // Address within this peripheral's address space
    input logic [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input logic [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input logic [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output logic [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output logic        data_ready,

    output logic        user_interrupt  // Dedicated interrupt request for this peripheral
);

    
    // +------+---------+--------+-------------------------------------------------------------------+
    // | Addr |  Name   | Width  |                               Desc                                |
    // +------+---------+--------+-------------------------------------------------------------------+
    // | READ WRITE                                                                                  |
    // | 0x00 | CTRL    | 32     | Bit 0; Start (flappy) Bit 1-2; Operation (Encrypt,Decrypt),       |
    // |      |         |        | Bit 3; Interrupt Enable                                           |
    // | 0x04 | KEY0    | 32-bit | AES Key [31:0]                                                    |
    // | 0x08 | KEY1    | 32-bit | AES Key [63:32]                                                   |
    // | 0x0C | KEY2    | 32-bit | AES Key [95:64]                                                   |
    // | 0x10 | KEY3    | 32-bit | AES Key [127:96]                                                  |
    // | 0x14 | DATA0   | 32-bit | Input block [31:0]                                                |
    // | 0x18 | DATA1   | 32-bit | Input block [63:32]                                               |
    // | 0x1C | DATA2   | 32-bit | Input block [95:64]                                               |
    // | 0x20 | DATA3   | 32-bit | Input block [127:96]                                              |
    // | READ ONLY                                                                                   |
    // | 0x24 | STATUS  | 32     | Bit 0; Ready, Bit 1; Done (read only)                             |
    // | 0x28 | RESULT0 | 32-bit | Output block [31:0]    (read only)                                |
    // | 0x2C | RESULT1 | 32-bit | Output block [63:32]   (read only)                                |
    // | 0x30 | RESULT2 | 32-bit | Output block [95:64]   (read only)                                |
    // | 0x34 | RESULT3 | 32-bit | Output block [127:96]  (read only)                                |
    // +------+---------+--------+-------------------------------------------------------------------+


    // Implement a 32-bit read/write register at address 0
    
    parameter int NUM_REGS = 14;
    parameter int NUM_RW_REGS = 9;
    logic [3:0] word_address;
    logic [31:0] registers    [NUM_RW_REGS-1:0];
    logic [31:0] register_out [NUM_REGS-1:0];

    logic start; 
    logic [1:0] op; 
    logic interrupt_en; 
    logic [127:0] key; 
    logic [127:0] data;
    logic valid; 
    logic ready; 
    logic [127:0] result; 

    
    assign word_address = address[5:2];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
          for (int i = 0; i <= NUM_RW_REGS; i++)
            registers[i] = 0;
        end else begin
            if (word_address <= NUM_RW_REGS-1) begin
                if (data_write_n != 2'b11)              registers[word_address][7:0]   <= data_in[7:0];
                if (data_write_n[1] != data_write_n[0]) registers[word_address][15:8]  <= data_in[15:8];
                if (data_write_n == 2'b10)              registers[word_address][31:16] <= data_in[31:16];
            end
            // create single cycle pulse for start, reset to 0 
            if (registers[0][0]) registers[0][0] <= 1'b0;
        end
    end

    always_comb begin 
        if (word_address <= NUM_REGS) begin
            data_out = register_out[word_address]; 
        end else begin 
            data_out = 32'b0;
        end
    end 

    assign start        = registers[0][0];
    assign op           = registers[0][2:1];
    assign interrupt_en = registers[0][3];

    assign key          = {registers[4],registers[3],registers[2],registers[1]};
    assign data         = {registers[8],registers[7],registers[6],registers[5]};

    genvar i;
    generate
      for (i = 0; i <= 8; i++) begin : reg_assign
        assign register_out[i] = registers[i];
      end
    endgenerate
    assign register_out[9]    = {30'b0,valid,ready};
    assign register_out[10]   = result[31:0];
    assign register_out[11]   = result[63:32];
    assign register_out[12]   = result[95:64];
    assign register_out[13]   = result[127:96];

    // LOGIC 
    aes128_fsm aes128_fsm_inst (
        .clk_i(clk), 
        .rst_n_i(rst_n),
        .start_i(start), 
        .op_i(op), 
        .key_i(key), 
        .data_i(data), 
        .result_o(result),
        .valid_o(valid), 
        .ready_o(ready) 
        );

    // IO 
    //
    // All reads complete in 1 clock
    assign data_ready = 1;

    assign user_interrupt = 1'b0;

    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    wire _unused = &{data_read_n, 1'b0};

endmodule
