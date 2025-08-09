import aes128_type_pkg::*;

module aes128_sub_bytes #(
    int N_BYTES = 16,
    logic EXTERNAL_SBOX = 0
    ) (
    input logic                     clk_i, 
    input logic                     rst_n_i,
    input [N_BYTES-1:0][7:0]        data_i, 
    input logic                     start_i, 
    output logic [7:0]              data_o, 
    output logic [3:0]              addr_o, 
    output logic                    valid_o,
    output logic                    done_o,
    // external S-BOX signals 
    output logic [7:0]              sbox_sub_o, 
    input logic  [7:0]              sbox_sub_i
    );

    // Rijndael S-Box LUT signals
    logic [7:0] sbox_data_in, sbox_data_out; 

    // State signals
    enum int unsigned { WAIT, OUTPUT } state, next_state;
    logic [3:0] byte_count;
    logic done;

    // Main State Machine
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            state <= WAIT;
        end else begin
            state <= next_state; 
        end
    end

    always_comb begin 
        valid_o = 1'b0; 
        addr_o  = 4'h0;
        data_o  = 8'h00; 
        sbox_data_in = 8'h00;
        next_state = state;
        case (state) 
            WAIT:   if (start_i) next_state = OUTPUT;
            OUTPUT: begin 
                if (byte_count >= N_BYTES-1) next_state = WAIT; 
                sbox_data_in  = data_i[byte_count];
                data_o = sbox_data_out;
                valid_o = 1'b1; 
                addr_o  = byte_count;
            end 
        endcase
    end 

    // Secondary Byte counter state
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            byte_count <= 4'b0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;
            if (state == OUTPUT) byte_count <= byte_count+1;
            else byte_count <= 4'b0; 

            if (state == OUTPUT) begin 
                if (byte_count >= N_BYTES-1) done <= 1'b1; 
            end
        end
    end

     generate
        if (EXTERNAL_SBOX) begin 
            assign sbox_sub_o = sbox_data_in;
            assign sbox_data_out = sbox_sub_i; 
        end else begin 
            assign sbox_sub_o = '0; 
            // Rijndael S-Box LUT signals
            aes128_rijndael_sbox aes128_rijndael_sbox_inst (
                .data_i(sbox_data_in),
                .data_o(sbox_data_out)
            );
        end 
    endgenerate
    
    // DONE SIGNAL 
    //assign done_o = (next_state==WAIT && state != WAIT) ? 1'b1 : 1'b0;
    assign done_o = done;

`ifndef synthesis
    initial begin
        $dumpfile("aes128_sub_bytes.vcd");
        $dumpvars(1, aes128_sub_bytes);
    end
`endif //synthesis

endmodule 
