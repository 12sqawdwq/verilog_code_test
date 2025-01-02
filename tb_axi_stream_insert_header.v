`timescale 1ns/1ps

module tb_axi_stream_insert_header;

    // Parameters
    parameter DATA_WD = 32;
    parameter DATA_BYTE_WD = DATA_WD / 8;
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD);

    // Signals
    reg clk;
    reg rst_n;

    // AXI Stream 输入信号
    reg valid_in;
    reg [DATA_WD-1:0] data_in;
    reg [DATA_BYTE_WD-1:0] keep_in;
    reg last_in;
    wire ready_in;

    // AXI Stream 输出信号
    wire valid_out;
    wire [DATA_WD-1:0] data_out;
    wire [DATA_BYTE_WD-1:0] keep_out;
    wire last_out;
    reg ready_out;

    // 插入头部信号
    reg valid_insert;
    reg [DATA_WD-1:0] data_insert;
    reg [DATA_BYTE_WD-1:0] keep_insert;
    reg [BYTE_CNT_WD-1:0] byte_insert_cnt;

    // DUT: Device Under Test
    axi_stream_insert_header #(
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD),
        .BYTE_CNT_WD(BYTE_CNT_WD)
    ) dut (
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
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 10ns period
    end

    // Reset generation
    initial begin
        rst_n = 1'b0;
        #15;
        rst_n = 1'b1;
    end

    // Random stimulus generation
    initial begin
        // Initialize inputs
        valid_in = 0;
        data_in = 0;
        keep_in = 0;
        last_in = 0;
        ready_out = 1;
        valid_insert = 0;
        data_insert = 0;
        keep_insert = 0;
        byte_insert_cnt = 0;

        // Wait for reset
        @(posedge rst_n);
        #10;

        // Random stimulus loop
        repeat (200) begin
            @(posedge clk);

            // Generate random control signals
            valid_in <= $random % 2;   // Randomly toggle valid_in
            valid_insert <= $random % 2;   // Randomly toggle valid_insert
            ready_out <= $random % 2;  // Randomly toggle ready_out (simulate backpressure)

            // Generate random data
            if (valid_in) begin
                data_in <= $random;               // Random data
                keep_in <= $random % (1 << DATA_BYTE_WD);  // Random keep (valid bytes)
                last_in <= ($random % 8 == 0);    // Randomly set last_in (8-to-1 chance)
            end

            if (valid_insert) begin
                data_insert <= $random;           // Random header data
                keep_insert <= $random % (1 << DATA_BYTE_WD);  // Random keep (valid bytes)
                byte_insert_cnt <= $random % DATA_BYTE_WD;     // Random valid byte count
            end
        end

        #100;
        $stop;  // End simulation
    end

    // Monitor outputs
    initial begin
        $monitor("Time=%0d | valid_out=%b, data_out=0x%h, keep_out=0x%h, last_out=%b",
                 $time, valid_out, data_out, keep_out, last_out);
    end

    // Coverage for corner cases
    initial begin
        @(posedge rst_n);

        // Case 1: Insert header and immediately send a valid data stream
        #10;
        valid_insert = 1;
        data_insert = 32'hABCD1234;
        keep_insert = 4'b1111;
        byte_insert_cnt = 4;

        #10;
        valid_insert = 0;

        valid_in = 1;
        data_in = 32'h12345678;
        keep_in = 4'b1111;
        last_in = 0;

        @(posedge clk);
        data_in = 32'hDEADBEEF;
        keep_in = 4'b1111;
        last_in = 1;

        @(posedge clk);
        valid_in = 0;

        // Case 2: Handle partial valid bytes in the last data
        #20;
        valid_in = 1;
        data_in = 32'hCAFEBABE;
        keep_in = 4'b1100;  // Only first two bytes valid
        last_in = 1;

        @(posedge clk);
        valid_in = 0;

        // Case 3: Multiple headers with backpressure
        #20;
        valid_insert = 1;
        data_insert = 32'hAAAA5555;
        keep_insert = 4'b1110;
        byte_insert_cnt = 3;

        #10;
        valid_insert = 0;

        ready_out = 0;  // Simulate backpressure
        #20;
        ready_out = 1;  // Resume downstream

        valid_in = 1;
        data_in = 32'h55667788;
        keep_in = 4'b1111;
        last_in = 0;

        @(posedge clk);
        data_in = 32'h99AABBCC;
        keep_in = 4'b1111;
        last_in = 1;

        @(posedge clk);
        valid_in = 0;

        // Case 4: Only headers, no data
        #20;
        valid_insert = 1;
        data_insert = 32'h11223344;
        keep_insert = 4'b1111;
        byte_insert_cnt = 4;

        #10;
        valid_insert = 0;

        // Wait and stop
        #100;
        $stop;
    end

endmodule

