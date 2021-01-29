//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : A dummy (inactive) module to terminate an existing AXI Master 
//             : interface
//-----------------------------------------------------------------------------

module axi_dummy_master #(
	parameter P_AXI_IDWIDTH = 5
)(
	// AXI Master inetrface - output
	output	[31:0]				axim_awaddr		,
	output	[ 7:0]				axim_awlen		,
	output	[ 2:0]				axim_awsize		,
	output	[ 1:0]				axim_awburst	,
	output	[P_AXI_IDWIDTH-1:0]	axim_awid		,
	output						axim_awlock		,
	output	[3:0]				axim_awcache	,
	output	[2:0]				axim_awprot		,
	output						axim_awvalid	,
	input						axim_awready	,
	
	output	[P_AXI_IDWIDTH-1:0]	axim_wid		,
	output	[63:0]				axim_wdata		,
	output	[ 7:0]				axim_wstrb		,
	output						axim_wlast		,
	output						axim_wvalid		,
	input						axim_wready		,

	input	[P_AXI_IDWIDTH-1:0]	axim_bid		,
	input	[ 1:0]				axim_bresp		,
	input						axim_bvalid		,
	output						axim_bready		,
	
	output	[P_AXI_IDWIDTH-1:0]	axim_arid		,
	output	[31:0]				axim_araddr		,
	output	[ 3:0]				axim_arlen		,
	output	[ 2:0]				axim_arsize		,
	output	[ 1:0]				axim_arburst	,
	output						axim_arlock		,
	output	[3:0]				axim_arcache	,
	output	[2:0]				axim_arprot		,
	output						axim_arvalid	,
	input						axim_arready	,
	
	input	[P_AXI_IDWIDTH-1:0]	axim_rid		,
	input	[63:0]				axim_rdata		,
	input	[ 1:0]				axim_rresp		,
	input						axim_rlast		,
	input						axim_rvalid		,
	output						axim_rready		,

	output						axim_awuser		,
	output						axim_wuser		,
	input						axim_buser		,
	output						axim_aruser		,
	input						axim_ruser		
);

	assign axim_awvalid = 0;
	assign axim_wvalid = 0;
	assign axim_bready = 0;
	assign axim_arvalid = 0;
	assign axim_rready = 0;
	assign axim_awid = 0;
	assign axim_wid = 0;
	assign axim_arid = 0;
	
	
endmodule
