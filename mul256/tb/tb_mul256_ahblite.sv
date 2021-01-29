//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : Unit TBs for mul256_ahblite
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

`timescale 1ns/1ns

module tb_mul256_ahblite;

	logic clk = 0, resetn = 0;
	always begin #5; clk++; end
	initial begin repeat(4) @(posedge clk); resetn = 1; end

	logic	[31:0]	ahb_haddr		;
	logic	[ 1:0]	ahb_hsize		;
	logic	[ 1:0]	ahb_htrans	= 2'b00	;
	logic	[31:0]	ahb_hwdata		;
	logic			ahb_hwrite		;
	logic			ahb_hready		;
	logic			ahb_hselx		;
	logic	[31:0]	ahb_hrdata		;
	logic			ahb_hresp		;
	logic			ahb_hreadyout	;


	mul256_ahblite dut (
		.hclk			(	clk				),
		.resetn			(	resetn			),
		.ahb_haddr		(	ahb_haddr		),
		.ahb_hsize		(	ahb_hsize		),
		.ahb_htrans		(	ahb_htrans		),
		.ahb_hwdata		(	ahb_hwdata		),
		.ahb_hwrite		(	ahb_hwrite		),
		.ahb_hready		(	ahb_hready		),
		.ahb_hselx		(	ahb_hselx		),
		.ahb_hrdata		(	ahb_hrdata		),
		.ahb_hresp		(	ahb_hresp		),
		.ahb_hreadyout	(	ahb_hreadyout	)
	);


	task ahb_write(input [31:0] addr, input [31:0] data);
		ahb_haddr  = addr;
		ahb_hwrite = 1'b1;
		ahb_hsize  = 2'b10;
		ahb_htrans = 2'b10;
		ahb_hselx  = 1'b1;
		ahb_hready = $random;
		while (~ahb_hready) begin
			@(posedge clk);
			ahb_hready = $random;
		end
		@(posedge clk);
		while (~ahb_hreadyout)
			@(posedge clk);
		ahb_htrans = 2'b00;
		ahb_hwdata = data;
		ahb_haddr  = 0;
		@(posedge clk);
		while (~ahb_hreadyout)
			@(posedge clk);
		ahb_hwrite = 1'b0;
		ahb_hselx  = 1'b0;
	endtask
	
	task ahb_read(input [31:0] addr, output [31:0] data);
		ahb_haddr  = addr;
		ahb_hwrite = 1'b0;
		ahb_hsize  = 2'b10;
		ahb_htrans = 2'b10;
		ahb_hselx  = 1'b1;
		ahb_hready = $random;
		while (~ahb_hready) begin
			@(posedge clk);
			ahb_hready = $random;
		end
		@(posedge clk);
		while (~ahb_hreadyout)
			@(posedge clk);
		ahb_htrans = 2'b00;
		ahb_haddr  = 0;
		@(posedge clk);
		while (~ahb_hreadyout)
			@(posedge clk);
		data = ahb_hrdata;
		ahb_hselx  = 1'b0;
	endtask

	task ahb_idle(input integer n=1);
		ahb_htrans = 2'b00;
		repeat (n)
			@(posedge clk);
	endtask

	
	task write_256b(input [255:0] data, input integer offset=0);
		for (int i=0; i<8; i++)  
			ahb_write((offset+i)*4, data[(i+1)*32-1 -: 32]);
	endtask
	
	task read_512b(input int offset=0, output reg [511:0] data);
		for (int i=0; i<16; i++)  
			ahb_read((offset+i)*4, data[(i+1)*32-1 -: 32]);
	endtask
	
	task read_256b(input int offset=0, output reg [511:0] data);
		for (int i=0; i<8; i++)  
			ahb_read((offset+i)*4, data[(i+1)*32-1 -: 32]);
	endtask
	
	
	task mul_test(input [255:0] _a, input [255:0] _b);
		reg [511:0] _ab, _x;
		_ab = _a * _b;
		write_256b(_a, 0);
		write_256b(_b, 8);
		ahb_write(32'h000000E0, 1);
		//ahb_idle(20);
		read_512b(16, _x);
		if (_ab !== _x)
			$display("%t ns: ERROR: a:0x%032X X b:0x%032X = 0x%064X != expected: 0x%064X", $time, _a, _b, _ab, _x);
		else 
			$display("%t ns: a:0x%032X X b:0x%032X = 0x%064X PASS", $time, _a, _b, _ab);
	endtask

	
	reg [255:0] a, b;
	reg [511:0] ab;
	reg [255:0] p;
	
	initial begin
		@(posedge resetn);
		ahb_idle(4);
		mul_test(256'h8ff2b776aaf6d91942fd096d2f1f7fd9aa2f64be71462131aa7f067d28fef4db, 256'hb7e31a064ed74d314de79011c5f0a46ac155602353dc3d340fbeaeec9767a6a6);
		
		for (int i=0; i<256; i++) begin
			b = $random << ($random % (255-32));
			mul_test(256'd1<<i, b);
		end
		$display("%t ps: Test finished", $time);
		$stop();
	end

endmodule
