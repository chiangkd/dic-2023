module Queue(clk, reset, d, q, push, pop);

input clk;
input reset;
input [3:0] d;          // input value
output reg [3:0] q;         // output value
input push;
input pop;
reg [3:0] i;  // counter

reg [3:0] queue [0:9];	// input number of trains ranges from 3 to 10 
reg [3:0] cnt_w = 0;   // counter (ranges from 3 ~ 10)
reg [3:0] cnt_r = 0;


always @(posedge clk)
begin
    if(reset)
    begin
        cnt_w <= 0;
        cnt_r <= 0;
        for(i = 0; i < 10; i = i + 1)
        begin
            queue[i] <= 0;  // clear all the value in queue
        end
    end
    else if (push)
    begin
        queue[cnt_w] <= d;  // push the data into queue
        cnt_w <= cnt_w + 1;
    end
    else if (pop)
    begin
        queue[cnt_r] <= 0;  // pop out an element from queue
        cnt_r <= cnt_r + 1;
    end

    assign q = queue[cnt_r];    // output first element of the queue

end

endmodule