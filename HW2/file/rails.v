module rails(clk, reset, data, valid, result);

input        clk;
input        reset;
input  [3:0] data;
output reg   valid;
output reg   result; 

/*
	Write Your Design Here ~
*/
reg flag_first_in;		// detect the first data input 
reg [3:0] number;				// input number of trains
reg [3:0] count;				// count coming train order
reg [3:0] pop_count;			// count pop times

reg data_tog = 0;				// toggle the data to detect data input

wire [3:0] q_out;	// queue output
wire [3:0] s_out;	// stack output

reg push_q;
reg pop_q;
reg rst_q;

reg push_s;
reg pop_s;
reg rst_s;

Queue queue1(clk, rst_q, data, q_out, push_q, pop_q);
Stack stack1(clk, rst_s, count, s_out, push_s, pop_s);

/* 4 state
 * ST0: Push the input data to queue (FIFO) and separate number and data
 * ST1 to ST2 is to compare queue output with stack output (number of train)
 * ST1: if q_out > s_out, push stack
 * ST2: if q_out = s_out, pop both (queue and stack)
 * ST3: Check result:
 * - if q_out < s_out, result = 0 (impossible to meet)
 * - if counter = number, result = 1
 */
reg [1:0] CurrentState, NextState;
parameter [1:0] ST0 = 2'b00,
				ST1 = 2'b01,
				ST2 = 2'b10,
				ST3 = 2'b11;

initial begin
	flag_first_in = 1;
	number = 0;
	count = 0;
	pop_count = 0;
end

/* State register (Sequential) */
always @(posedge clk or posedge reset)
begin
	if(reset)
		CurrentState <= ST0;
	else
		CurrentState <= NextState;
end

always @(CurrentState or data or number)
begin
	if(number)
	begin
		flag_first_in = 0;
	end
	else
	begin
		flag_first_in = 1;
	end
end

/* toggle the signal to detect consecutive input */
always @(negedge clk)
begin
	if(data)
	begin
		data_tog = ~data_tog;
	end
end

/* Next-state logic (Combinational) */
always @(data or data_tog or s_out or CurrentState)
begin
	case (CurrentState)
	ST0	:
	begin
		if(flag_first_in)	// not number and need to receive from data
		begin
			push_q = 0;
			number = data;
			NextState = ST0;
		end
		else if(count == number)
		begin
			count = 0;	// reset the count in order to use for stack input
			// push_s = 1;
			NextState = ST1;	// if get the number, push to ST1
		end
		else
		begin
			count = count + 1;	// count for filling queue
			push_q = 1;	// push data to queue
			NextState = ST0;
		end
	end 
	ST1 :
	begin
		if(q_out > s_out)
		begin
			count = count + 1;
			/* push stack */
			push_q = 0;
			push_s = 1;
			pop_q = 0;
			pop_s = 0;
	
			NextState = ST1;
		end

		else if(q_out == s_out)
		begin
			/* pop both */
			pop_count = pop_count + 1;
			push_q = 0;
			push_s = 0;
			pop_q = 1;
			pop_s = 1;
			NextState = ST2;
		end
		else
		begin
			NextState = ST1;
		end
	end

	ST2 :
	begin
		if(q_out > s_out)
		begin
			/* push stack */
			count = count + 1;
			push_q = 0;
			push_s = 1;
			pop_q = 0;
			pop_s = 0;
			NextState = ST1;
		end
		else if(q_out < s_out || pop_count == number)
		begin
			/* check result */
			push_q = 0;
			push_s = 0;
			pop_q = 0;
			pop_s = 0;
			NextState = ST3;
		end
		
		else
		begin
			pop_count = pop_count + 1;
			NextState = ST2;
		end
	end
	ST3 :
		begin
			if(valid)
			begin
				NextState = ST0;
			end
			else
			begin
				NextState = ST3;
			end
		end
		default: NextState = ST0;
	endcase
end

/* Output logic (Combinational) */

always @(CurrentState)
begin
	case (CurrentState)
	ST0	:
	begin
		valid = 0;
	end 
	ST1 :
	begin
		valid = 0;
	end
	ST2:
	begin
		valid = 0;
	end
	ST3:
	begin
		if(q_out < s_out)
		begin
			result = 0;
		end
		else if (pop_count == number)
		begin
			result = 1;
		end
		if(valid)
		begin
			valid = 0;
		end
		else
		begin
			valid = 1;
		end
	end
		default: valid = 0;
	endcase
end

always @(valid)
begin
	if(valid)
	begin
		rst_q = 1;
		rst_s = 1;
		count = 0;
		pop_count = 0;
		number = 0;
	end
	else
	begin
		rst_q = 0;
		rst_s = 0;
	end
end

endmodule