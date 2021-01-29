//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : eccop_alu
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

module eccop_alu #(parameter P_WIDTH = 260) (
	input		[P_WIDTH-1:0]	w		,
	input		[P_WIDTH-1:0]	b		,
	input		[P_WIDTH-1:0]	m		,
	input		[P_WIDTH-1:0]	p		,
	input		[        6:0]	s		,
	output		[P_WIDTH-1:0]	q		,
	output						zero	,
	output						carry	
);

	//operations:
	//s[6:0]
	//0000000 : q = w + b
	//0000001 : q = 2w + b
	//0000010 : q = w - b
	//0000011 : q = 2w - b

	//0000100 : q = 0 // w
	//0000101 : q = 0 // 2w

	//0011000 : q = (w >= b)? w - b : w //part of fast prime
	
	//0101000 : q = p
	//0101010 : q = w
	//0101011 : q = 2w
	//1001000 : q = b
	//1001001 : q = w >> 1
	

	wire [P_WIDTH-1:0] z, t, u;
	wire [P_WIDTH:0] sum, a, x, y, mb;
	
	assign mb = -b;
	
	assign x = s[0]? w << 1 : w;
	//assign y = s[2]? 0 : s[1]? mb : b;
	assign sum = s[2]? 0 : s[1]? x - b : x + b;
	assign a = s[3]? 0 : sum;
	assign carry =  sum[P_WIDTH];
	assign zero  = (sum[P_WIDTH-1:0] === {(P_WIDTH){1'b0}});

	// half of fast prime implemented directly
	assign z = s[4]? (w < b)? w : w - b : 0;

	//assign t = s[5]? s[0]? m : p  : 0;
	assign t = s[5]? s[1]? x : p  : 0;
	assign u = s[6]? s[0]? w >> 1 : b : 0;
	assign q = a | z | t | u;
	
endmodule

/* This variant is not optimal

module eccop_alu1 #(parameter P_WIDTH = 260) (
	input		[P_WIDTH-1:0]	w		,
	input		[P_WIDTH-1:0]	b		,
	input		[P_WIDTH-1:0]	m		,
	input		[P_WIDTH-1:0]	p		,
	input		[        6:0]	s		,
	output	reg	[P_WIDTH-1:0]	q		,
	output		reg				zero	,
	output		reg				carry	
);

	reg [P_WIDTH:0] b2, o;
	
	always @* begin
		carry = 0;
		zero = 0;
		b2 = b << 1;
		case (s[3:0]) 
			'd1 : q = b2;
			'd2 : begin q = w + b; zero = (q[P_WIDTH-1:0] === {(P_WIDTH){1'b0}}); carry = q[P_WIDTH]; end
			'd3 : begin q = w - b; zero = (q[P_WIDTH-1:0] === {(P_WIDTH){1'b0}}); carry = q[P_WIDTH]; end
			'd4 : begin q = w + b2; zero = (q[P_WIDTH-1:0] === {(P_WIDTH){1'b0}}); carry = q[P_WIDTH]; end
			'd5 : q = (w >= b)? (w >= b2)? w - b2 : w - b : w;
			'd6 : q = w[0]? (w + b)>>1 : w >> 1;
			'd7 : q = m;
			'd8 : q = p;
		default : q = b;
		endcase
	end
	
endmodule
*/

`ifdef __SYN_TEST
module eccop_alu_wrp #(parameter P_WIDTH = 260) (
	input		clk		,
	input		i		,
	output		o 		
);

	reg [P_WIDTH-1:0] w,b,m,p,q;
	reg [6:0] s;
	reg z,c;
	wire [P_WIDTH-1:0] wq;
	wire wc, wz;
	assign o = c ^ z ^ ^q;
	
	always @(posedge clk) begin
		w <= {w[P_WIDTH-2:0],i};
		b <= {b[P_WIDTH-2:0],w[P_WIDTH-1]};
		m <= {m[P_WIDTH-2:0],b[P_WIDTH-1]};
		p <= {p[P_WIDTH-2:0],m[P_WIDTH-1]};
		s <= {s[7-2:0],p[P_WIDTH-1]};
		c <= wc;
		z <= wz;
		q <= wq;
	end

	eccop_alu2 #(P_WIDTH) i_eccop_alu (
		.w		(	w	),
		.b		(	b	),
		.m		(	m	),
		.p		(	p	),
		.s		(	s	),
		.q		(	wq	),
		.zero	(	wz	),
		.carry	(	wc	)
	);

endmodule
`endif


