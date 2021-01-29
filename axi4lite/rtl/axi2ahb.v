//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Generic simple AXI4 Lite to AHB Lite
//----------------------------------------------------------------------------

module axi2ahb (
	//AHB Interface (master)
	input						clk				,
	input						reset			, //synchronous active high reset
	output 	reg	[31:0]			ahb_haddr		,
	output 	reg	[ 1:0]			ahb_hsize		,
	output 	reg	[ 1:0]			ahb_htrans		,
	output 	reg	[31:0]			ahb_hwdata		,
	output	reg					ahb_hwrite		,
	input		[31:0] 			ahb_hrdata		,
	input						ahb_hresp		,
	input						ahb_hready		,

	//AXI4Lite interface (slave)
	input	[   32-1:0]			axi_awaddr	,
	input						axi_awvalid	,
	output	reg					axi_awready	,
	input	[4*8-1:0]			axi_wdata	,
	input	[  4-1:0]			axi_wstrb	,
	input						axi_wvalid	,
	input						axi_bready	,
	output	reg					axi_bvalid	= 0,
	output	[			1:0]	axi_bresp	,
	output	reg					axi_wready	,
	input	[   32-1:0]			axi_araddr	,
	input	[           2:0]	axi_arsize	,
	input						axi_arvalid	,
	output	reg					axi_arready	,
	output	reg [4*8-1:0]		axi_rdata	,
	output	[           1:0]	axi_rresp	, //tied to valid response
	output	reg					axi_rvalid	= 0,
	input						axi_rready	
);
	parameter P_USE_ARSIZE = 1;
	
	assign axi_rresp  = 2'b00;
	assign axi_bresp  = 2'b00; //always OK response to writes
	
	reg axi_bvalid_nxt, axi_rvalid_nxt;
	
	
	typedef enum int {s_reset, s_idle, s_waddr1, s_waddr, s_write, s_raddr, s_read} state_t;
	state_t cs, ns;
	
	always @(posedge clk)
		if (reset) begin
			cs			<= s_reset;
			axi_bvalid	<= 1'b0;
			axi_rvalid  <= 1'b0;
		end else begin
			cs <= ns;
			axi_bvalid	<= axi_bvalid_nxt; 
			axi_rvalid	<= axi_rvalid_nxt;
		end

	always @(posedge clk) begin
		if (axi_awready | axi_arready) begin
			ahb_haddr <= axi_awready? axi_awaddr : axi_araddr;
			ahb_hsize <= P_USE_ARSIZE? axi_arsize[1:0] : 2'b10;
		end
		if (axi_wready & axi_wvalid) begin
			case (axi_wstrb)
				4'b0001: ahb_hwdata <= {4{axi_wdata[ 7: 0]}};
				4'b0010: ahb_hwdata <= {4{axi_wdata[15: 8]}};
				4'b0100: ahb_hwdata <= {4{axi_wdata[23:16]}};
				4'b1000: ahb_hwdata <= {4{axi_wdata[31:24]}};
				4'b0011: ahb_hwdata <= {2{axi_wdata[15: 0]}};
				4'b1100: ahb_hwdata <= {2{axi_wdata[31:16]}};
				default: ahb_hwdata <= axi_wdata;
			endcase
			case (axi_wstrb)
				4'b0001: ahb_hsize <= 2'b00;
				4'b0010: ahb_hsize <= 2'b00;
				4'b0100: ahb_hsize <= 2'b00;
				4'b1000: ahb_hsize <= 2'b00;
				4'b0011: ahb_hsize <= 2'b01;
				4'b1100: ahb_hsize <= 2'b01;
				default: ahb_hsize <= 2'b10;
			endcase
		end
		if (ahb_hready & ~axi_rvalid)
			axi_rdata <= ahb_hrdata;
	end
		
	always @*
		begin
			ns				<= cs; 
			axi_awready		<= 1'b0 ; 
			axi_wready      <= 1'b0 ; 
			axi_arready		<= 1'b0 ;
			axi_bvalid_nxt	<= axi_bvalid? ~axi_bready : 1'b0 ; 
			axi_rvalid_nxt	<= axi_rvalid? ~axi_rready : 1'b0 ;
			ahb_htrans      <= 2'b00;
			ahb_hwrite      <= 1'b0 ; 
			case (cs)
				s_reset: begin
					ns <= s_idle;
				end
				s_idle: begin
					axi_awready <= 1'b1;
					axi_arready <= 1'b1;
					axi_wready  <= 1'b1;
					if (axi_awvalid) begin
						ns <= axi_wvalid? s_waddr : s_waddr1;
					end else if (axi_arvalid) begin
						ns <= s_raddr;
					end
				end
				s_waddr1: begin // wait for wdata from AXI as we need the data size for AHB command
						axi_wready		<= 1'b1; 
						if (axi_wvalid) 
							ns <= s_waddr;
				end
				s_waddr: begin // wait for wdata from AXI and execute a command on AHB if data available
						ahb_htrans		<= 2'b10;
						axi_bvalid_nxt	<= ahb_hready;
						ahb_hwrite		<= 1'b1;
						if (ahb_hready) 
							ns <= s_write;
				end
				s_write: begin // data phase on AHB, also accept any new command from AXI when ready
					axi_awready <= ahb_hready;
					axi_arready <= ahb_hready;
					axi_wready  <= ahb_hready;
					if (ahb_hready) begin
						ns <= s_idle;
						if (axi_awvalid) begin
							ns <= axi_wvalid? s_waddr : s_waddr1;
						end else if (axi_arvalid) begin
							ns <= s_raddr;
						end	
					end
				end
				s_raddr: begin // execute read on AHB
					ahb_htrans <= 2'b10;
					if (ahb_hready) begin
						ns <= s_read;
					end
				end
				s_read: begin
					axi_awready <= ahb_hready;
					axi_arready <= ahb_hready;
					axi_wready  <= ahb_hready;
					if (ahb_hready) begin
						ns <= s_idle;
						if (axi_awvalid) begin
							ns <= axi_wvalid? s_waddr : s_waddr1;
						end else if (axi_arvalid) begin
							ns <= s_raddr;
						end	
					end
				end
			endcase
		end
		
endmodule
