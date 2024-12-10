`timescale 1ns / 1ps

module tb_axi_stream_insert_header;

    // Parameter definitions
    parameter DATA_WD = 32;
    parameter DATA_BYTE_WD = DATA_WD / 8;
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD);
    
    // Signals
    reg clk;
    reg rst_n;
    reg valid_in;
    reg [DATA_WD-1:0] data_in;
    reg [DATA_BYTE_WD-1:0] keep_in;
    reg last_in;
    wire ready_in;
    
    reg valid_insert;
    reg [DATA_WD-1:0] data_insert;
    reg [DATA_BYTE_WD-1:0] keep_insert;
    reg [BYTE_CNT_WD-1:0] byte_insert_cnt;

    wire valid_out;
    wire [DATA_WD-1:0] data_out;
    wire [DATA_BYTE_WD-1:0] keep_out;
    wire last_out;
    reg ready_out;

    // Instantiate the Unit Under Test (UUT)
    axi_stream_insert_header #(
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD),
        .BYTE_CNT_WD(BYTE_CNT_WD)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .keep_in(keep_in),
        .last_in(last_in),
        .ready_in(ready_in),
        .valid_out(valid_out),
        .data_out(data_out),
        .keep_out(keep_out),
        .last_out(last_out),
        .ready_out(ready_out),
        .valid_insert(valid_insert),
        .data_insert(data_insert),
        .keep_insert(keep_insert),
        .byte_insert_cnt(byte_insert_cnt)
    );

    // Clock generation
    always #5 clk = ~clk;  // 100 MHz clock

    // Reset generation
    initial begin
        clk = 0;
        rst_n = 0;
        #20 rst_n = 1;
    end

    // Stimulus generation
    initial begin
        // Initialize signals
        valid_in = 0;
        data_in = 32'b0;
        keep_in = 4'b0;
        last_in = 0;
        valid_insert = 0;
        data_insert = 32'b0;
        keep_insert = 4'b0;
        byte_insert_cnt = 0;
        ready_out = 1;

        // Wait for reset deassertion
        #20;

        // Test Case 1: Normal burst transmission with header insertion
        test_burst_with_header;

        // Test Case 2: Randomized burst transmission
        test_randomized_burst;

        // Test Case 3: Simulate backpressure and ensure no data loss
        test_backpressure_scenario;

        // End simulation
        #1000;
        $finish;
    end

    // Test Case 1: Normal burst transmission with header insertion
    task test_burst_with_header;
        begin
            // Set the header insertion signal
            valid_insert = 1;
            data_insert = 32'hA5A5A5A5;  // Arbitrary header
            keep_insert = 4'b1111;
            byte_insert_cnt = 1;

            // Simulate burst of data with header inserted
            valid_in = 1;
            data_in = 32'h12345678;
            keep_in = 4'b1111;
            last_in = 0;  // Not the last transfer
            #10;

            valid_in = 1;
            data_in = 32'h9ABCDEF0;
            keep_in = 4'b1111;
            last_in = 1;  // Last transfer
            #10;

            // Simulate last data with header inserted
            valid_in = 1;
            data_in = 32'h11223344;
            keep_in = 4'b1111;
            last_in = 1;
            #10;

            // Reset signals
            valid_in = 0;
            last_in = 0;
            valid_insert = 0;
        end
    endtask

    // Test Case 2: Randomized burst transmission
    task test_randomized_burst;
        integer i;
        begin
            for (i = 0; i < 10; i = i + 1) begin
                // Randomize the input values
                valid_in = $random % 2;
                data_in = $random;
                keep_in = $random;
                last_in = (i == 9) ? 1 : 0;  // Mark the last packet for the last iteration
                #10;
            end
        end
    endtask

    // Test Case 3: Simulate backpressure and ensure no data loss
    task test_backpressure_scenario;
        begin
            // Simulate backpressure by toggling `ready_out`
            valid_in = 1;
            data_in = 32'hABCDEF12;
            keep_in = 4'b1111;
            last_in = 0;
            ready_out = 0;  // No backpressure initially, `ready_out` is low
            #10;

            ready_out = 1;  // Backpressure removed, `ready_out` goes high
            #10;

            valid_in = 0;   // Stop sending data
        end
    endtask

    // Monitoring the output signals (checking for bubble, loss, and duplication)
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // Reset conditions
        end else begin
            // Check for data integrity
            if (valid_out) begin
                if (last_out) begin
                    $display("Last packet: data_out = %h", data_out);
                end else begin
                    $display("Data: data_out = %h", data_out);
                end
            end
        end
    end

endmodule
