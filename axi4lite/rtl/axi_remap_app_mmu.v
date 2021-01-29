//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Application CPU memory access remapping/blocking module
//-----------------------------------------------------------------------------

module axi_remap_app_mmu #(
	parameter P_AXI_IDWIDTH = 4
)(
	// AXI Slave inetrface - input
	input	[31:0]				axis_awaddr		,
	input	[ 3:0]				axis_awlen		,
	input	[ 2:0]				axis_awsize		,
	input	[ 1:0]				axis_awburst	,
	input	[P_AXI_IDWIDTH-1:0]	axis_awid		,
	input						axis_awvalid	,
	input	[P_AXI_IDWIDTH-1:0]	axis_wid		,
	input	[63:0]				axis_wdata		,
	input	[ 7:0]				axis_wstrb		,
	input						axis_wlast		,
	input						axis_wvalid		,
	input						axis_bready		,
	output						axis_awready	,
	output						axis_wready		,
	output	[ 1:0]				axis_bresp		,
	output	[P_AXI_IDWIDTH-1:0]	axis_bid		,
	output						axis_bvalid		,
	input						axis_arvalid	,
	output						axis_arready	,
	input	[31:0]				axis_araddr		,
	input	[ 2:0]				axis_arsize		,
	input	[P_AXI_IDWIDTH-1:0]	axis_arid		,
	input	[ 3:0]				axis_arlen		,
	input	[ 1:0]				axis_arburst	,
	input						axis_rready		,
	output						axis_rvalid		,
	output						axis_rlast		,
	output	[P_AXI_IDWIDTH-1:0]	axis_rid		,
	output	[63:0]				axis_rdata		,
	output	[ 1:0]				axis_rresp		,

	// AXI Master inetrface - output
	output	[31:0]				axim_awaddr		,
	output	[ 3:0]				axim_awlen		,
	output	[ 2:0]				axim_awsize		,
	output	[ 1:0]				axim_awburst	,
	output	[P_AXI_IDWIDTH-1:0]	axim_awid		,
	output						axim_awvalid	,
	output	[P_AXI_IDWIDTH-1:0]	axim_wid		,
	output	[63:0]				axim_wdata		,
	output	[ 7:0]				axim_wstrb		,
	output						axim_wlast		,
	output						axim_wvalid		,
	output						axim_bready		,
	input						axim_awready	,
	input						axim_wready		,
	input	[ 1:0]				axim_bresp		,
	input	[P_AXI_IDWIDTH-1:0]	axim_bid		,
	input						axim_bvalid		,
	output						axim_arvalid	,
	input						axim_arready	,
	output	[31:0]				axim_araddr		,
	output	[ 2:0]				axim_arsize		,
	output	[P_AXI_IDWIDTH-1:0]	axim_arid		,
	output	[ 3:0]				axim_arlen		,
	output	[ 1:0]				axim_arburst	,
	output						axim_rready		,
	input						axim_rvalid		,
	input						axim_rlast		,
	input	[P_AXI_IDWIDTH-1:0]	axim_rid		,
	input	[63:0]				axim_rdata		,
	input	[ 1:0]				axim_rresp		
);

	assign	axim_awaddr[24: 0]	=	axis_awaddr[24:0]	;
	assign	axim_awaddr[31:25]	=	7'd1;

	assign	axim_araddr[24: 0]	=	axis_araddr[24:0]	;
	assign	axim_araddr[31:25]	=	7'd1;

	assign	axim_awlen		=	axis_awlen		;
	assign	axim_awsize		=	axis_awsize		;
	assign	axim_awburst	=	axis_awburst	;
	assign	axim_awid		=	axis_awid		;
	assign	axim_awvalid	=	axis_awvalid	;
	assign	axim_wid		=	axis_wid		;
	assign	axim_wdata		=	axis_wdata		;
	assign	axim_wstrb		=	axis_wstrb		;
	assign	axim_wlast		=	axis_wlast		;
	assign	axim_wvalid		=	axis_wvalid		;
	assign	axim_bready		=	axis_bready		;
	assign	axim_arvalid	=	axis_arvalid	;
	assign	axim_arsize		=	axis_arsize		;
	assign	axim_arid		=	axis_arid		;
	assign	axim_arlen		=	axis_arlen		;
	assign	axim_arburst	=	axis_arburst	;
	assign	axim_rready		=	axis_rready		;

	assign	axis_awready	=	axim_awready	;
	assign	axis_wready		=	axim_wready		;
	assign	axis_bresp		=	axim_bresp		;
	assign	axis_bid		=	axim_bid		;
	assign	axis_bvalid		=	axim_bvalid		;
	assign	axis_arready	=	axim_arready	;
	assign	axis_rvalid		=	axim_rvalid		;
	assign	axis_rlast		=	axim_rlast		;
	assign	axis_rid		=	axim_rid		;
	assign	axis_rdata		=	axim_rdata		;
	assign	axis_rresp		=	axim_rresp		;

endmodule
