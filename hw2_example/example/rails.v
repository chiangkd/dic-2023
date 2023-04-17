module rails(clk, reset, data, valid, result);

input        clk;
input        reset;
input  [3:0] data;
output       valid;
output       result; 

localparam NUMBER_IN = 3'd0;
localparam DATA_IN = 3'd1;
localparam STATION_POP = 3'd2;
localparam STATION_PUSH = 3'd3;
localparam OUT = 3'd4;
localparam WAIT = 3'd5;

reg result, valid;
reg [2:0] state, nextState;
reg [3:0] num;
reg [3:0] index, station_index, sequence_index;
reg [3:0] station [0:9];//station stack
reg [3:0] order [0:9];//input order

wire [3:0] station_index_minus_one = station_index - 4'd1;

integer i;

always @(*) begin
    case(state)
        NUMBER_IN:begin
            nextState = DATA_IN;
        end
        DATA_IN:begin
            if(index == num - 1) nextState = STATION_POP;
            else nextState = DATA_IN;
        end
        STATION_POP:begin
            if((station_index > 4'd0) && (station[station_index_minus_one] == order[index])) nextState = STATION_POP;
            else nextState = STATION_PUSH;
        end
        STATION_PUSH:begin
            if(sequence_index == num + 1) nextState = OUT;
            else nextState = STATION_POP;
        end
        OUT:begin
            nextState = WAIT;
        end
        default:begin
            nextState = NUMBER_IN;
        end
    endcase
end

always @(posedge clk) begin
    if(reset) state <= NUMBER_IN;
    else state <= nextState;
end

always @(posedge clk or posedge reset) begin
    if(reset)begin
        for(i = 0; i < 10; i = i + 1) station[i] <= 4'b1111;
        valid <= 1'b0;
        result <= 1'b0;
        num <= 4'd0;
        index <= 4'd0;
        station_index <= 4'd0;
        sequence_index <= 4'd1;
    end
    else begin
        case(state)
            NUMBER_IN:begin//read number
                num <= data;
            end
            DATA_IN:begin//read data
                order[index] <= data;
                if(index == num - 1) index <= 4'd0;
                else index <= index + 1;
            end
            STATION_POP:begin//compare top with order
                if((station_index > 4'd0) && (station[station_index_minus_one] == order[index]))begin
                    index <= index + 1;
                    station_index <= station_index - 1;
                end
            end
            STATION_PUSH:begin//push data into stack
                station[station_index] <= sequence_index;
                station_index <= station_index + 1;
                sequence_index <= sequence_index + 1;
            end
            OUT:begin//output result
                valid <= 1;
                if(index == num) result <= 1;
            end
            WAIT:begin//reset register
                for(i = 0; i < 10; i = i + 1) station[i] <= 4'b1111;
                valid <= 0;
                result <= 0;
                index <= 0;
                station_index <= 4'd0;
                sequence_index <= 4'd1;
            end
        endcase
    end
end

endmodule