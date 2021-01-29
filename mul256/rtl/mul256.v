//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert, Hando Eilsen
//
// Description : Implementations of various wide multiplier modules
//
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//
//-------------------------------------------------------------------------------

// Generic asynchronous multiplier with recursive structure
// impl 0 - inferred by synthesis tool, not recursive
// impl 1 - 3 multipliers montgomery, center term multiplier 1-bit wider 
// impl 2 - 3 multipliers montgomery, all multipliers same width, center term overflow prevented by additions

// LUT and MHz values are measured on Microchip/Micosemi M2GL060TS-1FCSG325

// implementations (32 bit examples):
// impl = 0 : inferred multiplier. 
//  Inferred - 4 DSP, 0 LUTS, 0 CC, 123MHz
// impl = 1 : three multiplications, center multiplication 2 bits wider
//  3 DSP, 178 LUTS, 147 CC , 81.7 MHz 
// impl = 2 : three multiplications, a add-fix calculated for center multiplication
//  3 DSP, 215 LUT, 183 CC, 67,1 MHz

// 64 bit, impl=0:
// 16 DSP, 0 LUT, 0 CC - 24,7 MHz
// 64 bit, impl=1, infer32=0:
// 9 DSP, 897 LUT, 801 CC, 49.4 MHz
// 64 bit, impl=1, infer32=1:
// 12 DSP, 357 LUT, 357 CC, 48,2 MHz
// 64 bit, impl=2, infer32=0:
// 9 DSP, 1051 LUT, 939 CC, 46,6 MHz
// 64 bit, impl=2, infer32=1:
// 12 DSP, 424 LUT, 424 CC, 42.9 MHz

// 128 bit, impl=0:
// 64 DSP, 299 LUT, 299 CC, 13.6 MHz
// 128 bit, impl=1, infer32=0: (impl==1 may not be correct as center multiplier is 65 bit wide)
// 27 DSP, 3402 LUT, 3114 CC, 34.5MHz
// 128 bit, impl=1, infer32=1:
// 36 DSP, 1785 LUT, 1783 CC, 34.0 MHz
// 128 bit, impl=2, infer32=0:
// 27 DSP, 3931 LUT, 3591 CC, 35.1 MHz
// 128 bit, impl=2, infer32=1:
// 36 DSP, 2079 LUT, 2046 CC, 33.0 MHz


module mul_as #(parameter W=32, parameter impl=0, parameter infer32=0) (
	input	[W-1:0]		a,
	input	[W-1:0]		b,
	output  [2*W-1:0]	p
);

	generate if ((impl==0) || (W<(infer32? 34:19))) begin
		assign p = a * b;
	end else if (impl==1) begin
		wire [W/2-1:0] a0 = a[W/2-1: 0];
		wire [W/2-1:0] a1 = a[W-1: W/2];
		wire [W/2-1:0] b0 = b[W/2-1: 0];
		wire [W/2-1:0] b1 = b[W-1: W/2];
		wire [W/2  :0] t0 = a0 + a1;
		wire [W/2  :0] t1 = b0 + b1;
		
		wire [W-1:0]	a0b0;
		wire [W-1:0]	a1b1;
		wire [W+2-1:0]	t0t1;

		mul_as #(W/2+0, impl, infer32) i_mul_a0b0(.a(a0),.b(b0),.p(a0b0));
		mul_as #(W/2+0, impl, infer32) i_mul_a1b1(.a(a1),.b(b1),.p(a1b1));
		mul_as #(W/2+1, impl, infer32) i_mul_t0t1(.a(t0),.b(t1),.p(t0t1));

		wire [W+2-1:0] mt = t0t1 - a0b0 - a1b1;
		
		wire [W/2-1:0] o1  = a0b0[W/2-1:0];
		wire [W-1  :0] o23 = {a1b1[W/2-1:0], a0b0[W-1:W/2]};
		wire [W/2-1:0] o4  = a1b1[W-1:W/2];
		wire [W+2-1:0] mts = mt + o23;
		assign p = {o4+mts[W+2-1:W], mts[W-1:0], o1};
	end else begin
		wire [W/2-1:0] a0 = a[W/2-1: 0];
		wire [W/2-1:0] a1 = a[W-1: W/2];
		wire [W/2-1:0] b0 = b[W/2-1: 0];
		wire [W/2-1:0] b1 = b[W-1: W/2];
		wire [W/2  :0] t0 = a0 + a1;
		wire [W/2  :0] t1 = b0 + b1;
		
		wire [W-1  :0] a0b0;
		wire [W-1  :0] a1b1;
		wire [W-1  :0] t0t1;
		wire [W+2-1:0] t_fix = (t0[W/2]? {t1,{(W/2){1'b0}}} : 0) + (t1[W/2]? {1'b0,t0[W/2-1:0],{(W/2){1'b0}}} : 0);

		mul_as #(W/2, impl, infer32) i_mul_a0b0(.a(a0),.b(b0),.p(a0b0));
		mul_as #(W/2, impl, infer32) i_mul_a1b1(.a(a1),.b(b1),.p(a1b1));
		mul_as #(W/2, impl, infer32) i_mul_t0t1(.a(t0[W/2-1:0]),.b(t1[W/2-1:0]),.p(t0t1));

		wire [W+2-1:0] t = t_fix + t0t1;
		
		wire [W+2-1:0] mt = t - a0b0 - a1b1;
		
		wire [W/2-1:0] o1  = a0b0[W/2-1:0];
		wire [W-1  :0] o23 = {a1b1[W/2-1:0], a0b0[W-1:W/2]};
		wire [W/2-1:0] o4  = a1b1[W-1:W/2];
		wire [W+2-1:0] mts = mt + o23;
		assign p = {o4+mts[W+2-1:W], mts[W-1:0], o1};
	end endgenerate

endmodule

// Generic single stage synchronous multiplier with recursive structure
// latency:
// W < 19 : 1
// W > 19 : 2
// W > 35 : 3
// W > 65 : 4
 
// implementations:
// W=17 :
// 1 DSP, 0 LUT, 0 FF, 0 CC - 721 MHz
// W=18 :
// 1 DSP, 37 LUT, 36 FF, 19 CC - 163.5 MHz
// W=32 :
// 3 DSP, 192 LUT, 64 FF, 192 CC - 175.2 MHz
// W=33 :
// 3 DSP, 237 LUT, 102 FF, 219 CC - 129.9 MHz
// W=64 :
// 9 DSP, 943 LUT, 358 FF, 925 CC - 109.3 MHz
// W=128:
// 36 DSP, 3832 LUT, 1688 FF, 3760 CC - 109.2 MHz
// W=128, 3xmul
// 27 DSP, 3602 LUT, 1332 FF, 3548 CC - 92.1 MHz

module mul_so #(parameter W=32, parameter IMPL=0) (
	input					clk	,
	input					ce	,
	input		[  W-1:0]	a	,
	input		[  W-1:0]	b	,
	output 		[2*W-1:0]	pa	,
	output reg	[2*W-1:0]	p	
);
	generate if (W<18) begin
		assign pa = a * b;
		always @(posedge clk) 
			if (ce) 
				p <= pa;
	end else if ((W==18) || ((W>64) && (W&1))) begin
		//2*n+1 bit unsigned through montgomery 
		//al = A[16:0]; ah = A[17]<<17
		//bl = B[16:0]; bh = B[17]<<17
		//P = (ah+al)*(bh+bl) = al*bl + ah*bl + bh*al + ah*bh
		wire [W-2:0] al = a[W-2:0];
		wire [W-2:0] bl = b[W-2:0];
		wire [W*2-1:0] ahbl = a[W-1]? {1'b0,bl,{W-1{1'b0}}} : 0;
		wire [W*2-1:0] bhal_ahbh = b[W-1]? {(b[W-1]&a[W-1]),al,{W-1{1'b0}}} : 0;
		wire [W*2-3:0] albl;
		reg [W*2-1:0] t [0:3];
		mul_so #(W-1, IMPL) i_mul(.clk(clk),.ce(ce),.a(al),.b(bl),.pa(albl));
		always @(posedge clk) 
			if (ce) begin
				t[0] <= ahbl + bhal_ahbh;
				t[1] <= t[0];
				t[2] <= t[1];
				t[3] <= t[2];
			end
		
		assign pa = albl + ((W>64)? (W>128)? t[2] : t[1] : ahbl + bhal_ahbh);
		always @(posedge clk) 
			if (ce) 
				p <= pa;
	end else if ((W&1) && (W<34)) begin
		wire [W:0] ae = {1'b0,a};
		wire [W:0] be = {1'b0,b};
		wire [2*W+1:0] pe, pae;
		mul_so #(W+1, IMPL) i_mul(.clk(clk),.ce(ce),.a(ae),.b(be),.p(pe),.pa(pae));
		assign pa = pae[2*W-1:0];
		assign p  = pe [2*W-1:0];
	end else if (((IMPL==0) & (W>128)) | ((IMPL==1) & (W>65)) | ((IMPL==2) & (W>34))) begin // implementation with 4x multipliers
		wire [W/2-1:0] a0 = a[W/2-1: 0];
		wire [W/2-1:0] a1 = a[W-1: W/2];
		wire [W/2-1:0] b0 = b[W/2-1: 0];
		wire [W/2-1:0] b1 = b[W-1: W/2];
		
		wire [W-1:0]	a0b0;
		wire [W-1:0]	a1b1;
		wire [W-1:0]	a1b0;
		wire [W-1:0]	a0b1;

		mul_so #(W/2+0, IMPL) i_mul_a0b0(.clk(clk),.ce(ce),.a(a0),.b(b0),.p(a0b0));
		mul_so #(W/2+0, IMPL) i_mul_a0b1(.clk(clk),.ce(ce),.a(a0),.b(b1),.p(a0b1));
		mul_so #(W/2+0, IMPL) i_mul_a1b0(.clk(clk),.ce(ce),.a(a1),.b(b0),.p(a1b0));
		mul_so #(W/2+0, IMPL) i_mul_a1b1(.clk(clk),.ce(ce),.a(a1),.b(b1),.p(a1b1));
		
		assign pa = {a1b1,a0b0} + {a0b1,{W/2{1'b0}}} + {a1b0,{W/2{1'b0}}};
		
		always @(posedge clk)
			if (ce)
				p <= pa;
	end else begin // implementation with 3x multipliers
		wire [W/2-1:0] a0 = a[W/2-1: 0];
		wire [W/2-1:0] a1 = a[W-1: W/2];
		wire [W/2-1:0] b0 = b[W/2-1: 0];
		wire [W/2-1:0] b1 = b[W-1: W/2];
		wire [W/2  :0] t0 = a0 + a1;
		wire [W/2  :0] t1 = b0 + b1;
		
		wire [W-1:0]	a0b0;
		wire [W-1:0]	a1b1;
		wire [W+2-1:0]	t0t1;

		mul_so #(W/2+0, IMPL) i_mul_a0b0(.clk(clk),.ce(ce),.a(a0),.b(b0),.p(a0b0));
		mul_so #(W/2+0, IMPL) i_mul_a1b1(.clk(clk),.ce(ce),.a(a1),.b(b1),.p(a1b1));
		mul_so #(W/2+1, IMPL) i_mul_t0t1(.clk(clk),.ce(ce),.a(t0),.b(t1),.p(t0t1));
		
		wire [W+2-1:0] a0b0a1b1 = a0b0 + a1b1;
		
		assign pa = {a1b1,a0b0} + {t0t1,{W/2{1'b0}}} - {a0b0a1b1,{W/2{1'b0}}};
		
		always @(posedge clk)
			if (ce)
				p <= pa;
	end endgenerate

endmodule

//Implementation results:
// W=128, 3x conf
// 27 DSP, 3729 LUT, 3672 CC - 46.2 MHz
// W=128, 4x conf
// 36 DSP, 3932 LUT, 3856 CC - 49.1 MHz
// W=64:
// 9 DSP, 943 LUT, 925 CC - 68.4 MHz
// W=32:
// 3 DSP, 192 LUT, 192 CC - 113.5 MHz

module mul_as1 #(parameter W=32) (
	input		[  W-1:0]	a	,
	input		[  W-1:0]	b	,
	output		[2*W-1:0]	p	
);
	generate if (W<18) begin
		assign p = a * b;
	end else if ((W==18) || ((W>64) && (W&1))) begin
		//2*n+1 bit unsigned through montgomery 
		//al = A[16:0]; ah = A[17]<<17
		//bl = B[16:0]; bh = B[17]<<17
		//P = (ah+al)*(bh+bl) = al*bl + ah*bl + bh*al + ah*bh
		wire [W-2:0] al = a[W-2:0];
		wire [W-2:0] bl = b[W-2:0];
		wire [W*2-1:0] ahbl = a[W-1]? {1'b0,bl,{W-1{1'b0}}} : 0;
		wire [W*2-1:0] bhal_ahbh = b[W-1]? {(b[W-1]&a[W-1]),al,{W-1{1'b0}}} : 0;
		wire [W*2-3:0] albl;
		mul_as1 #(W-1) i_mul(.a(al),.b(bl),.p(albl));
		assign p = albl + ahbl + bhal_ahbh;
	end else if ((W&1) && (W<34)) begin
		wire [W:0] ae = {1'b0,a};
		wire [W:0] be = {1'b0,b};
		wire [2*W+1:0] pe, pae;
		mul_as1 #(W+1) i_mul(.a(ae),.b(be),.p(pe));
		assign p  = pe [2*W-1:0];
	//end else if (W>128) begin // large multiplier implement with 3x 
	end else if (W>65) begin // large multiplier implement with 4x 
		wire [W/2-1:0] a0 = a[W/2-1: 0];
		wire [W/2-1:0] a1 = a[W-1: W/2];
		wire [W/2-1:0] b0 = b[W/2-1: 0];
		wire [W/2-1:0] b1 = b[W-1: W/2];
		
		wire [W-1:0]	a0b0;
		wire [W-1:0]	a1b1;
		wire [W-1:0]	a1b0;
		wire [W-1:0]	a0b1;

		mul_as1 #(W/2+0) i_mul_a0b0(.a(a0),.b(b0),.p(a0b0));
		mul_as1 #(W/2+0) i_mul_a0b1(.a(a0),.b(b1),.p(a0b1));
		mul_as1 #(W/2+0) i_mul_a1b0(.a(a1),.b(b0),.p(a1b0));
		mul_as1 #(W/2+0) i_mul_a1b1(.a(a1),.b(b1),.p(a1b1));
		
		assign p = {a1b1,a0b0} + {a0b1,{W/2{1'b0}}} + {a1b0,{W/2{1'b0}}};
		
	end else begin 
		wire [W/2-1:0] a0 = a[W/2-1: 0];
		wire [W/2-1:0] a1 = a[W-1: W/2];
		wire [W/2-1:0] b0 = b[W/2-1: 0];
		wire [W/2-1:0] b1 = b[W-1: W/2];
		wire [W/2  :0] t0 = a0 + a1;
		wire [W/2  :0] t1 = b0 + b1;
		
		wire [W-1:0]	a0b0;
		wire [W-1:0]	a1b1;
		wire [W+2-1:0]	t0t1;

		mul_as1 #(W/2+0) i_mul_a0b0(.a(a0),.b(b0),.p(a0b0));
		mul_as1 #(W/2+0) i_mul_a1b1(.a(a1),.b(b1),.p(a1b1));
		mul_as1 #(W/2+1) i_mul_t0t1(.a(t0),.b(t1),.p(t0t1));
		
		wire [W+2-1:0] a0b0a1b1 = a0b0 + a1b1;
		
		assign p = {a1b1,a0b0} + {t0t1,{W/2{1'b0}}} - {a0b0a1b1,{W/2{1'b0}}};
		
	end endgenerate

endmodule


//multiplier with val/rdy hand-shaking
//input must be stable when ival==! until irdy == 1
//output is valid when oval == 1 and until ordy == 1
// implementations:
// MODE = 0 : inside is asynchronous multiplier
// input has to be kept stable until oval == 1 and ordy == 1
// MODE = 1 : inside is mul_so - input is always ready
// multiplication enables pipelining
module mul_hs #(parameter W=32, parameter MODE=0, parameter K=2, parameter IMPL=0) (
	input					clk		,
	input					srstn	,
	input					arstn	,
	input		[  W-1:0]	ia		,
	input		[  W-1:0]	ib		,
	input		[  K-1:0]	ikey	,
	input					ival	,
	output					irdy	,
	output		[2*W-1:0]	o		,
	output		[  K-1:0]	okey	,
	output					oval	,
	input					ordy	
);

	generate if (MODE == 0) begin
		// internally asynchronous, requires multicycle paths
		localparam LAT_128 = 2;
		localparam LAT_64  = 1;
		reg [2:0] lcntr = 0;
		assign oval = (lcntr == ((W > 65)? LAT_128 : (W>34)? LAT_64 : 0)) & ((W>34)? 1'b1 : ival);
		assign irdy = oval & ordy;
		assign okey = ikey;
		
		always @(posedge clk or negedge arstn)
			if (~srstn | ~arstn) begin
				lcntr <= 0;
			end else begin
				if (W>34) begin
					if (oval) begin
						lcntr <= ordy? 0 : lcntr;
					end else begin
						lcntr <= ival? lcntr + 1'b1 : lcntr;
					end
				end else begin
				end
			end
		
		mul_as1 #(W) i_mul (
			.a	(	ia	),
			.b	(	ib	),
			.p	(	o	)
		);
	
	end else begin
		//internally synchronous, no multicycles
		localparam LAT = (W>66)? 3: (W>34)? 2 : (W>18)? 1 : 1; 
		reg [3:0] inval = 0;
		reg [K-1:0] keypipe [0:3];
		wire ce /* synthesis syn_maxfan=33 */;
		assign ce = (oval? ordy : 1'b1 ) & ((ival & irdy) | ((W>18)? (|inval[LAT-1:0]) : 1'b0));
		assign irdy = oval? ordy : 1'b1;
		assign oval = (W>18)? inval[LAT] : (ival & irdy);
		assign okey = (W>18)? keypipe[LAT] : ikey;
		integer i;
		wire [2*W-1:0]	so, wo;
		assign o = (W>18)? so: wo;
		
		always @(posedge clk or negedge arstn)
			if (~srstn | ~arstn) begin
				inval <= 0;
				for (i=3; i>=0; i=i-1)
					keypipe[i] <= 0;
			end else begin
				if (ce | (oval & ordy))
					inval <= {inval[2:0], (ival & irdy)};
				if (ce) begin
					keypipe[0] <= ikey;
					for (i=3; i>0; i=i-1)
						keypipe[i] <= keypipe[i-1];
				end
			end
		
		mul_so #(W, IMPL) i_mul (
			.clk	(	clk		),
			.ce		(	ce		),
			.a		(	ia		),
			.b		(	ib		),
			.pa		(	wo		),
			.p		(	so		)
		);
	end endgenerate

endmodule


// multimplier implementing a wide multiplication with 4 sequential W/2 
// stages. If LEVEL = 0 the inetrnal W/2 multiplier is mul_hs, otherwise
// mul_4s
//
module mul_4s #(parameter W=256, parameter LEVEL=0, parameter K=2, parameter IMPL=0) (
	input					clk			,
	input					srstn		,
	input					arstn		,
	input		[  W-1:0]	ia			,
	input		[  W-1:0]	ib			,
	input		[  K-1:0]	ikey		,
	input					iload		,
	input					ival		,
	output					irdy		,
	output	reg	[2*W-1:0]	o	 = 0	,
	output	reg	[  K-1:0]	okey = 0	,
	output	reg				oval = 0	,
	input					ordy		
);

	localparam MODE = 1;

	reg [1:0] icnt = 0;
	wire ilast = (icnt == 2'b11);
	wire eirdy;
	reg [W/2-1:0] eia, eib;
	wire [W-1:0] c;
	wire [K+2-1:0] eokey;
	wire eoval, eordy;
	wire [1:0] ocnt;
	
	reg [W/2-1:0] ria, rib;
	reg rival = 0;
	reg [K+2-1:0] rikey;
	wire rilast = (rikey[1:0] == 2'b11);

	//input logic
	always @*
		case (icnt)
			2'b00  : begin eia <= ia[W/2-1 -: W/2]; eib <= ib[W/2-1 -: W/2]; end // a0b0
			2'b01  : begin eia <= ia[W/2-1 -: W/2]; eib <= ib[W  -1 -: W/2]; end // a0b1
			2'b10  : begin eia <= ia[W  -1 -: W/2]; eib <= ib[W/2-1 -: W/2]; end // a1b0
			default: begin eia <= ia[W  -1 -: W/2]; eib <= ib[W  -1 -: W/2]; end // a1b1
		endcase
	
	assign irdy = ilast & eirdy;
	
	always @(posedge clk or negedge arstn)
		if (~srstn | ~arstn) begin
			icnt <= 0;
			rival <= 0;
		end else begin
			if (ival & eirdy)
				icnt <= icnt + 1'b1;
			if (rival) begin
				if (eirdy & rilast)
					rival <= ival;
			end else begin
				rival <= ival;
			end
		end

	always @(posedge clk)
		if ((rival & eirdy) | (ival & ~rival)) begin
			ria <= eia;
			rib <= eib;
			rikey <= {ikey, icnt};
		end
		
		
		
	//output logic
	always @(posedge clk or negedge arstn)
		if (~srstn | ~arstn) begin
			oval <= 0;
			o <= 0;
			okey <= 0;
		end else begin
			if (eoval & eordy) begin
				case (ocnt)
					2'b00  : o <= {{W{1'b0}},c}; //          a0b0
					2'b01  : o <= o + {c, {W/2{1'b0}}}; // + a0b1 << W/2
					2'b10  : o <= o + {c, {W/2{1'b0}}}; // + a1b0 << W/2
					default: o <= o + {c, {W  {1'b0}}}; // + a1b1 << W
				endcase
				oval <= (ocnt==2'b11);
				okey <= eokey[K+2-1 -:K];
			end
			if (oval)
				oval <= ~ordy;
			if (iload) begin
				o <= {ib,ia};
				okey <= ikey;
			end
		end
	
	assign ocnt = eokey[1:0];
	assign eordy = oval? ordy : 1'b1;
	
	generate if (LEVEL == 0) begin
		mul_hs #(W/2,MODE,K+2,IMPL) i_mul (
			.clk	(	clk			),
			.srstn	(	srstn		),
			.arstn	(	arstn		),
			.ia		(	ria			),
			.ib		(	rib			),
			.ikey	(	rikey		),
			.ival	(	rival		),
			.irdy	(	eirdy		),
			.o		(	c			),
			.okey	(	eokey		),
			.oval	(	eoval		),
			.ordy	(	eordy		)
		);
	end else begin
		mul_4s #(W/2,LEVEL-1,K+2,IMPL) i_mul (
			.clk	(	clk			),
			.srstn	(	srstn		),
			.arstn	(	arstn		),
			.ia		(	ria			),
			.ib		(	rib			),
			.ikey	(	rikey		),
			.ival	(	rival		),
			.irdy	(	eirdy		),
			.iload	(	1'b0		),
			.o		(	c			),
			.okey	(	eokey		),
			.oval	(	eoval		),
			.ordy	(	eordy		)
		);
	end endgenerate


endmodule


// multimplier implementing a wide multiplication with 3 sequential W/2 
// stages. If LEVEL = 0 the internal W/2 multiplier is mul_hs, otherwise
// mul_3s
// 
module mul_3s #(parameter W=256, parameter LEVEL=0, parameter K=2, parameter IMPL=0) (
	input					clk			,
	input					srstn		,
	input					arstn		,
	input		[  W-1:0]	ia			,
	input		[  W-1:0]	ib			,
	input		[  K-1:0]	ikey		,
	input					iload		,
	input					ival		,
	output					irdy		,
	output	reg	[2*W-1:0]	o	 = 0	,
	output	reg	[  K-1:0]	okey = 0	,
	output	reg				oval = 0	,
	input					ordy		
);

	localparam MODE = 1;
	localparam IW = (W&1)? (W+1):W;

	wire [IW-1:0] wa = {1'b0,ia};
	wire [IW-1:0] wb = {1'b0,ib};
	
	
	reg [1:0] icnt = 0;
	wire ilast = (icnt == 2'b10);
	wire eirdy;
	reg [IW/2:0] eia, eib;
	wire [IW+1:0] c;
	wire [K+2-1:0] eokey;
	wire eoval, eordy;
	wire [1:0] ocnt;
	
	reg [IW/2:0] ria, rib;
	reg rival = 0;
	reg [K+2-1:0] rikey;
	wire rilast = (rikey[1:0] == 2'b10);


	//input logic
	always @*
		case (icnt)
			2'b00  : begin eia <= {1'b0,wa[IW/2-1 -: IW/2]}; eib <= {1'b0,wb[IW/2-1 -: IW/2]}; end // a0b0
			2'b01  : begin eia <= {1'b0,wa[IW  -1 -: IW/2]}; eib <= {1'b0,wb[IW  -1 -: IW/2]}; end // a1b1
			default: begin eia <= wa[IW/2-1 -: IW/2] + wa[IW  -1 -: IW/2]; eib <= wb[IW/2-1 -: IW/2] + wb[IW  -1 -: IW/2]; end // t0: (a0+a1) t1: (b0+b1)
		endcase
	
	assign irdy = ilast & eirdy;
	
	always @(posedge clk or negedge arstn)
		if (~srstn | ~arstn) begin
			icnt <= 0;
			rival <= 0;
		end else begin
			if ((ival & eirdy) | (ival & ~rival))
				icnt <= ilast? 2'b00 : icnt + 1'b1;
			if (rival) begin
				if (eirdy & rilast)
					rival <= ival;
			end else begin
				rival <= ival;
			end
		end

	always @(posedge clk)
		if ((rival & eirdy) | (ival & ~rival)) begin
			ria <= eia;
			rib <= eib;
			rikey <= {ikey, icnt};
		end
		
	/*
	// synopsys translate_off
	reg [IW-1:0] tsts_a [0:5];
	reg [IW-1:0] tsts_b [0:5];
	reg [2*IW-1:0] tsts_c;
	int tsts_rp = 0;
	always @(posedge clk) begin
		if (rival & eirdy) begin
			tsts_a[0] <= ria;
			tsts_b[0] <= rib;
			for (int i=0; i<5; i++) begin
				tsts_a[i+1] <= tsts_a[i];
				tsts_b[i+1] <= tsts_b[i];
			end
			tsts_rp <= tsts_rp + 1'b1;
		end
		if (eoval & eordy) begin
			tsts_c = tsts_a[tsts_rp-1] * tsts_b[tsts_rp-1];
			if (c !== tsts_c) begin
				$display("a = 0x%0X, b = 0x%0X", tsts_a[tsts_rp-1], tsts_b[tsts_rp-1]);
				$display("%tns: ERROR: Mismatch: c = 0x%0X, tsts_c = 0x%0X", $time() /10, c, tsts_c);
			end
			tsts_rp <= tsts_rp - 1'b1;
		end
	end
	// synopsys translate_on
	*/
	
		
	reg	[2*W-1:0]	o1, o2;


	always @(posedge clk) begin
		if (eoval & eordy) begin
			o1 <= {{IW{1'b0}},c[IW-1:0]}; //          a0b0
			o2 <= {c[IW-1:0],o1[IW-1:0]} - {(o1[IW:0] + c[IW-1:0]),{IW/2{1'b0}}}; // o = {a1b1,a0b0} - {a0b0+a1b1}<<W/2
			o  <= o2 + {c, {IW/2{1'b0}}}; // o = o + t0t1 << W/2
		end
		if (iload) begin
			o <= {ib,ia};
		end
	end

	
	//output logic
	always @(posedge clk or negedge arstn)
		if (~srstn | ~arstn) begin
			oval <= 0;
			okey <= 0;
		end else begin
			if (eoval & eordy) begin
				oval <= (ocnt==2'b10);
				okey <= eokey[K+2-1 -:K];
			end
			if (oval)
				oval <= ~ordy;
			if (iload) begin
				okey <= ikey;
			end
		end
		
	assign ocnt = eokey[1:0];
	assign eordy = oval? ordy : 1'b1;
	
	generate if (LEVEL == 0) begin
		mul_hs #(IW/2+1,MODE,K+2,IMPL) i_mul (
			.clk	(	clk			),
			.srstn	(	srstn		),
			.arstn	(	arstn		),
			.ia		(	ria			),
			.ib		(	rib			),
			.ikey	(	rikey		),
			.ival	(	rival		),
			.irdy	(	eirdy		),
			.o		(	c			),
			.okey	(	eokey		),
			.oval	(	eoval		),
			.ordy	(	eordy		)
		);
	end else begin
		mul_3s #(IW/2+1,LEVEL-1,K+2,IMPL) i_mul (
			.clk	(	clk			),
			.srstn	(	srstn		),
			.arstn	(	arstn		),
			.ia		(	ria			),
			.ib		(	rib			),
			.ikey	(	rikey		),
			.ival	(	rival		),
			.iload	(	1'b0		),
			.irdy	(	eirdy		),
			.o		(	c			),
			.okey	(	eokey		),
			.oval	(	eoval		),
			.ordy	(	eordy		)
		);
	end endgenerate


endmodule



module mul32_bit_as #(parameter p=32, parameter infer=1) (
	input	[p-1:0]		a,
	input	[p-1:0]		b,
	output  [2*p-1:0]	c
);
	mul_as #(p, 0, 0) i_mul(.a(a),.b(b),.p(c));
endmodule

module mul64_bit_as #(parameter p=64) (
	input	[p-1:0]		a,
	input	[p-1:0]		b,
	output  [2*p-1:0]	c
);
	mul_as #(p, 1, 0) i_mul(.a(a),.b(b),.p(c));
endmodule

module mul128_bit_as #(parameter p=128) (
	input	[p-1:0]		a,
	input	[p-1:0]		b,
	output  [2*p-1:0]	c
);
	mul_as #(p, 2, 1) i_mul(.a(a),.b(b),.p(c));
endmodule




module mul32_bit #(parameter p=32) (
	input 			clk,
	input           ce,
	input	[p-1:0]	a,
	input	[p-1:0]	b,
	output  [2*p-1:0]  c
);

	wire [p/2-1:0] a0 = a[p/2-1: 0];
	wire [p/2-1:0] a1 = a[p-1: p/2];
	wire [p/2-1:0] b0 = b[p/2-1: 0];
	wire [p/2-1:0] b1 = b[p-1: p/2];
	reg [p/2:0] t0;
	reg [p/2:0] t1;
	reg [p/2-1:0] a0r, a1r, b0r, b1r;
	
	reg [p+2-1:0] t;
	reg [p-1:0] a0b0, a1b1, a0b0r, a1b1r;

	wire [p+2-1:0] mt = t - a1b1r;
	wire [p/2-1:0] o1 = a0b0r[p/2-1:0];
	wire [p-1:0] o23 = {a1b1r[p/2-1:0], a0b0r[p-1:p/2]};
	wire [p/2-1:0] o4 = a1b1r[p-1:p/2];
	wire [p+2-1:0] mts = mt + o23;

	reg [2*p-1:0] cr;
	assign c = cr;
	
	always @(posedge clk)
		if (ce) begin
			t0 <= a0 + a1;
			t1 <= b0 + b1;
			b1r <= b1;		
			t <= t0 * t1 - a0b0;
			a0b0 <= a0 * b0;
			a1b1 <= a1 * b1;
			a0b0r <= a0b0;
			a1b1r <= a1b1;
			cr <= {o4+mts[p+2-1:p], mts[p-1:0], o1};
		end

endmodule


module mul64b_par #(parameter p=64) (
	input 					clk		,
	input					ce		,
	input	[p-1:0]			a		,
	input	[p-1:0]			b		,
	output reg [2*p-1:0]	c		
);
	
	reg [p-1:0] ar, br;
	wire [p/2-1:0] a0 = ar[p/2-1:  0];
	wire [p/2-1:0] a1 = ar[p  -1:p/2];
	wire [p/2-1:0] b0 = br[p/2-1:  0];
	wire [p/2-1:0] b1 = br[p  -1:p/2];
	wire [p-1:0] a0b0, a0b1, a1b0, a1b1;
	wire [2*p-1:0] wc;
	wire [p+1  :0] mt;
	
	mul32_bit #(p/2) i_mul32_a0b0 (
		.clk	(	clk		),
		.ce		(	ce		),
		.a		(	a0		),
		.b		(	b0		),
		.c		(	a0b0	)
	);

	mul32_bit #(p/2) i_mul32_a0b1 (
		.clk	(	clk		),
		.ce		(	ce		),
		.a		(	a0		),
		.b		(	b1		),
		.c		(	a0b1	)
	);

	mul32_bit #(p/2) i_mul32_a1b0 (
		.clk	(	clk		),
		.ce		(	ce		),
		.a		(	a1		),
		.b		(	b0		),
		.c		(	a1b0	)
	);

	mul32_bit #(p/2) i_mul32_a1b1 (
		.clk	(	clk		),
		.ce		(	ce		),
		.a		(	a1		),
		.b		(	b1		),
		.c		(	a1b1	)
	);
	
	assign wc[p/2-1:0] = a0b0[p/2-1:0];
	assign mt = a0b1 + a1b0 + {a1b1[p/2-1:0],a0b0[p-1:p/2]};
	assign wc[2*p-1:2*p-p/2] = a1b1[p-1:p/2] + mt[p+1:p];
	assign wc[2*p-p/2-1:p/2] = mt[p-1:0];
	
	always @(posedge clk) //begin
		if (ce) begin
			ar <= a; br <= b;
			c <= wc;
		end

endmodule



module mul128b_par #(parameter p=128) (
	input 					clk		,
	input					ce		,
	input	[p-1:0]			a		,
	input	[p-1:0]			b		,
	output reg [2*p-1:0]	c		
);
	
	wire [p/2-1:0] a0 = a[p/2-1:  0];
	wire [p/2-1:0] a1 = a[p  -1:p/2];
	wire [p/2-1:0] b0 = b[p/2-1:  0];
	wire [p/2-1:0] b1 = b[p  -1:p/2];
	wire [p-1:0] a0b0, a0b1, a1b0, a1b1;
	wire [2*p-1:0] wc;
	wire [p+1  :0] mt;
	
	mul64b_par #(p/2) i_mul64_a0b0 (
		.clk	(	clk		),
		.ce		(	ce		),
		.a		(	a0		),
		.b		(	b0		),
		.c		(	a0b0	)
	);

	mul64b_par #(p/2) i_mul64_a0b1 (
		.clk	(	clk		),
		.ce		(	ce		),
		.a		(	a0		),
		.b		(	b1		),
		.c		(	a0b1	)
	);

	mul64b_par #(p/2) i_mul64_a1b0 (
		.clk	(	clk		),
		.ce		(	ce		),
		.a		(	a1		),
		.b		(	b0		),
		.c		(	a1b0	)
	);

	mul64b_par #(p/2) i_mul64_a1b1 (
		.clk	(	clk		),
		.ce		(	ce		),
		.a		(	a1		),
		.b		(	b1		),
		.c		(	a1b1	)
	);
	
	assign wc[p/2-1:0] = a0b0[p/2-1:0];
	assign mt = a0b1 + a1b0 + {a1b1[p/2-1:0],a0b0[p-1:p/2]};
	assign wc[2*p-1:2*p-p/2] = a1b1[p-1:p/2] + mt[p+1:p];
	assign wc[2*p-p/2-1:p/2] = mt[p-1:0];
	
	always @(posedge clk)
		if (ce) begin
			c <= wc;
		end

endmodule


module mul128b_par_wrp #(parameter p=128) (
	input 					clk		,
	input	[p-1:0]			ia		,
	input	[p-1:0]			ib		,
	input					ival	,
	output					irdy	,	
	output [2*p-1:0]		oc		,
	output  				oval	
);
	
	reg [5-1:0] oproc  = 0;
	reg roval = 1'b0;

	assign irdy = 1'b1;
	assign oval = oproc[4] & roval;
		
	mul128b_par #(p) i_mul128b (
		.clk	(	clk		),
		.ce		(	ival	),
		.a		(	ia		),
		.b		(	ib		),
		.c		(	oc		)
	);
		
	always @(posedge clk) begin
		if (ival) begin
			oproc  <= {oproc[3:0], ival};
		end
		roval <= ival;
	end

endmodule


module mul128_as_wrp #(parameter p=128, parameter latency=3) (
	input 					clk		,
	input					rstn	,
	input	[p-1:0]			ia		,
	input	[p-1:0]			ib		,
	input					ival	,
	output					irdy	,
	output		 [2*p-1:0]	oc		,
	output					oval	
);

	generate if ((latency==0) || (latency==1)) begin
		assign irdy = 1'b1;
		assign oval = 1'b1;
	end else begin
		reg  [$clog2(latency)-1:0] lc = 0;
		assign irdy = (lc == (latency-1));
		assign oval = irdy;
		always @(posedge clk)
			if (~rstn) begin
				lc <= 0;
			end else begin
				lc <= (irdy)? 0 : ival? lc+1'b1 : lc;
			end
	end endgenerate

	mul128_bit_as #(p) i_mul128b (
		.a		(	ia		),
		.b		(	ib		),
		.c		(	oc		)
	);

endmodule




//mul256b:
//p=256, par=2:
//48DSP, 3595 FFs, 5010 LUT, 2949 CC, 139,8 MHz

module mul256b #(parameter p=256, parameter par=2) (
	input 					clk		,
	input					rstn	,
	input	[p-1:0]			ia		,
	input	[p-1:0]			ib		,
	input					iload	,
	input					ival	,
	output reg				irdy	,
	output reg [2*p-1:0]	oc		,
	output reg				oval	= 0
);

	wire [p/2-1:0] a0, a1, b0, b1;
	reg [p/2-1:0] wa, wb;
	wire [p-1:0] wc;
	wire m128_ival, m128_irdy, m128_oval;
	
	reg [2:0] incntr = 3'b000, incntr_nxt;
	reg [1:0] oncntr = 2'b00;
	

	generate if ((par == 0) || (par == 1)) begin : proc_seq
	/*
		mul128b #(p/2, par) i_mul128b (
			.clk	(	clk			),
			.ia		(	wa			),
			.ib		(	wb			),
			.ival	(	m128_ival	),
			.irdy	(	m128_irdy	),
			.oc		(	wc			),
			.oval	(	m128_oval	)
		);
	*/
	end else if (par == 2) begin : proc_par
		mul128b_par_wrp #(p/2) i_mul128b (
			.clk	(	clk			),
			.ia		(	wa			),
			.ib		(	wb			),
			.ival	(	m128_ival	),
			.irdy	(	m128_irdy	),
			.oc		(	wc			),
			.oval	(	m128_oval	)
		);
	end else if (par == 3) begin : proc_async
		mul128_as_wrp #(p/2) i_mul128b (
			.clk	(	clk			),
			.rstn	(	rstn		),
			.ia		(	wa			),
			.ib		(	wb			),
			.ival	(	m128_ival	),
			.irdy	(	m128_irdy	),
			.oc		(	wc			),
			.oval	(	m128_oval	)
		);
	end endgenerate

	assign m128_ival = (incntr[1:0] == 2'b00)? ival : 1'b1;
	
	assign a0 = ia[p/2-1:  0];
	assign a1 = ia[p-1  :p/2];
	assign b0 = ib[p/2-1:  0];
	assign b1 = ib[p-1  :p/2];

	always @* begin
		irdy <= 0;
		incntr_nxt <= m128_irdy? incntr+1'b1 : incntr;
		case (incntr[1:0])
			2'b00: begin
				//irdy <= m128_irdy & incntr[2];
				wa <= a0;
				wb <= b0;
				incntr_nxt <= (ival & m128_irdy)? 3'b001 : incntr;
			end
			2'b01: begin
				wa <= a0;
				wb <= b1;
			end
			2'b10: begin
				wa <= a1;
				wb <= b0;
			end
			default: begin
				wa <= a1;
				wb <= b1;
				irdy <= m128_irdy;
			end
		endcase
	end

	always @(posedge clk) 
		if (~rstn) begin
			incntr <= 3'b000;
		end else begin
			incntr <= incntr_nxt;
		end

	always @(posedge clk) 
		if (~rstn) begin
			oncntr <= 2'b00;
			oval <= 1'b0;
			oc <= 0;
		end else begin
			oval <= 1'b0;
			if (iload)
				oc <= {ib,ia};
			if (m128_oval) begin
				oncntr <= oncntr + 1'b1;
				case (oncntr) 
					2'b00: begin
						oc[  p-1:0] <= wc;
						oc[2*p-1:p] <= 0;
					end
					2'b11: begin
						oc[2*p-1:p] <= oc[2*p-1:p] + wc;
						oval <= 1'b1;
					end
					default: begin
						oc[p/2+p:p/2] <= oc[p/2+p-1:p/2] + wc;
					end
				endcase
			end
		end

endmodule



module mul_syn_wrp #(parameter W=32) (
	input				clk	,
	input	[W-1:0]		a	,
	input	[W-1:0]		b	,
	output  [2*W-1:0]	c	
);

	reg [W-1:0] ra, rb;
	reg [2*W-1:0] rc;
	wire [2*W-1:0] wc;
	
	
	assign c = rc;
	

	always @(posedge clk) begin
		ra <= a;
		rb <= b;
		rc <= wc;
	end 
	
/*
	mul_so #(W) i_mul (
		.clk(	clk		),
		.ce	(	1'b1	),
		.a	(	ra		),
		.b	(	rb		),
		.p	(	wc		)
	);
*/
	mul_as1 #(W) i_mul (
		.a	(	ra		),
		.b	(	rb		),
		.p	(	wc		)
	);
endmodule




//mul_4s_syn_wrp
// LEVEL 0 - 10 cycle max latency with 4 cycles internal processing (4 cycles input ready)
//impl 2:
// 48 DSP, 3617 FFs (-1027), 4886 LUT, 4224 CC, 113.4 MHz
//impl 1:
// 36 DSP, 3641 FFs (-1027), 4878 LUT, 4144 CC, 109.2 MHz
//impl 0:
// 27 DSP, 3385 FFs (-1027), 4648 LUT, 3932 CC, 92.1 MHz

// LEVEL 1 - 26 cycle max latency (16 cycles input ready)
//impl 2:
// 12 DSP, 2608 FFs (-1027), 2468 LUT, 1472 CC, 116.1 MHz
//impl 0 & 1:
// 9 DSP, 2614 FFs (-1027), 2515 LUT, 1501 CC, 109.3 MHz

// LEVEL 2 - 91 cycle max latency (64 cycles input ready)
//impl 0 & 1 % 2:
// 3 DSP, 2495 FFs (-1027), 2035 LUT, 896 CC, 116.1 MHz

// LEVEL 3 - 347 cycle max latency, (258 cycles input ready)
// 1 DSP, 2499 FFs (-1027), 1976 LUT, 768 CC, 116.1 MHz

module mul_4s_syn_wrp #(parameter W=256, parameter LEVEL=3, parameter K=2, parameter IMPL=0) (
		input					clk			,
		input					rstn		,
		input		[  W-1:0]	ia			,
		input		[  W-1:0]	ib			,
		input		[  K-1:0]	ikey		,
		input					ival		,
		output					irdy		,
		output		[2*W-1:0]	o	 		,
		output		[  K-1:0]	okey 		,
		output					oval 		,
		input					ordy		
);

	reg [W-1:0] ra, rb;
	reg [2*W-1:0] rc;
	wire [2*W-1:0] wc;
	reg [  K-1:0] rkey;
	reg rval;
	
	
	assign o = rc;
	

	always @(posedge clk) begin
		ra <= ia;
		rb <= ib;
		rc <= wc;
		rkey <= ikey;
		rval <= ival;
	end 
	

	mul_4s #(W, LEVEL, K, IMPL) i_mul (
		.clk		(	clk		),
		.srstn		(	1'b1	),
		.arstn		(	rstn	),
		.ia			(	ra		),
		.ib			(	rb		),
		.ikey		(	rkey	),
		.ival		(	rval	),
		.irdy		(	irdy	),
		.o			(	wc		),
		.okey 		(	okey	),
		.oval 		(	oval	),
		.ordy		(	ordy	)
	);


endmodule


//mul_3s_syn_wrp
// LEVEL 0 - 8 cycle max latency with 3 cycles internal processing (3 cycles input ready)
//impl 2:
// 48DSP, 4011 FFs (-1027), 6558 LUT, 5125 CC, 96.0 MHz
//impl 1:
// 36DSP, 4035 FFs (-1027), 6551 LUT, 5045 CC, 96.0 MHz
//impl 0:
// 27DSP, 3779 FFs (-1027), 6321 LUT, 4833 CC, 92.0 MHz // NB this implementation gives sometimes incorrect result

// LEVEL 1 - 15 cycle max latency with 3x3 cycles internal processing (9 cycles input ready)
//impl 1 & 2:
// 12 DSP, 2900 FFs (-1027), 4790 LUT, 2552 CC, 96.0 MHz
//impl 0:
// 9 DSP, 2752 FFs (-1027), 4770 LUT, 2599 CC, 96.0 MHz

// LEVEL 2 - 34 cycle max latency with 3x3x3 cycles internal processing ()
//impl 0 & 1 % 2:
// 3 DSP, 2551 FFs (-1027), 4498 LUT, 2035 CC, 96.0 MHz

// LEVEL 3 - 88 cycle max latency, (44 cycles input ready)
// 1 DSP, 2555 FFs (-1027), 4580 LUT, 1969 CC, 96.0 MHz

module mul_3s_syn_wrp #(parameter W=256, parameter LEVEL=0, parameter K=2, parameter IMPL=0) (
		input					clk			,
		input					rstn		,
		input		[  W-1:0]	ia			,
		input		[  W-1:0]	ib			,
		input		[  K-1:0]	ikey		,
		input					iload		,
		input					ival		,
		output					irdy		,
		output		[2*W-1:0]	o	 		,
		output		[  K-1:0]	okey 		,
		output					oval 		,
		input					ordy		
);

	reg [W-1:0] ra, rb;
	reg [2*W-1:0] rc;
	wire [2*W-1:0] wc;
	reg [  K-1:0] rkey;
	reg rval;
	
	
	assign o = rc;
	

	always @(posedge clk) begin
		ra <= ia;
		rb <= ib;
		rc <= wc;
		rkey <= ikey;
		rval <= ival;
	end 
	

	mul_3s #(W, LEVEL, K, IMPL) i_mul (
		.clk		(	clk		),
		.srstn		(	1'b1	),
		.arstn		(	rstn	),
		.ia			(	ra		),
		.ib			(	rb		),
		.ikey		(	rkey	),
		.iload		(	iload	),
		.ival		(	rval	),
		.irdy		(	irdy	),
		.o			(	wc		),
		.okey 		(	okey	),
		.oval 		(	oval	),
		.ordy		(	ordy	)
	);


endmodule


