//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : a module to improve bus timing - inserts FFs to address and 
//             : data paths
//----------------------------------------------------------------------------

module ahb_master_retime (
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
	output	reg	[31:0] 	ahb_mmst_hrdata			,
	output	reg			ahb_mmst_hready			,
	output	reg	[ 1:0]	ahb_mmst_hresp			,

	//AHB Master (master)
	output	reg	[31:0]	ahb_mst_haddr			,
	output	reg	[ 1:0]	ahb_mst_htrans	= 2'b00	,
	output	reg			ahb_mst_hwrite			,
	output	reg	[ 2:0]	ahb_mst_hsize			,
	output	reg	[ 2:0]	ahb_mst_hburst			,
	output	reg	[ 3:0]	ahb_mst_hprot			,
	output	reg	[31:0]	ahb_mst_hwdata			,
	output	reg			ahb_mst_hlock			,
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
	
	reg [2:0] cs = sIdle, ns;

	reg addr_enable, wdata_enable, trans_to_busy, trans_to_idle, rdata_enable, burst_ena = 0, nxt_burst_ena;

	
	always @(posedge hclk)
		if (~resetn) begin
			cs				<= sIdle;
			burst_ena		<= 0;
			ahb_mst_htrans	<= tIDLE;
		end else begin
			cs <= ns;
			burst_ena <= nxt_burst_ena;
			if (addr_enable) begin
				ahb_mst_htrans <= ahb_mmst_htrans ;
			end
			if (trans_to_idle) begin
				ahb_mst_htrans <= tIDLE;
			end
			if (trans_to_busy) begin
				ahb_mst_htrans <= tBUSY;
			end
		end
	
	always @(posedge hclk) begin
		if (addr_enable) begin
			ahb_mst_haddr  <= ahb_mmst_haddr  ;
			ahb_mst_hwrite <= ahb_mmst_hwrite ;
			ahb_mst_hsize  <= ahb_mmst_hsize  ;
			ahb_mst_hburst <= ahb_mmst_hburst ;
			ahb_mst_hprot  <= ahb_mmst_hprot  ;
			ahb_mst_hlock  <= ahb_mmst_hlock  ;
		end
		if (rdata_enable) begin
			ahb_mmst_hrdata <= ahb_mst_hrdata ;
			ahb_mmst_hresp  <= ahb_mst_hresp  ;
		end
		if (wdata_enable) begin
			ahb_mst_hwdata <= ahb_mmst_hwdata ;
		end
	end
	
	wire burst_end = (ahb_mst_htrans == tIDLE) | (ahb_mst_htrans == tNONSEQ);
	
	always @* begin
		ns <= cs;
		addr_enable		<= 0; 
		wdata_enable	<= 0; 
		rdata_enable	<= 0; 
		trans_to_busy	<= 0; 
		trans_to_idle	<= 0;
		ahb_mmst_hready <= 1;
		nxt_burst_ena   <= burst_ena;
		if ((ahb_mst_htrans != tIDLE) & (ahb_mst_htrans != tBUSY)) begin
			if (ahb_mst_hready) begin
				trans_to_idle <= burst_ena? burst_end : 1'b1;
				trans_to_busy <= burst_ena & ~burst_end;
			end
		end
		case (cs)
			sIdle: begin
				if ((ahb_mmst_htrans == tNONSEQ) | (ahb_mmst_htrans == tSEQ)) begin
					addr_enable	<= 1;
					nxt_burst_ena <= (ahb_mmst_hburst != tSINGLE);
					ns <= ahb_mmst_hwrite? sWrite : sRead;
				end
			end
			sWrite: begin
				ahb_mmst_hready <= 0;
				wdata_enable    <= 1; // correct would be to wait fo ahb_mst_hready, but shouldnt be a problem to present data ASAP since no other pending transaction on mst side
				ns              <= sWWait;
			end
			sWWait: begin
				ahb_mmst_hready <= 0;
				ns              <= ahb_mst_hready? sIdle : sWWait;
			end
			sRead: begin
				ahb_mmst_hready <= 0;
				ns              <= sRWait;
			end
			sRWait: begin
				ahb_mmst_hready <= 0;
				rdata_enable	<= 1;
				ns              <= ahb_mst_hready? sIdle : sRWait;
			end
		endcase
		
	end


endmodule

