import aes128_type_pkg::*;

module aes128_key_expansion (
    input logic          clk_i, 
    input logic          rst_n_i,
    input logic [127:0]  key_i, 
    input logic          start_i, 
    input logic          key_req_i, 
    output logic [127:0] key_o, 
    output logic         valid_o
    );
    
    // start_i 
    //  flop key into register 
    //  set valid high 
    //  await next key request
    //
    //  key_req_i:
    //  set valid low
    //  take top 4 bytes, ROT, SUB, RCON into new reg
    //  xor cascade though 16 bytes (4 bytes at time)
    //  set valid high 
    //  

    logic 


endmodule 
