//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Generic simple AHB Lite to Avalon MM module
//----------------------------------------------------------------------------

module amm2ahb (
	//Avalon MM interface (slave)
	input				aclk			,
	input				aresetn			, //synchronous active low reset
	input		[31:0]	amm_address		,
	input		[31:0]	amm_writedata	,
	input		[ 3:0]	amm_byteenable	,
	input				amm_write		,
	input				amm_read		,
	output		[31:0]	amm_readdata	,
	output				amm_waitrequest	,
	//AHB Lite interface (master)
	output		[31:0]	ahb_haddr		,
	output	reg	[ 2:0]	ahb_hsize		,
	output		[ 1:0]	ahb_htrans		,
	output		[31:0]	ahb_hwdata		,
	output				ahb_hwrite		,
	output		[ 2:0]	ahb_hburst		,
	input		[31:0]	ahb_hrdata		,
	input				ahb_hresp		,
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
	//localparam [2:0] tBYTE = 3'b100;	// 128 4-word line
	//localparam [2:0] tBYTE = 3'b101;	// 256 8-word line
	//localparam [2:0] tBYTE = 3'b110;	// 512 -
	//localparam [2:0] tBYTE = 3'b111;	// 1024 -

	
	reg exec = 0;
	
	assign ahb_haddr = amm_address	;
	assign ahb_hwrite= amm_write	;
	assign amm_waitrequest = exec? ~ahb_hready : 1'b1;
	assign ahb_htrans= exec? tIDLE : (amm_write|amm_read)? tNONSEQ : tIDLE	;
	assign ahb_hwdata= amm_writedata;
	assign amm_readdata = ahb_hrdata;
	assign ahb_hburst = tSINGLE;
	
	always @(posedge aclk)
		if (~aresetn) begin
			exec <= 1'b0;
		end else begin
			exec <= exec? ~ahb_hready : (amm_write | amm_read);
		end
	
	always @* begin
		ahb_hsize <= tWORD;
		case (amm_byteenable)
			4'b0001, 4'b0010, 4'b0100, 4'b1000 : ahb_hsize <= tBYTE;
			4'b1100, 4'b0011 : ahb_hsize <= tHWORD;
			default: ahb_hsize <= tWORD;
		endcase
	end
	
		
endmodule


//FIXME: this module does not work properly when single clock and amm side is 0 waitstates
module amm2ahb_rv #(parameter P_AHB_2X_CLK = 0) (
	//Avalon MM interface (slave)
	input				aclk_2x					,
	input				aclk					,
	input				aresetn					, //synchronous active low reset
	input		[31:0]	amm_address				,
	input		[31:0]	amm_writedata			,
	input		[ 3:0]	amm_byteenable			,
	input				amm_write				,
	input				amm_read				,
	output	reg	[31:0]	amm_readdata			,
	output	reg			amm_readdatavalid	= 0	,
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

	reg [31:0] ahb_hrdata_r;
	
	wire falling;
	wire ahb_clk = P_AHB_2X_CLK? aclk_2x : aclk;
	reg [1:0] ahb_addr_lsb;
	reg tr_act = 0;
	reg tr_rack= 0;
	
	reg tr_wrack  = 0;
	reg tr_wract = 0;
	
	
	clk_sync_phase #(P_AHB_2X_CLK == 0) i_clk_sync_phase (
		.clk		(	aclk		),
		.clk_2x		(	aclk_2x		),
		.falling	(	falling		),
		.sync		(				) // this output indicates if synchronization error happened
	);
	
	assign ahb_haddr = {amm_address[31:2],ahb_addr_lsb};
	assign ahb_hwrite = amm_write;
	assign ahb_hburst = 0;
	assign amm_waitrequest = P_AHB_2X_CLK? amm_write? ~tr_wrack :  ~(tr_rack | (ahb_htrans[1] & ~ahb_hwrite))  : tr_act? ~ahb_hready : 1'b0;
	
	//assign amm_readdata = (tr_act | (P_AHB_2X_CLK == 0))? ahb_hrdata : ahb_hrdata_r;
	//assign amm_readdatavalid = (tr_act | (P_AHB_2X_CLK == 0))? ahb_hready & tr_read & ~falling & (P_AHB_2X_CLK? ~tr_ack : 1'b1): (tr_read1 | tr_read);
	
	assign ahb_htrans = ((amm_write | amm_read) & (falling | (P_AHB_2X_CLK == 0)) & (~tr_act | (tr_act & ahb_hready & ~tr_wrack)))? tNONSEQ : tIDLE;
	
	always @* begin
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
	
	
	always @(posedge ahb_clk)
		if ((tr_act & ~tr_wrack) & ahb_hready)
			amm_readdata <= ahb_hrdata;
	
	always @(posedge ahb_clk or negedge aresetn)
		if (~aresetn) begin
			tr_act <= 0;
			ahb_hwdata <= 0;
			ahb_hrdata_r <= 0;
			tr_wrack  <= 0;
			tr_wract  <= 0;
			tr_rack   <= 0;
			
			amm_readdatavalid <= 0;

		end else begin
			tr_rack <= tr_rack? 0 : ahb_htrans[1] & falling & ~ahb_hwrite;// used to acknowledge the amm command for reads
			tr_act <= tr_act? ahb_hready? ahb_htrans[1] : 1'b1 : ahb_htrans[1];
			tr_wrack <= tr_wrack? (P_AHB_2X_CLK? ~falling : 0) : ahb_htrans[1] & ahb_hwrite;
			tr_wract <= tr_wract? ahb_hready? ahb_htrans[1] & ahb_hwrite : 1'b1 : ahb_htrans[1] & ahb_hwrite;
			
			amm_readdatavalid <= amm_readdatavalid? falling : (tr_act & ~tr_wract) & ahb_hready;
			
			if (ahb_htrans[1] & ahb_hwrite)
				ahb_hwdata <= amm_writedata;
			if (ahb_hready & tr_act)
				ahb_hrdata_r <= ahb_hrdata;
			
		end
	

	
endmodule


// improved timing amm2ahb module for slow clock to fast clock transition
module amm2ahb_rv_dc (
	//Avalon MM interface (slave)
	input				aclk_2x					,
	input				aclk					,
	input				aresetn					, //asynchronous active low reset
	input				sresetn					, //synchronous active low reset
	input		[31:0]	amm_address				,
	input		[31:0]	amm_writedata			,
	input		[ 3:0]	amm_byteenable			,
	input				amm_write				,
	input				amm_read				,
	output	reg	[31:0]	amm_readdata			,
	output	reg			amm_readdatavalid	= 0	,
	output				amm_waitrequest			,
	//AHB Lite interface (master)
	output	reg	[31:0]	ahb_haddr				,
	output	reg	[ 2:0]	ahb_hsize				,
	output	reg	[ 1:0]	ahb_htrans				,
	output	reg	[31:0]	ahb_hwdata				,
	output	reg			ahb_hwrite				,
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

	reg [31:0] ahb_hrdata_r;
	
	wire falling;
	reg [1:0] ahb_addr_lsb;
	reg tr_act = 0;
	reg tr_act_d = 0;
	reg resp_phase = 0;
	reg [2:0] ahb_hsize_i;
	wire latch_addr;
	
	
	clk_sync_phase #(0) i_clk_sync_phase (
		.clk		(	aclk		),
		.clk_2x		(	aclk_2x		),
		.falling	(	falling		),
		.sync		(				) // this output indicates if synchronization error happened
	);
	

	assign ahb_hburst = tSINGLE;
	assign latch_addr = tr_act? 0 : (amm_read | amm_write);
	
	assign amm_waitrequest = tr_act & ~tr_act_d;
	
	always @* begin
		case (amm_byteenable)
			4'b0001: begin
				ahb_hsize_i = tBYTE;
				ahb_addr_lsb = 2'b00;
			end
			4'b0010: begin
				ahb_hsize_i = tBYTE;
				ahb_addr_lsb = 2'b01;
			end
			4'b0100: begin
				ahb_hsize_i = tBYTE;
				ahb_addr_lsb = 2'b10;
			end
			4'b1000: begin
				ahb_hsize_i = tBYTE;
				ahb_addr_lsb = 2'b11;
			end
			4'b0011: begin
				ahb_hsize_i = tHWORD;
				ahb_addr_lsb = 2'b00;
			end
			4'b1100: begin
				ahb_hsize_i = tHWORD;
				ahb_addr_lsb = 2'b10;
			end
			default: begin
				ahb_hsize_i = tWORD;
				ahb_addr_lsb = 2'b00;
			end
		endcase
	end
	
	
	always @(posedge aclk_2x) begin
		if (latch_addr) begin
			ahb_haddr <= {amm_address[31:2],ahb_addr_lsb};
			ahb_hwdata<= amm_writedata;
			ahb_hsize <= ahb_hsize_i;
			ahb_hwrite<= amm_write;
		end
		if (resp_phase & ahb_hready & ~ahb_hwrite)
			amm_readdata <= ahb_hrdata;
	end
	
	always @(posedge aclk_2x or negedge aresetn)
		if (~aresetn | ~sresetn) begin
			ahb_htrans <= tIDLE;
			amm_readdatavalid <= 0;
			tr_act <= 0;
			tr_act_d <= 0;
			resp_phase <= 0;
		end else begin
			tr_act_d <= 0;
			if ((amm_read | amm_write) & falling & ~tr_act)
				tr_act_d <= 1'b1;
			ahb_htrans <= tIDLE;
			if (latch_addr)
				ahb_htrans <= tNONSEQ;
				
			tr_act <= tr_act? ahb_htrans[1]? tr_act : ~ahb_hready : latch_addr;
			resp_phase <= resp_phase? ~ahb_hready : ahb_htrans[1] & tr_act;
				
			amm_readdatavalid <= amm_readdatavalid? falling : (resp_phase & ahb_hready & ~ahb_hwrite);
		end
	

	
endmodule
