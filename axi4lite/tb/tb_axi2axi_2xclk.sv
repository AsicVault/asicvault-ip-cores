`timescale 1 ns / 100 ps

interface tb_axi_if #(parameter P_AXI_IDWIDTH = 4) (input clk);
	logic	[31:0]				awaddr			;
	logic	[ 7:0]				awlen			;
	logic	[ 2:0]				awsize			;
	logic	[ 1:0]				awburst			;
	logic	[P_AXI_IDWIDTH-1:0]	awid			;
	logic						awlock			;
	logic	[3:0]				awcache			;
	logic	[2:0]				awprot			;
	logic						awvalid			;
	logic						awready			;
	
	logic	[P_AXI_IDWIDTH-1:0]	wid				;
	logic	[63:0]				wdata			;
	logic	[ 7:0]				wstrb			;
	logic						wlast			;
	logic						wvalid			;
	logic						wready			;

	logic	[P_AXI_IDWIDTH-1:0]	bid				;
	logic	[ 1:0]				bresp			;
	logic						bvalid			;
	logic						bready			;
	
	logic	[P_AXI_IDWIDTH-1:0]	arid			;
	logic	[31:0]				araddr			;
	logic	[ 3:0]				arlen			;
	logic	[ 2:0]				arsize			;
	logic	[ 1:0]				arburst			;
	logic						arlock			;
	logic	[3:0]				arcache			;
	logic	[2:0]				arprot			;
	logic						arvalid			;
	logic						arready			;
	
	logic	[P_AXI_IDWIDTH-1:0]	rid				;
	logic	[63:0]				rdata			;
	logic	[ 1:0]				rresp			;
	logic						rlast			;
	logic						rvalid			;
	logic						rready			;
	logic						awuser			;
	logic						wuser			;
	logic						buser			;
	logic						aruser			;
	logic						ruser			;
endinterface

function real reftime();
	reftime = $time/1000.0;
endfunction

function bit [31:0] urandom(int range=32'hFFFFFFFF);
	urandom = $random;
	urandom = (urandom < 0)? -urandom : urandom;
	urandom = urandom % range;
endfunction

module tb_axi2axi_2xclk;

	parameter P_PASSTHROUGH = 0;
	parameter P_AXI_IDWIDTH = 1;
	reg clk2x = 0, clk1x = 0;
	reg reset = 1'b0;

	tb_axi_if #(P_AXI_IDWIDTH) mst(), slv();
	
	event e_error;
	
	int errors = 0;
	int wcmdindx = 0;
	int rcmdindx = 0;
	bit running = 1;
	
	typedef struct {
		bit	[31:0]				addr	;
		bit	[ 7:0]				len		;
		bit	[ 2:0]				size	;
		bit	[ 1:0]				burst	;
		bit	[P_AXI_IDWIDTH-1:0]	id		;
		bit						lock	;
		bit	[3:0]				cache	;
		bit	[2:0]				prot	;
		int						num		;
	} cmd_req_t;
	
	cmd_req_t wcmd_que[$], rcmd_que[$]; 
	
	typedef struct {
			bit	[P_AXI_IDWIDTH-1:0]	wid		;
			bit	[63:0]				wdata	;
			bit	[ 7:0]				wstrb	;
			bit						wlast	;
			int						num		;
	} wdata_t;
	
	typedef struct {
		bit	[P_AXI_IDWIDTH-1:0]	rid			;
		bit	[63:0]				rdata		;
		bit	[ 1:0]				rresp		;
		bit						rlast		;
		int						num			;
	} rdata_t;
	
	typedef struct {
		bit	[P_AXI_IDWIDTH-1:0]	bid			;
		bit	[ 1:0]				bresp		;
		int						num			;
	} bresp_t;
	
	typedef struct {
		bit	[ 7:0]				len		;
		int						num		;
	} comm_t;
	
	
	bresp_t bresp_que[$];
	wdata_t wdata_que[$];
	rdata_t rdata_que[$];
	comm_t write_com_que[$];
	comm_t read_com_que[$];
	comm_t ferd_com_que[$];
	
	int bresp_expect_que[$];
	int bresp_gen_que[$];
	int rdata_expect_que[$];
	
	always begin
		if (P_PASSTHROUGH) begin
			#10;
			clk2x <= ~clk2x;
			clk1x <= ~clk1x;
		end else begin
			clk2x <= ~clk2x;
			clk1x <= ~clk1x;
			#5;
			clk2x <= ~clk2x;
			#5;
			clk2x <= ~clk2x;
			clk1x <= ~clk1x;
			#5;
			clk2x <= ~clk2x;
			#5;
		end
	end
	
	initial begin repeat(4) @(posedge clk1x); reset++; end
	
	
	initial begin
		mst.awvalid <= 0;
		mst.wvalid  <= 0;
		mst.bready  <= 0;
		mst.arvalid <= 0;
		mst.rready  <= 0;
		slv.awready <= 0;
		slv.wready  <= 0;
		slv.bvalid  <= 0;
		slv.arready <= 0;
		slv.rvalid  <= 0;
	end
	
	
	
	axi2axi_2xclk #(
		.P_PASSTHROUGH	(	P_PASSTHROUGH	),
		.P_AXI_IDWIDTH	(	P_AXI_IDWIDTH	)
	) dut (
		.aclk			(	clk1x			),
		.aclkx2			(	clk2x			),
		.aresetn		(	reset			),
		.axis_awaddr	(	mst.awaddr		),
		.axis_awlen		(	mst.awlen		),
		.axis_awsize	(	mst.awsize		),
		.axis_awburst	(	mst.awburst		),
		.axis_awid		(	mst.awid		),
		.axis_awlock	(	mst.awlock		),
		.axis_awcache	(	mst.awcache		),
		.axis_awprot	(	mst.awprot		),
		.axis_awvalid	(	mst.awvalid		),
		.axis_awready	(	mst.awready		),
		.axis_wid		(	mst.wid			),
		.axis_wdata		(	mst.wdata		),
		.axis_wstrb		(	mst.wstrb		),
		.axis_wlast		(	mst.wlast		),
		.axis_wvalid	(	mst.wvalid		),
		.axis_wready	(	mst.wready		),
		.axis_bid		(	mst.bid			),
		.axis_bresp		(	mst.bresp		),
		.axis_bvalid	(	mst.bvalid		),
		.axis_bready	(	mst.bready		),
		.axis_arid		(	mst.arid		),
		.axis_araddr	(	mst.araddr		),
		.axis_arlen		(	mst.arlen		),
		.axis_arsize	(	mst.arsize		),
		.axis_arburst	(	mst.arburst		),
		.axis_arlock	(	mst.arlock		),
		.axis_arcache	(	mst.arcache		),
		.axis_arprot	(	mst.arprot		),
		.axis_arvalid	(	mst.arvalid		),
		.axis_arready	(	mst.arready		),
		.axis_rid		(	mst.rid			),
		.axis_rdata		(	mst.rdata		),
		.axis_rresp		(	mst.rresp		),
		.axis_rlast		(	mst.rlast		),
		.axis_rvalid	(	mst.rvalid		),
		.axis_rready	(	mst.rready		),
		.axis_awuser	(	mst.awuser		),
		.axis_wuser		(	mst.wuser		),
		.axis_buser		(	mst.buser		),
		.axis_aruser	(	mst.aruser		),
		.axis_ruser		(	mst.ruser		),
		
		.axim_awaddr	(	slv.awaddr		),
		.axim_awlen		(	slv.awlen		),
		.axim_awsize	(	slv.awsize		),
		.axim_awburst	(	slv.awburst		),
		.axim_awid		(	slv.awid		),
		.axim_awlock	(	slv.awlock		),
		.axim_awcache	(	slv.awcache		),
		.axim_awprot	(	slv.awprot		),
		.axim_awvalid	(	slv.awvalid		),
		.axim_awready	(	slv.awready		),
		.axim_wid		(	slv.wid			),
		.axim_wdata		(	slv.wdata		),
		.axim_wstrb		(	slv.wstrb		),
		.axim_wlast		(	slv.wlast		),
		.axim_wvalid	(	slv.wvalid		),
		.axim_wready	(	slv.wready		),
		.axim_bid		(	slv.bid			),
		.axim_bresp		(	slv.bresp		),
		.axim_bvalid	(	slv.bvalid		),
		.axim_bready	(	slv.bready		),
		.axim_arid		(	slv.arid		),
		.axim_araddr	(	slv.araddr		),
		.axim_arlen		(	slv.arlen		),
		.axim_arsize	(	slv.arsize		),
		.axim_arburst	(	slv.arburst		),
		.axim_arlock	(	slv.arlock		),
		.axim_arcache	(	slv.arcache		),
		.axim_arprot	(	slv.arprot		),
		.axim_arvalid	(	slv.arvalid		),
		.axim_arready	(	slv.arready		),
		.axim_rid		(	slv.rid			),
		.axim_rdata		(	slv.rdata		),
		.axim_rresp		(	slv.rresp		),
		.axim_rlast		(	slv.rlast		),
		.axim_rvalid	(	slv.rvalid		),
		.axim_rready	(	slv.rready		),
		.axim_awuser	(	slv.awuser		),
		.axim_wuser		(	slv.wuser		),
		.axim_buser		(	slv.buser		),
		.axim_aruser	(	slv.aruser		),
		.axim_ruser		(	slv.ruser		)
	);


	// produce write commands from master
	task generate_wreq(int n = 1000);
		cmd_req_t r;
		comm_t c;
		reg val;
		repeat (n) begin
			while (write_com_que.size() > 1) // keep up to 2 commands in queue 
				@(posedge clk1x); 
			r.addr		=	urandom();
			r.len		=	urandom(8);
			r.size		=	urandom();
			r.burst		=	urandom();
			r.id		=	urandom();
			r.lock		=	urandom();
			r.cache		=	urandom();
			r.prot		=	urandom();
			r.num = wcmdindx++;
			mst.awvalid = ((urandom(2)) == 0);
			while (~mst.awvalid) begin
				@(posedge clk1x);
				mst.awvalid = ((urandom(2)) == 0);
			end
			mst.awaddr	<= r.addr	;
			mst.awlen	<= r.len	;
			mst.awsize	<= r.size	;
			mst.awburst	<= r.burst	;
			mst.awid	<= r.id		;
			mst.awlock	<= r.lock	;
			mst.awcache	<= r.cache	;
			mst.awprot	<= r.prot	;
			wcmd_que.push_back(r);
			$display("%t ns: Init WCMD %d, 0x%08H, %d", reftime(), r.num, r.addr, r.len);
			@(posedge clk1x);
			while (~mst.awready)
				@(posedge clk1x);
			mst.awvalid	= 1'b0;
			mst.awaddr	<= 0;
			mst.awlen	<= 0;
			mst.awsize	<= 0;
			mst.awburst	<= 0;
			mst.awid	<= 0;
			mst.awlock	<= 0;
			mst.awcache	<= 0;
			mst.awprot	<= 0;
			c.num = r.num;
			c.len = r.len;
			write_com_que.push_back(c);
		end
	endtask
	
	// produce write data sequences from master
	task generate_writes();
		wdata_t d;
		comm_t c;
		while (running) begin
			while (write_com_que.size() < 1)
				@(posedge clk1x);
			c = write_com_que.pop_front();
			repeat (c.len) begin
				d.num	= c.num;
				d.wid	= urandom();
				d.wdata	= {urandom(),urandom()};
				d.wstrb	= urandom();
				d.wlast	= 0;
				wdata_que.push_back(d);
				mst.wvalid = $random();
				while (~mst.wvalid) begin
					@(posedge clk1x);
					mst.wvalid = $random();
				end
				mst.wid		<= d.wid	;
				mst.wdata	<= d.wdata	;
				mst.wstrb	<= d.wstrb	;
				mst.wlast	<= d.wlast	;
				@(posedge clk1x);
				while (~mst.wready)
					@(posedge clk1x);
				mst.wvalid  = 0;
				mst.wid		<= 0;
				mst.wdata	<= 0;
				mst.wstrb	<= 0;
				mst.wlast	<= 0;
			end
			d.num	= c.num;
			d.wid	= urandom();
			d.wdata	= {urandom(),urandom()};
			d.wstrb	= urandom();
			d.wlast	= 1;
			wdata_que.push_back(d);
			mst.wvalid = urandom();
			while (~mst.wvalid) begin
				@(posedge clk1x);
				mst.wvalid = urandom();
			end
			mst.wid		<= d.wid	;
			mst.wdata	<= d.wdata	;
			mst.wstrb	<= d.wstrb	;
			mst.wlast	<= d.wlast	;
			@(posedge clk1x);
			while (~mst.wready)
				@(posedge clk1x);
			mst.wvalid  = 0;
			mst.wid		<= 0;
			mst.wdata	<= 0;
			mst.wstrb	<= 0;
			mst.wlast	<= 0;
			bresp_expect_que.push_back(d.num);
			// wait for bresp after each write data sequences
			// FIXME: shall fork the bready process and check that the response is not given too early. bready may go high even before the write process is completed
			mst.bready = $random;
			while (~mst.bready) begin
				@(posedge clk1x);
				mst.bready = $random;
			end
			@(posedge clk1x);
			while (~mst.bvalid)
				@(posedge clk1x);
			mst.bready = 0;
		end
	endtask
	
	// BRESP checker
	always @(posedge clk1x) begin
		int exp;
		bresp_t b;
		if (dut.axis_bready & dut.axis_bvalid) begin
			if (bresp_expect_que.size() < 1) begin
				$display("%t ns: ERROR: unexpected dut.axis_bvalid", reftime());
				-> e_error;
			end
			exp = bresp_expect_que.pop_front();
			if (bresp_que.size() < 1) begin
				$display("%t ns: ERROR: bresp_que empty ", reftime());
				-> e_error;
			end
			b = bresp_que.pop_front();
			if (exp != b.num) begin
				$display("%t ns: ERROR: bresp sequence number mismatch. expected %d != got %d", reftime(), exp, b.num);
				-> e_error;
			end else begin
				if (b.bresp !== dut.axis_bresp) begin
					$display("%t ns: ERROR: dut.bresp %2b != expected %2b", reftime(), dut.axis_bresp, b.bresp);
					-> e_error;
				end
				if (b.bid !== dut.axis_bid) begin
					$display("%t ns: ERROR: dut.bid %b != expected %b", reftime(), dut.axis_bid, b.bid);
					-> e_error;
				end
			end
		end
	end
	
	// WADDR channel checker
	always @(posedge clk2x) begin
		cmd_req_t c;
		int err;
		if (slv.awvalid)
			slv.awready <= $random;
		if (slv.awvalid & slv.awready) begin
			err = 0;
			if (wcmd_que.size() < 1) begin
				$display("%t ns: ERROR: unexpected dut.axim_awvalid, wcmd_que empty", reftime());
				err++;
				-> e_error;
			end
			c = wcmd_que.pop_front();
			if (c.addr	!== slv.awaddr	) begin
				$display("%t ns: ERROR: wcmd %d c.addr(0x%08H) != slv.awaddr(0x%08H)", reftime(), c.num, c.addr, slv.awaddr);
				err++;
				-> e_error;
			end
			if (c.len	!== slv.awlen	) begin
				$display("%t ns: ERROR: wcmd %d c.len(%d) != slv.awlen(%d)", reftime(), c.num, c.len, slv.awlen);
				err++;
				-> e_error;
			end
			if (c.size	!== slv.awsize	) begin
				$display("%t ns: ERROR: wcmd %d c.size(%d) != slv.awsize(%d)", reftime(), c.num, c.size, slv.awsize);
				err++;
				-> e_error;
			end
			if (c.burst	!== slv.awburst	) begin
				$display("%t ns: ERROR: wcmd %d c.burst(%d) != slv.awburst(%d)", reftime(), c.num, c.burst, slv.awburst);
				err++;
				-> e_error;
			end
			if (c.id	!== slv.awid	) begin
				$display("%t ns: ERROR: wcmd %d c.id(%d) != slv.awid(%d)", reftime(), c.num, c.id, slv.awid);
				err++;
				-> e_error;
			end
			if (c.lock	!== slv.awlock	) begin
				$display("%t ns: ERROR: wcmd %d c.lock(%d) != slv.awlock(%d)", reftime(), c.num, c.lock, slv.awlock);
				err++;
				-> e_error;
			end
			if (c.cache	!== slv.awcache	) begin
				$display("%t ns: ERROR: wcmd %d c.cache(%d) != slv.awcache(%d)", reftime(), c.num, c.cache, slv.awcache);
				err++;
				-> e_error;
			end
			if (c.prot	!== slv.awprot	) begin
				$display("%t ns: ERROR: wcmd %d c.prot(%d) != slv.awprot(%d)", reftime(), c.num, c.prot, slv.awprot);
				err++;
				-> e_error;
			end
			if (err == 0)
				$display("%t ns: Testing wcmd %d PASSED", reftime(), c.num);
		end
	end
	
	
	// WDATA checker
	always @(posedge clk2x) begin
		wdata_t d;
		int err;
		if (slv.wvalid)
			slv.wready <= $random();
		if (slv.wvalid & slv.wready) begin
			err = 0;
			if (wdata_que.size() < 1) begin
				$display("%t ns: ERROR: unexpected dut.axim_wvalid, wdata_que empty", reftime());
				err++;
				-> e_error;
			end
			d = wdata_que.pop_front();
			if (d.wdata	!== slv.wdata	) begin
				$display("%t ns: ERROR: wdata %d d.wdata(0x%08H) != slv.wdata(0x%08H)", reftime(), d.num, d.wdata, slv.wdata);
				err++;
				-> e_error;
			end
			if (d.wstrb	!== slv.wstrb	) begin
				$display("%t ns: ERROR: wdata %d d.wstrb(0x%02H) != slv.wstrb(0x%02H)", reftime(), d.num, d.wstrb, slv.wstrb);
				err++;
				-> e_error;
			end
			if (d.wid	!== slv.wid	) begin
				$display("%t ns: ERROR: wdata %d d.wid(%d) != slv.wid(%d)", reftime(), d.num, d.wid, slv.wid);
				err++;
				-> e_error;
			end
			if (d.wlast	!== slv.wlast	) begin
				$display("%t ns: ERROR: wdata %d d.wlast(%d) != slv.wlast(%d)", reftime(), d.num, d.wlast, slv.wlast);
				err++;
				-> e_error;
			end
			if (err == 0)
				$display("%t ns: Testing wdata %d element PASSED", reftime(), d.num);
			if (slv.wlast) begin
				bresp_gen_que.push_back(d.num); // enable bresp generation
			end
		end
	end
	
	
	// BRESP generator
	initial begin
		bresp_t b;
		while (running) begin
			while (bresp_gen_que.size() < 1)
				@(posedge clk2x);
			b.num = bresp_gen_que.pop_front();
			b.bid = urandom();
			b.bresp = urandom();
			slv.bvalid = urandom();
			while (~slv.bvalid) begin
				@(posedge clk2x);
				slv.bvalid = urandom();
			end
			bresp_que.push_back(b);
			slv.bid <= b.bid;
			slv.bresp <= b.bresp;
			@(posedge clk2x);
			while (~slv.bready)
				@(posedge clk2x);
			slv.bvalid = 0;
			slv.bresp <= 0;
			slv.bid <= 0;
		end
	end
	
	
	// produce read commands from master
	task generate_rreq(int n = 1000);
		cmd_req_t r;
		comm_t c;
		reg val;
		repeat (n) begin
			while (read_com_que.size() > 0) // keep up to 1 commands in queue 
				@(posedge clk1x); 
			r.addr		=	urandom();
			r.len		=	urandom(8);
			r.size		=	urandom();
			r.burst		=	urandom();
			r.id		=	urandom();
			r.lock		=	urandom();
			r.cache		=	urandom();
			r.prot		=	urandom();
			r.num = rcmdindx++;
			mst.arvalid = (($random%3) == 0);
			while (~mst.arvalid) begin
				@(posedge clk1x);
				mst.arvalid = (($random%3) == 0);
			end
			mst.araddr	<= r.addr	;
			mst.arlen	<= r.len	;
			mst.arsize	<= r.size	;
			mst.arburst	<= r.burst	;
			mst.arid	<= r.id		;
			mst.arlock	<= r.lock	;
			mst.arcache	<= r.cache	;
			mst.arprot	<= r.prot	;
			rcmd_que.push_back(r);
			$display("%t ns: Init RCMD %d, 0x%08H, %d", reftime(), r.num, r.addr, r.len);
			@(posedge clk1x);
			while (~mst.arready)
				@(posedge clk1x);
			mst.arvalid	= 1'b0;
			mst.araddr	<= 0;
			mst.arlen	<= 0;
			mst.arsize	<= 0;
			mst.arburst	<= 0;
			mst.arid	<= 0;
			mst.arlock	<= 0;
			mst.arcache	<= 0;
			mst.arprot	<= 0;
			c.num = r.num;
			c.len = r.len;
			ferd_com_que.push_back(c);
		end
	endtask
	
	
	// RADDR channel checker
	always @(posedge clk2x) begin
		cmd_req_t c;
		comm_t rc;
		int err;
		if (slv.arvalid)
			slv.arready <= $random;
		if (slv.arvalid & slv.arready) begin
			err = 0;
			if (rcmd_que.size() < 1) begin
				$display("%t ns: ERROR: unexpected dut.axim_arvalid, rcmd_que empty", reftime());
				err++;
				-> e_error;
			end
			c = rcmd_que.pop_front();
			if (c.addr	!== slv.araddr	) begin
				$display("%t ns: ERROR: rcmd %d c.addr(0x%08H) != slv.araddr(0x%08H)", reftime(), c.num, c.addr, slv.araddr);
				err++;
				-> e_error;
			end
			if (c.len	!== slv.arlen	) begin
				$display("%t ns: ERROR: rcmd %d c.len(%d) != slv.arlen(%d)", reftime(), c.num, c.len, slv.arlen);
				err++;
				-> e_error;
			end
			if (c.size	!== slv.arsize	) begin
				$display("%t ns: ERROR: rcmd %d c.size(%d) != slv.arsize(%d)", reftime(), c.num, c.size, slv.arsize);
				err++;
				-> e_error;
			end
			if (c.burst	!== slv.arburst	) begin
				$display("%t ns: ERROR: rcmd %d c.burst(%d) != slv.arburst(%d)", reftime(), c.num, c.burst, slv.arburst);
				err++;
				-> e_error;
			end
			if (c.id	!== slv.arid	) begin
				$display("%t ns: ERROR: rcmd %d c.id(%d) != slv.arid(%d)", reftime(), c.num, c.id, slv.arid);
				err++;
				-> e_error;
			end
			if (c.lock	!== slv.arlock	) begin
				$display("%t ns: ERROR: rcmd %d c.lock(%d) != slv.arlock(%d)", reftime(), c.num, c.lock, slv.arlock);
				err++;
				-> e_error;
			end
			if (c.cache	!== slv.arcache	) begin
				$display("%t ns: ERROR: rcmd %d c.cache(%d) != slv.arcache(%d)", reftime(), c.num, c.cache, slv.arcache);
				err++;
				-> e_error;
			end
			if (c.prot	!== slv.arprot	) begin
				$display("%t ns: ERROR: rcmd %d c.prot(%d) != slv.arprot(%d)", reftime(), c.num, c.prot, slv.arprot);
				err++;
				-> e_error;
			end
			if (err == 0)
				$display("%t ns: Testing rcmd %d PASSED", reftime(), c.num);
			rc.num = c.num;
			rc.len = c.len;
			read_com_que.push_back(rc);
		end
	end
	

	// RDATA generator
	initial begin
		rdata_t d;
		comm_t c;
		while (running) begin
			while (read_com_que.size() < 1)
				@(posedge clk2x);
			c = read_com_que.pop_front();
			d.num = c.num;
			repeat (c.len) begin
				d.rid	= urandom();
				d.rdata	= {urandom(),urandom()};
				d.rresp	= urandom();
				d.rlast	= 0;
				slv.rvalid = urandom();
				while (~slv.rvalid) begin
					@(posedge clk2x);
					slv.rvalid = urandom();
				end
				slv.rid		<= d.rid	;
				slv.rdata	<= d.rdata	;
				slv.rresp	<= d.rresp	;
				slv.rlast	<= d.rlast	;
				rdata_que.push_back(d);
				@(posedge clk2x);
				while (~slv.rready)
					@(posedge clk2x);
				slv.rvalid = 0;
				slv.rid		<= 0;
				slv.rdata	<= 0;
				slv.rresp	<= 0;
				slv.rlast	<= 0;
			end
			d.rid	= urandom();
			d.rdata	= {urandom(),urandom()};
			d.rresp	= urandom();
			d.rlast	= 1;
			slv.rvalid = urandom();
			while (~slv.rvalid) begin
				@(posedge clk2x);
				slv.rvalid = urandom();
			end
			slv.rid		<= d.rid	;
			slv.rdata	<= d.rdata	;
			slv.rresp	<= d.rresp	;
			slv.rlast	<= d.rlast	;
			rdata_que.push_back(d);
			@(posedge clk2x);
			while (~slv.rready)
				@(posedge clk2x);
			slv.rvalid = 0;
			slv.rid		<= 0;
			slv.rdata	<= 0;
			slv.rresp	<= 0;
			slv.rlast	<= 0;
		end
	end
	

	bit rena = 0;
	// RDATA checker
	always @(posedge clk1x) begin
		comm_t c;
		rdata_t d;
		int err;
		//if ((ferd_com_que.size() > 0) & (~rena | (rena & mst.rvalid  & mst.rready & mst.rlast))) begin
		if ((ferd_com_que.size() > 0) & ~rena) begin
			rena = 1'b1;
			c = ferd_com_que.pop_front();
			mst.rready <= 1;
		end
		if (rena) begin
			if (mst.rvalid & mst.rready) begin
				if (mst.rlast) begin
					mst.rready <= 0;
					rena = 0;
				end else begin
					mst.rready <= $random();
				end
			end
			if (~mst.rready)
				mst.rready <= $random();
		end
		if (mst.rvalid & mst.rready) begin
			if (rdata_que.size() < 1) begin
				$display("%t ns: ERROR: unexpected mst.rvalid, rdata_que empty", reftime());
				-> e_error;
			end else begin
				d = rdata_que.pop_front();
				err = 0;
				if (d.num != c.num) begin
					$display("%t ns: ERROR: rdata sequence mismatch. expected %d, got %d", reftime(), c.num, d.num);
					err++;
					-> e_error;
				end
				if (d.rdata	!== mst.rdata	) begin
					$display("%t ns: ERROR: rdata %d d.rdata(0x%08H) != mst.rdata(0x%08H)", reftime(), d.num, d.rdata, mst.rdata);
					err++;
					-> e_error;
				end
				if (d.rresp	!== mst.rresp	) begin
					$display("%t ns: ERROR: rdata %d d.rresp(0x%02H) != mst.rresp(0x%02H)", reftime(), d.num, d.rresp, mst.rresp);
					err++;
					-> e_error;
				end
				if (d.rid	!== mst.rid	) begin
					$display("%t ns: ERROR: rdata %d d.rid(%d) != mst.rid(%d)", reftime(), d.num, d.rid, mst.rid);
					err++;
					-> e_error;
				end
				if (d.rlast	!== mst.rlast	) begin
					$display("%t ns: ERROR: rdata %d d.rlast(%d) != mst.rlast(%d)", reftime(), d.num, d.rlast, mst.rlast);
					err++;
					-> e_error;
				end
				if ((c.len == 0) &  (mst.rlast !== 1'b1)) begin
					$display("%t ns: ERROR: rdata %d mst.rlast(%d) != 1 at last word", reftime(), d.num, mst.rlast);
					err++;
					-> e_error;
				end
				if (err == 0)
					$display("%t ns: Testing rdata %d element PASSED", reftime(), d.num);
				c.len--;
			end
		end
	end
	
	
	//test seq
	initial begin
		@(posedge reset);
		@(posedge clk1x);
		fork
			generate_wreq();
			//generate_rreq();
			generate_writes();
			begin
				@(e_error);
				$display("TEST ERROR");
				$stop();
			end
			begin
				#10ms;
				$display("TB Timeout");
				-> e_error;
			end
		join_any
		running = 0;
		repeat (10) @(posedge clk1x);
		$display("TB Complete");
		$stop();
	end
	
endmodule