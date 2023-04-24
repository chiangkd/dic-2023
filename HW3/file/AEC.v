module AEC(clk, rst, ascii_in, ready, valid, result);

// Input signal
input clk;
input rst;
input ready;
input [7:0] ascii_in;

// Output signal
output reg valid;
output reg [6:0] result;

reg [6:0] data [0:15];
reg [3:0] data_index, data_num;
reg [6:0] out_string [0:15];  // output out_string
reg [6:0] stack [0:15];   // stack
reg [3:0] out_string_index, stack_index;

localparam DATA_IN = 2'd0;
localparam POPSINGLE = 2'd1;
localparam POPMULT = 2'd2;
localparam CALCULATION_AND_OUTPUT = 2'd3;

reg [2:0] CurrentState, NextState;
reg [4:0] i;

initial begin
    data_index = 4'd0;
    data_num = 4'd0;
    out_string_index = 4'd0;
    stack_index = 4'd0;
end

wire [3:0] simo = stack_index - 4'd1;   // stack index - 1 (for calculation stage)
wire [3:0] simt = stack_index - 4'd2;   // stack index - 2 (for calculation stage)

/* State register (Sequential) */
always @(posedge clk) begin
    if(rst) CurrentState <= DATA_IN;
    else CurrentState <= NextState;
end

always @(posedge clk) begin
    if(rst) begin
        for(i = 0; i < 5'b1_0000; i = i + 5'b1) begin 
            data[i] <= 7'b000_0000; 
            out_string[i] <= 7'b000_0000;
            stack[i] <= 7'b000_0000;
        end
        data_index <= 0;
    end
    else begin
        case(CurrentState)
            DATA_IN: begin
                valid <= 0;
                for(i = 0; i < 5'b1_0000; i = i + 5'b1) begin 
                    out_string[i] <= 7'b000_0000;
                    stack[i] <= 7'b000_0000;
                end
                if(!(ascii_in ^ 8'b0011_1101 /* 61 */)) begin
                    data_num <= data_index;
                    data_index <= 4'd0;
                end
                else begin
                    /* 
                     * ( ) * +          => 0010_1000 ~ 0010_1101        (do not modify this)
                     * 0 ~ 9            => 0011_0000 ~ 0011_1001        (translate to binary code represent decimal, 0000_0000 ~ 0000_1001)
                     * a(10) ~ f(15)    => 0110_0001 ~ 0110_0110        (translate to binary code represent decimal, 0000_1010 ~ 0000_1111)
                     */
                    data[data_index] <= (ascii_in[6:4] ^ 3'b010) ? ((ascii_in[4] & 1'b1) ?  (ascii_in[3:0]): (ascii_in[3:0] + 4'b1001)) : ascii_in[6:0];
                    data_index <= data_index + 4'b1; 
                end
            end
            POPSINGLE: begin
                if(out_string_index < data_num ) begin   // no done yet
                    if(!(data[data_index] ^ 7'b010_1000 /* 40 */)) begin   // if detect "(", force push
                    stack[stack_index] <= data[data_index];
                    stack_index <= stack_index + 4'b1;
                    data_index <= data_index + 4'b1;
                    end
                    else if(!(data[data_index] ^ 7'b010_1001 /* 41 */)) begin   // if detect ")", force pop stack
                        out_string[out_string_index] <= stack[stack_index - 4'b1];
                        out_string_index <= out_string_index + 4'b1;
                        stack_index <= stack_index - 4'b1;
                        data_index <= data_index + 4'b1;
                    end
                                    /* 42 (0010_1010) ~ 45 (0010_1101) */
                    else if(!(data[data_index][5:3] ^ 3'b101) && (data[data_index][2:0] & 3'b110)) begin  // detect operator
                        if(!(stack[stack_index - 4'b1] ^ 7'b010_1000 /* 40 */)) begin    // if stack is "(", force push to stack
                            stack[stack_index] <= data[data_index];
                            stack_index <= stack_index + 4'b1;
                            data_index <= data_index + 4'b1;
                        end
                        else if((stack[stack_index - 4'b1] != 0 ) && (stack[stack_index - 4'b1][0]) <= (data[data_index][0])) begin    // stack oper is prior than data oper.
                            out_string[out_string_index] <= stack[stack_index - 4'b1]; // push the popped element to out_string
                            out_string_index <= out_string_index + 4'b1;
                            stack_index <= stack_index - 4'b1;  // pop stack
                        end
                        else if(out_string_index + stack_index < data_num) begin
                            stack[stack_index] <= data[data_index]; // push data to stack
                            stack_index <= stack_index + 4'b1; // push stack
                            data_index <= data_index + 4'b1;
                        end
                        else begin
                            stack_index <= stack_index - 4'b1;
                        end
                    end
                    else if(out_string_index + stack_index == data_num) begin   // data over, but stack not empty
                        out_string[out_string_index] <= stack[stack_index-4'b1];
                        out_string_index <= out_string_index + 4'b1;
                        stack_index <= stack_index - 4'b1;
                    end
                    else begin  // detect number, push to out_string
                        out_string[out_string_index] <= data[data_index];
                        out_string_index <= out_string_index + 4'b1;
                        data_index <= data_index + 4'b1;
                    end
                end
                else begin
                    out_string_index <= 0; // reset out_string index and next do the calculation
                end
            end
            POPMULT: begin
                if(!(stack[stack_index - 4'b1] ^ 7'b010_1000 /* 40 */)) begin  // discard "("
                    stack_index <= stack_index - 4'b1;
                    data_num <= data_num - 4'd2;
                end
                else if(stack_index) begin  // pop until stack is empty
                    out_string[out_string_index] <= stack[stack_index - 1];
                    out_string_index <= out_string_index + 4'b1;
                    stack_index <= stack_index - 4'b1;
                end
                else begin
                    data_num <= out_string_index;   // reuse number counter, the counter will be out_string index
                    out_string_index <= 0; // reset out_string index and next do the calculation
                    stack_index <= 0;   // reset stack index to reuse the stack
                end
            end
            CALCULATION_AND_OUTPUT: begin  // now out_string_index = 0, stack_index = 0, reuse the stack
                if(out_string_index == data_num) begin
                    result <= stack[0];
                    valid <= 1;
                    for(i = 0; i < 5'b1_0000; i = i + 5'b1) begin 
                        data[i] <= 7'b000_0000; 
                        out_string[i] <= 7'b000_0000;
                        stack[i] <= 7'b000_0000;
                    end
                    stack_index <= 0;
                    out_string_index <= 0;
                    data_index <= 0;
                    data_num <= 0;
                end                                             /* 42 (0010_1010) ~ 45 (0010_1101) */
                else if(/*out_string[out_string_index] >= 42*/ (!(out_string[out_string_index][5:3] ^ 3'b101) && (out_string[out_string_index][2:0] & 3'b110)) /*(out_string[out_string_index] <= 45)*/) begin  // detect operator, pop two number from the stack, calculate it and re-push back to stack
                    case(out_string[out_string_index])
                        42: stack[simt] <= stack[simt] * stack[simo];
                        43: stack[simt] <= stack[simt] + stack[simo];
                        45: stack[simt] <= stack[simt] - stack[simo];
                    endcase
                    out_string_index <= out_string_index + 4'b1;
                    stack_index <= stack_index - 4'b1;
                end
                else begin  // detect number, push the number to stack
                    stack[stack_index] <= out_string[out_string_index];
                    stack_index <= stack_index + 4'b1;
                    out_string_index <= out_string_index + 4'b1;
                end
            end
            default: valid <= 0;
        endcase
    end
end

/* Next-state logic (Combinational) */
always @(*) begin
    case(CurrentState)
        DATA_IN:begin
            if(!(ascii_in ^ 8'b0011_1101 /* 61 */)) NextState = POPSINGLE;
            else NextState = DATA_IN;
        end
        POPSINGLE: begin
            if(out_string_index == data_num && !stack_index) NextState = CALCULATION_AND_OUTPUT;
            else if(out_string_index + stack_index == data_num) NextState = POPMULT;
            else if(!(data[data_index] ^ 7'b010_1001 /* 41 */)) NextState = POPMULT;    // detect ")"
            else NextState = POPSINGLE;
        end
        POPMULT:begin // check to pop stack 
            if(!(stack[stack_index - 1] ^ 7'b010_1000 /* 40 */)) NextState = POPSINGLE; // detect ")", back to POPSINGLE
            else if(!stack_index) NextState = CALCULATION_AND_OUTPUT;
            else NextState = POPMULT;
        end
        CALCULATION_AND_OUTPUT:begin
            if(valid) NextState = DATA_IN;
            else NextState = CALCULATION_AND_OUTPUT;
        end
    endcase
end

endmodule