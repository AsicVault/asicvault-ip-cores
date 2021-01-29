//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OU
//
// Author      : Hando Eilsen
//
// Description : High speed 512-bit pipelined secp256k1 modulo prime accelerator
//               https://en.bitcoin.it/wiki/Secp256k1
//
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//
//
// Pr = 1 00000000 00000000 00000000 00000000 00000000 00000000 00000001 000003D1 
//    = 2^256 + 2^32 +  2^9 + 2^8 + 2^7 + 2^6 + 2^4 + 2^0
//    = 2^256 + 2^32 + 2^10 - 2^6 + 2^4 + 2^0
//
// C = A - (A_high*Pr)>>256 * P {- P} {- P}
// Y = (A_high*Pr)>>256
// C = A - Y*P {- P}
//
//-------------------------------------------------------------------------------

module mod_secp256k1_prime_exact #(parameter p=256) (
	input 			    clk,
	input               ce,
	input	[p*2-1:0]   a,      // 512-bit input
	output  [p-1:0]     c
);

	reg	[p+32:0]    yA;
	reg	[p+32:0]    yB;
	reg	[p*2-1:0]   ar;
	reg	[32:0]      zA;
	reg	[32:0]      zB;

	reg	[p-1:0]     y;
	reg	[p+1:0]     z_plusA;
	reg	[p+1:0]     z_plusB;
	reg	[p-1:0]     ar2;

	reg [p-1:0]     p_plusA;
	reg [p-1:0]     p_plusB;
	reg	[p-1:0]     ar3;

	reg [p-1:0] cr;

    assign c = cr;

    wire [p+32:0] ywA   = {a[p*2-1:p],10'b0} - {a[p*2-1:p],6'b0};				// A_high
    wire [p+32:0] ywB   = {a[p*2-1:p],32'b0} + {a[p*2-1:p],4'b0} + a[p*2-1:p];	// A_high

    wire [p+32:0] zwA   = {a[p-1:0],10'b0} - {a[p-1:0],6'b0};					// A_low
    wire [p+32:0] zwB   = {a[p-1:0],32'b0} + {a[p-1:0],4'b0};

    wire [p+1:0] z_plus = z_plusA + z_plusB;

	always @(posedge clk)
		if (ce) begin
            yA <= ywA;
            yB <= ywB;
            ar <= a;
            zA <= zwA[p+32:p];
            zB <= zwB[p+32:p];

            y <= yA[p+32:p] + yB[p+32:p] + ar[p*2-1:p];
            ar2 <= ar[p-1:0];                           // low part only
            z_plusA <= yA[p-1:0] + yB[p-1:0];           // 256+2 bits
            z_plusB <= zA + zB + ar[p-1:0]; 			// (ar_low<<256 + zwA + zwB )>>256
   
            // P = 2^256 - 2^32 - 2^9 - 2^8 - 2^7 - 2^6 - 2^4 - 2^0
            p_plusA <= {y,10'b0} - {y,6'b0} + (z_plus[p] ? 33'h1000003D1 : 0);
            p_plusB <= {y,32'b0} + {y,4'b0} + y;
            ar3 <= ar2 + (z_plus[p+1] ? 34'h2000007A2 : 0);

            cr <= ar3 + p_plusA + p_plusB; 
		end

endmodule

module mod_secp256k1_prime_simple #(parameter p=256, parameter exact=1) (
	input 			    clk,
	input               ce,
	input	[p*2-1:0]   a,      // 512-bit input
	output  [p+2-1:0]   c
);

	reg	[32:0]      yA;
	reg	[32:0]      yB;
	reg	[p*2-1:0]   ar;

	reg	[p-1:0]     y;
	reg	[p*2-1:0]   ar2;

	reg [p+32:0]    p_plusA;
	reg [p+32:0]    p_plusB;
	reg	[p*2-1:0]   ar3;

	reg [p+2-1:0] cr;
	reg [p+2-1:0] crr;
	
    assign c = exact? {2'b0,crr[p-1:0]} : cr;   // assign smallest cr vs cr2

    wire [p+32:0] ywA   = {a[p*2-1:p],10'b0} - {a[p*2-1:p],6'b0};				// A_high
    wire [p+32:0] ywB   = {a[p*2-1:p],32'b0} + {a[p*2-1:p],4'b0} + a[p*2-1:p];	// A_high

	always @(posedge clk)
		if (ce) begin

            yA <= ywA[p+32:p];
            yB <= ywB[p+32:p];
            ar <= a;

            y <= ar[p*2-1:p] + yA + yB;
            ar2 <= ar;

            // P = 2^256 - 2^32 - 2^9 - 2^8 - 2^7 - 2^6 - 2^4 - 2^0
            p_plusA <= {y,10'b0} - {y,6'b0};
            p_plusB <= {y,32'b0} + {y,4'b0} + y;
            ar3 <= ar2 - {y,256'b0};

            cr <= ar3 + p_plusA + p_plusB;

            crr <= cr + ( cr >= 258'h0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F ?
						( cr >= 258'h1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFF85E ?
								34'h2000007A2 : 33'h1000003D1) : 0 );

            //  Y = A_high * Pr >> 256
            //  Result = A512 - Y * P = A512 - {Y,256'b0} - Y_plus
		end

endmodule

module mod_secp256k1_prime_simple_hs #(parameter p=256, parameter exact=1) (
	input 			    clk,
	input				sreset,
	input				areset,
	input				ival,
	output				irdy,
	input	[p*2-1:0]   a,      // 512-bit input
	output				oval,
	input				ordy,
	output  [p+2-1:0]   c
);

	reg [p*2-1:0] a0;

	reg	[32:0]      yA;
	reg	[32:0]      yB;
	reg	[p*2-1:0]   ar;

	reg	[p-1:0]     y;
	reg	[p*2-1:0]   ar2;

	reg [p+32:0]    p_plusA;
	reg [p+32:0]    p_plusB;
	reg	[p*2-1:0]   ar3;

	reg [p+2-1:0] cr;
	reg [p+2-1:0] crr;
	
    assign c = exact? {2'b0,crr[p-1:0]} : cr;   // assign smallest cr vs cr2

    wire [p+32:0] ywA   = {a0[p*2-1:p],10'b0} - {a0[p*2-1:p],6'b0};					// A_high
    wire [p+32:0] ywB   = {a0[p*2-1:p],32'b0} + {a0[p*2-1:p],4'b0} + a0[p*2-1:p];	// A_high

	reg val1=0, val2=0, val3=0, val4=0, val5=0, val0=0;;
	wire rdy1, rdy2, rdy3, rdy4, rdy5, rdy0;
	
	assign irdy = val0? rdy0 : 1'b1;
	assign rdy0 = val1? rdy1 : 1'b1;
	assign rdy1 = val2? rdy2 : 1'b1;
	assign rdy2 = val3? rdy3 : 1'b1;
	assign rdy3 = val4? rdy4 : 1'b1;
	assign rdy4 = exact? (val5? rdy5 : 1'b1) : ordy;
	
	assign oval = exact? val5 : val4;
	assign rdy5 = ordy;
	
	always @(posedge clk or posedge areset) begin
		if (sreset | areset) begin
			val0 <= 1'b0;
			val1 <= 1'b0;
			val2 <= 1'b0;
			val3 <= 1'b0;
			val4 <= 1'b0;
			val5 <= 1'b0;
		end else begin
			val0 <= val0? (rdy0? ival : val0) : ival;
			val1 <= val1? (rdy1? val0 : val1) : val0;
			val2 <= val2? (rdy2? val1 : val2) : val1;
			val3 <= val3? (rdy3? val2 : val3) : val2;
			val4 <= val4? (rdy4? val3 : val4) : val3;
			val5 <= val5? (rdy5? val4 : val5) : val4;
		end
	end
	
	
	always @(posedge clk) begin
			if (ival & irdy) begin
				a0 <= a;
			end

			if (val0 & rdy0) begin
				yA <= ywA[p+32:p];
				yB <= ywB[p+32:p];
				ar <= a0;
			end

			if (val1 & rdy1) begin
				y <= ar[p*2-1:p] + yA + yB;
				ar2 <= ar;
			end

			// P = 2^256 - 2^32 - 2^9 - 2^8 - 2^7 - 2^6 - 2^4 - 2^0
			if (val2 & rdy2) begin
				p_plusA <= {y,10'b0} - {y,6'b0};
				p_plusB <= {y,32'b0} + {y,4'b0} + y;
				ar3 <= ar2 - {y,256'b0};
			end

			if (val3 & rdy3) begin
				cr <= ar3 + p_plusA + p_plusB;
			end

			if (val4 & rdy4) begin
				crr <= cr + ( cr >= 258'h0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F ?
							( cr >= 258'h1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFF85E ?
									34'h2000007A2 : 33'h1000003D1) : 0 );
			end
	end
	
endmodule

module mod_secp256k1_prime_simple_small #(parameter p=256, parameter exact=1) (
	input					clk		,
	input					rst		,
	input					val		,
	output					rdy		,
	input		[p*2-1:0]	a		,      // 512-bit input
	output		[p+2-1:0]	c		
);

	reg [2:0] phase = 0;
	assign rdy = phase == (exact? 3'd6 : 3'd5);

    wire [p+32:0] ywA   = {a[p*2-1:p],10'b0} - {a[p*2-1:p],6'b0};				// A_high
    wire [p+32:0] ywB   = {a[p*2-1:p],32'b0} + {a[p*2-1:p],4'b0} + a[p*2-1:p];	// A_high

	reg  [p+32:0] yA;
	reg  [p-1:0]  y;
	reg  [p+2-1:0]  cr;
	assign c = exact? {2'b0,cr[p-1:0]} : cr;

	always @(posedge clk) begin
		if (val) begin
			phase <= rdy? phase : phase + 1'b1;
			case (phase)
				3'd0: begin y <= a[p*2-1:p] + ywA[p+32:p]; end
				3'd1: begin y <= y + ywB[p+32:p]; end
				3'd2: begin cr <= a - {y,256'd0} + y; yA <= {y,10'b0} - {y,6'b0}; end
				3'd3: begin cr <= cr + yA; yA <= {y,32'b0} + {y,4'b0}; end
				3'd4: cr <= cr + yA;
				3'd5: if (exact)
					cr <= cr + ( cr >= 258'h0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F ?
							   ( cr >= 258'h1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFF85E ?
									   34'h2000007A2 : 33'h1000003D1) : 0 );
				default: ; 
			endcase
		end else begin
			phase <= 0;
		end
	end
	
endmodule

module mod_secp256k1_prime_simple_small_hs #(parameter p=256, parameter exact=1) (
	input					clk			,
	input					rst			,
	input					ival		,
	output					irdy		,
	output	reg				oval	= 0	,
	input					ordy		,
	input		[p*2-1:0]	a			,	// 512-bit input
	output		[p+2-1:0]	c		
);

	reg [2:0] phase = 0;
	assign rdy = phase == (exact? 3'd6 : 3'd5);

    wire [p+32:0] ywA   = {a[p*2-1:p],10'b0} - {a[p*2-1:p],6'b0};				// A_high
    wire [p+32:0] ywB   = {a[p*2-1:p],32'b0} + {a[p*2-1:p],4'b0} + a[p*2-1:p];	// A_high

	reg  [p+32:0] yA, yB;
	reg  [p-1:0]  y, y1;
	reg  [p+2-1:0]  cr, cr1;
	assign c = exact? {2'b0,cr[p-1:0]} : cr;

	wire ena = oval? (ival & (phase < 2)) : (ival | (phase > 0));
	
	always @(posedge clk) begin
		if (ena) begin
			phase <= oval? 0 : phase + 1'b1;
			case (phase)
				3'd0: begin y <= a[p*2-1:p] + ywA[p+32:p]; y1 <= ywB; end
				3'd1: begin y <= y + y1 + ywB[p+32:p]; end
				3'd2: begin cr1 <= a - {y,256'd0} + y; yA <= {y,10'b0} - {y,6'b0}; yB <= {y,32'b0} + {y,4'b0}; end
				3'd3: begin cr <= cr1 + yA + yB; end
				3'd4: cr <= cr + yA;
				3'd5: if (exact)
					cr <= cr + ( cr >= 258'h0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F ?
							   ( cr >= 258'h1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFF85E ?
									   34'h2000007A2 : 33'h1000003D1) : 0 );
				default: ; 
			endcase
		end
	end
	
	assign irdy = (phase == 2);
	
	always @(posedge clk)
		if (rst) begin
			oval <= 1'b0;
		end else begin
			if (oval)
				oval <= ~ordy;
			else 
				oval <=(phase == 3'd5);
		end
	
endmodule

