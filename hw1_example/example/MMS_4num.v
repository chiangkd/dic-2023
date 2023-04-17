module MMS_4num(result, select, number0, number1, number2, number3);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
output [7:0] result; 

reg [7:0] result, mux0, mux1;
wire cmp0 = number0 < number1;
wire cmp1 = number2 < number3;
wire cmp2 = mux0 < mux1;

always @(*) begin
	case({select, cmp0})
		2'b00:mux0 = number0;
		2'b01:mux0 = number1;
		2'b10:mux0 = number1;
		2'b11:mux0 = number0;
	endcase
end

always @(*) begin
	case({select, cmp1})
		2'b00:mux1 = number2;
		2'b01:mux1 = number3;
		2'b10:mux1 = number3;
		2'b11:mux1 = number2;
	endcase
end

always @(*) begin
	case({select, cmp2})
		2'b00:result = mux0;
		2'b01:result = mux1;
		2'b10:result = mux1;
		2'b11:result = mux0;
	endcase
end

endmodule