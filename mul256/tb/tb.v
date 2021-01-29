//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert, Hando Eilsen
// Description : Unit TBs for wide multipliers
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

`timescale 1ns / 100ps

module tb;

	parameter p = 34;

	reg clk;
	reg [2:0] te;
	reg [2*p-1:0] tv [2:0];
	reg [p-1:0] a, b;
	wire [2*p-1:0] c;
	reg [2*p-1:0] tvi;
	
	initial begin
		clk = 0;
		te  = 0;
	end

	always
		#5 clk <= !clk;


	mul32_bit #(p) dut  (
		.clk	(	clk	),
		.ce		(	1'b1),
		.a		(	a	),
		.b		(	b	),
		.c		(	c	)
	);

	always @(posedge clk)
		if (te[2]) begin
			if (c != tv[2]) begin
				$display("%tps: ERROR: Mismatch: c = %d, tv = %d", $time() * 100, c, tv[2]);
				$stop();
			end else begin
			end
		end
	
	always @(posedge clk) begin
		tv[2] <= tv[1];
		tv[1] <= tv[0];
		tv[0] <= tvi;
		te <= {te[1:0], 1'b1};
	end
	
	
	initial begin
		repeat (100000) begin
			a = $random();
			b = $random();
			tvi = a * b;
			@(posedge clk);
		end
		$stop();
	end
	
	
endmodule



module tb64b;

	parameter p =64;
	parameter latency = 1; //4+4+1
	reg clk;
	reg [latency:0] te = 0;
	reg [2*p-1:0] tv [$], tvt;
	reg [p-1:0] a, b;
	wire [2*p-1:0] cw;
	reg [2*p-1:0] c;
	reg [2*p-1:0] tvi;
	wire n;
	
	initial begin
		clk = 0;
		te  = 1;
	end

	always
		#5 clk <= !clk;

	/*
	mul64b_par #(p) dut  (
		.clk	(	clk	),
		.ce		(	1'b1),
		.a		(	a	),
		.b		(	b	),
		.c		(	c	)
		//.next	(	n	)
	);
	*/

	mul32_bit_as #(p) dut  (
		.a		(	a	),
		.b		(	b	),
		.c		(	cw	)
	);
	
	always @(posedge clk)
		if (te[latency]) begin
			tvt = tv.pop_front();
			if (c != tvt) begin
				$info("%tps: ERROR: Mismatch: c = %d, tv = %d", $time() * 100, c, tvt);
				$stop();
			end else begin
			end
		end
	
	always @(posedge clk) begin
		te <= {te[latency-1:0], 1'b1};
		c <= cw;
	end
	
	
	initial begin
		a = {$random(),$random()};
		b = {$random(),$random()};
		tvi = a * b;
		tv.push_back(tvi);
		repeat (100000) begin
			@(posedge clk) if (1) begin
				a = {$random(),$random()};
				b = {$random(),$random()};
				tvi = a * b;
				tv.push_back(tvi);
			end 
		end
		$stop();
	end
	
endmodule



module tb64b_wrap;

	parameter p = 16;
	parameter par = 1;

	reg clk;
	reg [2*p-1:0] tv [$], tvt;
	reg [p-1:0] a, b;
	wire [2*p-1:0] c;
	reg [2*p-1:0] tvi;
	reg val = 0;
	wire irdy, ordy;
	
	initial begin
		clk = 0;
	end

	always
		#5 clk <= !clk;

	mul64b_wrp #(p, par) dut (
		.clk	(	clk		),
		.ia		(	a		),
		.ib		(	b		),
		.ival	(	val		),
		.irdy	(	irdy	),	
		.oc		(	c		),
		.oval	(	ordy	)
	);

	always @(posedge clk)
		if (ordy) begin
			tvt = tv.pop_front();
			if (c != tvt) begin
				$display("%tps: ERROR: Mismatch: c = %d, tv = %d", $time() * 100, c, tvt);
				$stop();
			end else begin
			end
		end
	
	task delay;
		input int d;
		begin
			//$display("%tps: delay %d", $time() * 100, d);
			repeat (d)
				@(posedge clk);
		end 
	endtask
	
	initial begin
		fork
			begin
				while (1) begin
					if (par==0) begin
						delay($random()%8);
						if (~val) begin
							a <= {$random(),$random()};
							b <= {$random(),$random()};
						end
					end else begin
						a <= {$random(),$random()};
						b <= {$random(),$random()};
					end
					val <= $random()&1;
					@(posedge clk);
				end
			end
			begin
				int cnt = 100000;
				while (cnt > 0) begin
					@(posedge clk) if (irdy & val) begin
						tvi = a * b;
						tv.push_back(tvi);
						cnt--;
					end
				end
				$stop();
			end
		join
	end
endmodule



module tb128b;

	parameter p = 128;

	reg clk;
	reg [2*p-1:0] tv [$], tvt;
	reg [p-1:0] a, b;
	wire [2*p-1:0] c;
	reg [2*p-1:0] tvi;
	reg val = 0;
	wire irdy, ordy;
	
	initial begin
		clk = 0;
	end

	always
		#5 clk <= !clk;

	mul128b #(p) dut (
		.clk	(	clk		),
		.ia		(	a		),
		.ib		(	b		),
		.ival	(	val		),
		.irdy	(	irdy	),
		.oc		(	c		),
		.oval	(	ordy	)
	);

	always @(posedge clk)
		if (ordy) begin
			tvt = tv.pop_front();
			if (c != tvt) begin
				$display("%tps: ERROR: Mismatch: c = %d, tv = %d", $time() * 100, c, tvt);
				$stop();
			end else begin
			end
		end
	
	task delay;
		input int d;
		begin
			//$display("%tps: delay %d", $time() * 100, d);
			repeat (d)
				@(posedge clk);
		end 
	endtask
	
	initial begin
		fork
			begin
				while (1) begin
					delay($random()%8);
					if (~val) begin
						a <= {$random(),$random(),$random(),$random()};
						b <= {$random(),$random(),$random(),$random()};
					end
					val <= $random()&1;
					@(posedge clk);
				end
			end
			begin
				int cnt = 1000;
				while (cnt > 0) begin
					@(posedge clk) if (irdy & val) begin
						tvi = a * b;
						tv.push_back(tvi);
						cnt--;
					end
				end
				$stop();
			end
		join
	end
endmodule


module tb256b;

	parameter p = 256;
	parameter par = 2;

	reg clk;
	reg [2*p-1:0] tv [$], tvt;
	reg [p-1:0] a, b;
	wire [2*p-1:0] c;
	reg [2*p-1:0] tvi;
	reg val = 0;
	wire irdy, ordy;
	
	initial begin
		clk = 0;
	end

	always
		#10 clk <= !clk;

	mul256b #(p, par) dut (
		.clk	(	clk		),
		.ia		(	a		),
		.ib		(	b		),
		.ival	(	val		),
		.irdy	(	irdy	),	
		.oc		(	c		),
		.oval	(	ordy	)
	);

	always @(posedge clk)
		if (ordy) begin
			tvt = tv.pop_front();
			if (c != tvt) begin
				$display("%tps: ERROR: Mismatch: c = %d, tv = %d", $time() * 100, c, tvt);
				$stop();
			end else begin
			end
		end
	
	task delay;
		input int d;
		begin
			//$display("%tps: delay %d", $time() * 100, d);
			repeat (d)
				@(posedge clk);
		end 
	endtask
	
	initial begin
		fork
			begin
				while (1) begin
					if (par == 0) begin
						delay($random()%8);
						if (~val) begin
							a <= {$random(),$random(),$random(),$random(),$random(),$random(),$random(),$random()};
							b <= {$random(),$random(),$random(),$random(),$random(),$random(),$random(),$random()};
						end
					end else begin
						a <= {$random(),$random(),$random(),$random(),$random(),$random(),$random(),$random()};
						b <= {$random(),$random(),$random(),$random(),$random(),$random(),$random(),$random()};
					end
					val <= 1; //$random()&1;
					@(posedge clk);
				end
			end
			begin
				int cnt = 1000;
				while (cnt > 0) begin
					@(posedge clk) if (irdy & val) begin
						tvi = a * b;
						tv.push_back(tvi);
						cnt--;
					end
				end
				$stop();
			end
		join
	end
endmodule



module tb_mul_wrp;

	parameter p = 256;
	parameter par = 2;
	reg clk = 0;
	always begin #10; clk<=~clk; end
	
	reg [2*p-1:0] tv [$], tvt;
	reg [p-1:0] a, b;
	wire [2*p-1:0] c;
	reg [2*p-1:0] tvi;
	reg val = 0;
	wire irdy, ordy;
	
	initial begin
		clk = 0;
	end

	always
		#5 clk <= !clk;

	mul256b #(p, par) dut (
		.clk	(	clk		),
		.ia		(	a		),
		.ib		(	b		),
		.ival	(	val		),
		.irdy	(	irdy	),
		.oc		(	c		),
		.oval	(	ordy	)
	);

	always @(posedge clk)
		if (ordy) begin
			tvt = tv.pop_front();
			if (c != tvt) begin
				$display("%tps: ERROR: Mismatch: c = %d, tv = %d", $time() * 100, c, tvt);
				$stop();
			end else begin
			end
		end
	
	task delay;
		input int d;
		begin
			//$display("%tps: delay %d", $time() * 100, d);
			repeat (d)
				@(posedge clk);
		end 
	endtask
	
	initial begin
		fork
			begin
				while (1) begin
					if (par == 0) begin
						delay($random()%8);
						if (~val) begin
							a <= {$random(),$random(),$random(),$random(),$random(),$random(),$random(),$random()};
							b <= {$random(),$random(),$random(),$random(),$random(),$random(),$random(),$random()};
						end
					end else begin
						a <= {$random(),$random(),$random(),$random(),$random(),$random(),$random(),$random()};
						b <= {$random(),$random(),$random(),$random(),$random(),$random(),$random(),$random()};
					end
					val <= 1; //$random()&1;
					@(posedge clk);
				end
			end
			begin
				int cnt = 1000;
				while (cnt > 0) begin
					@(posedge clk) if (irdy & val) begin
						tvi = a * b;
						tv.push_back(tvi);
						cnt--;
					end
				end
				$stop();
			end
		join
	end
endmodule


module tb_mul_so;

	parameter W = 128;
	reg clk = 0;
	always begin #10; clk<=~clk; end
	
	typedef struct {
		logic [W-1:0]	a;
		logic [W-1:0]	b;
		logic [2*W-1:0]	c;
	} tv_t;
	
	tv_t tv [$], tvi, tvo;
	reg [W-1:0] a, b;
	wire [2*W-1:0] c;
	reg ce = 0;
	int latency_cntr = 0;
	wire latency_done = (W > 64)? (latency_cntr == 3) : (W>32)? (latency_cntr == 2) : (W>16)? (latency_cntr == 1) : (latency_cntr == 0);
	reg check = 0;
	

	mul_so #(W) dut (
		.clk(	clk		),
		.ce	(	ce		),
		.a	(	a		),
		.b	(	b		),
		.p	(	c		)
	);

	always @(posedge clk)
		ce <= $random;
	
	always @(posedge clk) begin
		check <= 0;
		if (ce) begin
			latency_cntr <= latency_done? latency_cntr: latency_cntr+1;
			check <= latency_done;
		end
	end
	
	always @(posedge clk)
		if (check) begin
			tvo = tv.pop_front();
			if (c !== tvo.c) begin
				$display("a = 0x%032X, b = 0x%032X", tvo.a, tvo.b);
				$display("%tns: ERROR: Mismatch: c = 0x%064X, tv = 0x%064X", $time() /10, c, tvo.c);
				$stop();
			end else begin
				$display("%tns: PASS a = 0x%032X, b = 0x%032X, a*b=0x%64X", $time() /10, tvo.a, tvo.b, c);
			end
		end
	
	
	function [W-1:0] rnd_arg();
		rnd_arg = 0;
		if (W < 32) begin
			rnd_arg = $random;
		end else begin
			repeat (W/32)
				rnd_arg = (rnd_arg << 32) + unsigned'($random);
		end
	endfunction
	
	function [W-1:0] bit_arg();
		bit_arg = 1 << unsigned'($random())%W;
	endfunction

	
	always @(posedge clk) begin
		a <= ($random%4==0)? bit_arg : rnd_arg;
		b <= ($random%4==0)? bit_arg : rnd_arg;
	end
	
	
	always @(posedge clk) begin
		if (ce) begin
			tvi.a = a;
			tvi.b = b;
			tvi.c = a * b;
			tv.push_back(tvi);
		end
	end
	
	
	initial begin
		repeat (1000)
			@(posedge clk);
		$stop();
	end
endmodule



module tb_mul_as;

	parameter W = 128;

	reg [W-1:0] a, b;
	wire [2*W-1:0] c;
	reg [2*W-1:0] tv;
	

	mul_as1 #(W) dut (
		.a	(	a		),
		.b	(	b		),
		.p	(	c		)
	);

	function [W-1:0] rnd_arg();
		rnd_arg = 0;
		if (W < 32) begin
			rnd_arg = $random;
		end else begin
			repeat (W/32)
				rnd_arg = (rnd_arg << 32) + unsigned'($random);
		end
	endfunction
	
	function [W-1:0] bit_arg();
		bit_arg = 1 << unsigned'($random())%W;
	endfunction

	task check;
		a = ($random%4==0)? bit_arg : rnd_arg;
		b = ($random%4==0)? bit_arg : rnd_arg;
		tv = a * b;
		#10;
		if (c !== tv) begin
			$display("a = 0x%032X, b = 0x%032X", a, b);
			$display("%tns: ERROR: Mismatch: c = 0x%064X, tv = 0x%064X", $time() /10, c, tv);
			$stop();
		end else begin
			$display("%tns: PASS a = 0x%032X, b = 0x%032X, a*b=0x%64X", $time() /10, a, b, c);
		end
	endtask
	
	initial begin
		repeat (1000)
			check();
		$stop();
	end
endmodule




module tb_mul_hs;

	parameter W = 128;
	parameter MODE = 1;
	parameter K = 4;
	
	reg clk = 0, rstn = 0;
	always begin #10; clk<=~clk; end
	initial begin repeat(2) @(posedge clk); rstn <= 1'b1; end
	
	typedef struct {
		logic [W-1:0]	a;
		logic [W-1:0]	b;
		logic [2*W-1:0]	c;
		logic [K-1:0]	k;
	} tv_t;
	
	tv_t tv [$], tvi, tvo;
	
	wire [2*W-1:0] c;
	wire [K-1:0] okey;
	reg ival = 0, ordy = 0;
	wire irdy, oval;
	
	reg oval1=0, ordy1=0;
	
	
	mul_hs #(W,MODE,K) dut (
		.clk	(	clk		),
		.rstn	(	rstn	),
		.ia		(	tvi.a	),
		.ib		(	tvi.b	),
		.ikey	(	tvi.k	),
		.ival	(	ival	),
		.irdy	(	irdy	),
		.o		(	c		),
		.okey	(	okey	),
		.oval	(	oval	),
		.ordy	(	ordy	)
	);
	
	function [W-1:0] rnd_arg();
		rnd_arg = 0;
		if (W < 32) begin
			rnd_arg = $random;
		end else begin
			repeat (W/32)
				rnd_arg = (rnd_arg << 32) + unsigned'($random);
		end
	endfunction
	
	function [W-1:0] bit_arg();
		bit_arg = 1 << unsigned'($random())%W;
	endfunction
	
	task drive;
		ival = $random;
		while (~ival) begin
			@(posedge clk);
			ival = $random;
		end
		tvi.a = ($random%4==0)? bit_arg : rnd_arg;
		tvi.b = ($random%4==0)? bit_arg : rnd_arg;
		tvi.c = tvi.a*tvi.b;
		tvi.k = $random;
		tv.push_back(tvi);
		@(posedge clk);
		while (~irdy)
			@(posedge clk);
		ival = 0;
		tvi.a = ($random%4==0)? bit_arg : rnd_arg;
		tvi.b = ($random%4==0)? bit_arg : rnd_arg;
		tvi.c = tvi.a*tvi.b;
		tvi.k = $random;
	endtask
	
	// random output ready signal
	always @(posedge clk)
		ordy <= $random; 
	
	
	// oval check
	always @(posedge clk)
		if (~rstn) begin
			ordy1 <= 0;
			oval1 <= 0;
		end else begin
			oval1 <= oval;
			ordy1 <= ordy;
			if (oval1 & ~ordy1 & ~oval) begin
				$display("%tns: ERROR: oval cleared while ordy==0", $time() /10);
				$stop();
			end
			if ((MODE == 0) && (W > 34)) begin
				if (oval1 & ordy1 & oval) begin
					$display("%tns: ERROR: oval active 2 cycles in row", $time() /10);
					$stop();
				end
			end
			
		end
		
	
	
	
	
	// output monitoring task
	always @(posedge clk) begin
		if (ordy & oval) begin
			tvo = tv.pop_front();
			if (c !== tvo.c) begin
				$display("a = 0x%032X, b = 0x%032X", tvo.a, tvo.b);
				$display("%tns: ERROR: Mismatch: c = 0x%064X, tv = 0x%064X", $time() /10, c, tvo.c);
				$stop();
			end else begin
				$display("%tns: PASS a = 0x%032X, b = 0x%032X, a*b=0x%64X", $time() /10, tvo.a, tvo.b, c);
			end
			if (okey !== tvo.k) begin
				$display("%tns: ERROR: Mismatch: okey = 0x%X, tvo.k = 0x%X", $time() /10, okey, tvo.k);
				$stop();
			end else begin
				$display("%tns: PASS okey = 0x%X, tvo.k=0x%X", $time() /10, okey, tvo.k);
			end
		end
	end
	
		
	
	initial begin
		while (~rstn) @(posedge clk);
		repeat (1000)
			drive();
		$stop();
	end
endmodule



module tb_mul_4s;

	parameter W = 256;
	parameter LEVEL = 2;
	parameter K = 2;
	parameter IMPL = 0;
	
	reg clk = 0, rstn = 0;
	always begin #10; clk<=~clk; end
	initial begin repeat(2) @(posedge clk); rstn <= 1'b1; end
	
	typedef struct {
		logic [W-1:0]	a;
		logic [W-1:0]	b;
		logic [2*W-1:0]	c;
		logic [K-1:0]	k;
	} tv_t;
	
	tv_t tv [$], tvi, tvo;
	
	wire [2*W-1:0] c;
	wire [K-1:0] okey;
	reg ival = 0, ordy = 0;
	wire irdy, oval;
	
	reg oval1=0, ordy1=0;
	
	
	//mul_3s #(W,LEVEL,K,IMPL) dut (
	mul_4s #(W,LEVEL,K,IMPL) dut (
		.clk	(	clk		),
		.rstn	(	rstn	),
		.ia		(	tvi.a	),
		.ib		(	tvi.b	),
		.ikey	(	tvi.k	),
		.ival	(	ival	),
		.irdy	(	irdy	),
		.o		(	c		),
		.okey	(	okey	),
		.oval	(	oval	),
		.ordy	(	ordy	)
	);
	
	function [W-1:0] rnd_arg();
		rnd_arg = 0;
		if (W < 32) begin
			rnd_arg = $random;
		end else begin
			repeat (W/32)
				rnd_arg = (rnd_arg << 32) + unsigned'($random);
		end
	endfunction
	
	function [W-1:0] bit_arg();
		bit_arg = 1 << unsigned'($random())%W;
	endfunction
	
	task drive;
		ival = $random;
		while (~ival) begin
			@(posedge clk);
			ival = $random;
		end
		tvi.a = ($random%4==0)? bit_arg : rnd_arg;
		tvi.b = ($random%4==0)? bit_arg : rnd_arg;
		tvi.c = tvi.a*tvi.b;
		tvi.k = $random;
		tv.push_back(tvi);
		@(posedge clk);
		while (~irdy)
			@(posedge clk);
		ival = 0;
		tvi.a = ($random%4==0)? bit_arg : rnd_arg;
		tvi.b = ($random%4==0)? bit_arg : rnd_arg;
		tvi.c = tvi.a*tvi.b;
		tvi.k = $random;
	endtask
	
	// random output ready signal
	always @(posedge clk)
		ordy <= 1'b1; //$random; 
	
	
	// oval check
	always @(posedge clk)
		if (~rstn) begin
			ordy1 <= 0;
			oval1 <= 0;
		end else begin
			oval1 <= oval;
			ordy1 <= ordy;
			if (oval1 & ~ordy1 & ~oval) begin
				$display("%tns: ERROR: oval cleared while ordy==0", $time() /10);
				$stop();
			end
		end
		
	
	
	reg [W/2-1:0] a0, b0, a1, b1;
	reg [W-1:0] a0b0, a1b1;
	reg [W/2: 0] t0, t1;
	reg [W+1: 0] t0t1;
	reg [2*W-1:0] m, m1;
	reg [2*W-1:0] cd1;
	reg [2*W-1:0] od[0:3];
	reg [W+1: 0] dutc[0:3];
	always @(posedge clk) begin
		if (!oval) begin
			od[0] <= c;
		end
		if (dut.eoval & dut.eordy) begin
			dutc[0] <= dut.c;
			for (int i=0; i<3; i++) begin
				od[i+1] <= od[i];
				dutc[i+1] <= dutc[i];
			end
		end
	end
	
	// output monitoring task
	always @(posedge clk) begin
		if (ordy & oval) begin
			tvo = tv.pop_front();
			if (c !== tvo.c) begin
				a0 = tvo.a[W/2-1 -: W/2];
				b0 = tvo.b[W/2-1 -: W/2];
				a1 = tvo.a[W  -1 -: W/2];
				b1 = tvo.b[W  -1 -: W/2];
				a0b0 = a0*b0;
				a1b1 = a1*b1;
				t0 = a0+a1;
				t1 = b0+b1;
				t0t1 = t0*t1;
				cd1 = {a1b1,a0b0} - {(a0b0+a1b1), {W/2{1'b0}}};
				m = {a1b1,a0b0} - {(a0b0+a1b1), {W/2{1'b0}}} + {t0t1,{W/2{1'b0}}};
				m1 = {a1b1,a0b0} + {(t0t1 - a0b0 - a1b1), {W/2{1'b0}}};
				$display("a0*b0= 0x%064X %s c[W-1:0]", a0b0, (a0b0==od[1][W-1:0])? "==" : "!=" );
				$display("a1*b1= 0x%064X %s dut.c[-2]", a1b1, (a1b1==dutc[1])? "==" : "!="  );
				$display("a1b1,a0b0 - (a0b0+a1b1)<<W2 = 0x%0128X %s c[-1]", cd1, (cd1==od[0])? "==" : "!=");
				$display("a0+b0= 0x%033X", t0);
				$display("a1+b1= 0x%033X", t1);
				$display("(a0+a1)*(b0+b1)= 0x%065X %s dut.c[-1]", t0t1, (t0t1==dutc[0])? "==" : "!=");
				$display("m = 0x%0128X %s c", m, (m==c)? "==" : "!=");
				$display("m1 = 0x%0128X %s c", m, (m1==c)? "==" : "!=");
				$display("a = 0x%064X, b = 0x%064X", tvo.a, tvo.b);
				$display("%tns: ERROR: Mismatch: c = 0x%0128X, tv = 0x%0128X", $time() /10, c, tvo.c);
				$display("c^tv = 0x%0128X", c^tvo.c);
				$stop();
			end else begin
				$display("%tns: PASS a = 0x%064X, b = 0x%064X, a*b=0x%0128X", $time() /10, tvo.a, tvo.b, c);
			end
			if (okey !== tvo.k) begin
				$display("%tns: ERROR: Mismatch: okey = 0x%X, tvo.k = 0x%X", $time() /10, okey, tvo.k);
				$stop();
			end else begin
				$display("%tns: PASS okey = 0x%X, tvo.k=0x%X", $time() /10, okey, tvo.k);
			end
		end
	end
	
		
	
	initial begin
		while (~rstn) @(posedge clk);
		repeat (1000)
			drive();
		$stop();
	end
endmodule

