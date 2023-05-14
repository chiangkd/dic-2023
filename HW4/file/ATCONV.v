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

// reg signed [12:0] imgData_tmp [0:8];	// stored t
// reg signed [12:0] imgData_pad [0:4623];	// 68 * 68
reg signed [15:0] da_CONV;	// data after convolution (need larger than 13 bits to store)

localparam CHECKRDY = 4'd0;
localparam PADANDCONV = 4'd1;
localparam ACONV	= 4'd2;
localparam CHECK = 4'd3;
localparam RELU = 4'd4;
localparam STRL0 = 4'd5;		// store information to layer 0 memory
localparam MAXPOOLING = 4'd6;
localparam STRL1 = 4'd7;	// store information to layer 1 memory


reg [5:0] ori_i, ori_j;
reg [6:0] pad_i, pad_j;	// padding index (i for row, j for column) (2^7 = 128)
reg [3:0] kernel_count;	// count each kernel multiplication time
reg [3:0] data_index;	// count for each data for convolution

/* State register (Sequentual) */
always @(posedge clk) begin
	if(reset) CurrentState <= CHECKRDY;
	else CurrentState <= NextState;
end

always @(posedge clk) begin
	if(reset) begin
		busy <= 0;
		pad_i <= 0;
		pad_j <= 0;
		ori_i <= 0;
		ori_j <= 0;
		kernel_count <= 0;
		data_index <= 0;
		csel <= 0;
		crd <= 0;
		cwr <= 0;
		caddr_rd <= 0;
		// cdata_rd <= 0;
		caddr_wr <= 0;
		cdata_wr <= 0;
		da_CONV <= 0;
	end
	else begin
		case(CurrentState)
			CHECKRDY: begin
				if(ready) begin
					busy <= 1;
				end
			end
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
						da_CONV <= da_CONV + ~(idata >> 4) + 1 + `BIAS;
					end
					2: begin
						da_CONV <= da_CONV + ~(idata >> 3) + 1 + `BIAS;
					end
					3: begin
						da_CONV <= da_CONV + ~(idata >> 4) + 1 + `BIAS;
					end
					4: begin
						da_CONV <= da_CONV + ~(idata >> 2) + 1 + `BIAS; 
					end
					0: begin
						da_CONV <= da_CONV + idata + `BIAS;
					end
					5: begin
						da_CONV <= da_CONV + ~(idata >> 3) + 1 + `BIAS;
					end
					6: begin
						da_CONV <= da_CONV + ~(idata >> 4) + 1 + `BIAS;
					end
					7: begin
						da_CONV <= da_CONV + ~(idata >> 3) + 1 + `BIAS;
					end
					8: begin
						da_CONV <= da_CONV + ~(idata >> 4) + 1 + `BIAS;
					end
				endcase
				// imgData_pad[pad_i + 68 * pad_j] <= idata;
			end
			RELUANDSTRL0: begin
				if(da_CONV & 13'b1_0000_0000_0000) begin
					da_CONV <= 0
				end

			end
			RELU: begin
				da_CONV = da_CONV[12] ? 0 : da_CONV;
			end
			STRL0: begin
				
			end

		endcase
	end
end

/* Control padding index (pad_i)*/
always @(posedge clk) begin
	case(CurrentState)
		PADANDCONV:
			if(busy && idata) begin
				pad_i <= pad_i + 1;
				if(pad_i == 67) begin
					pad_i <= 0;
				end
			end
		ACONV:
			if(pad_j == 67) begin
				/* padding image initial index */
				pad_i <= `PADNUM;
			end
			else if(pad_i >= `PADNUM && pad_i < (67 - `PADNUM)) begin
				pad_i <= pad_i + 1;	// convolution iteration
			end
			else begin
				pad_i <= 2;
			end
	endcase
end

/* Control padding index (pad_j) */
always @(posedge clk) begin
	case(CurrentState)
		PADANDCONV:
			if(busy && idata) begin
				if(pad_i == 67 && pad_j != 67) begin
					pad_j <= pad_j + 1;
				end
			end
		ACONV:
			if(pad_j == 67) begin
				/* padding image initial index */
				pad_j <= `PADNUM;
			end
			else if(pad_j >= `PADNUM && pad_j < (67 - `PADNUM) && pad_i == (67 - `PADNUM)) begin
				pad_j <= pad_j + 1;
			end
			else begin
				// pad_j <= 0;
			end
	endcase
end

/* Control original size index (ori_i) */
always @(posedge clk) begin
	case(CurrentState)
		PADANDCONV:
			if(busy && idata) begin
				if(pad_i <= `PADNUM && pad_i > (67 - `PADNUM)) begin	// pad_i < 2 and pad_i > 66
					ori_i <= ori_i + 1;	// next column
				end
				else if(pad_i == 67) begin
					ori_i <= 0;
				end
			end
		ACONV:
			if(pad_j == 67) begin
				/* reset original size index for reusing */
				ori_i <= 0;
			end

	endcase
end

/* Control original size index (ori_j) */
always @(posedge clk) begin
	case(CurrentState)
		PADANDCONV:
			if(busy && idata) begin
				if(pad_j >= `PADNUM && pad_j < (67 - `PADNUM) && pad_i == 67) begin
					ori_j <= ori_j + 1;
				end
			end
		ACONV:
			if(pad_j == 67) begin
				/* reset original size index for reusing */
				ori_j <= 0;
			end
	endcase
end
/* kernel count */
always @(posedge clk) begin
	case (CurrentState)
		PADANDCONV:
			if(idata) begin
				kernel_count <= kernel_count + 1;
			end
	endcase
end

/* data count */
always @(posedge clk) begin
	case (CurrentState)
		PADANDCONV:
			if(idata) begin
				data_index <= data_index + 1;
			end
	endcase
end

/* Control iaddr */
always @(*) begin
	case(CurrentState)
		PADANDCONV: begin
			case (kernel_count)	// count for kernel
				1: begin	// upper left
					if(data_index[5:0] < `PADNUM) begin	// left edge (0, 64, 128, ...) and left side value (<= 2)
						iaddr <= data_index;	// catch left edge value
					end
					else if (data_index[6])begin	// upper left is in the zone
						iaddr <= data_index
					end
				end
				2: begin	// upper mid

				end
				3: begin	// upper right

				end
				4: begin	// left

				end
				0: begin	// center
					iaddr <= data_count;
				end
				5: begin	// right

				end
				6: begin	// lower left

				end
				7: begin	// lower mid

				end
				8: begin	// lower right

				end
			endcase





			iaddr = ori_i + 64 * ori_j;
		end
	endcase
end



/* csel */
always @(*) begin
	case (CurrentState)
		STRL0: begin
			csel = 0;
			cwr = 1;
		end
		STRL1: begin
			csel = 1;
		end
		default: begin
			csel = 0;
			cwr = 0;
			crd = 0;
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
			if(pad_i == 67 && pad_j == 67) NextState = ACONV;
			else NextState = PADANDCONV;
		end
		ACONV: begin
			if(pad_i == 65 && pad_j == 65) NextState = RELU;
			else NextState = ACONV;
		end
		RELU: begin
			
		end

	endcase
end


endmodule