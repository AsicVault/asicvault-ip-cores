//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Avalon MM 1 to 2 master with readdata valid
//----------------------------------------------------------------------------

module amm1to2mux (
	//Avalon MM interface (master)
	input				clk						,
	input				reset					, //synchronous active high reset
	
	input				s_portsel				, // 0: m0, 1: m1 
	input	[31:0]		s_address				,
	input	[ 3:0]		s_byteenable			,
	input	[31:0]		s_writedata				,
	input				s_read					,
	input				s_write					,
	output				s_waitrequest			,
	output	[31:0]		s_readdata				,
	output				s_readdatavalid			,
	
	output	[31:0]		m0_address				,
	output	[ 3:0]		m0_byteenable			,
	output	[31:0]		m0_writedata			,
	output				m0_read					,
	output				m0_write				,
	input				m0_waitrequest			,
	input	[31:0]		m0_readdata				,
	input				m0_readdatavalid		,

	output	[31:0]		m1_address				,
	output	[ 3:0]		m1_byteenable			,
	output	[31:0]		m1_writedata			,
	output				m1_read					,
	output				m1_write				,
	input				m1_waitrequest			,
	input	[31:0]		m1_readdata				,
	input				m1_readdatavalid		
);

	wire rv_sel, rv_wreq;

	assign m0_address    = s_address;
	assign m0_byteenable = s_byteenable;
	assign m0_writedata  = s_writedata;
	assign m0_read       = s_read  & ~s_portsel;
	assign m0_write      = s_write & ~s_portsel;

	assign m1_address    = s_address;
	assign m1_byteenable = s_byteenable;
	assign m1_writedata  = s_writedata;
	assign m1_read       = s_read  & s_portsel;
	assign m1_write      = s_write & s_portsel;

	assign s_waitrequest = s_portsel? m1_waitrequest : m0_waitrequest;
	
	
	assign rv_wreq = s_read & ~s_waitrequest;

	wire	[31:0]		i0_readdata			;
	wire				i0_readdatavalid, i0_empty	;
	wire	[31:0]		i1_readdata			;
	wire				i1_readdatavalid, i1_empty	;

	assign s_readdatavalid = rv_sel? i1_readdatavalid : i0_readdatavalid;
	assign s_readdata      = rv_sel? i1_readdata      : i0_readdata;
	
	// response order queue
	// No full or empty monitoring - assuming no more than 4 request in pipeline
	sc_fifo_ffmem #(
		.P_WIDTH	(	1	),	// FIFO data width
		.P_LOG2SIZE	(	2	),	// FIFO size = 2**P_LOG2SIZE
		.P_AEMPTY	(	2	),	// aempty = usedw < P_AEMPTY
		.P_AFULL	(	4	),	// afull = usedw >= P_AFULL
		.P_PPROTECT	(	0	),	// pointer overflow protection  
		.P_SHOWAHEAD(	1	)	// 1 - showahead, 0 - synchronous
	) i_sc_fifo_ffmem_rorder (
		.aclr	(	1'b0			),
		.sclr	(	reset			),
		.clock	(	clk				),
		.data	(	s_portsel		),
		.rdreq	(	s_readdatavalid	),
		.wrreq	(	rv_wreq			),
		.aempty	(					),
		.empty	(					),
		.afull	(					),
		.full	(					),
		.usedw	(					),
		.q		(	rv_sel			)
	);

	assign i0_readdatavalid = rv_sel? 1'b0 : ~i0_empty;
	
	// readdata response fifo
	// No full or empty monitoring - assuming no more than 4 request in pipeline
	sc_fifo_ffmem #(
		.P_WIDTH	(	32	),	// FIFO data width
		.P_LOG2SIZE	(	1	),	// FIFO size = 2**P_LOG2SIZE
		.P_AEMPTY	(	2	),	// aempty = usedw < P_AEMPTY
		.P_AFULL	(	4	),	// afull = usedw >= P_AFULL
		.P_PPROTECT	(	1	),	// pointer overflow protection  
		.P_SHOWAHEAD(	1	)	// 1 - showahead, 0 - synchronous
	) i_sc_fifo_ffmem_resp0 (
		.aclr	(	1'b0			),
		.sclr	(	reset			),
		.clock	(	clk				),
		.data	(	m0_readdata		),
		.rdreq	(	i0_readdatavalid),
		.wrreq	(	m0_readdatavalid),
		.aempty	(					),
		.empty	(	i0_empty		),
		.afull	(					),
		.full	(					),
		.usedw	(					),
		.q		(	i0_readdata		)
	);
	
	assign i1_readdatavalid = rv_sel? ~i1_empty : 1'b0;
	
	// readdata response fifo
	// No full or empty monitoring - assuming no more than 4 request in pipeline
	sc_fifo_ffmem #(
		.P_WIDTH	(	32	),	// FIFO data width
		.P_LOG2SIZE	(	1	),	// FIFO size = 2**P_LOG2SIZE
		.P_AEMPTY	(	2	),	// aempty = usedw < P_AEMPTY
		.P_AFULL	(	4	),	// afull = usedw >= P_AFULL
		.P_PPROTECT	(	1	),	// pointer overflow protection  
		.P_SHOWAHEAD(	1	)	// 1 - showahead, 0 - synchronous
	) i_sc_fifo_ffmem_resp1 (
		.aclr	(	1'b0			),
		.sclr	(	reset			),
		.clock	(	clk				),
		.data	(	m1_readdata		),
		.rdreq	(	i1_readdatavalid),
		.wrreq	(	m1_readdatavalid),
		.aempty	(					),
		.empty	(	i1_empty		),
		.afull	(					),
		.full	(					),
		.usedw	(					),
		.q		(	i1_readdata		)
	);
	
	
endmodule
