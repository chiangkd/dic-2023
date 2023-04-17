
module MMS_8num(result, select, number0, number1, number2, number3, number4, number5, number6, number7);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
input  [7:0] number4;
input  [7:0] number5;
input  [7:0] number6;
input  [7:0] number7;
output [7:0] result; 

reg [7:0] result;
wire [7:0] temp0, temp1;
MMS_4num MMS_4num0(temp0, select, number0, number1, number2, number3);
MMS_4num MMS_4num1(temp1, select, number4, number5, number6, number7);
wire cmp = temp0 < temp1;

always @(*) begin
	case({select, cmp})
		2'b00:result = temp0;
		2'b01:result = temp1;
		2'b10:result = temp1;
		2'b11:result = temp0;
	endcase
end

endmodule