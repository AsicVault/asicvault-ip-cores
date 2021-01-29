//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : Unit TBs for eccop_mcu
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

`timescale 1ns / 100ps

interface tb_eccop_mcu_if #(
	parameter	P_MEMSIZE_LOG2	= 9		, // size of program memory
	parameter	P_OPCODE_WIDTH	= 7		  // width of program opcode, ALU opcode is 1 bit narrower
);
	logic	[P_MEMSIZE_LOG2-1:0]	opmem_waddr			;
	logic	[P_OPCODE_WIDTH-1:0]	opmem_wdata			;
	logic							opmem_we		= 0	;
	logic	[P_MEMSIZE_LOG2-1:0]	opmem_raddr			;
	logic							opmem_re		= 0	;
	logic	[P_OPCODE_WIDTH-1:0]	opmem_rdata			;
	logic	[P_MEMSIZE_LOG2-1:0]	op_start_addr		;
	logic							op_start_en			; // enable / disable operation machine
	logic							op_start_wr		= 0	; // write pulse to set operation machine mode op_start_en
	logic	[P_MEMSIZE_LOG2-1:0]	op_pc				; // operand program counter
	logic							op_running			; // 1 - operation machine is executing, 0 - operation machine is done
	logic	[P_OPCODE_WIDTH-2:0]	alu_op_code			; // opcode to ALU
	logic							alu_flags_carry	= 0	; // arithmetic operation carry
	logic							alu_flags_zero	= 0	; // arithmetic operation result is zero
	logic							alu_flags_w0	= 0	; // bit 0 of W
	logic							alu_op_req			; // request to ALU to execute the opcode
	logic							alu_op_ack		    ; // ack from ALU that the opcode has been executed
endinterface


module tb_eccop_mcu;
	localparam	P_MEMSIZE_LOG2	= 9	;
	localparam	P_OPCODE_WIDTH	= 7	;

	localparam T_ZERO         = 0;
	localparam T_CARRY        = 1;
	localparam T_CARRY_ZERO   = 2;
	localparam T_CARRY_NZERO  = 3;
	localparam T_NCARRY_ZERO  = 4;
	localparam T_NCARRY_NZERO = 5;
	localparam T_W0           = 6;
	localparam T_LAST         = 7;
	
	
	
	reg clk = 0;
	always begin #5; clk=~clk; end
	reg reset = 1'b1;
	initial begin repeat (2) @(posedge clk); reset <= 1'b0; end

	int aluop_cnt = 0;
	
	tb_eccop_mcu_if #() tbif();
	
	eccop_mcu #(
		.P_MEMSIZE_LOG2	(	P_MEMSIZE_LOG2		),
		.P_OPCODE_WIDTH	(	P_OPCODE_WIDTH		)
	) dut (
		.clk				(	clk		),
		.reset				(	reset	),
		.opmem_waddr		(	tbif.opmem_waddr		),
		.opmem_wdata		(	tbif.opmem_wdata		),
		.opmem_we			(	tbif.opmem_we			),
		.opmem_raddr		(	tbif.opmem_raddr		),
		.opmem_re			(	tbif.opmem_re			),
		.opmem_rdata		(	tbif.opmem_rdata		),
		.op_start_addr		(	tbif.op_start_addr		),
		.op_start_en		(	tbif.op_start_en		),
		.op_start_wr		(	tbif.op_start_wr		),
		.op_pc				(	tbif.op_pc				),
		.op_running			(	tbif.op_running			),
		.alu_op_code		(	tbif.alu_op_code		),
		.alu_flags_carry	(	tbif.alu_flags_carry	),
		.alu_flags_zero		(	tbif.alu_flags_zero		),
		.alu_flags_w0		(	tbif.alu_flags_w0		),
		.alu_op_req			(	tbif.alu_op_req			),
		.alu_op_ack			(	tbif.alu_op_ack			)
	);

	// ALU emulation
	reg r_alu_op_ack = 0;
	always @(posedge clk) begin
		r_alu_op_ack = $random();
		{tbif.alu_flags_carry, tbif.alu_flags_zero, tbif.alu_flags_w0} = $random(); //flags get random values at every cycle
	end
		
	assign tbif.alu_op_ack = r_alu_op_ack & tbif.alu_op_req;
	
	always @(posedge clk) begin
		if (tbif.alu_op_ack) begin
			$display("%t ns: ALUOP[%d] %d == b%06b, C=%1b, Z=%1b, W0=%1b", $time()/10.0, aluop_cnt, tbif.alu_op_code, tbif.alu_op_code, 
																			tbif.alu_flags_carry, tbif.alu_flags_zero, tbif.alu_flags_w0);
			aluop_cnt++;
		end 
	end
	
	task opmem_write (input [P_MEMSIZE_LOG2-1:0] addr, input [P_OPCODE_WIDTH-1:0] data);
		tbif.opmem_waddr = addr;
		tbif.opmem_wdata = data;
		tbif.opmem_we    = 1'b1;
		@(posedge clk);
		tbif.opmem_we    = 1'b0;
		tbif.opmem_waddr = 0;
		tbif.opmem_wdata = 0;
	endtask
	
	
	task opmem_read (input [P_MEMSIZE_LOG2-1:0] addr, output logic [P_OPCODE_WIDTH-1:0] data);
		tbif.opmem_raddr = addr;
		tbif.opmem_re    = 1'b1;
		@(posedge clk);
		tbif.opmem_re    = 1'b0;
		tbif.opmem_raddr = 0;
		data = tbif.opmem_rdata;
	endtask
	
	task op_start (input [P_MEMSIZE_LOG2-1:0] addr);
		$display("%t ns: Start program @ 0x%04H", $time()/10.0, addr);
		tbif.op_start_addr = addr;
		tbif.op_start_en   = 1'b1;
		tbif.op_start_wr   = 1'b1;
		@(posedge clk);
		tbif.op_start_wr   = 1'b0;
		tbif.op_start_en   = 1'b0;
	endtask

	task op_stop;
		tbif.op_start_en   = 1'b0;
		tbif.op_start_wr   = 1'b1;
		@(posedge clk);
		tbif.op_start_wr   = 1'b0;
		tbif.op_start_en   = 1'b0;
	endtask	
	
	//opcode functions to simplify test writing
	function [P_OPCODE_WIDTH-1:0] ALUOP(int code);
		ALUOP = {1'b0,code[P_OPCODE_WIDTH-2:0]};
	endfunction
	
	function [P_OPCODE_WIDTH-1:0] JUMP(int offset);
		JUMP = {2'b11, offset[P_OPCODE_WIDTH-3:0]}; 
	endfunction
	
	function [P_OPCODE_WIDTH-1:0] STOP();
		STOP = {3'b100, {(P_OPCODE_WIDTH-3){1'b1}}}; 
	endfunction
	
	function [P_OPCODE_WIDTH-1:0] NOP();
		NOP = {3'b100, {(P_OPCODE_WIDTH-3){1'b0}}}; 
	endfunction
	
	function [P_OPCODE_WIDTH-1:0] TSC(int mux); // test skip if clear
		TSC = {4'b1010, mux[P_OPCODE_WIDTH-5:0]}; 
	endfunction
	
	function [P_OPCODE_WIDTH-1:0] TSS(int mux); // test skip if set
		TSS = {4'b1011, mux[P_OPCODE_WIDTH-5:0]}; 
	endfunction

	
	task load_test_prog1(input [P_MEMSIZE_LOG2-1:0] addr);
		reg [P_MEMSIZE_LOG2-1:0] a;
		a = addr;
		$display("%t ns: Loading %s to address 0x%04H", $time()/10.0, "load_test_prog1", a);
		opmem_write(a++, ALUOP(0));
		opmem_write(a++, ALUOP(1));
		opmem_write(a++, ALUOP(2));
		opmem_write(a++, ALUOP(3));
		opmem_write(a++, TSS(T_ZERO));
		opmem_write(a++, ALUOP(4));
		opmem_write(a++, TSS(T_LAST));
		opmem_write(a++, ALUOP(5));
		opmem_write(a++, TSC(T_LAST));
		opmem_write(a++, ALUOP(6));
		opmem_write(a++, TSC(T_W0));
		opmem_write(a++, JUMP(  2));
		opmem_write(a++, JUMP(-12));
		opmem_write(a++, ALUOP(7));
		opmem_write(a++, STOP());
	endtask
	
	
	// main test code
	initial begin
		@(negedge reset);
		@(posedge clk);
		fork
			begin
				load_test_prog1(10);
				op_start(10);
				@(posedge clk);
				while (tbif.op_running)
					@(posedge clk);
				$display("%t ns: Program finished 1", $time()/10.0);
				@(posedge clk);
				op_start(12);
				@(posedge clk);
				while (tbif.op_running)
					@(posedge clk);
				$display("%t ns: Program finished 2", $time()/10.0);
			end
			begin
				#1us;
				$display("%t ns: ERROR: TB timeout", $time()/10.0);
			end
		join_any

		repeat (10)
			@(posedge clk);
		$display("%t ns: TB Finished", $time()/10.0);
		$stop();
	end
	
	
endmodule
