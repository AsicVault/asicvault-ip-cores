//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
// Description : eccop_mcu
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//-------------------------------------------------------------------------------

module eccop_mcu #(
	parameter	P_MEMSIZE_LOG2	= 9		, // size of program memory
	parameter	P_OPCODE_WIDTH	= 14		  // width of program opcode, ALU opcode is 1 bit narrower
)(
	input								clk				,
	input								sreset			,
	input								areset			,
	input	[P_MEMSIZE_LOG2-1:0]		opmem_rwaddr	,
	input	[P_OPCODE_WIDTH-1:0]		opmem_wdata		,
	input								opmem_we		,
	//input	[P_MEMSIZE_LOG2-1:0]		opmem_raddr		,
	input								opmem_re		,
	output	[P_OPCODE_WIDTH-1:0]		opmem_rdata		,
	input	[P_MEMSIZE_LOG2-1:0]		op_start_addr	,
	input								op_start_en		, // enable / disable operation machine
	input								op_start_wr		, // write pulse to set operation machine mode op_start_en
	output	reg [P_MEMSIZE_LOG2-1:0]	op_pc	= 0		, // operand program counter
	output	reg							op_running	= 0	, // 1 - operation machine is executing, 0 - operation machine is done
	
	output		[P_OPCODE_WIDTH-2:0]    alu_op_code_ahead, // new opcode 
	output								alu_op_code_pass, // test check pass for the new opcode
	output	reg [P_OPCODE_WIDTH-2:0]	alu_op_code		, // opcode to ALU
	input								alu_flags_carry	, // arithmetic operation carry
	input								alu_flags_zero	, // arithmetic operation result is zero
	input								alu_flags_w0	, // bit 0 of W
	output	reg							alu_op_req	= 0	, // request to ALU to execute the opcode
	input								alu_op_ack		  // ack from ALU that the opcode has been executed. NB: Flags are set 1 cycle after ack
);

	//operation machine has two types of opcodes:
	// 1. control flow opcodes: jump, load loop counter, test-skip-(clear|set), nop, stop
	//    opcode[P_OPCODE_WIDTH-1] == 1 denotes a control opcode
	// 2. ALU opcodes: all opcodes carried out by ALU using alu_op_req / alu_op_ack handshaking
	//    ALU opcode (opcode[P_OPCODE_WIDTH-2:0]) is when opcode[P_OPCODE_WIDTH-1] == 0

	// control opcodes: opcode[P_OPCODE_WIDTH-1] == 1
	//   JUMP: opcode[P_OPCODE_WIDTH-2] == 1
	//     JUMP OFFSET: opcode[P_OPCODE_WIDTH-3:0]
	//   LOOPINIT: opcode[P_OPCODE_WIDTH-2-:2] == 01
	//     LOOP COUNT: opcode[P_OPCODE_WIDTH-4:0]
	//   OTHER: opcode[P_OPCODE_WIDTH-2-:3] == 001
	//       opcode[2:0]:
	//       3'b010: TEST & SKIP if CLEAR. Test flag: opcode[6:3]
	//       3'b011: TEST & SKIP if SET.   Test flag: opcode[6:3]
	//       3'b111: STOP
	//       others: NOP
	//       TEST FLAG opcode[6:3]:
	//            0 : ZERO 
	//            1 : CARRY
	//            2 : CARRY & ZERO 
	//            3 : CARRY & ~ZERO 
	//            4 : ZERO & ~CARRY 
	//            5 : ~ZERO & ~CARRY
	//            6 : W[0]
	//            7 : LOOPDONE (testing LOOPDONE decrements the loop counter by one, testing happens before decrement)
	//       others : last_flag (last flag gets updated during all "TEST" operations) enables chaining TEST & SKIP commands
	// ALU operations: opcode[P_OPCODE_WIDTH-1] == 0
	
	reg op_valid  = 0; // opcode is valid (this reg also incorporates op_running state)
	reg last_flag = 0;
	reg test = 0, flag;
	reg [3:0] test_sel = 0;
	reg [8:0] test_sel_oh = 0, test_sel_oh_nxt;
	reg test_set = 0;
	wire [P_OPCODE_WIDTH-1:0] opcode; //current opcode from memory
	
	reg [P_OPCODE_WIDTH-4:0] loop_cntr = 0;
	wire w_mcu_flag_loop = ~|loop_cntr;
	wire loop_dec = (opcode[P_OPCODE_WIDTH-1 -: 4] == 4'b1001) & (opcode[2:1] == 2'b01) & (opcode[6:3] == 4'b0111); //TEST SKIP LOOPDONE flag decrements loop counter
	wire loop_init = (opcode[P_OPCODE_WIDTH-1 -: 3] == 3'b101);
	reg mcu_flag_loop = 0;
	
	wire [P_MEMSIZE_LOG2-1:0]	op_pc_nxt, op_pc_nxt1;
	wire op_read = alu_op_req? alu_op_ack : op_running;
	//wire skip = test? (test_set? flag : ~flag) : 1'b0;
	wire skip;
	
	wire step = alu_op_req? alu_op_ack : op_valid; //go to next operation
	wire jump = opcode[P_OPCODE_WIDTH-2] & ~skip; // this bit denotes JUMP instruction in opcode
	wire [P_MEMSIZE_LOG2-1:0] jump_offset;
	generate if (P_MEMSIZE_LOG2 < (P_OPCODE_WIDTH-3)) begin
		assign jump_offset = opcode[P_MEMSIZE_LOG2-1:0]; // jump offset is relative +/- change, sign extended
	end else begin
		assign jump_offset = {{(P_MEMSIZE_LOG2-(P_OPCODE_WIDTH-3)){opcode[P_OPCODE_WIDTH-3]}},opcode[P_OPCODE_WIDTH-4:0]}; // jump offset is relative +/- change, sign extended
	end endgenerate
	wire alu_op = ~opcode[P_OPCODE_WIDTH-1] & ~skip;
	
	wire stop = (opcode[P_OPCODE_WIDTH-1 -: 4] == 4'b1001) & (opcode[2:0] == 3'b111) & op_valid & step & ~skip;
	wire test_next = (opcode[P_OPCODE_WIDTH-1 -: 4] == 4'b1001) & (opcode[2:1] == 2'b01) & ~skip; //it's a TEST&SKIP opcode

	wire alu_op_update  = alu_op_req? alu_op_ack? alu_op : 1'b0 : step & alu_op;
	wire alu_op_req_nxt = (op_start_wr | stop)? 0 : alu_op_req? alu_op_ack? alu_op : alu_op_req : step & alu_op;
	
	eccop_mcu_opmem #(
		.P_MEMSIZE_LOG2	(	P_MEMSIZE_LOG2	),
		.P_OPCODE_WIDTH	(	P_OPCODE_WIDTH	)
	) i_eccop_mcu_opmem (
		.clk	(	clk			),
		.sreset	(	sreset		),
		.areset	(	areset		),
		.rwaddr	(	opmem_rwaddr	),
		.wdata	(	opmem_wdata	),
		.we		(	opmem_we	),
		//.raddr1	(	opmem_raddr	),
		.rdata1	(	opmem_rdata	),
		.re1	(	opmem_re	),
		.raddr2	(	op_pc_nxt	),
		.rdata2	(	opcode		),
		.re2	(	op_read		)
	);

	assign op_pc_nxt1= (({opcode[P_OPCODE_WIDTH-1 -: 2],skip} == 3'b110))? (op_pc + jump_offset) : (op_pc + 1'b1);
	//assign op_pc_nxt = step? op_pc_nxt1 : op_pc; 
	assign op_pc_nxt = op_valid? op_pc_nxt1 : op_pc; 
	
	always @(posedge clk or posedge areset)
		if (sreset | areset) begin
			op_pc         <= 0;
			op_running    <= 1'b0;
			op_valid      <= 1'b0;
			alu_op_req    <= 1'b0;
			test          <= 1'b0;
			mcu_flag_loop <= 0;
			loop_cntr     <= 0;
		end else begin
			op_valid <= op_valid? op_valid : op_read; // op valid is delayed read // FIXME: jump shall clear op valid
			if (op_read)
				op_pc    <= op_pc_nxt;
			alu_op_req <= alu_op_req_nxt;
			if (step) begin
				test <= test_next;
				mcu_flag_loop <= w_mcu_flag_loop;
				if (loop_dec)
					loop_cntr <= loop_cntr - 1'b1;
				if (loop_init)
					loop_cntr <= opcode[P_OPCODE_WIDTH-4:0];
			end
			if (op_start_wr | stop) begin // write from SW has precedence
				op_running <= op_start_en & op_start_wr;
				op_valid   <= 1'b0;
				//alu_op_req <= 1'b0; //NB: alu_op_req may be lowered before alu_op_ack is provided
				test       <= 1'b0;
				op_pc <= (op_start_en & op_start_wr)? op_start_addr : op_pc;
			end
		end
	
	assign alu_op_code_ahead = opcode[P_OPCODE_WIDTH-2:0];
	assign alu_op_code_pass  = alu_op_req_nxt;
	
	always @(posedge clk) begin
		if (alu_op_update)
			alu_op_code <= opcode[P_OPCODE_WIDTH-2:0];
		if (step) begin
			test_sel <= opcode[6:3];
			test_sel_oh <= test_sel_oh_nxt;
			test_set <= opcode[0];
		end
		if (step & test)
			last_flag <= flag;
	end

	//test flag selector
	always @* begin
		case (opcode[6:3])
			4'd0:    test_sel_oh_nxt = 9'b000000001; //flag <=  alu_flags_zero;
			4'd1:    test_sel_oh_nxt = 9'b000000010; //flag <=  alu_flags_carry;
			4'd2:    test_sel_oh_nxt = 9'b000000100; //flag <=  alu_flags_carry &  alu_flags_zero;
			4'd3:    test_sel_oh_nxt = 9'b000001000; //flag <=  alu_flags_carry & ~alu_flags_zero;
			4'd4:    test_sel_oh_nxt = 9'b000010000; //flag <= ~alu_flags_carry &  alu_flags_zero;
			4'd5:    test_sel_oh_nxt = 9'b000100000; //flag <= ~alu_flags_carry & ~alu_flags_zero;
			4'd6:    test_sel_oh_nxt = 9'b001000000; //flag <=  alu_flags_w0;
			4'd7:    test_sel_oh_nxt = 9'b010000000; //flag <=  mcu_flag_loop;
			default: test_sel_oh_nxt = 9'b100000000; //flag <= last_flag;
		endcase
		test_sel_oh_nxt = test_sel_oh_nxt & ({9{test_next}});
	end
	
	
	always @* begin
		case (test_sel)
			4'd0:    flag <=  alu_flags_zero;
			4'd1:    flag <=  alu_flags_carry;
			4'd2:    flag <=  alu_flags_carry &  alu_flags_zero;
			4'd3:    flag <=  alu_flags_carry & ~alu_flags_zero;
			4'd4:    flag <= ~alu_flags_carry &  alu_flags_zero;
			4'd5:    flag <= ~alu_flags_carry & ~alu_flags_zero;
			4'd6:    flag <=  alu_flags_w0;
			4'd7:    flag <=  mcu_flag_loop;
			default: flag <= last_flag;
		endcase
	end
	
	
	
	assign skip = (test_sel_oh[0] & (~test_set ^   alu_flags_zero)) | 
				  (test_sel_oh[1] & (~test_set ^   alu_flags_carry)) |
				  (test_sel_oh[2] & (~test_set ^ ( alu_flags_carry &  alu_flags_zero))) |
				  (test_sel_oh[3] & (~test_set ^ ( alu_flags_carry & ~alu_flags_zero))) |
				  (test_sel_oh[4] & (~test_set ^ (~alu_flags_carry &  alu_flags_zero))) |
				  (test_sel_oh[5] & (~test_set ^ (~alu_flags_carry & ~alu_flags_zero))) |
				  (test_sel_oh[6] & (~test_set ^   alu_flags_w0)) |
				  (test_sel_oh[7] & (~test_set ^   mcu_flag_loop)) |
				  (test_sel_oh[8] & (~test_set ^   last_flag));
	
	
	
	`ifdef __SIM
	//FIXME: not updated since addition of LOOP command
	//synopsys translate_off
	// command decoding for debugging purpose
	static string flag_names[0:7] = '{"ZERO", "CARRY", "CARRY & ZERO", "CARRY & !ZERO", "!CARRY & ZERO", "!CARRY & !ZERO", "W[0]", "LAST"};
	always @(posedge clk) begin
		if (step) begin
			if (opcode[P_OPCODE_WIDTH-1]) begin
				if (opcode[P_OPCODE_WIDTH-2]) begin
					$display("%sJUMP %d", skip? "SKIPPED " : "", signed'(jump_offset));
				end else begin
					if (opcode[P_OPCODE_WIDTH-3]) begin
						$display("%sTS%s %s", skip? "SKIPPED " : "", opcode[P_OPCODE_WIDTH-4]? "S":"C", flag_names[opcode[2:0]]);
					end else begin
						if (opcode[P_OPCODE_WIDTH-4:0] == {(P_OPCODE_WIDTH-3){1'b1}})
							$display("%sSTOP", skip? "SKIPPED " : "");
						else 
							$display("%sNOP 0x%03h", skip? "SKIPPED " : "", opcode[P_OPCODE_WIDTH-4:0]);
					end
				end
			end else begin
				$display("%sALUOP(0x%03H)", skip? "SKIPPED " : "", opcode[P_OPCODE_WIDTH-2:0]);
			end
		end
	end
	//synopsys translate_on
	`endif
	
endmodule


module eccop_mcu_opmem #(
	parameter	P_MEMSIZE_LOG2	= 10,
	parameter	P_OPCODE_WIDTH	= 14 
)(
	input							clk		,
	input							sreset	,
	input							areset	,
	input	[P_MEMSIZE_LOG2-1:0]	rwaddr	,
	input	[P_OPCODE_WIDTH-1:0]	wdata	,
	input							we		,
	//input	[P_MEMSIZE_LOG2-1:0]	raddr1	,
	output	reg [P_OPCODE_WIDTH-1:0]	rdata1	,
	input							re1		,
	input	[P_MEMSIZE_LOG2-1:0]	raddr2	,
	output	reg [P_OPCODE_WIDTH-1:0]	rdata2	,
	input							re2		
);

	reg [P_OPCODE_WIDTH-1:0] mem [0:2**P_MEMSIZE_LOG2-1] /* synthesis syn_ramstyle = "rw_check" */;
	reg [P_MEMSIZE_LOG2-1:0] raddr_a, raddr_b1 , raddr_b;

	assign rdata1 = mem[raddr_a];
	assign rdata2 = mem[raddr_b];
	
	always @(posedge clk) begin
		//if (re1 | we) begin
			if (we)
				mem[rwaddr] <= wdata;
			raddr_a <= rwaddr; //raddr1;
		//end
		//if (re1)
		if (re2)
			raddr_b1 <= raddr2;
		raddr_b <= re2? raddr2 : raddr_b1;
		
	end
	
endmodule
