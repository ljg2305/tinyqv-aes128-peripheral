import aes128_type_pkg::*;

module aes128_fsm #(
    logic EXTERNAL_SBOX = 1
    )(
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

    //EXTERNAL SBOX
    logic [7:0] sub_byte_sbox_data_out;
    logic [7:0] sbox_data_out;
    logic [7:0] add_round_sbox_data_in;
    logic [7:0] sbox_data_in;
    logic       sbox_mode; 

    // ENCRYPT DECRYPT MODE SIG
    mode_t mode, mode_next;
    
   
    // KEY_EXPANSION
    logic [127:0] add_round_key_data; 
    logic         add_round_key_valid; 
    logic         add_round_key_request;
    logic [127:0] initial_key;
    logic         key_exp_start;
    logic         key_exp_request;
    logic         key_exp_valid; 
    logic [3:0]   key_counter;
    logic         decrypt_key_request;
    enum int unsigned { KEY_WAIT, DECRYPT_KEY_STATE} key_state;

    // MODE LOGIC
    always_comb begin 
        case (op_i)
            2'b0 : mode_next = ENCRYPT; 
            2'b1 : mode_next = DECRYPT; 
            default : mode_next = ENCRYPT; 
        endcase
    end 
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            mode <= ENCRYPT;
        end else begin
            if (current_state == WAIT && start_i) mode <= mode_next; 
        end
    end

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
        case ({mode,current_state}) 
            {ENCRYPT,WAIT}, {DECRYPT,WAIT}:   if (start_i) next_state = ADD_ROUND_KEY;
            {ENCRYPT,SUB_BYTES}: begin 
                if (sub_byte_done) next_state = MIX_ROWS; 
            end 
            {DECRYPT,SUB_BYTES}: begin 
                if (sub_byte_done) next_state = ADD_ROUND_KEY;
            end 
            {ENCRYPT,MIX_ROWS}: begin 
                if (round_counter == 10) begin 
                    next_state = ADD_ROUND_KEY;
                end else begin 
                    next_state = MIX_COLUMNS;
                end 
            end
            {DECRYPT,MIX_ROWS}: begin 
                next_state = SUB_BYTES;
            end
            {ENCRYPT,MIX_COLUMNS}: begin 
                if (mix_column_done) next_state = ADD_ROUND_KEY; 
            end 
            {DECRYPT,MIX_COLUMNS}: begin 
                if (mix_column_done) next_state = MIX_ROWS; 
            end 
            {ENCRYPT,ADD_ROUND_KEY}: begin 
                if (add_round_key_valid) begin 
                    if (round_counter == 10) begin 
                        next_state = STORE_RESULT;
                    end else begin 
                        next_state = SUB_BYTES; 
                    end 
                end
            end 
            {DECRYPT,ADD_ROUND_KEY}: begin 
                if (add_round_key_valid) begin 
                    if (round_counter == 10) begin 
                        next_state = STORE_RESULT;
                    end else if (round_counter == 0) begin 
                        next_state = MIX_ROWS; 
                    end else  begin 
                        next_state = MIX_COLUMNS; 
                    end 
                end
            end 
            {ENCRYPT,STORE_RESULT}, {DECRYPT,STORE_RESULT}: begin 
                next_state = WAIT; 
            end 
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

    aes128_sub_bytes #(.EXTERNAL_SBOX(EXTERNAL_SBOX)) aes128_sub_bytes_inst   (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i),
        .mode_i(mode),
        .data_i(working_data), 
        .start_i(sub_byte_start), 
        .data_o(sub_byte_data), 
        .addr_o(sub_byte_addr), 
        .valid_o(sub_byte_valid),
        .done_o(sub_byte_done),
        .sbox_sub_o(sub_byte_sbox_data_out), 
        .sbox_sub_i(sbox_data_out)
    );

    // MIX ROWS MODULE INST 
    aes128_mix_rows aes128_mix_rows_inst (
        .mode_i(mode),
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
   
    // KEY DATA REG CONTROL
    // ideally this would live in a submodule to keep things neat 
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            key_state <= KEY_WAIT;

            initial_key <= 128'b0;
            key_exp_start <= 1'b0;
            key_counter <= 4'b0; 
            decrypt_key_request <= 1'b0; 
        end else begin
            key_exp_start <= 1'b0;
            decrypt_key_request <= 1'b0; 
            case (key_state)  
                KEY_WAIT: begin  
                    if (start_i) begin 
                        key_exp_start <= 1'b1;
                        initial_key <= key_i;
                    end 
                    if (start_i || add_round_key_request) begin 
                        if (mode_next == DECRYPT) begin 
                            key_exp_start <= 1'b1;
                            key_counter <= '0; 
                            key_state <= DECRYPT_KEY_STATE; 
                        end 
                    end
                end 
                DECRYPT_KEY_STATE: begin 
                    if (key_counter == 10-round_counter) begin 
                        key_state <= WAIT; 
                    end else if (key_exp_valid && !decrypt_key_request) begin 
                        decrypt_key_request <= 1'b1; 
                        key_counter <= key_counter+1;
                    end 
                end 
            endcase
        end 
    end

    // single cycle request pulse when main FSM transtions away from
    // sub_bytes. 
    assign add_round_key_request = (current_state == SUB_BYTES && next_state != SUB_BYTES); 
    always_comb begin 
        case (mode) 
            ENCRYPT: begin 
                key_exp_request = add_round_key_request;
                add_round_key_valid = key_exp_valid; 
            end 
            DECRYPT: begin 
                key_exp_request = decrypt_key_request;
                add_round_key_valid = (key_counter == 10-round_counter) && (key_exp_valid && !decrypt_key_request); 
            end
            default: begin 
                key_exp_request = add_round_key_request;
                add_round_key_valid = key_exp_valid; 
            end 
        endcase
    end 

    aes128_key_expansion #(.EXTERNAL_SBOX(EXTERNAL_SBOX)) aes128_key_expansion_inst (
        .clk_i(clk_i), 
        .rst_n_i(rst_n_i),
        .key_i(initial_key), 
        .start_i(key_exp_start), 
        .key_req_i(key_exp_request), 
        .key_o(add_round_key_data), 
        .valid_o(key_exp_valid), 
        .sbox_sub_o(add_round_sbox_data_in), 
        .sbox_sub_i(sbox_data_out)
        );

    // SHARED SBOX LUT
     generate
        if (EXTERNAL_SBOX) begin 
            assign sbox_data_in = (current_state == SUB_BYTES) ? sub_byte_sbox_data_out : add_round_sbox_data_in;
            //for key expansion we always want to use the encrypt sbox
            assign sbox_mode    = (current_state == SUB_BYTES) ? mode : ENCRYPT;
            aes128_rijndael_sbox aes128_rijndael_sbox_inst (
                .mode_i(sbox_mode),
                .data_i(sbox_data_in),
                .data_o(sbox_data_out)
            );
        end else begin 
            assign sbox_data_out = '0; 
        end 
    endgenerate


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


`ifndef synthesis

   initial begin
     $dumpfile("aes128_fsm.vcd");
     $dumpvars(1, aes128_fsm);
   end 

`endif //synthesis

endmodule 
