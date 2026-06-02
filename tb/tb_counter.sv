// Interface
interface counter_if (input logic clk);

  logic rst_n = 1;
  logic en 		= 0;
  logic [7:0] cnt;
  
	// reset task
  task reset();
		en <= 0;
		
		@(negedge clk);
    rst_n <= 0;
		
    repeat(2) @(posedge clk);
		
		@(negedge clk);
    rst_n <= 1;
  endtask
  
  task drive_enable (input bit enable);
    en <= enable;
  endtask

endinterface

// Transaction
class counter_transaction;

  rand bit en; 
  bit [7:0] cnt; 
  bit is_reset = 0;  
  
  constraint cstr_en { 
		en dist {1:=70, 0:=30}; 
	}
endclass


// Generator
class counter_generator;

	virtual counter_if vif;
  mailbox #(counter_transaction) gen2drv;
  int num_tests = 100;
  
  task run();
    
		// reset transaction
    counter_transaction tr_reset = new();
		
    tr_reset.is_reset = 1;
    gen2drv.put(tr_reset);
    
    // random data transaction
    for (int i=0; i<num_tests; i++) begin
      counter_transaction tr = new();
      
			assert(tr.randomize());
			tr.is_reset = 0;
			
      gen2drv.put(tr);
      @(posedge vif.clk);
    end
		
  endtask
	
endclass


// Driver
class counter_driver;

  virtual counter_if vif;
  mailbox #(counter_transaction) gen2drv;
  
  task run();
	
    forever begin
      counter_transaction tr;
      gen2drv.get(tr);
      
      if (tr.is_reset) begin
        vif.reset();
      end 
			else begin
				@(negedge vif.clk);			// negedge clk, avoid racing with monitor
        vif.drive_enable(tr.en);
      end
    end
  endtask
endclass


// Monitor
class counter_monitor;

  virtual counter_if vif;
  mailbox #(counter_transaction) mon2scb;
  
  task run();
    counter_transaction tr;
		
    forever begin
      @(posedge vif.clk);
			#1step;				// avoid sampling race condition
      
      tr = new();
      tr.en = vif.en;
      tr.cnt = vif.cnt;
      tr.is_reset = !vif.rst_n;  // reset period
      
      mon2scb.put(tr);
    end
  endtask
endclass


// Scoreboard
class counter_scoreboard;

	virtual counter_if vif;
  mailbox #(counter_transaction) mon2scb;
  int error_count = 0;
  int total_checks = 0;
  
  task run();
    bit [7:0] expected_cnt = 0;
    
    forever begin
      counter_transaction tr;
      mon2scb.get(tr);
      
      total_checks++;
      
			// Comparison - reset period
      if (tr.is_reset) begin
				expected_cnt = 0;
				
        if (tr.cnt !== 0) begin
          $error("Reset Fail！Counter value: %h", tr.cnt);
          error_count++;
        end
				
      end 
			
			// Comparison - when tr.en = 1
			else if (tr.en) begin
        expected_cnt = (expected_cnt == 255) ? 0 : expected_cnt + 1;
				
        if (tr.cnt !== expected_cnt) begin
          $error("Error！ Actual value: %h, Expected value: %h", tr.cnt, expected_cnt);
          error_count++;
        end
				
				else
					$display("Pass! Actual value: %h, Expected value: %h", tr.cnt, expected_cnt);
			end
			
			// Comparison - when tr.en = 0
      else begin
        if (tr.cnt !== expected_cnt) begin
          $error("Error！ Actual value: %h, Expected value: %h", tr.cnt, expected_cnt);
          error_count++;
        end
				
				else
					$display("Pass! Actual value: %h, Expected value: %h", tr.cnt, expected_cnt);
      end
      
			
			
			
      // Print report for every 10 counts
      if (total_checks % 10 == 0) begin
        $display("Total Checked %0d time(s)，Error(s): %0d ", total_checks, error_count);
      end
    end
  endtask
endclass


// Env
class counter_env;
	virtual counter_if intf;
	
	counter_generator 	gen;
	counter_driver    	drv;
	counter_monitor   	mon;
	counter_scoreboard 	scb;
	
	mailbox #(counter_transaction) gen2drv = new();
	mailbox #(counter_transaction) mon2scb = new();
	
	function void build();
		// component instantiation
		gen = new();
		drv = new();
		mon = new();
		scb = new();
		
		// interface connection 
		gen.vif = intf;
		drv.vif = intf;
		mon.vif = intf;
		scb.vif = intf;
		
		// mailbox connection 
		gen.gen2drv = gen2drv;
		drv.gen2drv = gen2drv;
		mon.mon2scb = mon2scb;
		scb.mon2scb = mon2scb;
	endfunction
	
	// start run
	task run();
		fork
			gen.run();
			drv.run();
			mon.run();
			scb.run();
		join_none
	endtask
		
endclass


// Test 
program automatic test (counter_if intf);
	
	counter_env env;
	
	initial begin
		env = new();
		env.intf = intf;
		
		env.build();
		env.run();
	end

	initial begin
		// wait for test
		#10000ns;
		
		// Report
		$display("\n========== TEST DONE ==========");
		$display("Total checks：%0d", env.scb.total_checks);
		
		if (env.scb.error_count == 0)
			$display("\n========== TEST PASS !!! ==========");
		else begin
			$display("\n========== TEST FAILED !!! ==========");
			$display("Error count：%0d", env.scb.error_count);
		end
		
		$finish;
	end

endprogram
	
	
// Top_tb
module tb_counter;

  logic clk;

  counter_if intf(clk);
  
  counter dut (
    .clk		(clk),
    .rst_n	(intf.rst_n),
    .en			(intf.en),
    .cnt		(intf.cnt)
  );
	
	test t0(intf);
  
	initial begin
		clk = 0;
		
		forever
			#5 clk = ~clk;
	end

	// DUMP FSDB
  initial begin
    $fsdbDumpfile("tb_counter.fsdb");
    $fsdbDumpvars(0, "tb_counter");
  end

endmodule
