//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Avalon MM 2 to 1 arbiter for orca subsystem with readdatavalid
//----------------------------------------------------------------------------

module amm2to1arb_async (
	//Avalon MM interface (master)
	input				clk						,
	input				reset					, //synchronous active high reset
	
	input	[31:0]		s1_address				,
	input	[ 3:0]		s1_byteenable			,
	input	[31:0]		s1_writedata			,
	input				s1_read					,
	input				s1_write				,
	output				s1_waitrequest			,
	output	[31:0]		s1_readdata				,
	output				s1_readdatavalid		,
	
	input	[31:0]		s2_address				,
	input	[ 3:0]		s2_byteenable			,
	input	[31:0]		s2_writedata			,
	input				s2_read					,
	input				s2_write				,
	output				s2_waitrequest			,
	output	[31:0]		s2_readdata				,
	output				s2_readdatavalid		,
	
	output		[31:0]	m_address				,
	output		[ 3:0]	m_byteenable			,
	output		[31:0]	m_writedata				,
	output				m_read					,
	output				m_write					,
	input				m_waitrequest			,
	input		[31:0]	m_readdata				,
	input				m_readdatavalid			
);

	wire psel;
	wire wsel;
	
	reg selected = 0;
	reg rsel = 0;
	reg mdisable = 0;
	
	assign m_address    = psel? s2_address    : s1_address;
	assign m_byteenable = psel? s2_byteenable : s1_byteenable;
	assign m_writedata  = psel? s2_writedata  : s1_writedata;
	assign m_read       = mdisable? 1'b0 : psel? s2_read  : s1_read;
	assign m_write      = mdisable? 1'b0 : psel? s2_write : s1_write;
	assign s2_waitrequest = psel? m_waitrequest : 1'b1;
	assign s1_waitrequest = psel? 1'b1 : m_waitrequest;
	assign s1_readdata = m_readdata;
	assign s2_readdata = m_readdata;
	assign s2_readdatavalid = m_readdatavalid &  psel;
	assign s1_readdatavalid = m_readdatavalid & ~psel;

	assign wsel = (s2_read | s2_write);
	
	assign psel = selected? rsel : wsel;
	
	
	always @(posedge clk)
		if (reset) begin
			selected <= 0;
			rsel <= 0;
			mdisable <= 0;
		end else begin
			if (selected) begin
				if (mdisable) begin
					if (m_readdatavalid) begin
						mdisable <= 0;
						selected <= 0;
					end
				end else begin
					if (~m_waitrequest) begin
						selected <= m_read;
						mdisable <= m_read;
					end
				end
			end else begin
				if (s1_write | s1_read | s2_write | s2_read) begin
					selected <= 1'b1;
					rsel <= wsel;
					if (~m_waitrequest) begin
						mdisable <= m_read;
						selected <= m_read;
					end
				end
			end
		end
	

endmodule
