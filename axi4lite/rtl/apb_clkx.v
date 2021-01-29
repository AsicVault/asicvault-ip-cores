//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : APB bus clock domain crossing module
//-----------------------------------------------------------------------------

module apb_clkx #(
		parameter DW = 16,
		parameter AW = 16
)(
	// slave port - ingress
	input				APBS_CLK		,
	input				APBS_RESETN		,
	input				APBS_PSEL 		,
	input				APBS_PENABLE	,
	input  [AW-1:0]		APBS_PADDR		,
	input  [DW-1:0]		APBS_PWDATA		,
	input				APBS_PWRITE		,
	output [DW-1:0]		APBS_PRDATA		,
	output				APBS_PREADY		,
	output				APBS_PSLVERR	,

	// master port - egress
	input				APBM_CLK			,
	input				APBM_RESETN			,
	output reg			APBM_PSEL 		= 0	,
	output reg			APBM_PENABLE	= 0	,
	output [AW-1:0]		APBM_PADDR			,
	output [DW-1:0]		APBM_PWDATA			,
	output 				APBM_PWRITE			,
	input  [DW-1:0]		APBM_PRDATA			,
	input				APBM_PREADY			,
	input				APBM_PSLVERR		
);
			
	reg s_exec = 0;
	wire s_ack;
	reg s_ack1 = 0;
	always @(posedge APBS_CLK or negedge APBS_RESETN)
		if (~APBS_RESETN) begin
			s_exec <= 2'b00;
			s_ack1 <= 1'b0;
		end else begin
			s_ack1 <= s_ack;
			if (s_exec)	begin
				s_exec <= APBS_PWRITE? ~s_ack : ~s_ack1;
			end else begin
				if (APBS_PSEL & APBS_PENABLE & ~s_ack) begin
					s_exec <= 1'b1;
				end
			end
		end
	
	assign APBS_PREADY = s_exec? APBS_PWRITE? s_ack : s_ack1     : ~s_ack & ~APBS_PENABLE;
	
	reg [DW-1:0] PRDATA_meta;
	reg PSLVERR_meta ;

	reg [DW-1:0] PRDATA_async;
	reg PSLVERR_async ;
	reg m_ack = 0;
	wire m_exec;

	always @(posedge APBS_CLK)
		if (s_ack & ~APBS_PWRITE) begin
			PRDATA_meta <= PRDATA_async ;
			PSLVERR_meta<= PSLVERR_async;
		end
	
	nsync #(.N(2),.R(0)) i_m_nsync (.r(~APBM_RESETN),.c(APBM_CLK),.i(s_exec),.o(m_exec));
	nsync #(.N(2),.R(0)) i_s_nsync (.r(~APBS_RESETN),.c(APBS_CLK),.i(m_ack ),.o(s_ack ));

	assign APBS_PRDATA = PRDATA_meta ;
	assign APBS_PSLVERR= PSLVERR_meta;
	
	
	always @(posedge APBM_CLK or negedge APBM_RESETN)
	//always @(posedge APBM_CLK)
		if (~APBM_RESETN) begin
			APBM_PSEL 		<= 1'b0;
			APBM_PENABLE	<= 1'b0;
			m_ack			<= 1'b0;
		end else begin
			if (m_ack)
				m_ack <= m_exec;
			if (~APBM_PSEL & ~m_ack)
				APBM_PSEL <= m_exec;
			if (APBM_PREADY)
				APBM_PENABLE <= APBM_PSEL;
			if (APBM_PENABLE & APBM_PSEL & APBM_PREADY) begin
				APBM_PENABLE <= 1'b0;
				APBM_PSEL    <= 1'b0;
				m_ack		 <= 1'b1;
			end
		end
	
	
	reg [AW-1:0]	APBM_PADDR_meta			;
	reg [DW-1:0]	APBM_PWDATA_meta		;
	reg				APBM_PWRITE_meta		;
	
	assign	APBM_PADDR		=	APBM_PADDR_meta		;
	assign	APBM_PWDATA		=	APBM_PWDATA_meta	;
	assign	APBM_PWRITE		=	APBM_PWRITE_meta	;
	
	
	always @(posedge APBM_CLK) begin
		if (APBM_PENABLE & APBM_PSEL & APBM_PREADY) begin
			PRDATA_async  <= APBM_PRDATA ;
			PSLVERR_async <= APBM_PSLVERR;
		end
		if (m_exec & ~APBM_PSEL) begin
			APBM_PADDR_meta  <= APBS_PADDR ;
			APBM_PWDATA_meta <= APBS_PWDATA;
			APBM_PWRITE_meta <= APBS_PWRITE;
		end
	end

endmodule