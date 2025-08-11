import aes128_type_pkg::*;

module aes128_mix_rows (
    input  mode_t         mode_i, 
    input  logic [127:0]  data_i, 
    output logic [127:0]  data_o
    );

    localparam NUM_ROWS = 4;
    localparam NUM_COLS = 4;

    logic [127:0] data_encrypt, data_decrypt; 

    genvar row; 
    genvar col; 
    generate 
        for (row = 0; row < NUM_ROWS; row++) begin 
            localparam int Shift = row; 
            localparam logic [1:0] BottomAddr = row; 
            for (col = 0; col < NUM_COLS; col++) begin 
                localparam logic [1:0] TopAddr = col;
                localparam logic [1:0] TopAddrShiftLeft = col - Shift; 
                localparam logic [1:0] TopAddrShiftRight = col + Shift; 
                localparam logic [3:0] Addr = {TopAddr,BottomAddr};
                localparam logic [3:0] ShiftAddrLeft = {TopAddrShiftLeft,BottomAddr};
                localparam logic [3:0] ShiftAddrRight = {TopAddrShiftRight,BottomAddr};
                assign data_encrypt[ShiftAddrLeft*8+:8] = data_i[Addr*8+:8];
                assign data_decrypt[ShiftAddrRight*8+:8] = data_i[Addr*8+:8];
            end 
        end 
    endgenerate
        
    always_comb begin
        unique case (mode_i)
            ENCRYPT: data_o = data_encrypt;
            DECRYPT: data_o = data_decrypt;
            default: data_o = data_encrypt;
        endcase
    end
        

endmodule 
