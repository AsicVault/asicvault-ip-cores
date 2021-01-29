//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Avalon MM 2 to 1 arbiter for orca subsystem with readdatavalid
//----------------------------------------------------------------------------

module amm2to1arb (
	//Avalon MM interface (master)
	input				clk						,
	input				reset					, //synchronous active high reset
	
	input	[31:0]		s1_address				,
	input	[ 3:0]		s1_byteenable			,
	input	[31:0]		s1_writedata			,
	input				s1_read					,
	input				s1_write				,
	output	reg			s1_waitrequest		= 1	,
	output	[31:0]		s1_readdata				,
	output				s1_readdatavalid		,
	
	input	[31:0]		s2_address				,
	input	[ 3:0]		s2_byteenable			,
	input	[31:0]		s2_writedata			,
	input				s2_read					,
	input				s2_write				,
	output	reg			s2_waitrequest		= 1	,
	output	[31:0]		s2_readdata				,
	output				s2_readdatavalid		,
	
	output	reg [31:0]	m_address				,
	output	reg [ 3:0]	m_byteenable			,
	output	reg [31:0]	m_writedata				,
	output	reg			m_read				= 0	,
	output	reg			m_write				= 0	,
	input				m_waitrequest			,
	input	[31:0]		m_readdata				,
	input				m_readdatavalid			
);

	reg s2_active_r = 0, s1_active_r = 0;

	wire m_active  = m_read  | m_write;
	wire s1_active = s1_read | s1_write;
	wire s2_active = s2_read | s2_write;
	
	wire s1_activate = s1_active & (~m_active | (m_active & ~m_waitrequest)) & ~s1_active_r;
	wire s2_activate = s2_active & ~s1_activate & (~m_active | (m_active & ~m_waitrequest)) & ~s2_active_r;
	
	wire rv_sel;
	wire rv_wreq = (s1_activate & ~s1_write) | (s2_activate & ~s2_write);
	assign s1_readdata = m_readdata;
	assign s2_readdata = m_readdata;
	assign s1_readdatavalid = m_readdatavalid & ~rv_sel;
	assign s2_readdatavalid = m_readdatavalid &  rv_sel;
	
	
	
	
	always @(posedge clk)
		if (reset) begin
			m_read <= 0;
			m_write<= 0;
			s1_waitrequest <= 1'b1;
			s2_waitrequest <= 1'b1;
			s2_active_r <= 0;
			s1_active_r <= 0;
		end else begin
			s1_waitrequest <= 1'b1;
			s2_waitrequest <= 1'b1;
			if (s1_activate)
				s1_active_r <= 1'b1;
			if (s2_activate)
				s2_active_r <= 1'b1;
			if (m_active & ~m_waitrequest) begin
				m_read <= 0;
				m_write<= 0;
				s1_active_r <= 0;
				s2_active_r <= 0;
			end
			if (s2_activate) begin
				m_read <= s2_read;
				m_write<= s2_write;
				s2_waitrequest <= 1'b0;
			end
			if (s1_activate) begin
				s1_waitrequest <= 1'b0;
				s2_waitrequest <= 1'b1;
				m_read <= s1_read;
				m_write<= s1_write;
			end
		end
	
	always @(posedge clk) begin
		if (~m_active | m_active & ~m_waitrequest) begin
			m_address    <= s1_activate? s1_address    : s2_address   ;
			m_byteenable <= s1_activate? s1_byteenable : s2_byteenable;
			m_writedata  <= s1_activate? s1_writedata  : s2_writedata ;
		end
	end
	
	// readdatavalid response fifo
	// No full or empty monitoring - assuming no more than 4 request in pipeline
	sc_fifo_ffmem #(
		.P_WIDTH	(	1	),	// FIFO data width
		.P_LOG2SIZE	(	2	),	// FIFO size = 2**P_LOG2SIZE
		.P_AEMPTY	(	2	),	// aempty = usedw < P_AEMPTY
		.P_AFULL	(	4	),	// afull = usedw >= P_AFULL
		.P_PPROTECT	(	0	),	// pointer overflow protection  
		.P_SHOWAHEAD(	1	)	// 1 - showahead, 0 - synchronous
	) i_sc_fifo_ffmem (
		.aclr	(	1'b0			),
		.sclr	(	reset			),
		.clock	(	clk				),
		.data	(	~s1_activate	),
		.rdreq	(	m_readdatavalid	),
		.wrreq	(	rv_wreq			),
		.aempty	(					),
		.empty	(					),
		.afull	(					),
		.full	(					),
		.usedw	(					),
		.q		(	rv_sel			)
	);

endmodule
