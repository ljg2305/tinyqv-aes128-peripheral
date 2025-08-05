import aes128_type_pkg::*;

module aes128_fsm (
    input logic         clk_i, 
    input logic         rst_n_i,
    input logic          start_i, 
    input logic [1:0]    op_i, 
    input logic [127:0]  key_i, 
    input logic [127:0]  data_i, 
    output logic [127:0] result_o,
    output logic         valid_o, 
    output logic         ready_o 
    );
    import aes128_utils_pkg::*;

    // WORKING DATA REGISTER
    logic [127:0] working_data;

    // MAIN FSM SIGNALS
    enum int unsigned { WAIT, SUB_BYTES, MIX_ROWS, MIX_COLUMNS, ADD_ROUND_KEY, STORE_RESULT} current_state, next_state;

    // ROUND COUNTER SIGNALS
    logic [3:0]   round_counter;
    
    // SUB_BYTES SIGNALS
    logic [7:0]   sub_byte_data; 
    logic [3:0]   sub_byte_addr;
    logic         sub_byte_valid;
    logic         sub_byte_start;

    // MIX_ROWS SIGNALS
    logic [127:0] mix_rows_data; 

    // MIX_COLUMN SIGNALS
    logic [7:0]   mix_column_data; 
    logic [3:0]   mix_column_addr;
    logic         mix_column_valid;
    logic         mix_column_start;
    logic         mix_column_done;

    // ENCRYPT DECRYPT MODE SIG
    mode_t mode;
    //TODO remove hard coding capture mode on start_i
    assign mode = ENCRYPT;
   
    // KEY_EXPANSION
    logic [127:0] add_round_key_data; 
    logic         add_round_key_valid; 
    logic         add_round_Ket_request;

    // MAIN STATE MACHINE
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            current_state <= WAIT;
        end else begin
            current_state <= next_state; 
        end
    end

    always_comb begin 
        //DEFAULTS
        next_state = current_state;
        case (current_state) 
            WAIT:   if (start_i) next_state = ADD_ROUND_KEY;
            SUB_BYTES: begin 
                if (sub_byte_done) next_state = MIX_ROWS; 
            end 
            MIX_ROWS: begin 
                if (round_counter == 10) begin 
                    next_state = ADD_ROUND_KEY;
                end else begin 
                    next_state = MIX_COLUMNS;
                end 
            end
            MIX_COLUMNS: begin
                if (mix_column_done) next_state = ADD_ROUND_KEY; 
            end 
            ADD_ROUND_KEY: begin 
                if (add_round_key_valid) begin 
                    if (round_counter == 10) begin 
                        next_state = STORE_RESULT;
                    end else begin 
                        next_state = SUB_BYTES; 
                    end 
                end
            end 
            STORE_RESULT: next_state = WAIT; 
        endcase
    end 

    // WORKING DATA REG CONTROL
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            working_data <= 128'b0;
        end else begin
            case (current_state)  
                WAIT: begin  
                    working_data <= 128'b0;
                    if (start_i) working_data <= aes_reverse_bytes(data_i);
                end 
                SUB_BYTES: begin
                    // write byte by byte 
                    if (sub_byte_valid) begin 
                        working_data[sub_byte_addr * 8 +: 8] <= sub_byte_data;
                    end 
                end 
                MIX_ROWS: begin 
                    working_data <= mix_rows_data;
                end 
                MIX_COLUMNS: begin 
                    // write byte by byte 
                    if (mix_column_valid) begin 
                        working_data[mix_column_addr * 8 +: 8] <= mix_column_data;
                    end 
                end 
                ADD_ROUND_KEY: begin 
                    if (add_round_key_valid) begin  
                        working_data <=  working_data ^ add_round_key_data; 
                    end
                end 
            endcase
        end
    end

    // ROUND COUNTER 
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            round_counter <= '0; 
        end else begin
            case (current_state)  
                WAIT:          round_counter <= '0;
                ADD_ROUND_KEY: if (add_round_key_valid) round_counter <= round_counter+1;
            endcase
        end
    end

    // SUB_BYTES MODULE INST 
    assign sub_byte_start = (next_state==SUB_BYTES && current_state != SUB_BYTES);

    aes128_sub_bytes aes128_sub_bytes_inst (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i),
        .data_i(working_data), 
        .start_i(sub_byte_start), 
        .data_o(sub_byte_data), 
        .addr_o(sub_byte_addr), 
        .valid_o(sub_byte_valid),
        .done_o(sub_byte_done),
        .sbox_sub_o(), 
        .sbox_sub_i('0)
    );

    // MIX ROWS MODULE INST 
    aes128_mix_rows aes128_mix_rows_inst (
        .data_i(working_data), 
        .data_o(mix_rows_data) 
    );

    // MIX COLUMN MODULE INST 
    assign mix_column_start = (next_state==MIX_COLUMNS && current_state != MIX_COLUMNS);
    aes128_mix_column aes128_mix_column_inst (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i),
        .data_i(working_data), 
        .start_i(mix_column_start), 
        .mode_i(mode), 
        .data_o(mix_column_data), 
        .addr_o(mix_column_addr), 
        .valid_o(mix_column_valid),
        .done_o(mix_column_done)
    );

    // KEY EXPANSION 
    
    // ROUND KEYS CAN BE GENERATED AFTER SUB_BYTES ( TODO I WANT THEM TO SHARE THE
    // LUT for space saving) 
    
    // single cycle request pulse when main FSM transtions away from
    // sub_bytes. 
    
    assign add_round_key_request = (current_state == SUB_BYTES && next_state != SUB_BYTES); 
    aes128_key_expansion aes128_key_expansion_inst (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i),
        .key_i(key_i), 
        .start_i(start_i), 
        .key_req_i(add_round_key_request), 
        .key_o(add_round_key_data), 
        .valid_o(add_round_key_valid), 
        .sbox_sub_o(), 
        .sbox_sub_i('0)
        );

    // SHARED SBOX LUT
    // TODO 


    // STORE RESULT + SET RESET VALID
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            result_o <= 128'b0;
            valid_o  <= 1'b0; 
        end else begin
            if (current_state==STORE_RESULT) begin
                result_o <= aes_reverse_bytes(working_data);
                valid_o  <= 1'b1;
            end 
            if (start_i) valid_o <= 1'b0;
        end
    end

    // READY
    assign ready_o = (current_state==WAIT) ? 1'b1 : 1'b0;  

   initial begin
     $dumpfile("aes128_fsm.vcd");
     $dumpvars(0, aes128_fsm);
     #1;
   end 

endmodule 
