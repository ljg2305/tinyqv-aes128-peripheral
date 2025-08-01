module aes128_mix_rows (
    input  logic [127:0]  data_i, 
    output logic [127:0]  data_o
    );

    localparam NUM_ROWS = 4;
    localparam NUM_COLS = 4;

    genvar row; 
    genvar col; 
    generate 
        for (row = 0; row < NUM_ROWS; row++) begin 
            localparam int Shift = row; 
            localparam logic [1:0] BottomAddr = row; 
            for (col = 0; col < NUM_COLS; col++) begin 
                localparam logic [1:0] TopAddr = col;
                localparam logic [1:0] TopAddrShift = col - Shift; 
                localparam logic [3:0] Addr = {TopAddr,BottomAddr};
                localparam logic [3:0] ShiftAddr = {TopAddrShift,BottomAddr};
                assign data_o[ShiftAddr*8+:8] = data_i[Addr*8+:8];
            end 
        end 
    endgenerate
        
        

endmodule 
