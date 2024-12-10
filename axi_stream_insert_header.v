module axi_stream_insert_header #(
    parameter DATA_WD = 32,                // 数据宽度
    parameter DATA_BYTE_WD = DATA_WD / 8,  // 数据字节宽度
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)  // 字节计数宽度
) (
    input clk,
    input rst_n,
    
    // AXI Stream 输入数据
    input valid_in,
    input [DATA_WD-1:0] data_in,
    input [DATA_BYTE_WD-1:0] keep_in,
    input last_in,
    output ready_in,
    
    // AXI Stream 输出数据，带有插入的 header
    output valid_out,
    output [DATA_WD-1:0] data_out,
    output [DATA_BYTE_WD-1:0] keep_out,
    output last_out,
    input ready_out,
    
    // 要插入的 header 数据
    input valid_insert,
    input [DATA_WD-1:0] data_insert,
    input [DATA_BYTE_WD-1:0] keep_insert,
    input [BYTE_CNT_WD-1:0] byte_insert_cnt
);

    // 内部信号声明
    reg valid_reg, valid_out_reg;
    reg [DATA_WD-1:0] data_out_reg;
    reg [DATA_BYTE_WD-1:0] keep_out_reg;
    reg last_out_reg;
    reg [BYTE_CNT_WD-1:0] byte_cnt_reg;
    reg inserting_header;  // 标记是否正在插入 header
    reg buffer_valid;      // 缓存有效标志
    reg [DATA_WD-1:0] buffered_data;  // 缓存数据
    
    wire store_data;

    // 输出赋值
    assign valid_out = valid_out_reg;
    assign data_out = data_out_reg;
    assign keep_out = keep_out_reg;
    assign last_out = last_out_reg;
    
    // 输入和输出就绪信号
    assign ready_in = ready_out && (valid_insert || valid_in);

    // 存储数据逻辑（避免传输泡沫）
    assign store_data = valid_insert && ready_out && ~buffer_valid;

    ///////////////////////////////////////////////////////////////////
    // 1. 实现 data_out 传输
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            buffer_valid <= 1'b0;
        else
            buffer_valid <= buffer_valid ? ~ready_out : store_data;
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            buffered_data <= {DATA_WD{1'b0}};
        else
            buffered_data <= store_data ? data_insert : buffered_data;
    end

    ///////////////////////////////////////////////////////////////////
    // 2. 实现 header 数据处理
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            valid_out_reg <= 0;
        else if (valid_in && ready_in && !inserting_header) begin
            // 输入数据流传输
            valid_out_reg <= valid_in;
            data_out_reg <= data_in;
            keep_out_reg <= keep_in;
            last_out_reg <= last_in;
            inserting_header <= 0;
        end else if (valid_insert && ready_in && !inserting_header) begin
            // 插入 header 数据
            valid_out_reg <= valid_insert;
            data_out_reg <= data_insert;
            keep_out_reg <= keep_insert;
            last_out_reg <= 1'b0;  // header 永远不是最后一拍
            byte_cnt_reg <= byte_insert_cnt;
            inserting_header <= 1;
        end
    end

    ///////////////////////////////////////////////////////////////////
    // 3. header 插入到 data
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            valid_out_reg <= 0;
            data_out_reg <= {DATA_WD{1'b0}};
            keep_out_reg <= {DATA_BYTE_WD{1'b0}};
            last_out_reg <= 0;
            inserting_header <= 0;
        end else if (valid_in && ready_in && inserting_header) begin
            // 如果正在插入 header，传递原始数据
            valid_out_reg <= valid_in;
            data_out_reg <= data_in;
            keep_out_reg <= keep_in;
            last_out_reg <= last_in;
            if (last_in)
                inserting_header <= 0;  // 如果是最后一拍，结束插入 header
        end
    end

    ///////////////////////////////////////////////////////////////////
    // 4. 判断 valid_out
    ///////////////////////////////////////////////////////////////////
    // 在传输数据时，valid_out 根据 valid_in 和插入标志控制
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            valid_out_reg <= 0;
        else if (valid_in && ready_in && !inserting_header) begin
            valid_out_reg <= valid_in;
        end else if (valid_insert && ready_in && !inserting_header) begin
            valid_out_reg <= valid_insert;
        end
    end

    ///////////////////////////////////////////////////////////////////
    // 5. 判断 keep_out 输出
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            keep_out_reg <= 0;
        else if (valid_out && inserting_header) begin
            // 在插入 header 时，保持 keep_out 信号与 keep_insert 相一致
            keep_out_reg <= keep_insert;
        end else if (valid_out && !inserting_header) begin
            // 正常传输时，保持输入的 keep_in
            keep_out_reg <= keep_in;
        end
    end

    ///////////////////////////////////////////////////////////////////
    // 6. 判断 last_out
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            last_out_reg <= 0;
        else if (valid_out && inserting_header) begin
            // 在插入 header 时，last_out 永远为 0
            last_out_reg <= 0;
        end else if (valid_out && !inserting_header && last_in) begin
            // 如果不是插入 header 的状态，则按照 last_in 的值设置 last_out
            last_out_reg <= last_in;
        end
    end

endmodule

