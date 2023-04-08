module Stack(clk, reset, d, q, push, pop,);

input clk;
input reset;
input [3:0] d;          // input value
output reg [3:0] q;         // output value
input push;
input pop;
reg [3:0] i;  // counter

reg [3:0] stack [0:9];	// input number of trains ranges from 3 to 10 
reg [3:0] sp = 0;   // stack pointer (ranges from 3 ~ 10)

/* stack operation */
always@(posedge clk)
begin
    if(reset)
    begin
        sp <= 0;
        for(i = 0; i < 10; i = i + 1)
        begin
            stack[i] <= 0;  // clear all the value in stack
        end
    end
    else if (push)
    begin
        stack[sp] <= d;
        sp <= sp + 1;
    end
    else if (pop)
    begin
        sp <= sp - 1;
    end

    assign q = sp == 0 ? 0 : stack[sp - 1];
    
end

endmodule