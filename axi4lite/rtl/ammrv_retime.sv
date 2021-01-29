//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Avalon MM retiming module to improve timing in logic
//----------------------------------------------------------------------------

module ammrv_retime #(
	parameter FF_ON_CMD   = 1, //enable FF insertion on command channel
	parameter FF_ON_ACK   = 1, //enable FF insertion on waitrequest, when FF is on ACK it is also on readdata & readdatavalid
	parameter FF_ON_RDATA = 1  //enable FF insertion on readdata and readdatavalid
) (
	input				clk						,
	input				reset					, //synchronous active high reset
	input				areset					, //asynchronous active high reset

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

	reg	[31:0]		r_address		;
	reg	[ 3:0]		r_byteenable	;
	reg	[31:0]		r_writedata		;
	reg				r_read	= 0		;
	reg				r_write	= 0		;
	reg				r_waitrequest	= 1'b1;
	reg	[31:0]		r_readdata		;
	reg				r_readdatavalid	= 0;

	assign	m_address		= FF_ON_CMD? r_address		: s_address		;
	assign	m_byteenable	= FF_ON_CMD? r_byteenable	: s_byteenable	;
	assign	m_writedata		= FF_ON_CMD? r_writedata	: s_writedata	;
	assign	m_read			= FF_ON_CMD? r_read			: s_read		;
	assign	m_write			= FF_ON_CMD? r_write		: s_write		;
	
	assign	s_readdata		= (FF_ON_RDATA|FF_ON_ACK)? r_readdata		:	m_readdata		;
	assign	s_readdatavalid	= (FF_ON_RDATA|FF_ON_ACK)? r_readdatavalid	:	m_readdatavalid	;

	assign s_waitrequest = FF_ON_ACK? r_waitrequest : m_waitrequest;
	
	reg exec = 0;

	always @(posedge clk) begin
		r_readdata		<= m_readdata;
		if ((s_read | s_write) & ~exec & (FF_ON_ACK? r_waitrequest : 1'b1)) begin
			r_address		<= s_address	;
			r_byteenable	<= s_byteenable	;
			r_writedata		<= s_writedata	;
		end
	end
	
	
	always @(posedge clk or posedge areset)
		if (reset | areset) begin
			exec <= 0;
			r_waitrequest <= 1'b1;
			r_read <= 0;
			r_write <= 0;
			r_readdatavalid <= 0;
		end else begin
			exec <= exec? m_waitrequest? exec : 0 : FF_ON_ACK? r_waitrequest & (s_read | s_write) : (s_read | s_write);
			r_waitrequest <= ~(exec & ~m_waitrequest);
			r_readdatavalid	<= m_readdatavalid;
			if ((s_read | s_write) & ~exec & (FF_ON_ACK? r_waitrequest : 1'b1)) begin
				r_read			<= s_read		;
				r_write			<= s_write		;
			end else begin
				if (~m_waitrequest) begin
					r_read		<= 1'b0;
					r_write		<= 1'b0;
				end
			end
		end

endmodule


