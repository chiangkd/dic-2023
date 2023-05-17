`timescale 1ns/10ps
`define PADNUM 2	// padding number = 2
`define BIAS 13'h1FF4	// bias = -0.75(13'h1ff4)

module  ATCONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output reg	[11:0]	iaddr,
	input signed [12:0]	idata,
	
	output	reg 	cwr,
	output  reg	[11:0]	caddr_wr,
	output reg 	[12:0] 	cdata_wr,
	
	output	reg 	crd,
	output reg	[11:0] 	caddr_rd,
	input 	[12:0] 	cdata_rd,
	
	output reg 	csel
	);

//=================================================
//            write your design below
//=================================================

reg[3:0] CurrentState, NextState;

reg signed [12:0] da_CONV;	// data after convolution (need larger than 13 bits to store)
reg signed [12:0] pool_tmp;	// tmp compare pooling value

localparam CHECKRDY = 3'd0;
localparam PADANDCONV = 3'd1;
localparam RELUANDSTRL0	= 3'd2;
localparam RDANDMAXPOOL = 3'd3;
localparam CEILANDSTRL1 = 3'd4;
localparam DONE = 3'd5;

reg [3:0] kernel_count;	// count each kernel multiplication time
reg [11:0] data_index;	// count for each data for convolution
reg [9:0] data_index_after_pool;	// 32*32 index
reg [1:0] pool_index;	// max-pooling index
reg pool_done_flag;	// 

/* State register (Sequentual) */
always @(posedge clk) begin
	if(reset) CurrentState <= CHECKRDY;
	else CurrentState <= NextState;
end

always @(posedge clk) begin
	if(reset) begin
		busy <= 0;
		kernel_count <= 0;
		data_index <= 0;
		data_index_after_pool <= 0;
		csel <= 0;
		crd <= 0;
		cwr <= 0;
		caddr_rd <= 0;
		caddr_wr <= 0;
		cdata_wr <= 0;
		da_CONV <= 0;
		pool_index <= 0;
		pool_tmp <= 0;
		pool_done_flag <= 0;
	end
	else begin
		case(CurrentState)
			PADANDCONV: begin
				/*
				bias: 13'h1FF4
				kernel
				13'h1FFF---13'h1FFE---13'h1FFF			|	1---2---3
				    |		    |		  |				|	|	|	|
				13'h1FFC---13'h0010---13'h1FFC			|	4---0---5
					|		    |         |				|	|	|	|
				13'h1FFF---13'h1FFE---13'h1FFF			|	6---7---8
				*/
				case (kernel_count)	// count for kernel
					1: begin
						da_CONV <= da_CONV + ~(idata >> 4) + 1;
					end
					2: begin
						da_CONV <= da_CONV + ~(idata >> 3) + 1;
					end
					3: begin
						da_CONV <= da_CONV + ~(idata >> 4) + 1;
					end
					4: begin
						da_CONV <= da_CONV + ~(idata >> 2) + 1; 
					end
					0: begin
						da_CONV <= da_CONV + idata;
					end
					5: begin
						da_CONV <= da_CONV + ~(idata >> 2) + 1;
					end
					6: begin
						da_CONV <= da_CONV + ~(idata >> 4) + 1;
					end
					7: begin
						da_CONV <= da_CONV + ~(idata >> 3) + 1;
					end
					8: begin
						da_CONV <= da_CONV + ~(idata >> 4) + 1;
					end
				endcase
			end
			RELUANDSTRL0: begin
				da_CONV <= 0;	// reset
			end
		endcase
	end
end

/* busy control */
always @(posedge clk) begin
	if(!reset) begin
		case(CurrentState)
			CHECKRDY: begin
				if(ready) begin
					busy <= 1;
				end
			end
			DONE: begin
				busy <= 0;
			end
		endcase
	end
end

/* kernel count */
always @(posedge clk) begin
	case (CurrentState)
		PADANDCONV:
			if(kernel_count < 9) begin
				kernel_count <= kernel_count + 1;
			end
			else begin
				kernel_count <= 0;
			end
	endcase
end

/* data count */
always @(posedge clk) begin
	case (CurrentState)
		RELUANDSTRL0:
			if(data_index < 4096) begin
				data_index <= data_index + 1;
			end
			else begin
				data_index <= 0;	// reset
			end
		RDANDMAXPOOL: begin
			case(pool_index)	// read four data for maxpooling
				0: begin
					pool_done_flag<= 0;
					data_index <= data_index + 1;
				end
				1: begin
					data_index <= data_index + 63;
				end
				2: begin
					data_index <= data_index + 1;
				end
				3: begin
					if(data_index[5:0] == 63) begin
						data_index <= data_index + 1;
					end
					else begin
						data_index <= data_index - 63;
					end
					pool_done_flag <= 1;
				end
			endcase
		end			
	endcase
end

always @(posedge clk) begin
	case (CurrentState)
		CEILANDSTRL1: begin
			if(data_index_after_pool < 1024) begin
				data_index_after_pool <= data_index_after_pool + 1;
			end
			else begin
				data_index_after_pool <= 0;
			end
		end
	endcase
end

/* pool count */
always @(posedge clk) begin
	case (CurrentState)
		RDANDMAXPOOL: begin
			pool_index <= pool_index + 1;
		end
	endcase
end

/* pool temp */
always @(posedge clk) begin
	case (CurrentState)
		RDANDMAXPOOL: begin
			if(cdata_rd) begin
				pool_tmp <= (pool_tmp < cdata_rd) ? cdata_rd : pool_tmp;	// read value from layer 0 and updata the maximum value
			end
		end
		CEILANDSTRL1: begin
			pool_tmp <= 0;
		end
	endcase
end


/* Control iaddr */
always @(*) begin
	case(CurrentState)
		PADANDCONV: begin
			case (kernel_count)	// count for kernel
				1: begin	// upper left
					if(data_index[5:0] < `PADNUM) begin	// left side value (0, 1,... 64, 65,... )
						iaddr <= (data_index > 128 ? {data_index[11:2], 2'b00} - 128 /* push up two row */ : 0);	// catch upper left value
					end
					else begin // (2, 3, 4, ... 63,. 66, 67, ..., 127)
						iaddr <= (data_index > 128 /* must higher than 130 */ ? (data_index - 128 - `PADNUM /* push up two row */) : {6'b0, data_index[5:0]} - `PADNUM);
					end
				end
				2: begin	// upper mid
					if(data_index > 128) begin
						iaddr <= data_index - 128;	// push up two row
					end
					else begin
						iaddr <= {6'b0, data_index[5:0]};	// mask out first six bits
					end
				end
				3: begin	// upper right
					if(data_index[5:0] > (63 - `PADNUM)) begin	// right side value (62, 63, ...,126, 127,..., 190, 191)
						iaddr <= (data_index > 128 ? {data_index[11:2], 2'b11} - 128 /* push up two row */ : 63);	// catch upper right value
					end
					else begin
						iaddr <= (data_index > 128 ? (data_index - 128 + `PADNUM) /* push up two row */ : {6'b0, data_index[5:0]} + `PADNUM);
					end
				end
				4: begin	// left
					iaddr <= data_index[5:0] < `PADNUM ? {data_index[11:2], 2'b00} : data_index - `PADNUM;	// push left two column
				end
				0: begin	// center
					iaddr <= data_index;
				end
				5: begin	// right
					iaddr <= data_index[5:0] > (63 - `PADNUM) ? data_index | 2'b11 : data_index + 2;	// push right two column
				end
				6: begin	// lower left
					if(data_index[5:0] < `PADNUM) begin	// left side value (3908, 3909, ..., 3968, 3969,..., 4032, 4033)
						iaddr <= (data_index < 3904 ? {data_index[11:2], 2'b00} + 128 /* push down two row */ : 4032);	// catch lower left value
					end
					else begin
						iaddr <= (data_index < 3904 ? (data_index + 128 - `PADNUM) : {6'b111111, data_index[5:0]} - `PADNUM);
					end
				end
				7: begin	// lower mid
					if(data_index < 3904) begin
						iaddr <= data_index + 128;	// push down two row
					end
					else begin
						iaddr <= {6'b111111, data_index[5:0]};	 // mask first six bits with all 1 to push to the bottom
					end
				end
				8: begin	// lower right
					if(data_index[5:0] > (63 - `PADNUM)) begin // right side value (62, 63, ...,126, 127,..., 190, 191)
						iaddr <= (data_index < 3904 ? {data_index[11:2], 2'b11} + 128 /* push down two row */ : 4095);	// catch lower right value
					end
					else begin
						iaddr <= (data_index < 3904 ? (data_index + 128 + `PADNUM) : {6'b111111, data_index[5:0]} + `PADNUM);
					end
				end
			endcase
		end
	endcase
end

/* csel */
always @(posedge clk) begin
	case (CurrentState)
		PADANDCONV: begin
			if(kernel_count == 9) begin	// count convolution done
				csel <= 0;
				cwr <= 1;
			end
			else begin
				cwr <= 0;
			end
		end
		RDANDMAXPOOL: begin
			csel <= 0;
			cwr <= 0;
			crd <= 1;
		end
		CEILANDSTRL1: begin
			csel <= 1;	// select layer 1 memory to store data
			cwr <= 1;
			crd <= 0;
		end
	endcase
end

/* store data */
always @(posedge clk) begin
	case (CurrentState)
		RELUANDSTRL0: begin
			caddr_wr <= data_index;
			cdata_wr <= (da_CONV + `BIAS) &13'b1_0000_0000_0000 ? 0 : da_CONV + `BIAS;
		end
		CEILANDSTRL1: begin
			caddr_wr <= data_index_after_pool;
			cdata_wr <= pool_tmp[3:0] ? {pool_tmp[11:4] + 1, 4'b0} : pool_tmp;	// ceiling
		end
	endcase
end

/* read data */
always @(posedge clk) begin
	case (CurrentState)
		RDANDMAXPOOL: begin
			caddr_rd <= data_index;
		end 
	endcase
end

/* Next-state logic (Combinational) */
always @(*) begin
	case(CurrentState)
		CHECKRDY: begin
			if(ready) NextState = PADANDCONV;
			else NextState = CHECKRDY;
		end
		PADANDCONV: begin
			if(kernel_count == 9) NextState = RELUANDSTRL0;
			else NextState = PADANDCONV;
		end
		RELUANDSTRL0: begin
			if(data_index < 4095) NextState = PADANDCONV;
			else NextState = RDANDMAXPOOL;
		end
		RDANDMAXPOOL: begin
			if(caddr_wr == 1023) NextState = DONE;
			else if(pool_done_flag) NextState = CEILANDSTRL1;
			else NextState = RDANDMAXPOOL;
		end
		CEILANDSTRL1: begin
			if(data_index < 4095) NextState = RDANDMAXPOOL;
			else NextState = DONE;
		end
	endcase
end
endmodule