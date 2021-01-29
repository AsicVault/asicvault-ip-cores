//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : ECCOP module with AvalonMM interface
//             : separate bus and engine clocks
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

module eccop_amm_async #(
	parameter P_ASYNC_BUS = 1, //Enable separate bus and processing clock.
	parameter P_POLARFIRE = 0
) (
	input				clk				, // engine clock
	input				sreset			, // synchronous reset
	input				areset			, // asynchronous reset
	input				bus_clk			, // bus clock
	input				bus_sreset		, // bus reset - engine sreset is generated from this internally
	input				bus_areset		, // bus reset - asynchronous
	output				bus_interrupt	,
	input		[31:0]	bus_address		,
	input		[31:0]	bus_writedata	,
	input				bus_write		,
	input				bus_read		,
	output				bus_waitrequest	,
	output		[31:0]	bus_readdata	
) /* synthesis syn_hier = "hard" */;

	localparam P_UC_SIZE_LOG2 = 10; 
	localparam P_UC_WIDTH     = 14;

	//ALU opcode decoding
	//[5:0] operand register address
	//[9:6] opcode decoding
	localparam [3:0] c_LDW				=	4'b0000;
	localparam [3:0] c_STW				=	4'b0001;
	localparam [3:0] c_ADDW				=	4'b0010;
	localparam [3:0] c_ADDWx2			=	4'b0011;
	localparam [3:0] c_SUBW				=	4'b0100;
	localparam [3:0] c_SUBWx2			=	4'b0101;
	localparam [3:0] c_HFPRIM			=	4'b0110;
	localparam [3:0] c_SHRW				=	4'b0111;
	localparam [3:0] c_MUL_PUSH			=	4'b1000;
	localparam [3:0] c_MUL_POP			=	4'b1001;
	localparam [3:0] c_MUL_STH			=	4'b1010;
	localparam [3:0] c_MUL_PUSH_CPRIME	=	4'b1011;
	localparam [3:0] c_CPRIME_PUSH		=	4'b1100;
	localparam [3:0] c_CPRIME_POP		=	4'b1101;
	//[10] KEEP_W flag 1: do not change W, 0 : change W
	//[11] KEEP_F flag 1: do not change CARRY ZERO flags, 0: change the flags
	//[12] STORE flag 1: store to memory, 0: do not store
	
	wire [3:0] amm_byteenable = 4'b1111;
	
	wire	[31:0]	dat_address		;
	wire	[ 3:0]	dat_byteenable	;
	wire	[31:0]	dat_writedata	;
	wire			dat_write		;
	wire			dat_read		;
	wire			dat_waitrequest	;
	wire	[31:0]	dat_readdata	;

	wire	[31:0]	cod_address		;
	wire	[ 3:0]	cod_byteenable	;
	wire	[31:0]	cod_writedata	;
	wire			cod_write		;
	wire			cod_read		;
	wire			cod_waitrequest	;
	wire	[31:0]	cod_readdata	;

	wire	[31:0]	cmd_address		;
	wire	[ 3:0]	cmd_byteenable	;
	wire	[31:0]	cmd_writedata	;
	wire			cmd_write		;
	wire			cmd_read		;
	wire			cmd_waitrequest	;
	wire	[31:0]	cmd_readdata	;
	
	wire	[31:0]	amm_address		;
	wire	[31:0]	amm_writedata	;
	wire			amm_write		;
	wire			amm_read		;
	wire			amm_waitrequest	;
	wire	[31:0]	amm_readdata	;
	
	
	
	reg [259:0] W;
	wire [259:0] B, W_new;
	reg CARRY, ZERO, alu_op_ack;
	wire CARRY_new, ZERO_new;
	wire [P_UC_WIDTH-2:0] alu_op_code, alu_op_code_nxt;
	wire alu_op_req, alu_op_req_nxt;
	reg [259:0] op_wdata;
	
	wire mul_ival, mul_irdy, mul_ordy, mul_oval, mul_okey;
	wire prim_ival, prim_irdy, prim_ordy, prim_oval;
	wire [511:0] wm;
	wire [257:0] wp;
	
	wire [5:0] alu_op_reg_addr = alu_op_code[5:0];
	wire [3:0] alu_op_instr = alu_op_code[9:6];
	wire alu_op_keep_w = alu_op_code[10];
	wire alu_op_keep_f = alu_op_code[11];
	wire alu_op_store = alu_op_code[12];
	
	wire alu_op_stw = alu_op_req & alu_op_ack & alu_op_store;
	
	generate if (P_ASYNC_BUS) begin
		amm_if #(16,4) ibus(), obus();
		
		assign	ibus.address	=	bus_address		;
		assign	ibus.byteenable	=	4'b1111			;
		assign	ibus.writedata	=	bus_writedata	;
		assign	ibus.write		=	bus_write		;
		assign	ibus.read		=	bus_read		;
		assign	bus_waitrequest	=	ibus.waitrequest;
		assign	bus_readdata	=	ibus.readdata	;
		
		//sreset synchronization for the internal logic
		/*
		reg sreset, reset_meta;
		always @(posedge clk) begin
			reset_meta <= bus_sreset;
			sreset <= reset_meta;
		end
		*/
		
		amm_dsync i_eccop_amm_dsync (
			.i_clk		(	bus_clk		),
			.i_reset	(	bus_sreset | bus_areset	),
			.i			(	ibus		),
			.o_clk		(	clk			),
			.o_reset	(	sreset | areset	),
			.o			(	obus		)
		);
		
		assign	amm_address			=	obus.address	;
		assign	amm_writedata		=	obus.writedata	;
		assign	amm_write			=	obus.write		;
		assign	amm_read			=	obus.read		;
		assign	obus.waitrequest	=	amm_waitrequest	;
		assign	obus.readdata		=	amm_readdata	;
		
	end else begin
	
		//wire	sreset = bus_sreset;
		assign	amm_address			=	bus_address		;
		assign	amm_writedata		=	bus_writedata	;
		assign	amm_write			=	bus_write		;
		assign	amm_read			=	bus_read		;
		assign	bus_waitrequest		=	amm_waitrequest	;
		assign	bus_readdata		=	amm_readdata	;
		
	end endgenerate
	
	eccop_ic #(16, 4) inst_eccop_ic (
		`include "eccop_ic_connections.svh"
		//Clock and sreset
		.sreset	(	sreset	),
		.areset	(	areset	),
		.clk	(	clk		)
	);

	wire dat_wready;
	reg dat_rack = 0;
	assign dat_waitrequest = dat_read? ~dat_rack : ~dat_wready;
	always @(posedge clk or posedge areset) begin
		if (areset | sreset) begin
			dat_rack <= 0;
		end else begin
			dat_rack <= dat_rack? 0 : dat_read;
		end
	end
	
	reg op_read;
	
	always @* begin
		op_read = alu_op_req? alu_op_ack : 1'b1;
		case (alu_op_code_nxt[9:6])
			c_SHRW            : op_read = 1'b0;
			c_MUL_POP         : op_read = 1'b0;
			c_MUL_STH         : op_read = 1'b0;
			c_CPRIME_POP      : op_read = 1'b0;
		endcase
	end
	
	wire op_prefetch = alu_op_req_nxt & ~alu_op_code_nxt[12] & op_read;
	
	eccop_opram i_eccop_opram (
		.clk			(	clk		),
		.srstn			(	~sreset	),
		.arstn			(	~areset	),
		.bus_addr		(	dat_address[10-1+2:2]		),
		.bus_wdata		(	dat_writedata				),
		.bus_write		(	dat_write					),
		.bus_read		(	dat_read & ~dat_rack		),
		.bus_rdata		(	dat_readdata				),
		.bus_wready		(	dat_wready					),
		.op_read		(	op_prefetch					),
		.op_raddr		(	alu_op_code_nxt[5:0]		),
		.op_rdata		(	B							),
		.op_waddr		(	alu_op_reg_addr				),
		.op_write		(	alu_op_stw					), // op write has priority
		.op_wdata		(	op_wdata					) // FIXME: right from MUL, PRIME, higher part of mul?
	);
	
	// op_wdata multiplexing
	// it would be more flexible if W_new could be used
	always @* begin
		op_wdata = W;
		case (alu_op_instr)
			c_MUL_STH   : op_wdata = {4'd0,wm[511:256]};
			c_CPRIME_POP: op_wdata = {4'd0,wp};
			c_MUL_POP   : op_wdata = {4'd0,wm[255:0]};
		endcase
	end
	
	reg cod_rack = 0;
	assign cod_waitrequest = cod_read? ~cod_rack : 1'b0;
	always @(posedge clk or posedge areset) begin
		if (areset | sreset) begin
			cod_rack <= 0;
		end else begin
			cod_rack <= cod_rack? 0 : cod_read;
		end
	end

	assign cmd_waitrequest = 1'b0;
	assign cmd_readdata[30:P_UC_SIZE_LOG2] = 0;
	
	eccop_mcu #(
		.P_MEMSIZE_LOG2	(	P_UC_SIZE_LOG2	), // size of program memory
		.P_OPCODE_WIDTH	(	P_UC_WIDTH		)  // width of program opcode, ALU opcode is 1 bit narrower
	) i_eccop_mcu (
		.clk				(	clk					),
		.sreset				(	sreset				),
		.areset				(	areset				),
		.opmem_rwaddr		(	cod_address[P_UC_SIZE_LOG2-1+2:2]	),
		.opmem_wdata		(	cod_writedata		),
		.opmem_we			(	cod_write			),
		//.opmem_raddr		(	cod_address[P_UC_SIZE_LOG2-1+2:2]	),
		.opmem_re			(	cod_read			),
		.opmem_rdata		(	cod_readdata		),
		.op_start_addr		(	cmd_writedata[P_UC_SIZE_LOG2-1:0]	),
		.op_start_en		(	~cmd_address[2] 	), // enable / disable operation machine
		.op_start_wr		(	cmd_write			), // write pulse to set operation machine mode op_start_en
		.op_pc				(	cmd_readdata[P_UC_SIZE_LOG2-1:0]	), // operand program counter
		.op_running			(	cmd_readdata[31]	), // 1 - operation machine is executing, 0 - operation machine is done
		.alu_op_code_ahead	(	alu_op_code_nxt		),
		.alu_op_code_pass 	(	alu_op_req_nxt		),
		.alu_op_code		(	alu_op_code			), // opcode to ALU
		.alu_flags_carry	(	CARRY				), // arithmetic operation carry
		.alu_flags_zero		(	ZERO				), // arithmetic operation result is zero
		.alu_flags_w0		(	W[0]				), // bit 0 of W
		.alu_op_req			(	alu_op_req			), // request to ALU to execute the opcode
		.alu_op_ack			(	alu_op_ack			)  // ack from ALU that the opcode has been executed. NB: Flags are set 1 cycle after ack
	);
	
	/*
	function [6:0] alu_op_dec(input [3:0] op);
		alu_op_dec = 7'b0000100; //W = W : nop
		case (op)
			c_LDW           : alu_op_dec = 7'b1000000; //LDW: W = B
			c_STW           : alu_op_dec = 7'b0000100; //STW: W = W
			c_ADDW          : alu_op_dec = 7'b0000000; //ADDW: W = W + B
			c_ADDWx2        : alu_op_dec = 7'b0000001; //ADDWx2: W = 2W + B
			c_SUBW          : alu_op_dec = 7'b0000010; //SUBW: W = W - B
			c_SUBWx2        : alu_op_dec = 7'b0000011; //SUBWx2: W = 2W - B
			c_HFPRIM        : alu_op_dec = 7'b0010010; //HFPRIM: half of fast prim operation
			c_SHRW          : alu_op_dec = 7'b1000001; //SHRW: W = W >> 1
			c_MUL_PUSH      : alu_op_dec = 7'b0000100; //MUL_PUSH: W = W
			c_MUL_POP       : alu_op_dec = 7'b0000100; //MUL_PUSH: W = W //alu_op_dec = 7'b0100001; //MUL_POP: W = M
			c_MUL_STH       : alu_op_dec = 7'b0000100; //MUL_STH: W = W
			c_MUL_PUSH_CPRIME: alu_op_dec = 7'b0000100; //MUL_POP_CPRIME: W = W
			c_CPRIME_PUSH   : alu_op_dec = 7'b0000100; //CPRIME_PUSH: W = W
			c_CPRIME_POP    : alu_op_dec = 7'b0100000; //CPRIME_POP: W = P
		endcase
	endfunction
	*/

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
	
	function [6:0] alu_op_dec(input [3:0] op);
		alu_op_dec = 7'b0101010; //W = W : nop
		case (op)
			c_LDW           : alu_op_dec = 7'b1001000; //LDW: W = B
			c_STW           : alu_op_dec = 7'b0101010; //STW: W = W
			c_ADDW          : alu_op_dec = 7'b0000000; //ADDW: W = W + B
			c_ADDWx2        : alu_op_dec = 7'b0000001; //ADDWx2: W = 2W + B
			c_SUBW          : alu_op_dec = 7'b0000010; //SUBW: W = W - B
			c_SUBWx2        : alu_op_dec = 7'b0000011; //SUBWx2: W = 2W - B
			c_HFPRIM        : alu_op_dec = 7'b0011000; //HFPRIM: half of fast prim operation
			c_SHRW          : alu_op_dec = 7'b1001001; //SHRW: W = W >> 1
			c_MUL_PUSH      : alu_op_dec = 7'b0101010; //MUL_PUSH: W = W
			c_MUL_POP       : alu_op_dec = 7'b0101010; //MUL_PUSH: W = W //alu_op_dec = 7'b0100001; //MUL_POP: W = M
			c_MUL_STH       : alu_op_dec = 7'b0101010; //MUL_STH: W = W
			c_MUL_PUSH_CPRIME: alu_op_dec = 7'b0101010; //MUL_POP_CPRIME: W = W
			c_CPRIME_PUSH   : alu_op_dec = 7'b0101010; //CPRIME_PUSH: W = W
			c_CPRIME_POP    : alu_op_dec = 7'b0101000; //CPRIME_POP: W = P
		endcase
	endfunction

	
	always @* begin
		alu_op_ack = 1'b1;
		case (alu_op_instr)
			c_MUL_PUSH        : alu_op_ack = mul_irdy;
			c_MUL_POP         : alu_op_ack = mul_oval;
			c_MUL_STH         : alu_op_ack = mul_oval;
			c_MUL_PUSH_CPRIME : alu_op_ack = mul_irdy;
			c_CPRIME_PUSH     : alu_op_ack = prim_irdy;
			c_CPRIME_POP      : alu_op_ack = prim_oval;
		endcase
	end
	
	
	// FIXME : do we need multiply result to W ?
	// FIXME : do we need cprime result to W?
	
	eccop_alu #(260) i_eccop_alu (
		.w		(	W			),
		.b		(	B			),
		.m		(	wm[259:0]	),
		.p		(	{2'd0,wp}	),
		.s		(	alu_op_dec(alu_op_instr)	),
		.q		(	W_new		),
		.zero	(	ZERO_new	),
		.carry	(	CARRY_new	)
	);
	
	always @(posedge clk) begin
		if (alu_op_req & ~alu_op_keep_w)
			W <= W_new;
		if (alu_op_req & ~alu_op_keep_f) begin
			CARRY <= CARRY_new;
			ZERO <= ZERO_new;
		end
	end
	
	
	assign mul_ival = alu_op_req & ((alu_op_instr == c_MUL_PUSH) | (alu_op_instr == c_MUL_PUSH_CPRIME));
	assign mul_ordy = mul_okey? prim_irdy : ((alu_op_instr == c_MUL_POP) & alu_op_req);
	
	assign prim_ordy = alu_op_req & (alu_op_instr == c_CPRIME_POP);
	reg cprime_only = 0;
	assign prim_ival = mul_oval & mul_okey | cprime_only;
	
	always @(posedge clk or posedge areset)
		if (sreset | areset)
			cprime_only <= 1'b0;
		else 
			cprime_only <= cprime_only? ~prim_irdy : alu_op_req & (alu_op_instr == c_CPRIME_PUSH);
	
	generate if (P_POLARFIRE) begin
		//mul_4s #(.W(256), .LEVEL(0), .K(1), .IMPL(2)) i_mul (
		//mul_3s #(.W(256), .LEVEL(0), .K(1), .IMPL(2)) i_mul (
		mul_hs #(.W(256), .MODE(1), .K(1), .IMPL(2)) i_mul (
			.clk	(	clk			),
			.srstn	(	~sreset		),
			.arstn	(	~areset		),
			.ia		(	W			),
			.ib		(	B			),
			.ikey	(	(alu_op_instr == c_MUL_PUSH_CPRIME)	),
			//.iload	(	1'b0		),
			.ival	(	mul_ival	),
			.irdy	(	mul_irdy	),
			.o		(	wm			),
			.okey	(	mul_okey	),
			.oval	(	mul_oval	),
			.ordy	(	mul_ordy	)
		);	
	end else begin
		mul_3s #(.W(256), .LEVEL(0), .K(1), .IMPL(2)) i_mul (
			.clk	(	clk			),
			.srstn	(	~sreset		),
			.arstn	(	~areset		),
			.ia		(	W			),
			.ib		(	B			),
			.ikey	(	(alu_op_instr == c_MUL_PUSH_CPRIME)	),
			.iload	(	1'b0		),
			.ival	(	mul_ival	),
			.irdy	(	mul_irdy	),
			.o		(	wm			),
			.okey	(	mul_okey	),
			.oval	(	mul_oval	),
			.ordy	(	mul_ordy	)
		);	
	end endgenerate
	
	mod_secp256k1_prime_simple_hs #(256, 1) i_mod_prime (
		.clk	(	clk			),
		.sreset	(	sreset		),
		.areset	(	areset		),
		.ival	(	prim_ival	),
		.irdy	(	prim_irdy	),
		.a		(	cprime_only? {B[255:0],W[255:0]} : wm	),      // 512-bit input
		.oval	(	prim_oval	),
		.ordy	(	prim_ordy	),
		.c		(	wp			)
	);


endmodule
