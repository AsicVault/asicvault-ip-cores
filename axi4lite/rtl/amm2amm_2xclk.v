//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Simple 1x clock to 2x clock sync bridge for avalon mm
//----------------------------------------------------------------------------

module amm2amm_2xclk #(parameter P_PASSTHROUGH = 0) (
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
	
	output	[31:0]		m_address				,
	output	[ 3:0]		m_byteenable			,
	output	[31:0]		m_writedata				,
	output				m_read					,
	output				m_write					,
	input				m_waitrequest			,
	input	[31:0]		m_readdata				
);

	wire phase;
	clk_sync_phase #(P_PASSTHROUGH) i_clk_sync_phase (.clk(clk),.clk_2x(clk_2x),.falling(phase));
	
	reg cmd_gate = 0;
	reg [31:0] m_readdata_f;
	
	assign m_address    = s_address;
	assign m_byteenable = s_byteenable;
	assign m_writedata  = s_writedata;
	assign m_read       = s_read  & (P_PASSTHROUGH? 1'b1 : ~cmd_gate);
	assign m_write      = s_write & (P_PASSTHROUGH? 1'b1 : ~cmd_gate);

	assign s_waitrequest = P_PASSTHROUGH? m_waitrequest : phase? 1'b1: cmd_gate? 1'b0 : m_waitrequest;
	assign s_readdata = P_PASSTHROUGH? m_readdata : cmd_gate? m_readdata_f : m_readdata;
	
	//this gates the command to fast side when the fast peripheral responds when slow clock is falling
	always @(posedge clk_2x) begin
		cmd_gate <= phase & (s_read | s_write) & ~m_waitrequest;
		if (cmd_gate | reset)
			cmd_gate <= 1'b0;
	end
	
	always @(posedge clk_2x) 
		if (phase & s_read & ~m_waitrequest)
			m_readdata_f <= m_readdata;
	

endmodule


module amm2amm_2xclk_sync (
	//Avalon MM interface (master)
	input				clk						,
	input				clk_2x					,
	input				reset					, //synchronous active high reset
	
	input	[31:0]		s_address				,
	input	[ 3:0]		s_byteenable			,
	input	[31:0]		s_writedata				,
	input				s_read					,
	input				s_write					,
	output		 		s_waitrequest			,
	output	reg [31:0]	s_readdata				,
	
	output	reg	[31:0]	m_address				,
	output	reg	[ 3:0]	m_byteenable			,
	output	reg	[31:0]	m_writedata				,
	output	reg			m_read				= 0	,
	output	reg			m_write				= 0	,
	input				m_waitrequest			,
	input	[31:0]		m_readdata				
);

	wire falling;
	clk_sync_phase #(0) i_clk_sync_phase (.clk(clk),.clk_2x(clk_2x),.falling(falling));
	
	reg active = 0, d_activate_wr = 0, rd_resp = 0;
	wire latch_cmd;
	assign latch_cmd = (active | rd_resp)? 0 : (s_read | s_write);
	
	// write is acknowledged immediately, read when data is available
	assign s_waitrequest = (active | rd_resp)? rd_resp? 0 : ~d_activate_wr : s_write? 1'b0 : 1'b1;
	
	always @(posedge clk_2x) begin
		if (latch_cmd) begin
			m_address    <= s_address;
			m_byteenable <= s_byteenable;
			m_writedata  <= s_writedata;
		end
		if (m_read & ~m_waitrequest)
			s_readdata <= m_readdata;
	end
	
	always @(posedge clk_2x) 
		if (reset) begin
			m_read <= 0;
			m_write <= 0;
			active <= 0;
			d_activate_wr <= 0;
			rd_resp <= 0;
		end else begin
			d_activate_wr <= 1'b0;
			rd_resp <= rd_resp? falling : (m_read & ~m_waitrequest);
			if (latch_cmd) begin
				m_read <= s_read;
				m_write <= s_write;
				active <= 1;
				d_activate_wr <= s_write & falling;
			end
			if (active & ~m_waitrequest) begin
				m_read <= 0;
				m_write <= 0;
				active <= 0;
			end
			
		end
	
	
	
endmodule

