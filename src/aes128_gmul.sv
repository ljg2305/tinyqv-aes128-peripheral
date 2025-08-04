import aes128_type_pkg::*;

module aes128_gmul (
    input logic         clk_i, 
    input logic         rst_n_i,
    input logic [7:0]   a_i, 
    input logic [7:0]   b_i, 
    input logic         start_i, 
    output logic [7:0]  result_o, 
    output logic        valid_o
    );

    // galois multiplier 
    // A is limited to <= 15
    // B is the input to be multiplied 
    
    logic [7:0] working_reg; 
    logic [7:0] result_reg; 

    logic [1:0] bit_count; 
    logic [1:0] shift_count; 

    
    // MAIN FSM SIGNALS
    enum int unsigned { WAIT, SHIFT, ADD, DONE } current_state, next_state;
     
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
            WAIT: if (start_i) next_state = ADD; // No shfiting required for bit 0
            SHIFT: next_state = ADD;
            ADD: begin 
                next_state = SHIFT; 
                if (bit_count == 3) next_state = DONE; 
                if ((4'b0001 << (bit_count+1)) > a_i) next_state = DONE; 
            end
            DONE: next_state = WAIT; 
        endcase
    end 

    // COUNTERS + REGS 
    always_ff @(posedge clk_i) begin
        if (!rst_n_i) begin
            shift_count <= 2'h0;
            bit_count   <= 2'h0;

            working_reg <= 8'h0;
            result_reg  <= 8'h0;
        end else begin
            case (current_state) 
                WAIT: begin 
                    shift_count <= 2'h0;
                    bit_count   <= 2'h0;
                    working_reg <= b_i;
                    if (start_i) result_reg <= 8'h00; 
                end 
                SHIFT: begin 
                    shift_count <= shift_count + 1; 
                    working_reg <= working_reg[7] ? (working_reg << 1) ^ 8'h1B : working_reg << 1; 
                end 
                ADD: begin 
                    bit_count <= bit_count + 1;
                    shift_count <=  '0;
                    if (a_i[bit_count]) result_reg <= result_reg ^ working_reg; 
                end 
            endcase
        end
    end

    // VALID 

    assign valid_o = (next_state == WAIT && current_state != WAIT) ? 1'b1 : 1'b0; 
    assign result_o = result_reg; 

    initial begin $dumpfile("aes128_gmul.vcd"); $dumpvars(0, aes128_gmul);
        #1;
    end

endmodule 
