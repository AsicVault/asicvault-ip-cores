`timescale 1 ns / 100 ps

module tb_ammrv2ammrv_2xclk;

	parameter P_PASSTHROUGH = 0;
	reg clk2x = 0, clk1x = 0;
	reg reset = 1'b1;

	ammrt_if #(32,4) f_if(), s_if();
	
	int errors = 0;
	int cmdindx = 0;
	
	typedef struct {
		reg [31:0] addr;
		reg [31:0] data;
		reg [3:0]  be;
		reg        rnw;
		int num;
	} req_t;
	
	req_t cmd_que[$], resp_que[$], read_resp_q[$];
	reg read_check_q[$];
	
	always begin
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
	
	initial begin repeat(4) @(posedge clk1x); reset++; end
	
	
	
	ammrv2ammrv_2xclk #(P_PASSTHROUGH) dut (
		.clk				(	clk1x	),
		.clk_2x				(	clk2x	),
		.reset				(	reset	), //synchronous active high reset
		.s_address			(	s_if.address			),
		.s_byteenable		(	s_if.byteenable			),
		.s_writedata		(	s_if.writedata			),
		.s_read				(	s_if.read				),
		.s_write			(	s_if.write				),
		.s_waitrequest		(	s_if.waitrequest		),
		.s_readdata			(	s_if.readdata			),
		.s_readdatavalid	(	s_if.readdatavalid		),
		.m_address			(	f_if.address			),
		.m_byteenable		(	f_if.byteenable			),
		.m_writedata		(	f_if.writedata			),
		.m_read				(	f_if.read				),
		.m_write			(	f_if.write				),
		.m_waitrequest		(	f_if.waitrequest		),
		.m_readdata			(	f_if.readdata			),
		.m_readdatavalid	(	f_if.readdatavalid		)
	);
	
	
	task generate_check(int n = 1000);
		req_t r;
		reg val;
		repeat (n) begin
			r.rnw  = $random;
			r.addr = $random;
			r.data = $random;
			r.be = $random;
			r.num = cmdindx++;
			s_if.address    = r.addr;
			s_if.byteenable = r.be;
			s_if.writedata  = r.data;
			val = (($random%3) == 0);
			while (~val) begin
				@(posedge clk1x);
				val = (($random%3) == 0);
			end
			s_if.read  =   r.rnw;
			s_if.write =  ~r.rnw;
			cmd_que.push_back(r);
			$display("%t ps: Init CMD %d, %s", $time, r.num, r.rnw? "read" : "write");
			@(posedge clk1x);
			while (s_if.waitrequest)
				@(posedge clk1x);
			s_if.read  = 1'b0;
			s_if.write = 1'b0;
			if (r.rnw) begin
				read_check_q.push_back(1);
			end 
		end
	endtask
	
	
	task responder (int n = 1000);
		req_t r;
		f_if.waitrequest = 1'b1;
		f_if.readdatavalid = 1'b0;
		repeat (n) begin
			@(posedge clk2x);
			while (~(f_if.read | f_if.write))
				@(posedge clk2x);
			f_if.waitrequest = ~(($random%3) == 0);
			while (f_if.waitrequest) begin
				@(posedge clk2x);
				f_if.waitrequest = ~(($random%3) == 0);
			end
			@(posedge clk2x);
			if (f_if.read) begin
				r = cmd_que.pop_front();
				read_resp_q.push_back(r);
			end else if (f_if.write) begin
				r = cmd_que.pop_front();
				$display("%t ps: write Testing CMD %d", $time, r.num);
				if (r.addr !== f_if.address) begin
					$display("%t ps: ERROR: r.addr:0x%8X != m.addr:0x%8X", $time, r.addr, f_if.address);
					errors++;
				end
				if (r.be !== f_if.byteenable) begin
					$display("%t ps: ERROR: r.be:0x%1X != m.be:0x%1X", $time, r.be, f_if.byteenable);
					errors++;
				end
				if (r.data !== f_if.writedata) begin
					$display("%t ps: ERROR: r.data:0x%1X != m.writedata:0x%8X", $time, r.data, f_if.writedata);
					errors++;
				end
				if (r.rnw !== 1'b0) begin
					$display("%t ps: ERROR: r.rnw is read", $time);
					errors++;
				end
			end
			f_if.waitrequest = 1'b1;
		end
	endtask
	
	
	// read response generator
	always begin
		if (read_resp_q.size() > 0) begin
			req_t r;
			r = read_resp_q.pop_front();
			r.data =  $random;
			resp_que.push_back(r);
			f_if.readdatavalid = (($random%3) == 0);
			while (~f_if.readdatavalid) begin
				@(posedge clk2x);
				f_if.readdatavalid = (($random%3) == 0);
			end
			f_if.readdata = r.data;
			@(posedge clk2x);
			$display("%t ps: read response to CMD %d", $time, r.num);
			f_if.readdatavalid = 1'b0;
			f_if.readdata = 0;
		end else 
		 @(posedge clk2x);
	end
	
	// read response wait and check
	always begin
		if (read_check_q.size() > 0) begin
			req_t r;
			read_check_q.pop_front();
			while (~s_if.readdatavalid)
				@(posedge clk1x);
			r = resp_que.pop_front();
			$display("%t ps: read Testing CMD %d", $time, r.num);
			if (r.data !== s_if.readdata) begin
				$display("%t ps: ERROR: r.data:0x%1X != s.readdata:0x%8X, addr=0x%8X", $time, r.data, s_if.readdata, r.addr);
				errors++;
			end
			if (r.rnw !== 1'b1) begin
				$display("%t ps: ERROR: r.rnw is write", $time);
				errors++;
			end
		end 
			@(posedge clk1x);
	end

	
	//test seq
	initial begin
		@(negedge reset);
		@(posedge clk1x);
		fork
			generate_check();
			responder();
		join
		if (errors) begin
			$display("TEST FAILED with %d errors", errors);
		end else begin
			$display("TEST PASSED");
		end
		repeat (10) @(posedge clk1x);
		$stop();
	end
	
endmodule