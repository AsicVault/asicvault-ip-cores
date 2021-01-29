//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : this module enables 2-cycle multicycle from input 
//             : ahb_mmst_haddr and ahb_mst_hwrite
//----------------------------------------------------------------------------

module ahb_master_multicycle (
	input				hclk					,
	input				resetn					, //synchronous active low reset
	//AHB Mirrored Master (slave)
	input		[31:0]	ahb_mmst_haddr			,
	input		[ 1:0]	ahb_mmst_htrans			,
	input				ahb_mmst_hwrite			,
	input		[ 2:0]	ahb_mmst_hsize			,
	input		[ 2:0]	ahb_mmst_hburst			,
	input		[ 3:0]	ahb_mmst_hprot			,
	input		[31:0]	ahb_mmst_hwdata			,
	input				ahb_mmst_hlock			,
	output		[31:0] 	ahb_mmst_hrdata			,
	output				ahb_mmst_hready			,
	output		[ 1:0]	ahb_mmst_hresp			,

	//AHB Master (master)
	output		[31:0]	ahb_mst_haddr			,
	output	reg	[ 1:0]	ahb_mst_htrans	= 2'b00	,
	output				ahb_mst_hwrite			,
	output		[ 2:0]	ahb_mst_hsize			,
	output		[ 2:0]	ahb_mst_hburst			,
	output		[ 3:0]	ahb_mst_hprot			,
	output		[31:0]	ahb_mst_hwdata			,
	output				ahb_mst_hlock			,
	input		[31:0] 	ahb_mst_hrdata			,
	input				ahb_mst_hready			,
	input		[ 1:0]	ahb_mst_hresp			
);

	localparam [1:0] tIDLE		= 2'b00	; 
	localparam [1:0] tBUSY		= 2'b01	; 
	localparam [1:0] tNONSEQ	= 2'b10	; 
	localparam [1:0] tSEQ		= 2'b11	;
	
	localparam [2:0] tSINGLE	= 3'b000;
	localparam [2:0] tINCR		= 3'b001;
	localparam [2:0] tWRAP4		= 3'b010;
	localparam [2:0] tINCR4		= 3'b011;
	localparam [2:0] tWRAP8		= 3'b100;
	localparam [2:0] tINCR8		= 3'b101;
	localparam [2:0] tWRAP16	= 3'b110;
	localparam [2:0] tINCR16	= 3'b111;
	
	localparam [2:0] sIdle	= 3'b000	;
	localparam [2:0] sWrite	= 3'b001	;
	localparam [2:0] sRead	= 3'b101	;
	localparam [2:0] sWWait	= 3'b011	;
	localparam [2:0] sRWait	= 3'b111	;

	assign ahb_mst_haddr   = ahb_mmst_haddr	;
	assign ahb_mst_hwrite  = ahb_mmst_hwrite;
	assign ahb_mst_hsize   = ahb_mmst_hsize	;
	assign ahb_mst_hburst  = ahb_mmst_hburst;
	assign ahb_mst_hprot   = ahb_mmst_hprot	;
	assign ahb_mst_hwdata  = ahb_mmst_hwdata;
	assign ahb_mst_hlock   = ahb_mmst_hlock	;
	assign ahb_mmst_hrdata = ahb_mst_hrdata	;
	assign ahb_mmst_hresp  = ahb_mst_hresp	;
	
	always @(posedge hclk)
		if (~resetn) begin
			ahb_mst_htrans	<= tIDLE;
		end else begin
			if (ahb_mst_htrans == 2'b00) begin
				ahb_mst_htrans <= ahb_mmst_htrans;
			end else begin
				if (ahb_mst_hready)
					ahb_mst_htrans <= 2'b00;
			end
		end

	assign ahb_mmst_hready = (ahb_mst_htrans == 2'b00)? 1'b0 : ahb_mst_hready;
		
endmodule

