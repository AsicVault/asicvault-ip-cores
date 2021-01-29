//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
//
// Description : Unit TBs for mod_secp256k1_prime_simple and 
//             : mod_secp256k1_prime_simple_small
//
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//
//-------------------------------------------------------------------------------

`timescale 1ns/1ns

module tb_mod_secp256k1_prime_simple_small;

	reg clk = 0;
	always begin #5; clk++; end

	reg [511:0] a = 0;
	reg val = 0;
	wire rdy;
	wire [257:0] c, c2;
	reg error = 0;

	mod_secp256k1_prime_simple_small #(256) dut (
		.clk	(	clk	),
		.val	(	val	),
		.rdy	(	rdy	),
		.a		(	a	),
		.c		(	c	)
	);

	mod_secp256k1_prime_simple #(256) dut_ref (
		.clk	(	clk	),
		.ce		(	((dut.phase >= 0) & (dut.phase < 5)) & val	),
		.a		(	a	),      // 512-bit input
		.c		(	c2	)
	);	
	
	reg [255:0] p = 256'hfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f;
	
	function [255:0] random_256b;
		for (int i=1; i<9; i++)
		random_256b[32*i-1 -: 32] = $random;
	endfunction
	
	
	task test_256b(input [257:0] expected, input [257:0] read, string msg = "");
		if (read !== expected) begin
			error++;
			$display("%t ns: ERROR: expected:0x%65X != read:0x%65X in %s", $time, expected, read, msg);
		end else begin
			$display("%t ns: PASS: expected:0x%65X == read:0x%65X in %s", $time, expected, read, msg);
		end 
	endtask
	
	
	task drive_test(input [511:0] _a);
		reg [257:0] t;
		val = $random;
		while (~val) begin
			@(posedge clk);
			val = $random;
		end
		a = _a;
		@(posedge clk);
		while (~rdy) 
			@(posedge clk);
		t = _a % p;
		$display("%t ns: testing:0x%128X %% prime", $time, _a);
		test_256b(t, c , "drive_test");
		test_256b(t, c2, "drive_test ref");
		val = 0;
		@(posedge clk);
	endtask
	
	
	initial begin
		int n;
		val = 0;
		repeat (2)
			@(posedge clk);
		repeat (10) begin
			drive_test(random_256b() * (random_256b()+n));
			n++;
		end
		repeat (2)
			@(posedge clk);
		$stop();
	end
	
	
	
endmodule
