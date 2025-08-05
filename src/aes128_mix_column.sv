import aes128_type_pkg::*;

module aes128_mix_column (
    input logic         clk_i, 
    input logic         rst_n_i,
    input logic [127:0] data_i, 
    input logic         start_i, 
    input mode_t         mode_i,
    output logic [7:0]  data_o, 
    output logic [3:0]  addr_o, 
    output logic        valid_o,
    output logic        done_o
    );

    // 65 cycles
    // matrix muliplication of:
    // [ 2 3 1 1 ] [ c0 ]
    // | 1 2 3 1 | | c1 |
    // | 1 1 2 3 | | c2 |
    // [ 3 1 1 2 ] [ c3 ] 
    // for each column.
    // as the values are just rotated we 
    // only need to store one row
    // with multiplication complete we just need to drive the logic 
    // we only want one multiplier so have a single working reg that gets
    // added to. 
    //
    // for each column 
    //  for each result_row
    //    matrix_index = (0 - row)
    //    set working reg to 0 
    //    for each row 
    //      multiply and add working reg 
    //          store in working reg
    //      matrix_index + 1 
    //    send valid result 
    //    
    
    // MAIN FSM SIGNALS
    enum int unsigned { WAIT, LOAD, MULTIPLY, DONE } current_state, next_state;
    
    // COUNTER SIGNALS
    logic [1:0] col_counter; 
    logic [1:0] next_col_counter; 
    logic [1:0] row_counter; 
    logic [1:0] multiplication_idx; 
    logic [5:0] counter;
    
    // MULTIPLICATION SIGNALS
    logic [7:0] mul_in_a, mul_in_b, mul_out; 
    logic       mul_start, mul_valid;
    logic [1:0] matrix_idx;

    // RESULT SIGNALS
    logic [31:0] col_reg; 
    logic [7:0] working_reg; 


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
            WAIT: if (start_i) next_state = LOAD;
            LOAD: next_state = MULTIPLY; 
            MULTIPLY: begin 
                if (counter == '1 && mul_valid) next_state = DONE;
            end
            DONE: next_state = WAIT; 
        endcase
    end 


    // COUNTER SIGNALS
    assign col_counter        = counter[5:4];
    assign row_counter        = counter[3:2];
    assign multiplication_idx = counter[1:0];
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            counter <= '0;
        end else begin
            if (current_state==MULTIPLY) begin 
                //automatic overflow to 0 in WAIT state
                if (mul_valid) counter <= counter + 1;  
            end 
        end
    end 

    //MULTIPLIER 
    assign mul_in_b = col_reg[(multiplication_idx)*8+:8];
    assign matrix_idx = multiplication_idx - row_counter;

    always_comb begin
        case (mode_i)
            ENCRYPT: begin  
                case (matrix_idx)
                    4'h0 : mul_in_a = 2;  
                    4'h1 : mul_in_a = 3;
                    4'h2 : mul_in_a = 1;  
                    4'h3 : mul_in_a = 1;
                endcase
            end
            DECRYPT: begin  
                case (matrix_idx)
                    4'h0 : mul_in_a = 14;  
                    4'h1 : mul_in_a = 11;
                    4'h2 : mul_in_a = 13;  
                    4'h3 : mul_in_a = 9;
                endcase
            end
        endcase
    end

    assign mul_start = (current_state == MULTIPLY);

    aes128_gmul aes128_gmul_inst (
        .clk_i(clk_i),
        .rst_n_i(rst_n_i),
        .a_i(mul_in_a), 
        .b_i(mul_in_b), 
        .start_i(mul_start), 
        .result_o(mul_out),
        .valid_o(mul_valid)
    );

    // RESULT CALC 
    assign next_col_counter = col_counter+1; 
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            working_reg <= '0;
            valid_o <= 1'b0;
            col_reg <= 1'b0;
        end else begin
            valid_o <= 1'b0;
            case (current_state)
                LOAD: begin 
                   col_reg <= data_i[col_counter*32 +: 32];
                end 
                MULTIPLY: begin 
                    if (mul_valid) begin 
                        if (multiplication_idx == 3) begin 
                            valid_o <= 1'b1;
                        end 
                        if (multiplication_idx == 0) begin 
                            working_reg <= mul_out; 
                        end else begin 
                            working_reg <= working_reg ^ mul_out; 
                        end 
                        if ( multiplication_idx == 3 && row_counter == 3 ) begin 
                            col_reg <= data_i[next_col_counter*32 +: 32];
                        end 
                    end 
                end
            endcase
        end
    end 
    
    // flops are precious in this implmentation. when the data is valid the
    // adress has already incremented so row counter - 1 gets the last address
    assign addr_o = (col_counter << 2) + (row_counter-1); 
    assign data_o = working_reg; 

    // DONE SIGNAL 
    assign done_o = (next_state==WAIT && current_state != WAIT) ? 1'b1 : 1'b0;

    initial begin
        $dumpfile("aes128_mix_column.vcd");
        $dumpvars(0, aes128_mix_column);
        #1;
    end
endmodule 


