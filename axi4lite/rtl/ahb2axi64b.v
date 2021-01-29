//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : simple AHB to AXI access bridge for MDDR interface debug
//-----------------------------------------------------------------------------

module ahb2axi64b #(
	parameter P_AXI_IDWIDTH = 5,
	parameter [31:0] P_ADDRESS_MASK = 32'hFFFFFFFF,
	parameter [31:0] P_ADDRESS_BASE = 32'h00000000
	
)(
	input						clk				,
	input						aresetn			,
	// AHB slave interface
	input		[31:0]			ahb_haddr		,
	input		[ 1:0]			ahb_hsize		,
	input		[ 1:0]			ahb_htrans		,
	input		[31:0]			ahb_hwdata		,
	input						ahb_hwrite		,
	input						ahb_hready		,
	input						ahb_hselx		,
	output	reg	[31:0]			ahb_hrdata	= 0	,
	output						ahb_hresp		,
	output						ahb_hreadyout	,
	
	// AXI Master inetrface - output
	output	reg [31:0]			axim_awaddr	=0	,
	output	[ 7:0]				axim_awlen		,
	output	[ 2:0]				axim_awsize		,
	output	[ 1:0]				axim_awburst	,
	output	[P_AXI_IDWIDTH-1:0]	axim_awid		,
	output	reg					axim_awvalid =0	,
	input						axim_awready	,
	
	output	[P_AXI_IDWIDTH-1:0]	axim_wid		,
	output	reg [63:0]			axim_wdata	=0	,
	output	reg [ 7:0]			axim_wstrb	=0	,
	output						axim_wlast		,
	output	reg					axim_wvalid	=0	,
	input						axim_wready		,

	input	[P_AXI_IDWIDTH-1:0]	axim_bid		,
	input	[ 1:0]				axim_bresp		,
	input						axim_bvalid		,
	output	reg					axim_bready	= 0	,
	
	output	[P_AXI_IDWIDTH-1:0]	axim_arid		,
	output	[31:0]				axim_araddr		,
	output	[ 3:0]				axim_arlen		,
	output	[ 2:0]				axim_arsize		,
	output	[ 1:0]				axim_arburst	,
	output	reg					axim_arvalid = 0,
	input						axim_arready	,
	
	input	[P_AXI_IDWIDTH-1:0]	axim_rid		,
	input	[63:0]				axim_rdata		,
	input	[ 1:0]				axim_rresp		,
	input						axim_rlast		,
	input						axim_rvalid		,
	output	reg					axim_rready	=0	
);



	assign	axim_araddr			=	axim_awaddr;
	assign	axim_arlen			=	0;
	assign	axim_arsize			=	3'd3; // 64-bit transfers only
	assign	axim_arburst		=	2'd1; // incrementing burst
	assign	axim_arid			=	0;

	assign	axim_awlen			=	0;
	assign	axim_awsize			=	3'd3; // 64-bit transfers only
	assign	axim_awburst		=	2'd1; // incrementing burst
	assign	axim_awid			=	0;
	assign	axim_wid			=	0;
	assign	axim_wlast			=	1'b1;
	
	assign ahb_hresp = 0;
	reg wr_active = 0;
	reg rd_active = 0;
	reg wr_init = 0;
	
	assign ahb_hreadyout = ~((wr_active | wr_init) | rd_active);
	
	always @(posedge clk or negedge aresetn)
		if (~aresetn) begin
			axim_awaddr <= 0;
			axim_awvalid<= 0;
			axim_wdata  <= 0;
			axim_wstrb  <= 0;
			axim_wvalid <= 0;
			axim_arvalid<= 0;
			axim_rready <= 0;
			wr_active <= 0;
			rd_active <= 0;
			wr_init <= 0;
			ahb_hrdata <= 0;
			axim_bready <= 0;
		end else begin
			if (ahb_hselx & ahb_hready & ahb_htrans[1]) begin
				axim_awaddr <= ahb_haddr & P_ADDRESS_MASK | P_ADDRESS_BASE;
				if (ahb_hwrite) begin
					axim_awvalid <= 1'b1;
					wr_init <= 1'b1;
					axim_wstrb <= {{4{ahb_haddr[2]}},{4{~ahb_haddr[2]}}};
				end else begin
					axim_arvalid <= 1'b1;
					rd_active    <= 1'b1;
				end
			end
			if (wr_init) begin
				wr_init <= 0;
				axim_wvalid <= 1'b1;
				axim_wdata <= {ahb_hwdata,ahb_hwdata};
				wr_active <= 1'b1;
			end
			if (axim_awvalid & axim_awready)
				axim_awvalid <= 1'b0;
			if (axim_wvalid & ~axim_bready)
				axim_bready <= 1'b1;
			if (axim_wvalid & axim_wready)
				axim_wvalid <= 1'b0;
			if (axim_arvalid & axim_arready)
				axim_arvalid <= 1'b0;
			if (axim_arvalid & ~axim_rready)
				axim_rready <= 1'b1;
			if (axim_bready & axim_bvalid) begin
				wr_active   <= 1'b0;
				axim_bready <= 1'b0;
			end
			if (axim_rready & axim_rvalid) begin
				axim_rready <= 1'b0;
				rd_active <= 0;
				ahb_hrdata <= axim_awaddr[2]? axim_rdata[63:32] : axim_rdata[31:0];
			end
		end
	
endmodule

