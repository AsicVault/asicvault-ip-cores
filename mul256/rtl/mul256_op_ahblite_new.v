//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : Optimized implementation of mul256_op_ahblite 
//             : different operation codes
//
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//
//-------------------------------------------------------------------------------


module mul256_op_ahblite_new (
	input				hclk			,
	input				resetn			,
	input		[31:0]	ahb_haddr		,
	input		[ 1:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output		[31:0]	ahb_hrdata		,
	output				ahb_hresp		,
	output				ahb_hreadyout	,
	input		[511:0]	rnd				
);

	// The following commet section is incorrect !
	// ALU working principle:
	// W "working" register gets updated during each operation where a "operation" is divided into 3(4) phases
	// 1. operand load phase: 
	//    load A to W with optional *2: W = shift? mem[A]<<1: mem[A];
	//    optionally load operand B (make B available): B = mem[B];
	// 2. Perform operation where result goes back to W
	//    W = OP(W, B); where OP could be:
	//        W
	//        W + B
	//        W - B (does also compare with result -1/0/1 to status register)
	//        W[0]? (W+B) : W
	//        W = (W >= B)? (W >= 2*B)? W - 2*B : W - B : W; // Fast prime
	//        BN_MOD(W * B)
	//        BN_MOD(RND512)
	// 3. Store W to Result register
	//    mem[Result] = W
	
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
	//OPCODE[7] = 1: op valid, 0: op done;
	
	wire [31:0]	amm_address		;
	wire [31:0]	amm_writedata	;
	wire [ 3:0]	amm_byteenable	;
	wire 		amm_write		;
	wire 		amm_read		;
	reg  [31:0]	amm_readdata	;
	wire [31:0]	amm_readdata_op	;
	wire 		amm_op_ready	;
	wire 		amm_waitrequest	;
	
	reg [31:0]  control_reg = 0;
	reg [ 1:0]  status_reg  = 0; // compare result reg

	ahb2amm i_ahb2amm (
		//Avalon MM interface (master)
		.aclk			(	hclk			),
		.aresetn		(	resetn			), //synchronous active low reset
		.amm_address	(	amm_address		),
		.amm_writedata	(	amm_writedata	),
		.amm_byteenable	(	amm_byteenable	),
		.amm_write		(	amm_write		),
		.amm_read		(	amm_read		),
		.amm_readdata	(	amm_readdata	),
		.amm_waitrequest(	amm_waitrequest	),
		//AHB Lite interface (slave)
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

	//Alu operands
	reg  [259:0] W;
	wire [259:0] B;
	wire op_done = ~control_reg[31];
	reg op_finish;
	wire [5:0] rd_addr_a, rd_addr_b, wr_addr;
	wire nOP_LOAD_A, nOP_LOAD_B, nOP_WRITE;
	wire OP_LOAD_A = ~nOP_LOAD_A;
	wire OP_LOAD_B = ~nOP_LOAD_B;
	wire OP_WRITE  = ~nOP_WRITE ;
	assign {nOP_LOAD_A, rd_addr_a} = control_reg[ 6 -: 7];
	assign {nOP_LOAD_B, rd_addr_b} = control_reg[13 -: 7];
	assign {nOP_WRITE , wr_addr  } = control_reg[20 -: 7];
	
	wire [3:0] OP_A, OP_B;
	assign OP_A = control_reg[24 -: 4];
	assign OP_B = control_reg[28 -: 4];
	
	//OP_A|B:
	// x000: W = W : nop
	// x001: W = ARG
	// x010: W = W + ARG
	// x011: W = W - ARG
	// x100: W = W + 2*ARG
	// x101: W = W[0]? (W+ARG)>>1 : W>>1
	// x110: W = (W>MEM)? W-MEM : W
	
	wire OP512 = control_reg[29];
	//OP_B in case of OP512
	// xxx0: W = W
	// xxx1: W = ARG
	// xx1x: perform multiply
	// xx0x: multiply passthrough
	// x1xx: perform prime
	// x0xx: do not perform prime
	
	wire OP512_PRIM = control_reg[27];
	wire OP512_MUL  = control_reg[26];
	
	//256bit multiplier inputs
	wire [255:0] wa = W[255:0];
	wire [255:0] wb = B[255:0];
	wire [511:0] wm;
	wire [255:0] wp;
	wire x_we;
	
	reg rd_ack = 0, wr_ack = 0;
	assign amm_waitrequest = amm_write? ~wr_ack : ~rd_ack;
	
	reg  mul_ival = 0, mul_ival_next, mul_load;
	wire mul_irdy;
	
	reg  [5:0] op_read_addr, op_write_addr;
	reg  op_read, op_write, op_wdata_sel, alu_exec;
	wire op_write_ready, amm_op_ready_late;
	
	reg [5:0] alu_op;
	
	wire AB_ari_zero, AB_ari_neg;
	wire [259:0] W_new;
	reg prim_val;
	wire prim_rdy;
	reg x_we1 = 0;
	reg update_w;
	
	// operands memory
	mul256_op_usram i_mul256_op_usram (
		.clk			(	hclk							),
		.rstn			(	resetn							),
		.bus_addr		(	amm_address[9+2:2]				),
		.bus_wdata		(	amm_writedata					),
		.bus_write		(	amm_write & ~amm_address[12] 	),
		.bus_read		(	amm_read  & ~amm_address[12] & op_done & ~rd_ack),
		.bus_rdata		(	amm_readdata_op					),
		.bus_ready_early(	amm_op_ready					),
		.bus_ready		(	amm_op_ready_late				),
	
		.op_read		(	op_read			),
		.op_raddr		(	op_read_addr	),
		.op_rdata		(	B				),
		.op_waddr		(	op_write_addr	),
		.op_write		(	op_write		),
		.op_wdata		(	op_wdata_sel? {4'd0, wm[511 -: 256]} : W_new),
		.op_wready		(	op_write_ready	)
	);
	
	//bus write process
	always @(posedge hclk) 
		if (~resetn) begin
			control_reg <= 0;
			wr_ack      <= 1'b0;
		end else begin
			wr_ack <= 1'b0;
			if (amm_write) begin
				if (amm_address[12] & op_done & ~amm_address[2]) begin
					wr_ack <= ~wr_ack;
				end
				if (~amm_address[12])
					wr_ack <= amm_op_ready;
			end
			if (amm_address[12] & wr_ack) // each write to command register will start operation
				control_reg <= {1'b1,amm_writedata[30:0]};
			if (op_finish)
				control_reg[31] <= 1'b0;
		end

	//result read process
	always @(posedge hclk) 
		if (~resetn) begin
			amm_readdata <= 0;
			rd_ack <= 1'b0;
		end else begin
			rd_ack <= 1'b0;
			if (amm_address[12] & amm_read) begin
				case (amm_address[2])
					1'b0  : amm_readdata <= control_reg;
					1'b1  : amm_readdata <= {{31{status_reg[1]}},status_reg[0]};
				endcase
				rd_ack <= op_done;
			end else begin
				if (amm_op_ready_late) begin
					amm_readdata <= amm_readdata_op;
					rd_ack <= 1'b1;
				end
			end
		end
	
	
	mul256b #(.p(256), .par(3)) i_mul256b (
		.clk	(	hclk		),
		.rstn	(	resetn		),
		.ia		(	wa			),
		.ib		(	wb			),
		.iload	(	mul_load	), //load wa,wb to wm={wb,wa}
		.ival	(	mul_ival	),
		.irdy	(	mul_irdy	),
		.oc		(	wm			),
		.oval	(	x_we		)
	);

	
	mod_secp256k1_prime_simple_small #(256, 1) i_mod_prime (
		.clk	(	hclk		),
		.val	(	prim_val	),
		.rdy	(	prim_rdy	),
		.a		(	wm			), // 512-bit input
		.c		(	wp			)
	);
	
	
	function [5:0] alu_op_dec(input [3:0] op, input w0, input we_ge);
		alu_op_dec = 6'b000010; //W = W : nop
		casex (op)
			//2'bx000: alu_op_dec <= 6'b000010; //W = W : nop
			4'bx001: alu_op_dec = 6'b000000; //W = ARG
			4'bx010: alu_op_dec = 6'b000110; //W = W + ARG
			4'bx011: alu_op_dec = 6'b000100; //W = W - ARG
			4'bx100: alu_op_dec = 6'b001110; //W = W + 2*ARG
			4'bx101: alu_op_dec = w0? 6'b000111 : 6'b000001; //W = W[0]? (W+ARG)>>1 : W>>1
			4'bx110: alu_op_dec = we_ge? 6'b001000 : 6'b000010; //W = (W>=MEM)? W-MEM : W
		endcase
	endfunction
	
	
	//operations:
	//s[3:0] 
	// 0000: x = b
	// 0001: x = a>>1
	// 0010: x = a
	// 0011: x = a>>1
	// 0100: x = a-b
	// 0101: x = (a-b)>>1
	// 0110: x = a+b
	// 0111: x = (a+b)>>1
	// 1000: x = b
	// 1001: x = a>>1
	// 1010: x = a
	// 1011: x = a>>1
	// 1100: x = a-2*b
	// 1101: x = (a-2*b)>>1
	// 1110: x = (a+2*b)
	// 1111: x = (a+2*b)>>1
	// x = s[4]: wm[256:0]*s[5] | wp : x
	
	mul256_op_alu #(260) i_mul256_op_alu (
		.a	(	W					),
		.b	(	B					),
		.m	(	{4'd0,wm[255:0]}	),
		.p	(	{4'd0,wp}			),
		.s	(	alu_op				),
		.x	(	W_new				)
	);
	
	mul256_op_cmp #(260) i_mul256_op_cmp (
		.a	(	W			),
		.b	(	B			),
		.g	(				), // a  > b
		.l	(	AB_ari_neg	), // ~(g | eq)
		.eq	(	AB_ari_zero	)  // a == b
	);
	
	
	//localparam [8:0] sIdle = 9'd1, sLoad = 9'd2, sE256w1 = 9'd4, sE256 = 9'd8, sI512 = 9'd16, sE512M = 9'd32, sE512P = 9'd64, sStore = 9'd128, sStoreHi = 9'd256;
	
	typedef enum integer {sIdle, sSteadyA, sExecA, sSteadyB, sExecB, sE512M, sE512P, sStore, sStoreHi} states_t;
	states_t cs = sIdle, ns;
	//reg [8:0] cs = sIdle, ns;

	//ALU W Register
	always @(posedge hclk) begin
		if (update_w)
			W <= W_new;
		if (cs == sExecB)
			if (OP_B[2:0]==3'b011)
				status_reg <= {AB_ari_neg, ~AB_ari_zero};
	end

	// control state machine
	always @(posedge hclk)
		if (~resetn) begin
			cs       <= sIdle; 
			mul_ival <= 0;
		end else begin
			cs       <= ns;
			mul_ival <= mul_ival_next;
		end
	
	always @* begin
		ns <= cs;
		prim_val     <= 0;
		mul_load     <= 0;
		op_finish    <= 0;
		op_read      <= 0;
		op_write     <= 0;
		op_read_addr <= rd_addr_a;
		op_write_addr<= wr_addr  ;
		op_wdata_sel <= 0;
		mul_ival_next<= mul_ival;
		alu_op       <= 6'b000010;
		update_w     <= 0;
		case (cs) 
			sIdle: begin
				if (~op_done) begin
					op_read <= OP_LOAD_A | OP_LOAD_B;
					if (OP_LOAD_A) begin
						ns <= sSteadyA; //sExecA;
					end else if (OP_LOAD_B) begin
						ns <= sSteadyB; //sExecB;
					end else if (OP512) begin
						if (OP512_MUL) begin
							ns <= sE512M;
						end else if (OP512_PRIM) begin
							mul_load <= 1'b1;
							ns <= sE512P;
						end else if (OP_WRITE) begin
							mul_load <= 1'b1;
							op_write <= 1'b1;
							ns <= op_write_ready? sStoreHi : sStore;
							op_finish <= op_write_ready;
						end else begin
							mul_load <= 1'b1;
							op_finish<= 1'b1;
						end
					end else begin
						op_finish <= 1'b1; // clear any invalid command
					end
				end
			end
			sSteadyA: begin
				ns     <= sExecA;
				alu_op <= alu_op_dec(OP_A, W[0], ~AB_ari_neg);
			end
			sExecA: begin
				update_w      <= 1'b1;
				op_read       <= OP_LOAD_B;
				alu_op        <= alu_op_dec(OP_A, W[0], ~AB_ari_neg);
				op_read_addr  <= rd_addr_b;
				if (OP512) begin
					alu_op    <= OP_A[0]? 6'b000000 : 6'b000010;
					if (OP_LOAD_B) begin
						ns <= sSteadyB; //sExecB;
					end else begin
						if (OP512_MUL) begin
							ns <= sE512M;
							mul_ival_next <= 1'b1;
						end else if (OP512_PRIM) begin
							ns <= sE512P;
							mul_load <= 1'b1;
						end else begin
							op_write  <= OP_WRITE;
							ns        <= OP_WRITE? op_write_ready? sIdle : sStore : sIdle;
							op_finish <= OP_WRITE? op_write_ready? 1'b1  : 1'b0   : 1'b1 ;
						end 
					end
				end else begin
					op_write  <= OP_WRITE & ~OP_LOAD_B;
					ns        <= OP_LOAD_B? sSteadyB /*sExecB*/ : OP_WRITE? op_write_ready? sIdle : sStore : sIdle;
					op_finish <= OP_LOAD_B? 1'b0   : OP_WRITE? op_write_ready? 1'b1  : 1'b0   : 1'b1 ;
				end
			end
			sSteadyB: begin
				ns     <= sExecB;
				alu_op <= alu_op_dec(OP_B, W[0], ~AB_ari_neg);
			end
			sExecB: begin
				update_w      <= 1'b1;
				alu_op        <= alu_op_dec(OP_B, W[0], ~AB_ari_neg);
				if (OP512) begin
					alu_op    <= OP_B[0]? 6'b000000 : 6'b000010;
					if (OP512_MUL) begin
						ns <= sE512M;
						mul_ival_next <= 1'b1;
					end else if (OP512_PRIM) begin
						ns <= sE512P;
						mul_load <= 1'b1;
					end else begin
						op_write  <= OP_WRITE;
						ns        <= OP_WRITE? op_write_ready? sIdle : sStore : sIdle;
						op_finish <= OP_WRITE? op_write_ready? 1'b1  : 1'b0   : 1'b1 ;
					end 
				end else begin
					op_write  <= OP_WRITE;
					ns        <= OP_WRITE? op_write_ready? sIdle : sStore : sIdle;
					op_finish <= OP_WRITE? op_write_ready? 1'b1  : 1'b0   : 1'b1 ;
				end
			end
			sStore: begin 
				op_write <= 1'b1;
				if (op_write_ready) begin
					op_finish <= 1'b1;
					if (OP512 & ~OP512_PRIM) begin
						ns <= sStoreHi;
					end else begin
						ns <= sIdle;
					end
				end
			end
			sStoreHi: begin
				op_wdata_sel <= 1'b1;
				op_write_addr<= wr_addr + 1'b1;
				op_write     <= 1'b1;
				if (op_write_ready) begin 
					ns <= sIdle;
				end 
			end 
			sE512M: begin 
				if (mul_irdy)
					mul_ival_next <= 0;
				if (x_we) begin
					if (OP512_PRIM) begin
						ns <= sE512P;
					end else begin
						update_w      <= 1'b1;
						alu_op    <= 6'b010010;
						op_write  <= OP_WRITE;
						ns        <= OP_WRITE? op_write_ready? sIdle : sStore : sIdle;
						op_finish <= OP_WRITE? op_write_ready? 1'b1  : 1'b0   : 1'b1 ;
					end
				end
			end
			sE512P: begin
				prim_val <= 1'b1;
				if (prim_rdy) begin
					update_w      <= 1'b1;
					alu_op <= 6'b100010;
					if (OP_WRITE) begin
						op_write  <= 1'b1;
						ns        <= op_write_ready? sIdle : sStore ;
						op_finish <= op_write_ready? 1'b1  : 1'b0   ;
					end else begin
						ns        <= sIdle;
						op_finish <= 1'b1 ;
					end
				end
			end
		endcase
	end
	
	
endmodule





