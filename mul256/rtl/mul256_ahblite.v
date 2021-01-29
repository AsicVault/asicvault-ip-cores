//-------------------------------------------------------------------------------
// Copyright (c) 2017-2021 AsicVault OÜ
//
// Author      : Rain Adelbert
//
// Description : 256-bit multiplier with AHB Lite interface
//
// License     : Solderpad Hardware License v2.1 with Commons Clause, LICENSE.md
//
//-------------------------------------------------------------------------------

module mul256_ahblite (
	input				hclk			,
	input				resetn			,
	input		[31:0]	ahb_haddr		,
	input		[ 1:0]	ahb_hsize		,
	input		[ 1:0]	ahb_htrans		,
	input		[31:0]	ahb_hwdata		,
	input				ahb_hwrite		,
	input				ahb_hready		,
	input				ahb_hselx		,
	output		[31:0]	ahb_hrdata		,
	output				ahb_hresp		,
	output				ahb_hreadyout	
);

	localparam [2:0] s_idle  = 3'd0;
	localparam [2:0] s_mul   = 3'd1;
	localparam [2:0] s_prim1 = 3'd2;
	localparam [2:0] s_prim2 = 3'd3;
	localparam [2:0] s_prim3 = 3'd4;
	localparam [2:0] s_prim4 = 3'd5;
	localparam [2:0] s_prim5 = 3'd6;
	
	reg [2:0] cs = s_idle, ns;

	wire [31:0]	amm_address		;
	wire [31:0]	amm_writedata	;
	wire [ 3:0]	amm_byteenable	;
	wire 		amm_write		;
	wire 		amm_read		;
	reg [31:0]	amm_readdata	;
	wire 		amm_waitrequest	;


	ahb2amm i_ahb2amm (
		//Avalon MM interface (master)
		.aclk			(	hclk			),
		.aresetn		(	resetn			), //synchronous active low reset
		.amm_address	(	amm_address		),
		.amm_writedata	(	amm_writedata	),
		.amm_byteenable	(	amm_byteenable	),
		.amm_write		(	amm_write		),
		.amm_read		(	amm_read		),
		.amm_readdata	(	amm_readdata	),
		.amm_waitrequest(	amm_waitrequest	),
		//AHB Lite interface (slave)
		.ahb_haddr		(	ahb_haddr		),
		.ahb_hsize		(	ahb_hsize		),
		.ahb_htrans		(	ahb_htrans		),
		.ahb_hwdata		(	ahb_hwdata		),
		.ahb_hwrite		(	ahb_hwrite		),
		.ahb_hready		(	ahb_hready		),
		.ahb_hselx		(	ahb_hselx		),
		.ahb_hrdata		(	ahb_hrdata		),
		.ahb_hresp		(	ahb_hresp		),
		.ahb_hreadyout	(	ahb_hreadyout	)
	);

	/* synthesis syn_ramstyle = "registers" */
	reg [31:0] a[7:0], b[7:0], x[15:0];
	wire [255:0] wa, wb;
	wire [511:0] wx, wc;
	wire x_we;
	reg rd_ack = 0;
	
	reg [1:0] cntrl = 0;
	wire [255:0] wp;
	
	assign amm_waitrequest = amm_write? 1'b0 : ~rd_ack;
	
	reg mul_ival, prim_ce, mul_ival_r = 0, cntrl_clr;
	wire mul_irdy;
	
	//operand write process
	always @(posedge hclk)
		if (amm_write)
			if (amm_address[7]) begin
			end else if (amm_address[5]) begin
				b[amm_address[4:2]] <= amm_writedata;
			end else begin
				a[amm_address[4:2]] <= amm_writedata;
			end
	
	always @(posedge hclk)
		if (~resetn) begin
			cntrl <= 0; 
		end else begin
			if (amm_write)
				if (amm_address[7:5]==3'b111) begin
					cntrl <= amm_writedata[1:0];
				end 
			if (cntrl_clr)
				cntrl <= 0;
		end
	
	// control state machine
	always @(posedge hclk)
		if (~resetn) begin
			cs         <= s_idle; 
			mul_ival_r <= 0;
		end else begin
			cs <= ns;
			mul_ival_r <= mul_ival;
		end
	
	always @* begin
		ns <= cs;
		mul_ival <= mul_ival_r;
		prim_ce <= 0;
		cntrl_clr <= 0;
		case (cs) 
			s_idle: begin
				if (cntrl[0]) begin
					ns <= s_mul;
					mul_ival <= 1'b1;
				end else if (cntrl[1])
					ns <= s_prim1;
			end
			s_mul: begin
				mul_ival <= mul_ival_r & ~mul_irdy;
				if (x_we)
					if (cntrl[1]) begin
						ns <= s_prim1;
					end else begin
						ns <= s_idle;
						cntrl_clr <= 1'b1;
					end
			end
			s_prim1: begin 
				ns <= s_prim2;
				prim_ce <= 1'b1;
			end
			s_prim2: begin 
				ns <= s_prim3;
				prim_ce <= 1'b1;
			end
			s_prim3: begin 
				ns <= s_prim4;
				prim_ce <= 1'b1;
			end
			s_prim4: begin 
				ns <= s_prim5;
				prim_ce <= 1'b1;
			end
			default: begin 
				ns <= s_idle;
				prim_ce <= 1'b1;
				cntrl_clr <= 1'b1;
			end
		endcase
	end
	
	
	//result read process
	always @(posedge hclk) begin
		case (amm_address[7:5])
			3'b000  : amm_readdata <= a[amm_address[4:2]];
			3'b001  : amm_readdata <= b[amm_address[4:2]];
			3'b010  : amm_readdata <= wx[(amm_address[5:2]+1)*32-1 -: 32];
			3'b011  : amm_readdata <= wx[(amm_address[5:2]+1)*32-1 -: 32];
			3'b101  : amm_readdata <= wp[(amm_address[4:2]+1)*32-1 -: 32];
			default : amm_readdata[1:0] <= cntrl;
		endcase
		rd_ack <= 1'b0;
		if (amm_read) begin
			rd_ack <= (amm_address[7:6] == 2'b01)? ~cntrl[0] : (amm_address[7:5] == 3'b101)? ~cntrl[1]: 1'b1;
		end
	end
	
	assign wa = {a[7],a[6],a[5],a[4],a[3],a[2],a[1],a[0]}; 
	assign wb = {b[7],b[6],b[5],b[4],b[3],b[2],b[1],b[0]}; 
	assign wc = wx; //{x[15],x[14],x[13],x[12],x[11],x[10],x[9],x[8],x[7],x[6],x[5],x[4],x[3],x[2],x[1],x[0]}; 
	
	/*
	integer i;
	always @(posedge hclk)
		if (x_we)
			for (i=0; i<16; i=i+1)
				x[i] = wx[32*(i+1)-1 -: 32];
	*/
	
	mul256b #(.p(256), .par(3)) i_mul256b (
		.clk	(	hclk		),
		.rstn	(	resetn		),
		.ia		(	wa			),
		.ib		(	wb			),
		.ival	(	mul_ival	),
		.irdy	(	mul_irdy	),
		.oc		(	wx			),
		.oval	(	x_we		)
	);

	mod_secp256k1_prime_simple #(256) i_mod_secp256k1_prime_simple (
		.clk	(	hclk	),
		.ce		(	prim_ce	),
		.a		(	wc		), // 512-bit input
		.c		(	wp		)
	);	
	

endmodule
