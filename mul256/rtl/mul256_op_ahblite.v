//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : ALU module with operand memory and AHB interface
//             : this module implements a arithmetic-logic-unit for performing 
//             : operations on 260-bit and 512-bit operands for accelerating
//             : elliptic curve cryptography operations. the module 
//             : has internal 64 x 260-bit operand memory which can be used 
//             : as source of operand and destination of the result in 
//             : operations 
//             : this is the original implementation
//
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//
//-------------------------------------------------------------------------------

module mul256_op_ahblite (
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
	wire [31:0]	amm_address		;
	wire [31:0]	amm_writedata	;
	wire [ 3:0]	amm_byteenable	;
	wire 		amm_write		;
	wire 		amm_read		;
	wire [31:0]	amm_readdata	;
	wire 		amm_waitrequest	;

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

	mul256_op_amm i_mul256_op_amm (
		.hclk				(	hclk				),
		.resetn				(	resetn				),
		.amm_address		(	amm_address			),
		.amm_writedata		(	amm_writedata		),
		.amm_byteenable		(	amm_byteenable		),
		.amm_write			(	amm_write			),
		.amm_read			(	amm_read			),
		.amm_readdata		(	amm_readdata		),
		.amm_waitrequest	(	amm_waitrequest		),
		.rnd				(	rnd					)
	);

endmodule


module mul256_op_amm (
	input			hclk			,
	input			resetn			,
	input	[31:0]	amm_address		,
	input	[31:0]	amm_writedata	,
	input	[ 3:0]	amm_byteenable	,
	input			amm_write		,
	input			amm_read		,
	output	reg [31:0]	amm_readdata	,
	output			amm_waitrequest	,

	input	[511:0]	rnd				
);

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
	
	wire [31:0]	amm_readdata_op	;
	wire 		amm_op_ready	;
	
	reg [31:0]  control_reg = 0;
	reg [ 1:0]  status_reg  = 0; // compare result reg

	//Alu operands
	reg  [259:0] W;
	wire [259:0] B;
	wire [7:0] OP = control_reg[31 -: 8];
	wire op_done = ~OP[7];
	reg op_finish;
	wire [5:0] rd_addr_a = control_reg[23-2 -: 6];
	wire OP_LOAD_A = control_reg[23];
	wire [5:0] rd_addr_b = control_reg[15-2 -: 6];
	wire OP_LOAD_B = control_reg[15];
	wire [5:0] wr_addr_r = control_reg[ 7-2 -: 6];
	wire OP_WRITE_R = control_reg[7];
	wire OP512 = OP[4];
	wire OP512_MUL = ~OP[1];
	wire mul_isel = (OP[2:1] == 2'b10);
	
	//256bit multiplier inputs
	wire [255:0] wa = mul_isel? rnd[255 -:256] : W[255:0];
	wire [255:0] wb = mul_isel? rnd[511 -:256] : B[255:0];
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

	reg [2:0] prim_cnt = 0;
	wire prim_done = ~|prim_cnt;
	wire prim_predone = (prim_cnt == 3'd1);
	
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
		.op_wdata		(	op_wdata_sel? wm[511 -: 256] : W),
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

	
	wire [259:0] AB_ari = OP[1]? W + B : W - B;
	wire AB_ari_zero, AB_ari_neg;
	reg [259:0] W_new, W_new_m1, W_new3;
	wire [259:0] W_new_m2;
	reg update_w = 0, update_w_nxt, alu_load_a, prim_start;
	reg x_we1 = 0;
	
	mod_secp256k1_prime_simple #(256) i_mod_secp256k1_prime_simple (
		.clk	(	hclk		),
		.ce		(	prim_start | ~prim_done	),
		.a		(	wm			), // 512-bit input
		.c		(	wp			)
	);	
	
	mul256_op_alu_comb i_alu (
		.OP		(	OP			),
		.W		(	W			),
		.B		(	B			),
		.D		(	W_new_m2	),
		.zero	(	AB_ari_zero	),
		.neg	(	AB_ari_neg	)
	);

	always @* begin
		W_new_m1 <= B << OP[0];
		W_new3 <= OP512? OP[3]? {4'd0,wp} : {4'd0,wm[255:0]} : W_new_m2;
		W_new  <= alu_load_a? W_new_m1 : W_new3;
	end 
	
	//ALU W Register
	always @(posedge hclk)
		if (update_w) begin
			W <= W_new;
			if (OP[4:1] == 4'b0010)
				status_reg <= {AB_ari_neg, ~AB_ari_zero};
		end 
	
	//localparam [8:0] sIdle = 9'd1, sLoad = 9'd2, sE256w1 = 9'd4, sE256 = 9'd8, sI512 = 9'd16, sE512M = 9'd32, sE512P = 9'd64, sStore = 9'd128, sStoreHi = 9'd256;
	
	typedef enum integer {sIdle, sLoad, sE256w1, sE256, sI512, sE512M, sE512P, sStore, sStoreHi} states_t;
	states_t cs = sIdle, ns;
	//reg [8:0] cs = sIdle, ns;
	
	// control state machine
	always @(posedge hclk)
		if (~resetn) begin
			cs         <= sIdle; 
			prim_cnt   <= 0;
			update_w   <= 0;
			mul_ival   <= 0;
			x_we1      <= 0;
		end else begin
			cs <= ns;
			update_w <= update_w_nxt;
			mul_ival <= mul_ival_next;
			x_we1    <= x_we;
			if (~prim_done)
				prim_cnt <= prim_cnt - 1'b1;
			if (prim_start)
				prim_cnt <= 3'd4;
		end
	
	always @* begin
		ns <= cs;
		update_w_nxt <= 0;
		alu_load_a   <= 0;
		prim_start   <= 0;
		alu_exec     <= 1;
		mul_load     <= 0;
		op_finish    <= 0;
		op_read      <= 0;
		op_write     <= 0;
		op_read_addr <= rd_addr_a;
		op_write_addr<= wr_addr_r;
		op_wdata_sel <= 0;
		mul_ival_next<= mul_ival;
		case (cs) 
			sIdle: begin
				if (~op_done) begin
					op_read <= OP_LOAD_A | OP_LOAD_B;
					update_w_nxt <= OP_LOAD_A;
					if (~OP_LOAD_A)
						op_read_addr <= rd_addr_b;
					if (OP512) begin
						ns <= OP_LOAD_A? sLoad : (OP[2:1] == 2'b11)? sE512M : sI512;
						mul_ival_next <= (OP[2:1] == 2'b11) & ~OP_LOAD_A;
					end else begin
						ns <= OP_LOAD_A? sLoad : sE256w1;
					end 
				end
			end
			sLoad: begin
				alu_load_a   <= 1'b1;
				op_read      <= OP_LOAD_B;
				op_read_addr <= rd_addr_b;
				ns <= OP512? ((OP[2:1] == 2'b11)? sE512M : sI512) : ((OP[3:1] == 3'b000)? (OP_WRITE_R? sStore : sIdle) : sE256w1);
				mul_ival_next <= OP512 & (OP[2:1] == 2'b11);
				// FIXME : add op_finish if we go back to sIdle from here
			end
			sE256w1: begin 
				ns <= sE256;
				update_w_nxt <= 1'b1;
			end
			sE256: begin
				ns <= OP_WRITE_R? sStore : sIdle;
				op_finish <= OP_WRITE_R? 1'b0 : 1'b1;
			end
			sStore: begin 
				op_write <= 1'b1;
				if (op_write_ready) begin 
					ns <= OP512? OP[3]? sIdle : sStoreHi : sIdle;
					op_finish <= 1'b1;
				end 
			end
			sStoreHi: begin
				op_wdata_sel <= 1'b1;
				op_write_addr<= wr_addr_r + 1'b1;
				op_write     <= 1'b1;
				if (op_write_ready) begin 
					ns <= sIdle;
				end 
			end 
			sI512: begin
				mul_load <= ~update_w;
				update_w_nxt <= ~update_w;
				if (update_w) begin 
					if (mul_isel) begin
						// random input, no multiply
						ns <= OP[3]? sE512P : OP_WRITE_R? sStore : sIdle;
						prim_start <= OP[3];
					end else begin
						ns <= (OP[2:1] == 2'b11)? sE512M : OP[3]? sE512P : OP_WRITE_R? sStore : sIdle;
						mul_ival_next <= (OP[2:1] == 2'b11);
						prim_start <= (OP[2:1] == 2'b11)? 1'b0 : OP[3];
					end
				end 
			end
			sE512M: begin 
				if (mul_irdy)
					mul_ival_next <= 0;
				update_w_nxt <= x_we & ~OP[3];
				if ((x_we & ~OP[3]) | (x_we & OP[3])) begin
					ns <= OP[3]? sE512P : OP_WRITE_R? sStore : sIdle;
					prim_start <= x_we & OP[3];
				end
			end
			sE512P: begin
				update_w_nxt <= prim_predone;
				if (prim_done) begin
					ns <= OP_WRITE_R? sStore : sIdle;
					op_finish <= OP_WRITE_R? 1'b0 : 1'b1;
				end
			end
		endcase
	end
	
	
endmodule


module mul256_op_alu_comb (
	input		[  7:0]		OP	,
	input		[259:0]		W	,
	input		[259:0]		B	,
	output	reg	[259:0]		D	,
	output 					zero,
	output					neg	
);


	wire [259:0] AB_ari = OP[1]? W + B : W - B;
	assign zero    = (AB_ari == 259'd0);
	assign neg     = AB_ari[259];
	
	always @* begin
		case (OP[3:1])
			3'b001  : D <= AB_ari; // add
			3'b010  : D <= AB_ari; // sub
			3'b011  : D <= (W[0]? AB_ari : W)>>1; //mult half
			3'b100  : D <= (W>B)? (W>(B<<1))? (W-(B<<1)) : AB_ari : W; //Fast prime
			default : D <= W;
		endcase 
	end 

endmodule




