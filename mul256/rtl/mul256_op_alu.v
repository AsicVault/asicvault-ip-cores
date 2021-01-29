//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : ALU modules for mul256_op_ahblite_new
//
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//
//-------------------------------------------------------------------------------


module mul256_op_alu_tmp #(parameter P_WIDTH = 260) (
	input		[P_WIDTH-1:0]	a		,
	input		[P_WIDTH-1:0]	b		,
	input		[        3:0]	s		,
	output		[P_WIDTH-1:0]	x		
);

	//operations:
	//s[3] b1 = s[3]? b<<1 : b
	//s[2:1]:
	// 00: x1 = a
	// 01: x1 = a
	// 10: x1 = a - b1
	// 11: x1 = a + b1
	//s[0]:
	// x = s[0]? x1 >> 1 : x1


	wire [P_WIDTH-1:0] b1, x1;

	mul256_alu_pre1 #(P_WIDTH) i_mul256_alu_pre1 (
		.b	(	b		),
		.s	(	s[3]	),
		.x	(	b1		)
	);
	
	mul256_alu_op1 #(P_WIDTH) i_mul256_alu_op1 (
		.a	(	a		),
		.b	(	b1		),
		.s	(	s[2:1]	),
		.x	(	x1		)
	);
	
	mul256_alu_op2 #(P_WIDTH) i_mul256_alu_op2 (
		.a	(	x1		),
		.s	(	s[0]	),
		.x	(	x		)
	);

	//assign x = x1;
	
endmodule



module mul256_alu_op1 #(parameter P_WIDTH = 260) (
	input		[P_WIDTH-1:0]	a		,
	input		[P_WIDTH-1:0]	b		,
	input		[        1:0]	s		,
	output		[P_WIDTH-1:0]	x		
);

	wire [P_WIDTH-1:0] b1 = s[1]? b : 0;
	assign x = s[0]? a + b1 : a - b1;

endmodule


module mul256_alu_op2 #(parameter P_WIDTH = 260) (
	input		[P_WIDTH-1:0]	a		,
	input		[P_WIDTH-1:0]	b		,
	input		[        1:0]	s		,
	output		[P_WIDTH-1:0]	x		
);

	//assign x = s[1]? b<<1 : s[0]? 0 : b;
	assign x = s[1]? 0 : s[0]? a+b : a-b;

endmodule


module mul256_alu_pre1 #(parameter P_WIDTH = 8) (
	input		[P_WIDTH-1:0]	b		,
	input		[        0:0]	s		,
	output		[P_WIDTH-1:0]	x		
);

	assign x = s[0]? {b[P_WIDTH-2:0],1'b0} : b;

endmodule



module mul256_alu_mux1_wrp #(parameter P_WIDTH = 260) (
	input						clk		,
	input		[P_WIDTH-1:0]	a		,
	input		[P_WIDTH-1:0]	b		,
	input		[        3:0]	s		,
	output	reg	[P_WIDTH-1:0]	x		
);

	reg	 [P_WIDTH-1:0]	ra, rb;
	reg  [        1:0]	rs;
	wire [P_WIDTH-1:0]	wx;
	
	always @(posedge clk) begin
		ra <= a;
		rb <= b;
		x  <= wx;
		rs <= s;
	end

	mul256_alu_op1 #(P_WIDTH) i_dut (
		.a	(	ra	),
		.b	(	rb	),
		.s	(	rs	),
		.x	(	wx	)
	);
	
endmodule


module mul256_op_alu #(parameter P_WIDTH = 260) (
	input		[P_WIDTH-1:0]	a		,
	input		[P_WIDTH-1:0]	b		,
	input		[P_WIDTH-1:0]	m		,
	input		[P_WIDTH-1:0]	p		,
	input		[        5:0]	s		,
	output	reg	[P_WIDTH-1:0]	x		
);

	//operations:
	//s[3:0] 
	// 0000: x = b
	// 0001: x = a>>1
	// 0010: x = a
	// 0011: x = a>>1
	// 0100: x = a-b
	// 0101: x = (a-b)>>1
	// 0110: x = a+b
	// 0111: x = (a+b)>>1
	// 1000: x = b
	// 1001: x = a>>1
	// 1010: x = a
	// 1011: x = a>>1
	// 1100: x = a-2*b
	// 1101: x = (a-2*b)>>1
	// 1110: x = (a+2*b)
	// 1111: x = (a+2*b)>>1
	
	
	// 01: x1 = a
	// 10: x1 = a - b1
	// 11: x1 = a + b1
	//s[0]:
	// x = s[0]? x1 >> 1 : x1


	always @* begin
		x = s[3]? b<<1 : b;
		x = s[2]? x : 0;
		x = s[1]? a + x : a - x;
		//x = (s[0]? x>>1: (s[2:1]==2'b00)? b : x) & {P_WIDTH{~s[4]}};
		x = (s[0]? x>>1: (s[2:1]==2'b00)? b : x);
		x = s[5]? p : s[4]? m : x;
		//x = x | (m & {P_WIDTH{s[5]}} | p);
	end
	
	
endmodule


module mul256_op_cmp #(parameter P_WIDTH = 260) (
	input		[P_WIDTH-1:0]	a		,
	input		[P_WIDTH-1:0]	b		,
	output						g		,
	output						l		,
	output						eq		
);
	wire [P_WIDTH : 0] x;
	assign x = a - b;
	assign l = x[P_WIDTH];
	assign g = ~(l | eq);
	assign eq = x[P_WIDTH-1:0] == 0;
	
endmodule
