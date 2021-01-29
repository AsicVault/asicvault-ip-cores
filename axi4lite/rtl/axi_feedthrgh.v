//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : A simple feed-through module for constructing master to 
//             : mirrored slave translations
//-----------------------------------------------------------------------------

module axi_feedthrgh #(
	parameter P_AXI_IDWIDTH = 5
)(
	// AXI Slave inetrface - input
	input	[31:0]				axis_awaddr		,
	input	[ 7:0]				axis_awlen		,
	input	[ 2:0]				axis_awsize		,
	input	[ 1:0]				axis_awburst	,
	input	[P_AXI_IDWIDTH-1:0]	axis_awid		,
	input						axis_awlock		,
	input	[3:0]				axis_awcache	,
	input	[2:0]				axis_awprot		,
	input						axis_awvalid	,
	output						axis_awready	,
	
	input	[P_AXI_IDWIDTH-1:0]	axis_wid		,
	input	[63:0]				axis_wdata		,
	input	[ 7:0]				axis_wstrb		,
	input						axis_wlast		,
	input						axis_wvalid		,
	output						axis_wready		,

	output	[P_AXI_IDWIDTH-1:0]	axis_bid		,
	output	[ 1:0]				axis_bresp		,
	output						axis_bvalid		,
	input						axis_bready		,
	
	input	[P_AXI_IDWIDTH-1:0]	axis_arid		,
	input	[31:0]				axis_araddr		,
	input	[ 3:0]				axis_arlen		,
	input	[ 2:0]				axis_arsize		,
	input	[ 1:0]				axis_arburst	,
	input						axis_arlock		,
	input	[3:0]				axis_arcache	,
	input	[2:0]				axis_arprot		,
	input						axis_arvalid	,
	output						axis_arready	,
	
	output	[P_AXI_IDWIDTH-1:0]	axis_rid		,
	output	[63:0]				axis_rdata		,
	output	[ 1:0]				axis_rresp		,
	output						axis_rlast		,
	output						axis_rvalid		,
	input						axis_rready		,

	input						axis_awuser		,
	input						axis_wuser		,
	output						axis_buser		,
	input						axis_aruser		,
	output						axis_ruser		,

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

	assign	axim_awaddr[31: 0]	=	axis_awaddr[31:0]	;

	assign	axim_araddr[31: 0]	=	axis_araddr[31:0]	;

	//assign	axim_awaddr			=	axis_awaddr		;
	assign	axim_awlen			=	axis_awlen		;
	assign	axim_awsize			=	axis_awsize		;
	assign	axim_awburst		=	axis_awburst	;
	assign	axim_awid			=	axis_awid		;
	assign	axim_awlock			=	axis_awlock		;
	assign	axim_awcache		=	axis_awcache	;
	assign	axim_awprot			=	axis_awprot		;
	assign	axim_awvalid		=	axis_awvalid	;
	assign	axim_wid			=	axis_wid		;
	assign	axim_wdata			=	axis_wdata		;
	assign	axim_wstrb			=	axis_wstrb		;
	assign	axim_wlast			=	axis_wlast		;
	assign	axim_wvalid			=	axis_wvalid		;
	assign	axim_bready			=	axis_bready		;
	assign	axim_arid			=	axis_arid		;
	//assign	axim_araddr			=	axis_araddr		;
	assign	axim_arlen			=	axis_arlen		;
	assign	axim_arsize			=	axis_arsize		;
	assign	axim_arburst		=	axis_arburst	;
	assign	axim_arlock			=	axis_arlock		;
	assign	axim_arcache		=	axis_arcache	;
	assign	axim_arprot			=	axis_arprot		;
	assign	axim_arvalid		=	axis_arvalid	;
	assign	axim_rready			=	axis_rready		;
	assign	axim_awuser			=	axis_awuser		;
	assign	axim_wuser			=	axis_wuser		;
	assign	axim_aruser			=	axis_aruser		;

	assign	axis_awready		=	axim_awready	;
	assign	axis_wready			=	axim_wready		;
	assign	axis_bid			=	axim_bid		;
	assign	axis_bresp			=	axim_bresp		;
	assign	axis_bvalid			=	axim_bvalid		;
	assign	axis_arready		=	axim_arready	;
	assign	axis_rid			=	axim_rid		;
	assign	axis_rdata			=	axim_rdata		;
	assign	axis_rresp			=	axim_rresp		;
	assign	axis_rlast			=	axim_rlast		;
	assign	axis_rvalid			=	axim_rvalid		;
	assign	axis_buser			=	axim_buser		;
	assign	axis_ruser			=	axim_ruser		;
	
	
	
	
endmodule
