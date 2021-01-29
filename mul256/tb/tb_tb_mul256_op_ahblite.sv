//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : Unit TBs for mul256_op_ahblite
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

`timescale 1ns/100ps

interface mul256_op_ahblite_if;
	logic	[31:0]	ahb_haddr		;
	logic	[ 1:0]	ahb_hsize		;
	logic	[ 1:0]	ahb_htrans	=2'b00	;
	logic	[31:0]	ahb_hwdata		;
	logic			ahb_hwrite		;
	logic			ahb_hready		;
	logic			ahb_hselx		;
	logic	[31:0]	ahb_hrdata		;
	logic			ahb_hresp		;
	logic			ahb_hreadyout	;
	logic 	[511:0]	rnd			= 512'd0	;
endinterface

module tb_mul256_op_ahblite;

	reg clk = 0;
	always begin #5; clk=~clk; end
	reg reset = 1'b1;
	initial begin repeat (2) @(posedge clk); reset <= 1'b0; end
	int error = 0;
	mul256_op_ahblite_if tbif();
	

	mul256_op_ahblite dut (
		.hclk				(	clk						),
		.resetn				(	~reset					),
		.ahb_haddr			(	tbif.ahb_haddr			),
		.ahb_hsize			(	tbif.ahb_hsize			),
		.ahb_htrans			(	tbif.ahb_htrans			),
		.ahb_hwdata			(	tbif.ahb_hwdata			),
		.ahb_hwrite			(	tbif.ahb_hwrite			),
		.ahb_hready			(	tbif.ahb_hready			),
		.ahb_hselx			(	tbif.ahb_hselx			),
		.ahb_hrdata			(	tbif.ahb_hrdata			),
		.ahb_hresp			(	tbif.ahb_hresp			),
		.ahb_hreadyout		(	tbif.ahb_hreadyout		),
		.rnd				(	tbif.rnd				)
	);

	task ahb_write(input [31:0] addr, input [31:0] data);
		tbif.ahb_haddr  = addr;
		tbif.ahb_hwrite = 1'b1;
		tbif.ahb_hsize  = 2'b10;
		tbif.ahb_htrans = 2'b10;
		tbif.ahb_hselx  = 1'b1;
		tbif.ahb_hready = 1'b1;
		@(posedge clk);
		tbif.ahb_haddr  = $random;
		tbif.ahb_hwrite = 1'b0;
		tbif.ahb_hsize  = 2'b00;
		tbif.ahb_htrans = 2'b00;
		tbif.ahb_hselx  = 1'b0;
		tbif.ahb_hwdata = data;
		@(posedge clk);
		while (~tbif.ahb_hreadyout)
			@(posedge clk);
		tbif.ahb_hwdata = $random;
		while ($random&1)
			@(posedge clk);
	endtask
	
	task ahb_read(input [31:0] addr, output [31:0] data);
		tbif.ahb_haddr  = addr;
		tbif.ahb_hwrite = 1'b0;
		tbif.ahb_hsize  = 2'b10;
		tbif.ahb_htrans = 2'b10;
		tbif.ahb_hselx  = 1'b1;
		tbif.ahb_hready = 1'b1;
		@(posedge clk);
		tbif.ahb_haddr  = $random;
		tbif.ahb_hwrite = 1'b0;
		tbif.ahb_hsize  = 2'b00;
		tbif.ahb_htrans = 2'b00;
		tbif.ahb_hselx  = 1'b0;
		@(posedge clk)
		while (~tbif.ahb_hreadyout)
			@(posedge clk);
		data = tbif.ahb_hrdata;
	endtask

	task ahb_idle(input integer n=1);
		tbif.ahb_htrans = 2'b00;
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
			ahb_write((index*16+i)*4, data[32*(i+1)-1 -: 32]);
	endtask
	
	task read_256b(input [5:0] index, output reg [255:0] data);
		for (int i=0; i<8; i++)
			ahb_read((index*16+i)*4, data[32*(i+1)-1 -: 32]);
	endtask
	
	task read_260b(input [5:0] index, output reg [259:0] data);
		reg [31:0] t;
		read_256b(index, data[255:0]);
		ahb_read((index*16+9)*4, t);
		data[259:256] = t[3:0];
	endtask
	
	
	task read_cmp_status(output int result);
		ahb_read(4096+4, result);
	endtask 
	
	
	task exec_op(input [7:0] op, input [6:0] a, input [6:0] b, input [6:0] r);
		reg [31:0] cmd;
		cmd[31 -: 8] = op;
		cmd[23 -: 8] = a[6]? 8'd0 : {1'b1,a};
		cmd[15 -: 8] = b[6]? 8'd0 : {1'b1,b};
		cmd[ 7 -: 8] = r[6]? 8'd0 : {1'b1,r};
		ahb_write(4096, cmd); 
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
	
	//OPCODES
	//OPCODE[0] - load A shift
	//OPCODE[-] bit 7 of index A - load A -> W = A:
	//OPCODE[-] bit 7 of index B - load B
	//OPCODE[4] - 1: 512 bit operation / 0: 260 bit operation
	//OPCODE[3:1] - operation (260 bit):
	// 000 - NOP
	// 001 - ADD
	// 010 - SUB & CMP
	// 011 - (Condition ADD) >> 1
	// 100 - Fast Prime (prime is B)
	//OPCODE[3:1] - operation (512 bit):
	// 000 - NOP
	// 010 - Load RND to mul output
	// 011 - MUL256 (W * B)
	// 1xx - PRIME on MUL output (prime on mul or rnd)
	//OPCODE[-] bit 7 of index Result: store W to Result
	// when 512bit operation was requested (MUL or RND) it depends on followed prime command if data requested to be stored
	// is 512 bit: (no prime operation)
	// is 256 bit: (prime function is done [bit 3 is set])

	
	task test_mov(int a, int b);
		reg [255:0] r, t;
		r = random_256b;
		write_256b(a, r);
		exec_op(8'b10000000, a, -1, b);
		read_256b(b, t);
		test_256b(r, t, "test_mov");
	endtask
	
	
	task test_compare(int a, int b, int c);
		reg [255:0] r1, r2, t;
		int cmp;
		r1 = random_256b-1;
		r2 = r1;
		write_256b(a, r1);
		write_256b(b, r2);
		write_256b(c, r2+1);
		exec_op(8'b10000100, a, b, -1); // compare with B - should be equal
		read_cmp_status(cmp);
		if (cmp != 0) begin 
			$display("%t ns: ERROR: compare result(%d) not ZERO in %s", $time/10, cmp, "test_compare 1");
			error++;
		end else begin
			$display("%t ns: PASS: compare result(%d) is ZERO in %s", $time/10, cmp, "test_compare 1");
		end
		exec_op(8'b10000100, a, c, -1); // compare A to C - should be less
		read_cmp_status(cmp);
		if (cmp != -1) begin 
			$display("%t ns: ERROR: compare result(%d) not LESS in %s", $time/10, cmp, "test_compare 2");
			error++;
		end else begin
			$display("%t ns: PASS: compare result(%d) is LESS in %s", $time/10, cmp, "test_compare 2");
		end
		exec_op(8'b10000100, c, b, -1); // compare C to B - should be more
		read_cmp_status(cmp);
		if (cmp != 1) begin 
			$display("%t ns: ERROR: compare result(%d) not MORE in %s", $time/10, cmp, "test_compare 3");
			error++;
		end else begin
			$display("%t ns: PASS: compare result(%d) is MORE in %s", $time/10, cmp, "test_compare 3");
		end
	endtask
	
	
	task test_add(int a, int b, int c, int d1, int d2);
		reg [255:0] ra, rb, rc;
		reg [259:0] t, e;
		reg [255:0] p;
		ra = random_256b>>1;
		rb = random_256b>>1;
		rc = ones_256b;
		write_256b(a, ra);
		write_256b(b, rb);
		write_256b(c, rc);
		exec_op(8'b10000010, a, b, d1);
		exec_op(8'b10000010, a, c, d2);
		e = ra + rb;
		read_260b(d1, t);
		test_260b(e, t, "test_add 1");
		exec_op(8'b10000010, c, b, d1);
		e = ra + rc;
		read_260b(d2, t);
		test_260b(e, t, "test_add 2");
		e = rc + rb;
		read_260b(d1, t);
		test_260b(e, t, "test_add 3");
		exec_op(8'b10000100, c, b, d1);
		exec_op(8'b10000100, b, a, d2);
		e = rc - rb;
		read_260b(d1, t);
		test_260b(e, t, "test_sub 1");
		e = rb - ra;
		read_260b(d2, t);
		test_260b(e, t, "test_sub 2");
		
		//sequential add with a*2
		exec_op(8'b1000011,  a, b, -1);
		exec_op(8'b1000010, -1, c, d1);
		e = ra*2 + rb + rc;
		read_260b(d1, t);
		test_260b(e, t, "test 2*a+b+c");
		
		exec_op(8'b1000011,  a, a, d2);
		e = ra*3;
		read_260b(d2, t);
		test_260b(e, t, "test 3*a");
		
		exec_op(8'b1000010, a, -1, d1);
		e = ra*2;
		read_260b(d1, t);
		test_260b(e, t, "test 2*a");
		
		// fast prime on W, W is 2*a
		//p = 256'hfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f;
		p = ra*2+1;
		write_256b(c, p);
		exec_op(8'b1001000, a, c, d2);
		e = ra % p;
		read_260b(d2, t);
		test_260b(e, t, "test fast_prime (2*a) ");
	endtask
	
	
	task test_mul256(int a, int b, int c);
		reg [255:0] ra, rb;
		reg [512:0] t, e;
		reg [255:0] p;
		ra = random_256b;
		rb = random_256b;
		write_256b(a, ra);
		write_256b(b, rb);
		exec_op(8'b10010110, a, b, c);
		e = ra * rb;
		read_256b(c, t[255:0]);
		read_256b(c+1, t[511-:256]);
		test_512b(e, t, "test_mul256 1");
		exec_op(8'b1000011,  a, a, c+4);
		p = 256'hfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f;
		exec_op(8'b10011000, c, c+1, c+3); // prime {b,a}
		e = (ra * rb) % p;
		read_256b(c+3, t[255:0]);
		test_256b(e[255:0], t[255:0], "test_mul256 + prime");
	endtask
	
	
	initial begin
		@(negedge reset);
		ahb_idle(1);
		test_mov(1,2);
		test_compare(22,1,63);
		test_add(3,56,7,32,33);
		test_mul256(5,15,3);
		ahb_idle(10);
		$stop();
	end
	
endmodule
