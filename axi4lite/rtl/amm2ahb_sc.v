//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Generic simple AHB Lite to Avalon MM with readdata valid
//----------------------------------------------------------------------------


module amm2ahb_rv_sc (
	//Avalon MM interface (slave)
	input				aclk					,
	input				aresetn					, //asynchronous active low reset
	input				sresetn					, //synchronous active low reset
	input		[31:0]	amm_address				,
	input		[31:0]	amm_writedata			,
	input		[ 3:0]	amm_byteenable			,
	input				amm_write				,
	input				amm_read				,
	output		[31:0]	amm_readdata			,
	output				amm_readdatavalid		,
	output				amm_waitrequest			,
	//AHB Lite interface (master)
	output		[31:0]	ahb_haddr				,
	output	reg	[ 2:0]	ahb_hsize				,
	output		[ 1:0]	ahb_htrans				,
	output	reg	[31:0]	ahb_hwdata				,
	output				ahb_hwrite				,
	output		[ 2:0]	ahb_hburst				,
	input		[31:0]	ahb_hrdata				,
	input				ahb_hresp				,
	input 				ahb_hready				
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

	localparam [2:0] tBYTE  = 3'b000;	// 8 Byte
	localparam [2:0] tHWORD = 3'b001;	// 16 Halfword
	localparam [2:0] tWORD  = 3'b010;	// 32 Word
	localparam [2:0] tDWORD = 3'b011;	// 64 Doubleword

	
	reg [1:0] ahb_addr_lsb;
	reg active = 0, active_nxt;
	reg ractive = 0, ractive_nxt;
	reg latch_wdata;
	
	assign ahb_haddr = {amm_address[31:2],ahb_addr_lsb};
	assign ahb_hwrite = amm_write;
	assign ahb_hburst = tSINGLE;
	assign amm_waitrequest = active? ~ahb_hready : 1'b0;
	assign amm_readdata = ahb_hrdata;
	assign amm_readdatavalid = ractive & ahb_hready;
	
	assign ahb_htrans = active? (ahb_hready & (amm_write | amm_read))? tNONSEQ : tIDLE : (amm_write | amm_read)? tNONSEQ : tIDLE;
	
	always @* begin
		active_nxt <= 0;
		ractive_nxt <= 0;
		latch_wdata <= (amm_write & ~amm_waitrequest);
		active_nxt <= active? (ahb_hready? ahb_htrans[1] : active) : ahb_htrans[1];
		ractive_nxt <= active? (ahb_hready? amm_read : ractive) : amm_read;
		
		case (amm_byteenable)
			4'b0001: begin
				ahb_hsize = tBYTE;
				ahb_addr_lsb = 2'b00;
			end
			4'b0010: begin
				ahb_hsize = tBYTE;
				ahb_addr_lsb = 2'b01;
			end
			4'b0100: begin
				ahb_hsize = tBYTE;
				ahb_addr_lsb = 2'b10;
			end
			4'b1000: begin
				ahb_hsize = tBYTE;
				ahb_addr_lsb = 2'b11;
			end
			4'b0011: begin
				ahb_hsize = tHWORD;
				ahb_addr_lsb = 2'b00;
			end
			4'b1100: begin
				ahb_hsize = tHWORD;
				ahb_addr_lsb = 2'b10;
			end
			default: begin
				ahb_hsize = tWORD;
				ahb_addr_lsb = 2'b00;
			end
		endcase
	end
	
	
	
	always @(posedge aclk)
		if (latch_wdata)
			ahb_hwdata <= amm_writedata;
	
	always @(posedge aclk or negedge aresetn)
		if (~aresetn | ~sresetn) begin
			active <= 0;
			ractive <= 0;
		end else begin
			active <= active_nxt;
			ractive <= ractive_nxt;
		end
	

	
endmodule

