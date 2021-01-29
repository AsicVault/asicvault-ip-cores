//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Avalon MM to cache management interface module
//----------------------------------------------------------------------------

module ammrv_cache_ctrl (
	input				clk						,
	input				reset					, //synchronous active high reset
	
	input	[31:0]		amm_address				,
	input	[ 3:0]		amm_byteenable			, // ignored
	input	[31:0]		amm_writedata			,
	input				amm_read				,
	input				amm_write				,
	output				amm_waitrequest			,
	output	[31:0]		amm_readdata			,
	output	reg			amm_readdatavalid	= 0	,
	
	//cache management interface
	output	reg [31:0]	icache_req_addr			,
	output	reg			icache_req_flush	= 0	,
	output	reg			icache_req_inval	= 0	,
	input				icache_req_ack			,

	output	reg [31:0]	dcache_req_addr			,
	output	reg			dcache_req_flush	= 0	,
	output	reg			dcache_req_inval	= 0	,
	input				dcache_req_ack			
);

	//avalon MM to cache managemeni interface bridge
	// 1. All read transactions return dummy data
	// 2. write transactions address bits [3:2] define the behaviour:
	// Address[4] selects between instruction cache and data cache
	// 1 - icache
	// 1 - dcache
	// Addr[3:2]
	// 00 - nop
	// 01 - x_req_inval
	// 10 - x_req_flush
	// 11 - x_req_flush & x_req_inval
	
	
	wire exec  = (icache_req_flush | icache_req_inval) | (dcache_req_flush | dcache_req_inval);
	wire iwait = (icache_req_flush | icache_req_inval) & ~icache_req_ack;
	wire dwait = (dcache_req_flush | dcache_req_inval) & ~dcache_req_ack;
	
	assign amm_waitrequest = amm_read? 1'b0 : exec? (iwait | dwait) : ~(amm_address[3:2] == 2'b00);
	
	always @(posedge clk) begin
		amm_readdatavalid <= (reset | amm_readdatavalid)? 1'b0 : amm_read;
		if (amm_write & ~exec) begin
			if (amm_address[4]) begin
				dcache_req_flush <= amm_address[3];
				dcache_req_inval <= amm_address[2];
				dcache_req_addr  <= amm_writedata ;
			end else begin
				icache_req_flush <= amm_address[3];
				icache_req_inval <= amm_address[2];
				icache_req_addr  <= amm_writedata ;
			end
		end else if (icache_req_ack | dcache_req_ack) begin
			dcache_req_flush <= 1'b0;
			dcache_req_inval <= 1'b0;
			icache_req_flush <= 1'b0;
			icache_req_inval <= 1'b0;
		end
	end
	
endmodule
