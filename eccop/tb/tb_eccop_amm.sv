//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : Unit TBs for eccop_amm
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

`timescale 1ns/100ps

interface eccop_amm_if;
		logic			interrupt		;
		logic	[31:0]	amm_address		;
		logic	[31:0]	amm_writedata	;
		logic			amm_write	= 0	;
		logic			amm_read	= 0	;
		logic			amm_waitrequest	;
		logic	[31:0]	amm_readdata	;
endinterface

module tb_eccop_amm;

	reg clk = 0;
	always begin #5; clk=~clk; end
	reg reset = 1'b1;
	initial begin repeat (2) @(posedge clk); reset <= 1'b0; end
	int error = 0;
	eccop_amm_if tbif(); 

	eccop_amm dut (
		.clk				(	clk		),
		.reset				(	reset	),
		.interrupt			(	tbif.interrupt			),
		.amm_address		(	tbif.amm_address		),
		.amm_writedata		(	tbif.amm_writedata		),
		.amm_write			(	tbif.amm_write			),
		.amm_read			(	tbif.amm_read			),
		.amm_waitrequest	(	tbif.amm_waitrequest	),
		.amm_readdata		(	tbif.amm_readdata		)
	);
	
	localparam P_UC_WIDTH     = dut.P_UC_WIDTH;
	
	
	
	task bus_write(input [31:0] addr, input [31:0] data);
		tbif.amm_write  = $random;
		while (~tbif.amm_write) begin
			@(posedge clk);
			tbif.amm_write = $random;
		end
		tbif.amm_address   = addr;
		tbif.amm_writedata = data;
		@(posedge clk);
		while (tbif.amm_waitrequest)
			@(posedge clk);
		tbif.amm_write = 0;
		tbif.amm_address   = $random;
		tbif.amm_writedata = $random;
	endtask
	
	task bus_read(input [31:0] addr, output [31:0] data);
		tbif.amm_read  = $random;
		while (~tbif.amm_read) begin
			@(posedge clk);
			tbif.amm_read = $random;
		end
		tbif.amm_address   = addr;
		@(posedge clk);
		while (tbif.amm_waitrequest)
			@(posedge clk);
		tbif.amm_read = 0;
		tbif.amm_address   = $random;
		data = tbif.amm_readdata;
	endtask

	task bus_idle(input integer n=1);
		tbif.amm_write = 0;
		tbif.amm_read  = 0;
		repeat (n)
			@(posedge clk);
	endtask
	
	
	function [255:0] random_256b;
		for (int i=1; i<9; i++)
		random_256b[32*i-1 -: 32] = $random;
	endfunction
	
	function [255:0] to256b(int a, int shift = 0);
		to256b = (256'd0 + a) << shift;
	endfunction 
	
	function [255:0] ones_256b;
		ones_256b = {256{1'b1}};
	endfunction
	
	task write_256b(input [5:0] index, input [255:0] data);
		for (int i=0; i<8; i++)
			bus_write((index*16+i)*4, data[32*(i+1)-1 -: 32]);
	endtask
	
	task read_256b(input [5:0] index, output reg [255:0] data);
		for (int i=0; i<8; i++)
			bus_read((index*16+i)*4, data[32*(i+1)-1 -: 32]);
	endtask
	
	task read_260b(input [5:0] index, output reg [259:0] data);
		reg [31:0] t;
		read_256b(index, data[255:0]);
		bus_read((index*16+9)*4, t);
		data[259:256] = t[3:0];
	endtask
	
	
	task load_code(input int offset, input [P_UC_WIDTH-1:0] data[]);
		for (int i=0; i<data.size(); i++)
			bus_write(16384+offset*4+i*4, data[i]);
	endtask
	
	
	task start_mcu(input int offset);
		bus_write(2*16384, offset);
	endtask
	
	task get_mcu_status(output [31:0] status);
		bus_read(2*16384, status);
	endtask

	
	
	task test_256b(input [255:0] expected, input [255:0] read, string msg = "");
		if (read !== expected) begin
			error++;
			$display("%t ns: ERROR: expected:0x%64X != read:0x%64X in %s", $time/10, expected, read, msg);
		end else begin
			$display("%t ns: PASS: expected:0x%64X == read:0x%64X in %s", $time/10, expected, read, msg);
		end 
	endtask

	task test_260b(input [259:0] expected, input [259:0] read, string msg = "");
		if (read !== expected) begin
			error++;
			$display("%t ns: ERROR: expected:0x%65X != read:0x%65X in %s", $time/10, expected, read, msg);
		end else begin
			$display("%t ns: PASS: expected:0x%65X == read:0x%65X in %s", $time/10, expected, read, msg);
		end 
	endtask

	task test_512b(input [511:0] expected, input [511:0] read, string msg = "");
		if (read !== expected) begin
			error++;
			$display("%t ns: ERROR: expected:0x%128X != read:0x%128X in %s", $time/10, expected, read, msg);
		end else begin
			$display("%t ns: PASS: expected:0x%128X == read:0x%128X in %s", $time/10, expected, read, msg);
		end 
	endtask
	

	
	function display260b(input [259:0] d, string msg = "");
		$display("%t ns: %s:0x%65X", $time/10, msg, d);
	endfunction
	


	
`include "tb_eccop_amm_testcode.svh"
	
	reg [259:0] tw;
	
	task exec_test1();
		reg [255:0] ra, rb, rc, rd;
		reg [259:0] t, t1, e;
		reg [511:0] ep, tp;

		//load_code(0, testcode);

		ra = random_256b>>1;
		rb = random_256b>>1;
		rc = ones_256b;
		rd = random_256b>>1;
		
		write_256b(0, ra); // R0 = ra
		write_256b(1, rb); // R1 = rb
		write_256b(2, rc); // R2 = rc
		write_256b(4, rd); // R4 = rd
		write_256b(3, ra+1); // R3 = ra+1
		
		start_mcu(TEST1);
		@(negedge dut.cmd_readdata[31]); // wait complete

		e = ra + rb;
		read_260b(63, t);
		test_260b(e,t,"W = R0 + R1");
		
		e = e*2 + ra;
		t1 = e;
		read_260b(62, t);
		test_260b(e,t,"W = 2*(R0 + R1) + R0");
		e = e - rd;
		e = e >> 1;
		read_260b(21, t);
		test_260b(e,t,"W = (2*(R0 + R1) + R0 - R4) >> 1");
		e = e - t1;
		read_260b(20, t);
		test_260b(e,t,"W = (2*(R0 + R1) + R0 - R4) >> 1 - 2*(R0 + R1) + R0");
		
		e = 0;
		read_260b(5, t);
		test_260b(e,t,"R5 = 0");
		
		ep = ra * rb;
		read_256b(60, tp[255-:256]);
		read_256b(61, tp[511-:256]);
		test_512b(ep,tp,"{R61,R60} == R0 * R1");
		
		ep = rb * rc;
		read_256b(30, tp[255-:256]);
		read_256b(31, tp[511-:256]);
		test_512b(ep,tp,"{R31,R30} == R1 * R2");
		
		ep = rb * (ra+1);
		read_256b(32, tp[255-:256]);
		read_256b(33, tp[511-:256]);
		test_512b(ep,tp,"{R33,R32} == R1 * R3");

		e = (ra+1) - ra;
		read_260b(10, t);
		test_260b(e,t,"jumptest1 R10 = R3 - R0");
		
		e = e - rb - rb;
		read_260b(11, t);
		test_260b(e,t,"jumptest2 R11 = R3 - R0 - R1 - R1");
		
		
	endtask
	
	
	task exec_test2();
		reg [255:0] p;
		reg [259:0] t, e;

		//load_code(0, testcode);

		p = random_256b>>2;
		
		//fast prime test
		write_256b(0, p-1); // R0 = less than prime
		write_256b(1, p+1);  //R1 = more than prime
		write_256b(2, p*2+3); // R2 = more than 2*prime
		write_256b(6, p); // R6 = prime 
		
		start_mcu(TEST2);
		@(negedge dut.cmd_readdata[31]); // wait complete

		e = p - 1;
		e = (e >= p)? (e >= 2*p)? e - 2*p : e - p : e;
		read_260b(7, t);
		test_260b(e,t," less than prime");
		
		e = p + 1;
		e = (e >= p)? (e >= 2*p)? e - 2*p : e - p : e;
		read_260b(8, t);
		test_260b(e,t," more than prime");

		e = p*2 + 3;
		e = (e >= p)? (e >= 2*p)? e - 2*p : e - p : e;
		read_260b(9, t);
		test_260b(e,t," more than 2*prime");
	endtask
	
	
	task exec_test_bninv();
		reg [255:0] prime;
		reg [255:0] bn_tmp, bn_inv;
		reg [255:0] t, e;
		reg [256:0] cprime;
		reg [511:0] p;
		

		
		//cprime = 'h1_00000000_00000000_00000000_00000000_00000000_00000000_00000001_000003D1;
		//cprime = ~cprime;
		cprime = 'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
		prime  = cprime - 2;
		bn_inv = 'h4C4619154810C1C0DAA4DDD8C73971D159DB91705F2113CE51B9885E4578874D;
		bn_tmp = 1;
		
		//fast prime test
		write_256b(30,  prime); // R0 = less than prime
		write_256b(31, bn_inv);  //R1 = more than prime
		write_256b(32, bn_tmp); // R2 = more than 2*prime
		
		start_mcu(BINV_TEST);
		@(negedge dut.cmd_readdata[31]); // wait complete

		e = prime;
		repeat (256) begin
			if (e[0]) begin
				p = bn_tmp * bn_inv;
				bn_tmp = p % cprime;
			end
			p = bn_inv * bn_inv;
			//$display("bn_inv * bn_inv :0x%128X", p);
			bn_inv = p % cprime;
			e=e>>1;
		end
		
		read_260b(31, t);
		test_260b(bn_inv,t," bn_inv");
		
		read_260b(32, t);
		test_260b(bn_tmp,t," bn_tmp");
	endtask	
	
	
	task exec_prime_only_test();

		reg [255:0] t, e;
		reg [256:0] cprime;
		reg [511:0] p;
		

		
		//cprime = 'h1_00000000_00000000_00000000_00000000_00000000_00000000_00000001_000003D1;
		//cprime = ~cprime;
		cprime = 'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
		e = random_256b;
		t = random_256b;
		p = e * t;
		
		//fast prime test
		write_256b(12, p[255-:256]); 
		write_256b(13, p[511-:256]); 
		
		start_mcu(PRIME_ONLY_TEST);
		@(negedge dut.cmd_readdata[31]); // wait complete

		e = p % cprime;
		read_260b(14, t);
		test_260b(e,t," prime only");
		
	endtask
	
	initial begin
		@(negedge reset);
		bus_idle(1);
		load_code(0, testcode);
		exec_test1();
		exec_test2();
		exec_test_bninv();
		exec_prime_only_test();
		bus_idle(10);
		$stop();
	end
	
endmodule
