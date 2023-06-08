module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output reg wr_r;
output reg [13:0] addr_r;
output reg [7:0] wdata_r;
input [7:0] rdata_r;
output reg wr_g;
output reg [13:0] addr_g;
output reg [7:0] wdata_g;
input [7:0] rdata_g;
output reg wr_b;
output reg [13:0] addr_b;
output reg [7:0] wdata_b;
input [7:0] rdata_b;
output reg done;

localparam WRITE_IN_RAW = 3'd0;
localparam PAD_GREEN = 3'd1;
localparam PAD_RED = 3'd2;
localparam PAD_BLUE = 3'd3;

reg[2:0] CurrentState, NextState;
reg[1:0] write_mode; 
reg[13:0] write_idx;
reg red_flag, blue_flag;
reg [10:0] sum_tmp;  // for calculate sum
reg [2:0] pad_cnt;
reg [13:0] data_idx;
reg missing_case;

/* State register (Sequential) */
always @(posedge clk) begin
    if(reset) CurrentState <= WRITE_IN_RAW;
    else CurrentState <= NextState;
end

always @(posedge clk) begin
    case (CurrentState)
        WRITE_IN_RAW: begin
            if(reset) begin
                addr_r <= 0;
                addr_g <= 0;
                addr_b <= 0;
                write_mode <= 0;
                write_idx <= 0;
                red_flag <= 1;  // reset to 1
                blue_flag <= 0;
                sum_tmp <= 0;
                pad_cnt <= 0;
                data_idx <= 0;
                done <= 0;
            end
            else begin
            /* 
                g r g r g ... r
                b g b g b ... g
                g r g r g ... r
                b g b g b ... g
                g r g r g ... r
            */
                if(write_idx < 16383) begin
                    write_idx <= write_idx + 1;
                end
                if(!(write_idx[6:0] ^ 7'b1111111)) begin // 127, 255, 383, ...
                    if(red_flag) begin
                        write_mode <= 2;    // red -> blue (next line)
                        red_flag <= 0;
                        blue_flag <= 1;
                    end
                    else if(blue_flag) begin
                        write_mode <= 0;    // green -> green (next line)
                        red_flag <= 1;
                        blue_flag <= 0;
                    end
                end
                else if(write_mode == 0) begin  // green
                    if(red_flag) begin
                        write_mode <= 1;    // red mode
                    end
                    else if(blue_flag) begin
                        write_mode <= 2;    // blue mode
                    end
                end
                else begin
                    write_mode <= 0;    // green mode
                end

                case (write_mode)
                    0:begin     // green
                        wdata_g <= data_in;
                        wr_g <= 1;
                        wr_b <= 0;
                        wr_r <= 0;
                        addr_g <= write_idx;
                        if(write_idx == 16383) begin    // reset rgb memory index
                            data_idx <= 1;  // pad green is started with 1
                            // addr_g <= 0;
                            addr_b <= 0;
                            addr_r <= 0;
                            red_flag <= 0;  // reuse red flag
                            blue_flag <= 0; // reuse blue flag
                            missing_case <= 0;
                            if(addr_g == 16383) wr_g <= 0;
                        end
                    end
                    1:begin     // red
                        wdata_r <= data_in;
                        wr_g <= 0;
                        wr_b <= 0;
                        wr_r <= 1;
                        addr_r <= write_idx;
                    end  
                    2:begin     // blue 
                        wdata_b <= data_in;
                        wr_g <= 0;
                        wr_b <= 1;
                        wr_r <= 0;
                        addr_b <= write_idx;
                    end
                endcase
            end
        end
        PAD_GREEN: begin // 4 neighbors
            if(pad_cnt < 4) begin
                pad_cnt <= pad_cnt + 1;
            end
            else begin
                pad_cnt <= 0;
            end
            case(pad_cnt)
                0: begin
                    addr_g <= data_idx - 128; // up
                end
                1: begin
                    addr_g <= data_idx - 1;   // left
                    sum_tmp <= sum_tmp + rdata_g;
                end
                2: begin
                    addr_g <= data_idx + 1;   // right
                    sum_tmp <= sum_tmp + rdata_g;
                end
                3: begin
                    addr_g <= data_idx + 128; // down
                    sum_tmp <= sum_tmp + rdata_g;
                end
            endcase
            if(pad_cnt == 4) begin
                sum_tmp <= 0;
                wr_g <= 1;
                addr_g <= data_idx; // store address
                wdata_g <= (sum_tmp + rdata_g) >> 2;
                if(!(data_idx[6:0] ^ 7'b1111111)) begin // 127, 383, ...
                    data_idx <= data_idx + 1;
                end
                else if(!(data_idx[6:0] ^ 7'b1111110))begin // 254, 510, ...
                    data_idx <= data_idx + 3;
                end
                else begin
                    data_idx <= data_idx + 2;
                end
            end
            else begin
                wr_g <= 0;
            end
            if(data_idx == 16382) begin
                data_idx <= 0;  // pad red is started with 0
                pad_cnt <= 0;   // reuse pad counter
            end
        end
        PAD_RED: begin
            case (missing_case)
                0: begin    /* left-right and up-down case */
                    if(pad_cnt < 2) begin
                    pad_cnt <= pad_cnt + 1;
                    end
                    else begin
                        pad_cnt <= 0;
                    end
                    /* left-right case */
                    if(!red_flag) begin
                        case (pad_cnt)
                            0: begin
                                addr_r <= data_idx - 1; // left
                            end
                            1: begin
                                addr_r <= data_idx + 1; // right
                                sum_tmp <= sum_tmp + rdata_r; 
                            end
                        endcase
                        if(pad_cnt == 2) begin
                            sum_tmp <= 0;
                            wr_r <= 1;
                            addr_r <= data_idx; // store address
                            wdata_r <= (sum_tmp + rdata_r) >> 1;
                            if(!(data_idx[6:0] ^ 7'b1111110)) begin // 126, 382, ...
                                data_idx <= data_idx + 130; // next two row (2 + 128)
                            end
                            else begin
                                data_idx <= data_idx + 2;
                            end
                        end
                        else begin
                            wr_r <= 0;
                        end
                        if(addr_r == 16254) begin // last element in left-right case
                            data_idx <= 129;    // up-down case start with 129
                            red_flag <= 1;  // reuse flag
                        end
                    end
                    else begin  /* up-down case */
                        case (pad_cnt)
                            0: begin
                                addr_r <= data_idx - 128;   // up 
                            end 
                            1: begin
                                addr_r <= data_idx + 128;   // down
                                sum_tmp <= sum_tmp + rdata_r;
                            end
                        endcase
                        if(pad_cnt == 2) begin
                            sum_tmp <= 0;
                            wr_r <= 1;
                            addr_r <= data_idx;  // store address
                            wdata_r <= (sum_tmp + rdata_r) >> 1;
                            if(!(data_idx[6:0] ^ 7'b1111111)) begin    // 255, 511, ...
                                data_idx <= data_idx + 130; // next two row (2 + 128)
                            end
                            else begin
                                data_idx <= data_idx + 2;
                            end
                        end
                        else begin
                            wr_r <= 0;
                        end
                        if(data_idx == 16383) begin // last element in up-down case
                            data_idx <= 128;    // four corner case started with 128
                            missing_case <= 1;  // four element corner case
                            pad_cnt <= 0;
                        end
                    end
                        end 
                1: begin    // four element corner case
                    if(pad_cnt < 4) begin
                        pad_cnt <= pad_cnt + 1;
                    end
                    else begin
                        pad_cnt <= 0;
                    end
                    case (pad_cnt)
                        0: begin
                            addr_r <= data_idx - 129;   // upper left
                        end 
                        1: begin
                            addr_r <= data_idx - 127;   // upper right
                            sum_tmp <= sum_tmp + rdata_r;
                        end
                        2: begin
                            addr_r <= data_idx + 127;   // lower left
                            sum_tmp <= sum_tmp + rdata_r;
                        end
                        3: begin
                            addr_r <= data_idx + 129;   // lower right
                            sum_tmp <= sum_tmp + rdata_r;
                        end
                    endcase
                    if(pad_cnt == 4) begin
                        sum_tmp <= 0;
                        wr_r <= 1;
                        addr_r <= data_idx; // store address
                        wdata_r <= (sum_tmp + rdata_r) >> 2;
                        if(!(data_idx[6:0] ^ 7'b1111110)) begin
                            data_idx <= data_idx + 130; // next two row
                        end
                        else begin
                            data_idx <= data_idx + 2;
                        end
                    end
                    else begin
                        wr_r <= 0;
                    end
                    if(data_idx == 16382) begin
                        data_idx <= 129;
                        missing_case <= 0;
                        pad_cnt <= 0;
                    end
                end
            endcase
            
        end
        PAD_BLUE: begin
            case (missing_case)
                0: begin
                    if(pad_cnt < 2) begin
                        pad_cnt <= pad_cnt + 1;
                    end
                    else begin
                        pad_cnt <= 0;
                    end
                    /* left-right case */
                    if(!blue_flag) begin
                        case (pad_cnt)
                            0: begin
                                addr_b <= data_idx - 1; // left
                            end
                            1: begin
                                addr_b <= data_idx + 1; // right
                                sum_tmp <= sum_tmp + rdata_b; 
                            end
                        endcase
                        if(pad_cnt == 2) begin
                            sum_tmp <= 0;
                            wr_b <= 1;
                            addr_b <= data_idx;
                            wdata_b <= (sum_tmp + rdata_b) >> 1;
                            if(!(data_idx[6:0] ^ 7'b1111111))begin  // 255, 511, ...
                                data_idx <= data_idx + 130; // next two row (2 + 128)
                            end
                            else begin
                                data_idx <= data_idx + 2;
                            end
                        end
                        else begin
                            wr_b <= 0;
                        end
                        if(data_idx == 16383) begin // last element in left-right case
                            data_idx <= 0;    // up-down case start with 0
                            blue_flag <= 1;  // reuse flag
                        end
                    end
                    else begin  /* up-down case */
                        case (pad_cnt)
                            0: begin
                                addr_b <= data_idx - 128;   // up
                            end
                            1: begin
                                addr_b <= data_idx + 128;   // down
                                sum_tmp <= sum_tmp + rdata_b;
                            end
                        endcase
                        if(pad_cnt == 2) begin
                            sum_tmp <= 0;
                            wr_b <= 1;
                            addr_b <= data_idx;
                            wdata_b <= (sum_tmp + rdata_b) >> 1;
                            if(!(data_idx[6:0] ^ 7'b1111110)) begin // 126, 382, ...
                                data_idx <= data_idx + 130; // next two row (2 + 128)
                            end
                            else begin
                                data_idx <= data_idx + 2;
                            end
                        end
                        else begin
                            wr_b <= 0;
                        end
                        if(data_idx == 16132) begin
                            data_idx <= 1;  // four element case started with 1
                            missing_case <= 1;  // four element corner case
                            pad_cnt <= 0;
                        end
                    end
                end 
                1:begin
                    if(pad_cnt < 4) begin
                        pad_cnt <= pad_cnt + 1;
                    end
                    else begin
                        pad_cnt <= 0;
                    end
                    case (pad_cnt)
                        0: begin
                            addr_b <= data_idx - 129;   // upper left
                        end 
                        1: begin
                            addr_b <= data_idx - 127;   // upper right
                            sum_tmp <= sum_tmp + rdata_b;
                        end
                        2: begin
                            addr_b <= data_idx + 127;   // lower left
                            sum_tmp <= sum_tmp + rdata_b;
                        end
                        3: begin
                            addr_b <= data_idx + 129;   // lower right
                            sum_tmp <= sum_tmp + rdata_b;
                        end
                    endcase
                    if(pad_cnt == 4) begin
                        sum_tmp <= 0;
                        wr_b <= 1;
                        addr_b <= data_idx; // store address
                        wdata_b <= (sum_tmp + rdata_b) >> 2;
                        if(!(data_idx[6:0] ^ 7'b1111111)) begin
                            data_idx <= data_idx + 130; // next two row
                        end
                        else begin
                            data_idx <= data_idx + 2;
                        end
                    end
                    else begin
                        wr_b <= 0;
                    end
                    if(data_idx == 16255) begin
                        done <= 1;
                    end
                end
            endcase
        end
    endcase
end

/* next state logic */
always @(*) begin
    case (CurrentState)
        WRITE_IN_RAW: begin
            if(addr_g == 16383) NextState = PAD_GREEN;
            else NextState = WRITE_IN_RAW;
        end 
        PAD_GREEN: begin
            if(data_idx == 16382) NextState = PAD_RED;
            else NextState = PAD_GREEN;
        end
        PAD_RED: begin
            if(data_idx == 16382) NextState = PAD_BLUE;
            else NextState = PAD_RED;
        end
    endcase
end

endmodule
