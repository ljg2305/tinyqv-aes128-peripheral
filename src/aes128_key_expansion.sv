import aes128_type_pkg::*;

module aes128_key_expansion #(
    logic EXTERNAL_SBOX = 0
    ) (
    input logic          clk_i, 
    input logic          rst_n_i,
    input logic [127:0]  key_i, 
    input logic          start_i, 
    input logic          key_req_i, 
    output logic [127:0] key_o, 
    output logic [127:0] key_big_end_o, 
    output logic         valid_o, 
    // external S-BOX signals 
    output logic   [7:0] sbox_sub_o, 
    input logic    [7:0] sbox_sub_i
    );

    import aes128_utils_pkg::*;

    localparam int WORD_LENGTH = 4;
    
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

    logic [127:0] working_key; 
    logic [31:0]  working_manip;
    logic         key_valid; 
    
    // MAIN FSM SIGNALS
    enum int unsigned { WAIT, ROT, SUB, RCON, XOR, DONE } current_state, next_state;

    // ROT WORD SIGNALS
    logic [31:0]  rot_word_data; 

    // SUB_BYTES SIGNALS
    logic [7:0]   sub_byte_data; 
    logic [3:0]   sub_byte_addr;
    logic         sub_byte_valid;
    logic         sub_byte_start;
    
    // ROUND CONST SIGNALS
    logic [7:0] round_const;

    //XOR SIGNALS
    logic [1:0] xor_count; 

    // KEY FLIP
    logic [128:0] input_key; 
    assign input_key = aes_reverse_bytes(key_i);

    // MAIN STATE MACHINE
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            current_state <= WAIT;
        end else begin
            current_state <= next_state; 
        end
    end

    always_comb begin 
        //Default 
        next_state = current_state; 
        case (current_state)
            WAIT:   if (key_req_i) next_state = ROT;
            ROT:    next_state = SUB;
            SUB: begin 
                if (sub_byte_done) next_state = RCON; 
            end 
            RCON:   next_state = XOR; 
            XOR:    if (xor_count == 2'h3) next_state = DONE;
            DONE:   next_state = WAIT;
        endcase
    end 

    // KEY EXPANSION LOGIC
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            working_key <= '0;
            working_manip <= '0; 
            key_valid   <= 1'b0; 
        end else begin
            case (current_state) 
                WAIT: begin 
                    if (start_i) begin 
                        working_key <= input_key;
                        key_valid   <= 1'b1;
                        working_manip <= input_key[12*8+:32];
                    end 
                    if (key_req_i) begin 
                        key_valid   <= 1'b0;
                    end 
                end 
                ROT: begin 
                    working_manip <= rot_word_data;
                end 
                SUB: begin
                    // write byte by byte 
                    if (sub_byte_valid) begin 
                        working_manip[sub_byte_addr * 8 +: 8] <= sub_byte_data;
                    end 
                end 
                RCON: begin 
                    working_manip <= working_manip ^ {24'b0,round_const}; 
                end
                XOR: begin 
                    if (xor_count == 0) begin 
                        working_key[xor_count*32 +: 32] <= working_manip ^ working_key[xor_count*32 +: 32]; 
                    end else begin 
                        working_key[xor_count*32 +: 32] <= working_key[(xor_count-1)*32 +: 32] ^ working_key[xor_count*32 +: 32]; 
                    end
                end 
                DONE: begin 
                    working_manip <= working_key[127:96];
                    key_valid <= 1'b1; 
                end
            endcase
        end
    end

    // ROT WORD LOGIC
    genvar i; 
    generate 
        for (i = 0; i < WORD_LENGTH; i++) begin 
            localparam logic [1:0] SourceAddr = i;
            //synthesis needs explicit overflow for localparam it seems
            localparam logic [1:0] DestAddr = (i == 0) ? 3: i-1;
            assign rot_word_data[DestAddr*8+:8] = working_manip[SourceAddr*8+:8];
        end 
    endgenerate

    // SUB_BYTES MODULE INST 
    assign sub_byte_start = (next_state==SUB && current_state != SUB);

    aes128_sub_bytes  #(.EXTERNAL_SBOX(EXTERNAL_SBOX), .N_BYTES(WORD_LENGTH)) aes128_sub_bytes_inst (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i),
        .data_i(working_manip), 
        .start_i(sub_byte_start), 
        .data_o(sub_byte_data), 
        .addr_o(sub_byte_addr), 
        .valid_o(sub_byte_valid),
        .done_o(sub_byte_done),
        .sbox_sub_o(sbox_sub_o), 
        .sbox_sub_i(sbox_sub_i)
    );

    // ROUND CONST LOGIC

    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            round_const <= 8'h00;
        end else begin
            case (current_state)
                WAIT: begin 
                    if (start_i) round_const <= 8'h00;
                    if (key_req_i) begin 
                        if (round_const == 8'h00) begin 
                            round_const <= 8'h01; 
                        end else begin 
                            round_const <= round_const[7] ? (round_const << 1) ^ 8'h1B : round_const << 1; 
                        end 
                    end 
                end
            endcase 
        end 
    end 

    // XOR COUNTER
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            xor_count <= 2'h0;
        end else begin
            case (current_state) 
                WAIT: begin 
                    xor_count <= 2'h0;
                end 
                XOR: begin 
                    xor_count <= xor_count + 1; 
                end 
            endcase
        end
    end

    // KEY OUTPUT 
    assign key_o = working_key;
    assign key_big_end_o = aes_reverse_bytes(working_key); 
    assign valid_o = key_valid; 

`ifndef synthesis
   initial begin
     $dumpfile("aes128_key_expansion.vcd");
     $dumpvars(1, aes128_key_expansion);
   end 
`endif //synthesis

endmodule 
