//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Simple 1x clock to 2x clock sync bridge for avalon mm with readdatavalid
//----------------------------------------------------------------------------

module ammrv2ammrv_2xclk #(parameter P_PASSTHROUGH = 0) (
	//Avalon MM interface (master)
	input				clk						,
	input				clk_2x					,
	input				reset					, //synchronous active high reset
	
	input	[31:0]		s_address				,
	input	[ 3:0]		s_byteenable			,
	input	[31:0]		s_writedata				,
	input				s_read					,
	input				s_write					,
	output				s_waitrequest			,
	output	[31:0]		s_readdata				,
	output				s_readdatavalid			,
	
	output	[31:0]		m_address				,
	output	[ 3:0]		m_byteenable			,
	output	[31:0]		m_writedata				,
	output				m_read					,
	output				m_write					,
	input				m_waitrequest			,
	input	[31:0]		m_readdata				,
	input				m_readdatavalid			
);

	wire phase;
	clk_sync_phase #(P_PASSTHROUGH) i_clk_sync_phase (.clk(clk),.clk_2x(clk_2x),.falling(phase));
	
	reg cmd_gate = 0;
	wire [31:0] s_readdata_f;
	wire s_empty;
	
	assign m_address    = s_address;
	assign m_byteenable = s_byteenable;
	assign m_writedata  = s_writedata;
	assign m_read       = s_read  & (P_PASSTHROUGH? 1'b1 : ~cmd_gate);
	assign m_write      = s_write & (P_PASSTHROUGH? 1'b1 : ~cmd_gate);

	assign s_waitrequest = P_PASSTHROUGH? m_waitrequest : phase? 1'b1: cmd_gate? 1'b0 : m_waitrequest;
	assign s_readdata = P_PASSTHROUGH? m_readdata : s_readdata_f;
	assign s_readdatavalid = P_PASSTHROUGH? m_readdatavalid : ~s_empty;
	
	sc_fifo_ffmem #(
		.P_WIDTH		(	32	),	//FIFO data width
		.P_LOG2SIZE		(	1	),	//FIFO size = 2**P_LOG2SIZE
		.P_AEMPTY		(	1	),	//aempty = usedw < P_AEMPTY
		.P_AFULL		(	1	),	//afull = usedw >= P_AFULL
		.P_PPROTECT		(	1	),	//pointer overflow protection
		.P_SHOWAHEAD	(	1	)	//1 - showahead, 0 - synchronous
	) i_sc_fifo_ffmem (
		.aclr	(	1'b0	),
		.sclr	(	reset	),
		.clock	(	clk_2x	),
		.data	(	m_readdata	),
		.rdreq	(	P_PASSTHROUGH? 1'b0 : ~phase	),
		.wrreq	(	P_PASSTHROUGH? 1'b0 : m_readdatavalid ),
		.aempty	(		),
		.empty	(	s_empty			),
		.afull	(		),
		.full	(		),
		.usedw	(		),
		.q		(	s_readdata_f	)
	);
	
	//this gates the command to fast side when the fast peripheral responds when slow clock is falling
	always @(posedge clk_2x) begin
		cmd_gate <= phase & (s_read | s_write) & ~m_waitrequest;
		if (cmd_gate | reset)
			cmd_gate <= 1'b0;
	end
	

endmodule
