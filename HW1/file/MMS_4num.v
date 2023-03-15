module MMS_4num(result, select, number0, number1, number2, number3);

input        select;
input  [7:0] number0;
input  [7:0] number1;
input  [7:0] number2;
input  [7:0] number3;
output reg[7:0] result; 

reg [7:0] cmp1, cmp2;

/* MUX 1 */
always @(*) begin
	if(select == 0) // get maximum value
	begin
		if(number0 < number1)	// cmp = 1
			cmp1 = number1;
		else					// cmp = 0
			cmp1 = number0;
	end
	else if (select == 1)	// get minumum value
	begin
		if(number0 < number1)	// cmp = 1
			cmp1 = number0;
		else					// cmp = 0
			cmp1 = number1;
	end
end

/* MUX 2 */
always @(*) begin
	if(select == 0)	// get maximum value
	begin
		if(number2 < number3)	// cmp = 1
			cmp2 = number3;
		else					// cmp = 0
			cmp2 = number2;
	end
	else if(select == 1)	// get minimum value
	begin
		if(number2 < number3)	// cmp = 1
			cmp2 = number2;
		else
			cmp2 = number3;
	end
end

/* MUX 3 */
always @(*) begin
	if(select == 0)	// output maximum value
	begin
		if(cmp1 < cmp2)	// cmp = 1
			result = cmp2;
		else			// cmp = 0
			result = cmp1;
	end
	else if(select == 1) // output minimum value
	begin
		if(cmp1 < cmp2)	// cmp = 1
			result = cmp1;
		else			// cmp = 0
			result = cmp2;
	end
end
endmodule