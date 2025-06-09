// Verilator-compatible testbench for the switch fabric
module tb_very_simple_switch;

    // Parameters
    parameter DATA_WIDTH = 64;
    parameter INPUT_QTY = 8;
    parameter OUTPUT_QTY = 8;
    parameter DEST_WIDTH = $clog2(OUTPUT_QTY);
    
    // Clock and reset
    logic clk;
    logic reset;
    
    // DUT signals
    logic [INPUT_QTY-1:0] data_in_valid;
    logic [INPUT_QTY-1:0][DATA_WIDTH-1:0] data_in;
    logic [INPUT_QTY-1:0][DEST_WIDTH-1:0] data_in_destination;
    logic [OUTPUT_QTY-1:0] data_out_valid;
    logic [OUTPUT_QTY-1:0][DATA_WIDTH-1:0] data_out;
    
    // Test tracking
    int test_count = 0;
    int error_count = 0;
    int cycle_count = 0;
    
    // Clock generation
    always begin
        clk = 0;
        #5;
        clk = 1;
        #5;
        cycle_count++;
        if (cycle_count > 5000) begin
            $display("Timeout reached");
            $finish;
        end
    end
    
    // DUT instantiation
    very_simple_switch #(
        .DATA_WIDTH(DATA_WIDTH),
        .INPUT_QTY(INPUT_QTY),
        .OUTPUT_QTY(OUTPUT_QTY)
    ) dut (
        .clk(clk),
        .reset(reset),
        .data_in_valid(data_in_valid),
        .data_in(data_in),
        .data_in_destination(data_in_destination),
        .data_out_valid(data_out_valid),
        .data_out(data_out)
    );
    
    // Helper task to apply reset
    task apply_reset();
        reset = 1;
        data_in_valid = '0;
        data_in = '0;
        data_in_destination = '0;
        wait_cycles(3);
        reset = 0;
        wait_cycles(1);
    endtask
    
    // Helper task to wait cycles (Verilator compatible)
    task wait_cycles(input int num_cycles);
        for (int i = 0; i < num_cycles; i++) begin
            wait(clk == 1);
            wait(clk == 0);
        end
    endtask
    
    // Helper task to send single data word
    task send_data(input int inp, input logic [DATA_WIDTH-1:0] data, input int dest);
        data_in_valid[inp] = 1;
        data_in[inp] = data;
        data_in_destination[inp] = DEST_WIDTH'(dest);
        wait_cycles(1);
        data_in_valid[inp] = 0;
    endtask
    
    // Helper task to check output
    task check_output(input int out_port, input logic [DATA_WIDTH-1:0] expected_data, input logic should_be_valid);
        if (data_out_valid[out_port] !== should_be_valid) begin
            $display("ERROR: Output %0d valid signal mismatch. Expected: %b, Got: %b", 
                     out_port, should_be_valid, data_out_valid[out_port]);
            error_count++;
        end
        
        if (should_be_valid && data_out[out_port] !== expected_data) begin
            $display("ERROR: Output %0d data mismatch. Expected: 0x%016h, Got: 0x%016h", 
                     out_port, expected_data, data_out[out_port]);
            error_count++;
        end
    endtask
    
    // Test case wrapper
    task run_test(input string test_name);
        test_count++;
        $display("\n=== Test %0d: %s ===", test_count, test_name);
    endtask
    
    // Concurrent data sending for parallel tests
    task send_parallel_data();
        // This replaces the fork/join construct
        data_in_valid[0] = 1;
        data_in[0] = 64'h1111111111111111;
        data_in_destination[0] = DEST_WIDTH'(0);
        
        data_in_valid[1] = 1;
        data_in[1] = 64'h2222222222222222;
        data_in_destination[1] = DEST_WIDTH'(1);
        
        data_in_valid[2] = 1;
        data_in[2] = 64'h3333333333333333;
        data_in_destination[2] = DEST_WIDTH'(2);
        
        data_in_valid[3] = 1;
        data_in[3] = 64'h4444444444444444;
        data_in_destination[3] = DEST_WIDTH'(3);
        
        wait_cycles(1);
        data_in_valid = '0;
    endtask
    
    // Main test sequence
    initial begin
        $display("Starting Switch Fabric Testbench (Verilator Compatible)");
        
        // Test 1: Basic reset test
        run_test("Reset Test");
        apply_reset();
        
        // Check all outputs are invalid after reset
        for (int i = 0; i < OUTPUT_QTY; i++) begin
            check_output(i, 64'h0, 1'b0);
        end
        
        // Test 2: Single input to single output
        run_test("Single Input to Output");
        send_data(0, 64'hDEADBEEFCAFEBABE, 3);
        
        // Wait for data to propagate through FIFO (1 cycle latency)
        wait_cycles(1);
        check_output(3, 64'hDEADBEEFCAFEBABE, 1'b1);
        
        // Check other outputs are inactive
        for (int i = 0; i < OUTPUT_QTY; i++) begin
            if (i != 3) check_output(i, 64'h0, 1'b0);
        end
        
        wait_cycles(1);
        check_output(3, 64'h0, 1'b0); // Should go inactive after one cycle
        
        // Test 3: Multiple inputs to different outputs (parallel)
        run_test("Parallel Routing");
        send_parallel_data();
        
        wait_cycles(1);
        check_output(0, 64'h1111111111111111, 1'b1);
        check_output(1, 64'h2222222222222222, 1'b1);
        check_output(2, 64'h3333333333333333, 1'b1);
        check_output(3, 64'h4444444444444444, 1'b1);
        
        // Test 4: Multiple inputs to same output (serialization with priority)
        run_test("Serialization with Priority");
        
        // Send multiple data to same destination simultaneously
        data_in_valid[0] = 1;
        data_in[0] = 64'hAAAAAAAAAAAAAAAA;
        data_in_destination[0] = DEST_WIDTH'(5);
        
        data_in_valid[1] = 1;
        data_in[1] = 64'hBBBBBBBBBBBBBBBB;
        data_in_destination[1] = DEST_WIDTH'(5);
        
        data_in_valid[2] = 1;
        data_in[2] = 64'hCCCCCCCCCCCCCCCC;
        data_in_destination[2] = DEST_WIDTH'(5);
        
        wait_cycles(1);
        data_in_valid = '0;
        
        // Input 0 should have priority (lowest index)
        wait_cycles(1);
        check_output(5, 64'hAAAAAAAAAAAAAAAA, 1'b1);
        
        // Next cycle should have input 1
        wait_cycles(1);
        check_output(5, 64'hBBBBBBBBBBBBBBBB, 1'b1);
        
        // Next cycle should have input 2
        wait_cycles(1);
        check_output(5, 64'hCCCCCCCCCCCCCCCC, 1'b1);
        
        // Should be inactive after all data is sent
        wait_cycles(1);
        check_output(5, 64'h0, 1'b0);
        
        // Test 5: Mixed scenario - some parallel, some serialized
        run_test("Mixed Parallel and Serialized");
        
        data_in_valid[0] = 1;
        data_in[0] = 64'h5555555555555555;
        data_in_destination[0] = DEST_WIDTH'(6); // Goes to output 6
        
        data_in_valid[1] = 1;
        data_in[1] = 64'h6666666666666666;
        data_in_destination[1] = DEST_WIDTH'(7); // Goes to output 7
        
        data_in_valid[2] = 1;
        data_in[2] = 64'h7777777777777777;
        data_in_destination[2] = DEST_WIDTH'(6); // Also goes to output 6 (conflict)
        
        data_in_valid[3] = 1;
        data_in[3] = 64'h8888888888888888;
        data_in_destination[3] = DEST_WIDTH'(4); // Goes to output 4
        
        wait_cycles(1);
        data_in_valid = '0;
        
        wait_cycles(1);
        // Parallel outputs
        check_output(7, 64'h6666666666666666, 1'b1);
        check_output(4, 64'h8888888888888888, 1'b1);
        // Serialized output (input 0 has priority)
        check_output(6, 64'h5555555555555555, 1'b1);
        
        wait_cycles(1);
        // Second data for output 6
        check_output(6, 64'h7777777777777777, 1'b1);
        check_output(7, 64'h0, 1'b0);
        check_output(4, 64'h0, 1'b0);
        
        // Test 6: Burst traffic test
        run_test("Burst Traffic");
        
        for (int burst = 0; burst < 5; burst++) begin
            for (int inp = 0; inp < INPUT_QTY; inp++) begin
                send_data(inp, DATA_WIDTH'(64'h1000 + (DATA_WIDTH'(burst) << 8) + DATA_WIDTH'(inp)), inp % OUTPUT_QTY);
            end
        end
        
        // Let all data drain
        wait_cycles(20);
        
        // Test 7: Edge case - invalid destination (should be ignored)
        run_test("Invalid Destination");
        
        // Send to destination that doesn't exist
        send_data(0, 64'hBADDEADBEEF0000, OUTPUT_QTY); // Invalid destination
        send_data(1, 64'h900DDA7A00000000, 2); // Valid destination
        
        wait_cycles(1);
        check_output(2, 64'h900DDA7A00000000, 1'b1);
        // All other outputs should be inactive
        for (int i = 0; i < OUTPUT_QTY; i++) begin
            if (i != 2) check_output(i, 64'h0, 1'b0);
        end
        
        // Test 8: Simple continuous traffic
        run_test("Continuous Traffic");
        
        // Simplified version without fork/join
        for (int cycle = 0; cycle < 10; cycle++) begin
            // Generate some traffic
            for (int inp = 0; inp < INPUT_QTY; inp++) begin
                if ((cycle + inp) % 3 == 0) begin // Pseudo-random pattern
                    data_in_valid[inp] = 1;
                    data_in[inp] = DATA_WIDTH'(64'h1000 + cycle * 256 + inp);
                    data_in_destination[inp] = DEST_WIDTH'((cycle + inp) % OUTPUT_QTY);
                end else begin
                    data_in_valid[inp] = 0;
                end
            end
            wait_cycles(1);
        end
        data_in_valid = '0;
        
        // Final drain
        wait_cycles(10);
        
        // Test summary
        $display("\n=== Test Summary ===");
        $display("Total tests run: %0d", test_count);
        $display("Total errors: %0d", error_count);
        
        if (error_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $finish;
    end
    
endmodule
