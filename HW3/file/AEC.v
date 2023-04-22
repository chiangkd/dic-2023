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

reg [6:0] string [0:15];  // output string
reg [6:0] stack [0:15];   // stack

reg [3:0] string_index, stack_index;

localparam DATA_IN = 3'd0;
localparam POPSINGLE = 3'd1;
localparam POPMULT = 3'd2;
localparam CALCULATION = 3'd3;
localparam OUTPUT = 3'd4;

reg [2:0] CurrentState, NextState;

initial begin
    data_index = 4'd0;
    data_num = 4'd0;
    string_index = 4'd0;
    stack_index = 4'd0;
end

always @(*) begin
    case(CurrentState)
        DATA_IN:begin
        end
        POPMULT:begin
            
        end
        CALCULATION:begin
            
        end
        OUTPUT:begin
            
        end
    endcase
end

/* State register (Sequential) */
always @(posedge clk) begin
    if(rst) CurrentState <= DATA_IN;
    else CurrentState <= NextState;
end

always @(posedge clk) begin
    if(rst) begin
        data_index <= 0;
    end
    else begin
        case(CurrentState)
            DATA_IN: begin
                if(ascii_in == 61) begin
                    data_num <= data_index;
                    data_index <= 4'd0;
                end
                // else if(ascii_in >= 97)
                else begin
                    /* 
                     * ( ) * +          => 0010_1000 ~ 0010_1101        (do not modify this)
                     * 0 ~ 9            => 0011_0000 ~ 0011_1001        (translate to binary code represent decimal, 0000_0000 ~ 0000_1001)
                     * a(10) ~ f(15)    => 0110_0001 ~ 0110_0110        (translate to binary code represent decimal, 0000_1010 ~ 0000_1111)
                     */
                    data[data_index] <= ();
                    // data[data_index] <= (ascii_in >= 97 && ascii_in <= 102) ? ascii_in - 40: ascii_in; // pre-offset the offset of ASCII code
                    data_index <= data_index + 1; 
                end
            end
            POPSINGLE: begin
                if((data[data_index] >= 40) && (data[data_index] <= 45)) begin
                    if(stack[stack_index] >= data[data_index]) begin    // pop out
                        string[string_index] <= stack[stack_index];
                        string_index = string_index + 1;    // push the popped element to string
                        stack_index = stack_index - 1;  // pop stack
                    end
                    else if(string_index + stack_index < data_num) begin  // push to stack
                        stack[stack_index] <= data[data_index]; // push data to stack
                        stack_index <= stack_index + 1; // push stack
                    end
                end
                else if(string_index + stack_index < data_num) begin
                    string[string_index] <= data[data_index];
                    string_index <= string_index + 1;
                end


                // if((data[data_index] >=48) && (data[data_index] <= 57) || (data[data_index] >= 97) && (data[data_index] <= 102)) begin  // push to string
                //     string[string_index] <= data[data_index];
                //     string_index <= string_index + 1;
                // end
                // else begin
                //     if(stack[stack_index] >= data[data_index]) begin    // pop out
                //         string[string_index] <= stack[stack_index];
                //         string_index = string_index + 1;    // push the popped element to string
                //         stack_index = stack_index - 1;  // pop stack
                //     end
                //     else if(string_index + stack_index < data_num) begin  // push to stack
                //         stack[stack_index] <= data[data_index]; // push data to stack
                //         stack_index <= stack_index + 1; // push stack
                //     end
                // end
                data_index <= data_index + 1;
            end
            POPMULT: begin
                if(data[data_index] == 41)begin // detect ")"
                    if(data[data_index] != 40) begin
                        string[string_index] <= stack[stack_index];
                        string_index <= string_index + 1;
                        stack_index <= stack_index - 1;
                    end
                    else stack_index <= stack_index - 1;    // discard "("
                end
                else if(stack_index) begin  // pop until stack is empty
                    string[string_index] <= stack[stack_index - 1];
                    string_index <= string_index + 1;
                    stack_index <= stack_index - 1;
                end
                else begin
                    data_num <= string_index - 1;   // reuse number counter, the counter will be string index - 1
                    string_index <= 0; // reset string index and next do the calculation
                    stack_index <= 0;   // reset stack index to reuse the stack
                end
            end
            CALCULATION: begin  // now string_index = 0, stack_index = 0, reuse the stack
                if((string[string_index] >= 42 && (string[string_index] <= 45))) begin  // detect operator, pop two number from the stack, calculate it and re-push back to stack
                    case(string[string_index])
                        42: stack[stack_index - 2] <= stack[stack_index - 2] * stack[stack_index - 1];
                        43: stack[stack_index - 2] <= stack[stack_index - 2] + stack[stack_index - 1];
                        45: stack[stack_index - 2] <= stack[stack_index - 2] - stack[stack_index - 1];
                    endcase
                    stack_index <= stack_index - 1;
                end
                else begin  // detect number, push the number to stack
                    stack[stack_index] <= string[string_index];
                    stack_index <= stack_index + 1;
                    string_index <= string_index + 1;
                end
            end
            OUTPUT: begin
                result <= stack[0];
                valid <= 1;
                stack_index <= 0;
                string_index <= 0;
                data_index <= 0;
            end
            default: valid <= 0;
        endcase
    end
end

/* Next-state logic (Combinational) */
always @(*) begin
    case(CurrentState)
        DATA_IN:begin
            if(ascii_in == 61) NextState = POPSINGLE;
            else NextState = DATA_IN;
        end
        POPSINGLE: begin
            if(string_index + stack_index == data_num) NextState = POPMULT;
            else if(data[data_index] == 41) NextState = POPMULT;    // detect ")"
            else NextState = POPSINGLE;
        end
        POPMULT:begin // check to pop stack 
            if(!stack_index) NextState = CALCULATION;
            else NextState = POPMULT;
        end
        CALCULATION:begin
            if(string_index == data_num) NextState = OUTPUT;
            else NextState = CALCULATION;
        end
        OUTPUT:begin
            if(valid) NextState = DATA_IN;
            else NextState = OUTPUT;
        end
    endcase
end


/* Output logic (Combinational) */


//-----Your design-----//


endmodule