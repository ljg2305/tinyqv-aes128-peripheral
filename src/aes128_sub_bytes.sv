module aes128_sub_bytes (
    input logic         clk_i, 
    input logic         rst_n_i,
    input logic [127:0] data_i, 
    input logic         start_i, 
    output logic [7:0]  data_o, 
    output logic [3:0]  addr_o, 
    output logic        valid_o,
    output logic        done_o
    );

    // Rijndael S-Box LUT signals
    logic [7:0] sbox_data_in, sbox_data_out; 

    // State signals
    enum int unsigned { WAIT, OUTPUT } state, next_state;
    logic [3:0] byte_count;

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
                if (byte_count >= 15) next_state = WAIT; 
                sbox_data_in  = data_i[byte_count*8+:8];
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
        end else begin
            if (state == OUTPUT) byte_count <= byte_count+1;
            else byte_count <= 4'b0; 
        end
    end

    // Rijndael S-Box LUT signals
    aes128_rijndael_sbox aes128_rijndael_sbox_inst (
        .data_i(sbox_data_in),
        .data_o(sbox_data_out)
    );
    
    // DONE SIGNAL 
    assign done_o = (next_state==WAIT && state != WAIT) ? 1'b1 : 1'b0;

  initial begin
    $dumpfile("aes128_sub_bytes.vcd");
    $dumpvars(0, aes128_sub_bytes);
    #1;
  end

endmodule 
