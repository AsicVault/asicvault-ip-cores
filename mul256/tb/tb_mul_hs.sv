//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : Unit TBs for wide multipliers with handshaking
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

`timescale 1ns / 100ps

module tb_mul_hs;

	parameter W = 256;
	parameter K = 1;
	parameter IMPL = 0;
	parameter LEVEL = 0;
	
	reg clk = 0;
	reg rstn = 0;
	
	typedef struct {
		reg [W-1:0] a;
		reg [W-1:0] b;
		reg [K-1:0] k;
	} args_t;
	
	args_t que[$];
	
	args_t t, e;
	
	
	reg  [2*W-1:0] pe;
	wire [2*W-1:0] pt;
	wire oval, irdy;
	reg ordy = 0, ival = 0;
	wire [K-1:0] okey;
	

	always
		#5 clk <= !clk;

	initial begin
		rstn <= 0;
		repeat (5) @(posedge clk);
		rstn <= 1;
	end

	function [W-1:0] wide_random();
		wide_random = 0;
		if (W < 32) begin
			wide_random = $random;
		end else begin
			repeat (W/32)
				wide_random = (wide_random << 32) + unsigned'($random);
		end
	endfunction
	
	function [W-1:0] bit_arg();
		bit_arg = 1 << unsigned'($random())%W;
	endfunction	
	
	
	mul_3s #(W, LEVEL, K, IMPL) dut (
	//mul_4s #(W, LEVEL, K, IMPL) dut (
		.clk		(	clk		),
		.srstn		(	rstn	),
		.arstn		(	1'b1	),
		.ia			(	t.a		),
		.ib			(	t.b		),
		.ikey		(	t.k		),
		.iload		(	1'b0	),
		.ival		(	ival	),
		.irdy		(	irdy	),
		.o			(	pt		),
		.okey 		(	okey	),
		.oval 		(	oval	),
		.ordy		(	ordy	)
	);
	 
	
	// test monitor
	always @(posedge clk) begin
		ordy <= ordy? oval? $random(): ordy : $random();
		if (ordy & oval) begin
			if (que.size() > 0) begin
				e = que.pop_front();
				pe = e.a * e.b;
				if (pt !== pe) begin
					$display("%tns: ERROR: a=0x%064H, b=0x%064H", $time()/10, e.a, e.b);
					$display("%tns: ERROR: a*b =0x%0128H", $time()/10, pe);
					$display("%tns: ERROR: read=0x%0128H", $time()/10, pt);
					$stop();
				end
				if (e.k !== okey) begin
					$display("%tns: ERROR: key mismatch. read = %d, expected %d", $time()/10, okey, e.k);
					$stop();
				end
			end else begin
				// error, queue empty
				$display("%tns: ERROR: unexpected output, queue empty", $time()/10);
				$stop();
			end
		end
	end
	
	int cntr = 0;
	
	task rnd_stimulus();
		ival = $random();
		while (~ival) begin
			@(posedge clk);
			ival = $random();
		end
		t.a = (cntr == 0)? wide_random() : 0;
		t.b = (cntr == 0)? wide_random() : 0;
		t.k = $random();
		cntr = (cntr == 6)? 0 : cntr + 1;
		que.push_back(t);
		@(posedge clk);
		while (~irdy)
			@(posedge clk);
		ival = 0;
		t.a = 0;
		t.b = 0;
		t.k = 0;
	endtask
	
	
	initial begin
		repeat (1000) begin
			rnd_stimulus();
		end
		$stop();
	end
	
	
endmodule



