//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Simple Avalon MM to Avalon MM with readdatavalid
//----------------------------------------------------------------------------

module amm2amm_rv (
	//Avalon MM interface (master)
	input				clk						,
	input				reset					, //synchronous active high reset
	
	input	[31:0]		s_address				,
	input	[ 3:0]		s_byteenable			,
	input	[31:0]		s_writedata				,
	input				s_read					,
	input				s_write					,
	output				s_waitrequest			,
	output	reg [31:0]	s_readdata				,
	output	reg			s_readdatavalid			,
	
	output	[31:0]		m_address				,
	output	[ 3:0]		m_byteenable			,
	output	[31:0]		m_writedata				,
	output				m_read					,
	output				m_write					,
	input				m_waitrequest			,
	input	[31:0]		m_readdata				
);

	assign m_address    = s_address;
	assign m_byteenable = s_byteenable;
	assign m_writedata  = s_writedata;
	assign m_read       = s_read  ;
	assign m_write      = s_write ;

	assign s_waitrequest = m_waitrequest;
	
	always @(posedge clk) begin
		if (m_read & ~m_waitrequest) begin
			s_readdata <= m_readdata;
			s_readdatavalid <= 1'b1;
		end
		if (reset | (s_readdatavalid & ~(m_read & ~m_waitrequest)))
		//if (reset | (s_readdatavalid)) //NB: less fan in, but zero waitstate commands is not supported 
			s_readdatavalid <= 1'b0;
	end
	

endmodule
