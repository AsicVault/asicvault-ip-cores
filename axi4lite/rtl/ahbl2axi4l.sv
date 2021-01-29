//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : AHB-Lite to AXI4-Lite bridge
//-----------------------------------------------------------------------------

module ahbl2axi4l (
	//AHBLite (slave)
	input				aclk		,
	input           	aresetn     ,
	input 		[31:0]	ahb_haddr	,
	input 		[ 1:0]	ahb_hsize	,
	input 		[ 1:0]	ahb_htrans	,
	input 		[31:0]	ahb_hwdata	,
	input 	    		ahb_hwrite	,
	output		[31:0] 	ahb_hrdata	,
	output reg    		ahb_hresp	,
	output reg    		ahb_hready	,
	//AXI4Lite interface (master)
	output		[31:0]	axi_awaddr	,
	output	reg			axi_awvalid	,
	input				axi_awready	,
	output		[31:0]	axi_wdata	,
	output	reg	[ 3:0]	axi_wstrb	,
	output	reg			axi_wvalid	,
	input				axi_wready	,
	output	reg			axi_bready	,
	input				axi_bvalid	,
	input		[ 1:0]	axi_bresp	, // write response is ignored
	output		[31:0]	axi_araddr	,
	output	reg	[ 2:0]	axi_arsize	,
	output	reg			axi_arvalid	,
	input				axi_arready	,
	input		[31:0]	axi_rdata	,
	input		[ 1:0]	axi_rresp	, //read response - passed over to AHB
	input				axi_rvalid	,
	output	reg			axi_rready	
);

	reg [31:0] addr;
	assign axi_awaddr = addr;
	assign axi_araddr = addr;
	assign axi_wdata = ahb_hwdata;
	assign ahb_hrdata = axi_rdata;
	
	
	typedef enum int {sIdle, sWriteA, sWriteD, sWriteR, sReadA, sReadD} states_t;
	states_t cs, ns;
	
	reg [3:0] wstrb;
	reg l_addr;
	
	always @(posedge aclk)
		if (~aresetn) begin
			cs <= sIdle;
			axi_wstrb <= 4'b1111;
			addr <= 0;
		end else begin
			cs <= ns;
			if (l_addr) begin
				axi_wstrb <= wstrb;
				addr <= ahb_haddr;
			end
		end
	
	always @* begin
		ns <= sIdle;
		axi_awvalid <= 1'b0;
		axi_wvalid  <= 1'b0;
		axi_bready  <= 1'b0;
		ahb_hready  <= 1'b1;
		ahb_hresp   <= 1'b0;
		axi_arvalid <= 1'b0;
		axi_rready  <= 1'b0;
		l_addr <= 0;
		case (cs)
			sIdle: begin
				if ((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) begin
					l_addr <= 1'b1;
					ns <= ahb_hwrite? sWriteA : sReadA;
				end
			end
			sWriteA: begin
				ns 			<= sWriteA;
				ahb_hready  <= 1'b0;
				axi_awvalid <= 1'b1;
				axi_wvalid  <= 1'b1;
				axi_bready  <= 1'b1;
				if (axi_awready) begin
					ns <= sWriteD;
					if (axi_wready) begin
						ns <= sWriteR;
						if (axi_bvalid) begin
							ahb_hready <= 1'b1;
							ns <= sIdle;
							if ((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) begin
								l_addr <= 1'b1;
								ns <= ahb_hwrite? sWriteA : sReadA;
							end
						end
					end
				end
			end
			sWriteD: begin
				ns 			<= sWriteD;
				axi_wvalid  <= 1'b1;
				axi_bready  <= 1'b1;
				ahb_hready  <= 1'b0;
				if (axi_wready) begin
					ns <= sWriteR;
					ahb_hready  <= 1'b1;
					if (axi_bvalid) begin
						ns <= sIdle;
						if ((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) begin
							l_addr <= 1'b1;
							ns <= ahb_hwrite? sWriteA : sReadA;
						end
					end
				end
			end
			sWriteR: begin
				ns 			<= sWriteR;
				axi_bready  <= 1'b1;
				ahb_hready  <= 1'b0;
				if (axi_bvalid) begin
					ns <= sIdle;
					if ((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) begin
						ahb_hready  <= 1'b1;
						l_addr <= 1'b1;
						ns <= ahb_hwrite? sWriteA : sReadA;
					end
				end
			end
			sReadA : begin
				ns <= sReadA;
				axi_arvalid <= 1'b1;
				axi_rready  <= 1'b1;
				ahb_hready  <= 1'b0;
				if (axi_arready)
					ns <= sReadD;
				if (axi_rvalid) begin
					ns <= sIdle;
					ahb_hready  <= 1'b1;
					ahb_hresp <= axi_rresp[1]; // OKAY=0, EXOKAY=1, SLVERR=2, and DECERR=3
					if ((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) begin
						l_addr <= 1'b1;
						ns <= ahb_hwrite? sWriteA : sReadA;
					end
				end
			end
			sReadD: begin
				ns <= sReadD;
				axi_rready  <= 1'b1;
				ahb_hready  <= 1'b0;
				if (axi_rvalid) begin
					ns <= sIdle;
					ahb_hready <= 1'b1;
					ahb_hresp <= axi_rresp[1]; // OKAY=0, EXOKAY=1, SLVERR=2, and DECERR=3
					if ((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) begin
						l_addr <= 1'b1;
						ns <= ahb_hwrite? sWriteA : sReadA;
					end
				end
			end
		endcase
	end

	// hsize to wr strobe translation
	always @* begin
		case (ahb_hsize)
			2'b00: wstrb <= 4'd1 << ahb_haddr[1:0];
			2'b01: wstrb <= ahb_haddr[1]? 4'hC:4'h3;
			default: wstrb <= 4'b1111;
		endcase
	end
	

endmodule
