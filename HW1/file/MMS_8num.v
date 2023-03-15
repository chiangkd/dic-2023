
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
output reg [7:0] result; 

wire [7:0] out1, out2;

MMS_4num mms4_1(out1, select, number0, number1, number2, number3);
MMS_4num mms4_2(out2, select, number4, number5, number6, number7);

always @(*) begin
	if(select == 0)	// result maximum value
	begin
		if(out1 < out2)	// cmp = 1
			result = out2;
		else			// cmp = 0
			result = out1;
	end
	else if(select == 1)	// result minimum value
	begin
		if(out1 < out2)	// cmp = 1
			result = out1;
		else			// cmp = 0
			result = out2;
	end
end

endmodule