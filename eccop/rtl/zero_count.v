//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : Various implementations of zero counting and shifting 
//             : functions
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

//688 LUT
module zero_count #(parameter P_WIDTH=256) (
	input		[P_WIDTH-1:0]			i,
	output	reg	[$clog2(P_WIDTH) :0]	c
);

	always @* begin : loop
		integer a;
		c = i[0]? 0 : P_WIDTH;
		for (a=0; a<P_WIDTH; a=a+1)
			if (i[a]) begin
				c = a;
				break;
			end
	end

endmodule


//693 LUT
module zero_count1 #(parameter P_WIDTH=256) (
	input		[P_WIDTH-1:0]			i,
	output	reg	[$clog2(P_WIDTH) :0]	c
);
	wire [P_WIDTH:0] wi = {1'b1,i};
	always @* begin : loop
		integer a;
		c = 0;
		for (a=0; a<P_WIDTH+1; a=a+1)
			if (wi[a]) begin
				c = a;
				break;
			end
	end

endmodule


//326 LUT (count 0 - 255, incorrect for all 0's))
module zero_count_rec #(parameter P_WIDTH_LOG2=8) (
	input	[2**P_WIDTH_LOG2-1:0]	i,
	output	[   P_WIDTH_LOG2-1:0]	c,
	output                          f
);

	generate if (P_WIDTH_LOG2 > 1) begin : mux
		wire [2**(P_WIDTH_LOG2-1)-1:0] l = i[2**(P_WIDTH_LOG2-1)-1 -:2**(P_WIDTH_LOG2-1)];
		wire [2**(P_WIDTH_LOG2-1)-1:0] h = i[2**(P_WIDTH_LOG2-0)-1 -:2**(P_WIDTH_LOG2-1)];
		wire [   P_WIDTH_LOG2-1:0]	x;
		//wire [2**(P_WIDTH_LOG2-1)-0:0] lt = l + {2**(P_WIDTH_LOG2-1){1'b1}}; 
		//assign c[P_WIDTH_LOG2-1] = ~lt[2**(P_WIDTH_LOG2-1)];
		assign c[P_WIDTH_LOG2-1] = (l==0);
		zero_count_rec #(P_WIDTH_LOG2-1) i_zero_count_rec (.i(c[P_WIDTH_LOG2-1]? h : l), .c(c[P_WIDTH_LOG2-2:0]), .f(f));
	end else begin
		assign c[P_WIDTH_LOG2-1] = i[0]? 1'b0 : 1'b1;
		assign f = (i[1:0]==2'b00)? 1'b1 : 1'b0;
	end endgenerate
	
endmodule

//339 LUT (correct count 0 - 256)
module zero_count_rec_crr #(parameter P_WIDTH_LOG2=8) (
	input	[2**P_WIDTH_LOG2-1:0]	i,
	output	[   P_WIDTH_LOG2  :0]	c
);
	wire f;
	wire	[   P_WIDTH_LOG2-1:0]	x;
	zero_count_rec #(P_WIDTH_LOG2) i_zero_count_rec (.i(i), .c(x), .f(f));
	
	assign c = x + f;
	
endmodule



//408 LUT
module zero_count_rec2 #(parameter P_WIDTH_LOG2=8) (
	input	[2**P_WIDTH_LOG2-1:0]	i,
	output	[   P_WIDTH_LOG2  :0]	c
);

	generate if (P_WIDTH_LOG2 > 2) begin : mux
		wire [   P_WIDTH_LOG2-1:0]	cl, ch;
		zero_count_rec2 #(P_WIDTH_LOG2-1) i_zero_count_rec_l (.i(i[2**(P_WIDTH_LOG2-1)-1 -:2**(P_WIDTH_LOG2-1)]), .c(cl));
		zero_count_rec2 #(P_WIDTH_LOG2-1) i_zero_count_rec_h (.i(i[2**(P_WIDTH_LOG2-0)-1 -:2**(P_WIDTH_LOG2-1)]), .c(ch));
		assign c = cl[P_WIDTH_LOG2-1]? {1'b0,ch} + 2**(P_WIDTH_LOG2-1) : {1'b0,cl};
	end else begin
		reg [P_WIDTH_LOG2:0] cr;
		assign c = cr;
		always @* begin
			cr = i[0]? 0 : 2**P_WIDTH_LOG2;
			for (int a=0; a<(2**P_WIDTH_LOG2); a=a+1)
				if (i[a]) begin
					cr = a;
					break;
				end
		end
	end endgenerate
	
endmodule


//2347 LUT
module zero_count_shift #(parameter P_WIDTH_LOG2=8, parameter P_DWIDTH=256) (
	input	[       P_DWIDTH-1:0]	d,
	output	[       P_DWIDTH-1:0]	e,
	input	[2**P_WIDTH_LOG2-1:0]	i,
	output	[   P_WIDTH_LOG2-1:0]	c
);

	generate if (P_WIDTH_LOG2 > 1) begin : mux
		wire [2**(P_WIDTH_LOG2-1)-1:0] l = i[2**(P_WIDTH_LOG2-1)-1 -:2**(P_WIDTH_LOG2-1)];
		wire [2**(P_WIDTH_LOG2-1)-1:0] h = i[2**(P_WIDTH_LOG2-0)-1 -:2**(P_WIDTH_LOG2-1)];
		assign c[P_WIDTH_LOG2-1] = (l==0)? 1'b1 : 0;
		zero_count_shift #(P_WIDTH_LOG2-1, P_DWIDTH) i_zero_count_shift (.d(c[P_WIDTH_LOG2-1]? d>>(2**(P_WIDTH_LOG2-1)) : d), .e(e), .i((l==0)? h : l), .c(c[P_WIDTH_LOG2-2:0]));
	end else begin
		assign c[P_WIDTH_LOG2-1] = i[0]? 1'b0 : 1'b1;
		assign e = d >> ~i[0];
	end endgenerate
	
endmodule


//2302 LUT
module zero_count_shift_2 #(parameter P_WIDTH_LOG2=8, parameter P_DWIDTH=256) (
	input	[       P_DWIDTH-1:0]	d,
	output	[       P_DWIDTH-1:0]	e,
	input	[2**P_WIDTH_LOG2-1:0]	i
);
	wire [P_WIDTH_LOG2-1:0] c;

	zero_count_rec #(P_WIDTH_LOG2) i_zero_count_rec (.i(i),.c(c));
	
	assign e = d >> c;

endmodule


//2045 LUT
module shifter_rec #(parameter P_WIDTH_LOG2=8, parameter P_DWIDTH=256) (
	input	[       P_DWIDTH-1:0]	d,
	output	[       P_DWIDTH-1:0]	e,
	input	[   P_WIDTH_LOG2-1:0]	c
);
	generate if (P_WIDTH_LOG2 > 1) begin
		shifter_rec #(P_WIDTH_LOG2-1, P_DWIDTH) i_shifter_rec (.d(c[P_WIDTH_LOG2-1]? d>>(2**(P_WIDTH_LOG2-1)) : d),.e(e),.c(c[P_WIDTH_LOG2-2:0]));
	end else begin 
		assign e = d >> c[0];
	end endgenerate

endmodule

//2355 LUT
module zero_count_shift_3 #(parameter P_WIDTH_LOG2=8, parameter P_DWIDTH=256) (
	input	[       P_DWIDTH-1:0]	d,
	output	[       P_DWIDTH-1:0]	e,
	input	[2**P_WIDTH_LOG2-1:0]	i
);
	wire [P_WIDTH_LOG2-1:0] c;

	zero_count_rec #(P_WIDTH_LOG2) i_zero_count_rec (.i(i),.c(c));
	shifter_rec #(P_WIDTH_LOG2, P_DWIDTH) i_shifter_rec (.d(d),.e(e),.c(c));

endmodule

`timescale 1ns/1ns
module tb_zero_count;
	parameter P_WIDTH_LOG2 = 8;
	reg clk = 0;
	always begin #5; clk++; end
	
	reg [2**P_WIDTH_LOG2:0] a;
	
	//zero_count_rec #(P_WIDTH_LOG2) dut (.i(a), .c());
	zero_count_rec_crr #(P_WIDTH_LOG2) dut (.i(a), .c());
	
	int t;
	initial begin
		a = {(2**P_WIDTH_LOG2){1'b1}};
		t = 0;
		repeat (2**P_WIDTH_LOG2) begin
			@(posedge clk);
			if (dut.c !== t)
				$display("%t ns: ERROR: expected %d !== read %d", $time, t, dut.c);
			a=a<<1;
			t++;
		end
		@(posedge clk);
		$stop();
	end

endmodule
