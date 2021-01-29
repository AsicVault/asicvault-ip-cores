//-----------------------------------------------------------------------------
// Copyright (c) 2017 AsicVault OU
//
// Author      : Rain Adelbert
// Description : Generic simple AHB Lite to Avalon MM module
//----------------------------------------------------------------------------

module ahb2amm #(
	parameter P_2X_CLOCK = 0 // set this to 1 when AHB bus has 2x slower (synchronous) clock compared to AMM interface
)(
	//Avalon MM interface (master)
	input				aclk			,
	input				aresetn			, //synchronous active low reset
	output	reg [31:0]	amm_address		,
	output		[31:0]	amm_writedata	,
	output	reg [ 3:0]	amm_byteenable	,
	output	reg			amm_write		,
	output	reg			amm_read		,
	input		[31:0]	amm_readdata	,
	input				amm_waitrequest	,
	//AHB Lite interface (slave interface)
	input		[31:0]	ahb_haddr		,
	input		[ 2:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output		[31:0]	ahb_hrdata		,
	output				ahb_hresp		,
	output reg			ahb_hreadyout	
);

	localparam [1:0] sIdle  = 2'b00;
	localparam [1:0] sWrite = 2'b01;
	localparam [1:0] sRead  = 2'b10;
	
	reg cphase = 0;
	wire phase = P_2X_CLOCK? cphase : 1'b0;
	
	assign amm_writedata = ahb_hwdata;
	assign ahb_hrdata    = amm_readdata;
	assign ahb_hresp     = 1'b0;
	
	//typedef enum int {sIdle, sWrite, sRead} states_t;
	reg [1:0] cs = sIdle, ns;
	
	reg [3:0] wstrb;
	reg l_addr;
	
	// hsize to wr strobe translation
	always @* begin
		case (ahb_hsize)
			3'b000: wstrb <= 4'd1 << ahb_haddr[1:0];
			3'b001: wstrb <= ahb_haddr[1]? 4'hC:4'h3;
			default: wstrb <= 4'b1111;
		endcase
	end

	always @(posedge aclk)
		if (~aresetn) begin
			cs				<= sIdle;
			amm_address		<= 0;
			amm_byteenable	<= 1'b0;
			cphase			<= 1'b0;
		end else begin
			cphase <= ~cphase;
			cs <= ns;
			if (l_addr) begin
				amm_address		<= ahb_haddr;
				amm_byteenable	<= wstrb; 
			end
		end

	always @* begin
		ns				<= sIdle;
		ahb_hreadyout	<= 1'b1;
		amm_write		<= 1'b0;
		amm_read		<= 1'b0;
		l_addr			<= 1'b0;
		case (cs)
			sIdle: begin
				if (((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) & ahb_hready & ahb_hselx & ~phase) begin
					l_addr <= 1'b1;
					ns <= ahb_hwrite? sWrite : sRead;
				end
			end
			sWrite: begin
				ns 			<= sWrite;
				ahb_hreadyout	<= 1'b0;
				amm_write 	<= 1'b1;
				if (~amm_waitrequest) begin
					ahb_hreadyout	<= 1'b1;
					ns				<= sIdle;
					if (((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) & ahb_hready & ahb_hselx & ~phase) begin
						l_addr <= 1'b1;
						ns <= ahb_hwrite? sWrite : sRead;
					end
				end
			end
			sRead: begin
				ns				<= sRead;
				ahb_hreadyout	<= 1'b0;
				amm_read 		<= 1'b1;
				if (~amm_waitrequest) begin
					ahb_hreadyout	<= 1'b1;
					ns				<= sIdle;
					if (((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) & ahb_hready & ahb_hselx & ~phase) begin
						l_addr <= 1'b1;
						ns <= ahb_hwrite? sWrite : sRead;
					end
				end
			end
		endcase
	end
		
endmodule



//ahb2amm module with improved read data timing

module ahb2amm_d1 (
	//Avalon MM interface (master)
	input				aclk			,
	input				aresetn			, //synchronous active low reset
	output	reg [31:0]	amm_address		,
	output		[31:0]	amm_writedata	,
	output	reg [ 3:0]	amm_byteenable	,
	output	reg			amm_write		,
	output	reg			amm_read		,
	input		[31:0]	amm_readdata	,
	input				amm_waitrequest	,
	//AHB Lite interface (slave interface)
	input		[31:0]	ahb_haddr		,
	input		[ 2:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output	reg	[31:0]	ahb_hrdata		,
	output				ahb_hresp		,
	output reg			ahb_hreadyout	
);

	localparam [1:0] sIdle  = 2'b00;
	localparam [1:0] sWrite = 2'b01;
	localparam [1:0] sRead  = 2'b10;
	localparam [1:0] sAck   = 2'b11;
	

	assign amm_writedata = ahb_hwdata;
	//assign ahb_hrdata    = amm_readdata;
	assign ahb_hresp     = 1'b0;
	
	//typedef enum int {sIdle, sWrite, sRead} states_t;
	reg [1:0] cs = sIdle, ns;
	
	reg [3:0] wstrb;
	reg l_addr, l_rdata;
	
	// hsize to wr strobe translation
	always @* begin
		case (ahb_hsize)
			3'b000: wstrb <= 4'd1 << ahb_haddr[1:0];
			3'b001: wstrb <= ahb_haddr[1]? 4'hC:4'h3;
			default: wstrb <= 4'b1111;
		endcase
	end

	always @(posedge aclk)
		cs	<= aresetn? ns : sIdle;

	always @(posedge aclk) begin
		if (l_rdata)
			ahb_hrdata <= amm_readdata;
		if (l_addr) begin
			amm_address		<= ahb_haddr;
			amm_byteenable	<= ahb_hwrite? wstrb : 4'b1111; 
		end
	end
		
		
	always @* begin
		ns				<= sIdle;
		ahb_hreadyout	<= 1'b1;
		amm_write		<= 1'b0;
		amm_read		<= 1'b0;
		l_addr			<= 1'b0;
		l_rdata			<= 1'b0;
		case (cs)
			sIdle: begin
				if (((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) & ahb_hready & ahb_hselx) begin
					l_addr <= 1'b1;
					ns <= ahb_hwrite? sWrite : sRead;
				end
			end
			sWrite: begin
				ns				<= sWrite;
				ahb_hreadyout	<= 1'b0;
				amm_write 		<= 1'b1;
				if (~amm_waitrequest) begin
					l_rdata		<= 1'b1; //doesn't matter
					ns			<= sAck;
				end
			end
			sRead: begin
				ns				<= sRead;
				ahb_hreadyout	<= 1'b0;
				amm_read 		<= 1'b1;
				if (~amm_waitrequest) begin
					l_rdata		<= 1'b1;
					ns			<= sAck;
				end
			end
			sAck: begin
				ns				<= sIdle;
				ahb_hreadyout	<= 1'b1;
				if (((ahb_htrans == 2'b10) | (ahb_htrans == 2'b11)) & ahb_hready & ahb_hselx) begin
					l_addr <= 1'b1;
					ns <= ahb_hwrite? sWrite : sRead;
				end
			end
		endcase
	end
		
endmodule

