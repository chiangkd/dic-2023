`timescale 1ns/10ps
`define PADNUM 2	// padding number = 2

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

reg [12:0] imgData_pad [0:4623];	// 68 * 68


localparam CHECKRDY = 4'd0;
localparam GETANDPAD = 4'd1;
localparam ACONV	= 4'd2;
localparam CHECK = 4'd3;
localparam RELU = 4'd4;

reg [5:0] ori_i, ori_j;
reg [6:0] pad_i, pad_j;	// padding index (i for row, j for column) (2^7 = 128)

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
	end
	else begin
		case(CurrentState)
			CHECKRDY: begin
				if(ready) begin
					busy <= 1;
				end
			end
			GETANDPAD: begin
				/* 
				0.........63
				.		   .
				.	 	   .
				.	       .
				4032.....4095
				*/
				imgData_pad[pad_i + 68 * pad_j] <= idata;	
			end
		endcase
	end
end

/* Control padding index */
always @(posedge clk) begin
	case(CurrentState)
		GETANDPAD: begin
			if(busy && idata) begin
				pad_i <= pad_i + 1;
				if(pad_i == 67) begin
					pad_i <= 0;
					// pad_j <= pad_j + 1;
				end
			end
		end
	endcase
end
always @(posedge clk) begin
	case(CurrentState)
		GETANDPAD:
			if(busy && idata) begin
				if(pad_i >= `PADNUM && pad_i < (67 - `PADNUM)) begin
					ori_i <= ori_i + 1;	// next column
				end
				else if(pad_i == 67) begin
					ori_i <= 0;
					// ori_j <= ori_j + 1;	// next row
				end
			end
	endcase
end
always @(posedge clk) begin
	case(CurrentState)
		GETANDPAD: begin
			if(busy && idata) begin
				if(pad_i == 67) begin
					pad_j <= pad_j + 1;
				end
			end
		end
	endcase
end
always @(posedge clk) begin
	case(CurrentState)
		GETANDPAD:
			if(busy && idata) begin
				if(pad_j >= `PADNUM && pad_j < (67 - `PADNUM) && pad_i == 67) begin
					ori_j <= ori_j + 1;
				end
			end
	endcase
end


/* Control iaddr */
always @(*) begin
	case(CurrentState)
		GETANDPAD: begin
			iaddr = ori_i + 64 * ori_j;
		end
	endcase
end

/* Next-state logic (Combinational) */
always @(*) begin
	case(CurrentState)
		CHECKRDY: begin
			if(ready) NextState = GETANDPAD;
			else NextState = CHECKRDY;
		end
		GETANDPAD: begin
			if(pad_i == 67 && pad_j == 67) NextState = ACONV;
			else NextState = GETANDPAD;
		end

	endcase
end


endmodule