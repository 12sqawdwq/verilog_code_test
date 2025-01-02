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
    //assign ready_in = ready_out && (valid_insert || valid_in);
    //改为：
    //assign ready_in = (valid_insert && ~buffer_valid) || (valid_in && ~inserting_header);
    /*仅当头部数据未缓存（~buffer_valid）时，允许接收头部数据。
      仅当没有正在插入头部数据时，允许接收主数据流。
      不再直接依赖 ready_out，确保输入握手信号独立于输出端状态。*/
      //改为：
      //assign ready_in = (valid_insert && ~buffer_valid) || (valid_in && (~inserting_header || ready_out));
      /*增加了 ready_out 条件，确保即使在 inserting_header 状态下，
      只要下游已经准备好（ready_out=1），主数据流可以立即恢复传输。
      这样使得头部插入完成后，ready_in 无需等待多余的周期即可拉高。*/
      //改为：
      assign ready_in = (valid_insert && ~buffer_valid) || (valid_in && (~inserting_header || (last_in && ready_out)));
    //增加 (last_in && ready_out) 的条件，确保最后一拍在下游准备好时优先处理，避免被阻塞

    // 存储数据逻辑（避免传输泡沫），判断是否需要将 data_insert 存入内部缓冲
    assign store_data = valid_insert && ready_out && ~buffer_valid;

    ///////////////////////////////////////////////////////////////////
    // 1. 实现 data_out 传输
    ///////////////////////////////////////////////////////////////////

    //always @(posedge clk or negedge rst_n) begin
      //  if (~rst_n)
        //    buffer_valid <= 1'b0;
        //else
          //  buffer_valid <= buffer_valid ? ~ready_out : store_data;
            /*如果头部数据有效 (valid_insert=1)，且模块准备好输出 (ready_out=1)，
            则将头部数据缓存到 buffered_data 中。*/
    //end 改为：
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    buffer_valid <= 1'b0;
                    buffered_data <= {DATA_WD{1'b0}};
                end else if (valid_insert && ~buffer_valid) begin
                    buffer_valid <= 1'b1;
                    buffered_data <= data_insert;
                end else if (ready_out ) begin
                    buffer_valid <= 1'b0;  // 数据已发送，清空缓存
                end
            end
            /*仅在 valid_insert=1 且缓存未满（~buffer_valid）时存储头部数据。
              当 ready_out=1 且 buffer_valid=1 时释放缓存数据。*/
    

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
            valid_out_reg <= valid_insert;// 插入头部数据
            data_out_reg <= data_insert;// 头部数据输出到 data_out
            keep_out_reg <= keep_insert;// 保持头部数据的有效字节标记
            last_out_reg <= 1'b0;  // header 永远不是最后一拍
            byte_cnt_reg <= byte_insert_cnt;
            inserting_header <= 1;//正在插入
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
    //always @(posedge clk or negedge rst_n) begin
      //  if (~rst_n)
        //    valid_out_reg <= 0;
        //else if (valid_in && ready_in && !inserting_header) begin
          //  valid_out_reg <= valid_in;
        //end else if (valid_insert && ready_in && !inserting_header) begin
          //  valid_out_reg <= valid_insert;
        //end
    //end 改为：
    //always @(posedge clk or negedge rst_n) begin
     //   if (~rst_n)
       //     valid_out_reg <= 1'b0;
        //else if (buffer_valid) begin
          //  valid_out_reg <= 1'b1;  // 缓存数据有效
        //end else if (valid_in && ~inserting_header) begin
            //valid_out 可能因为 valid_in 和 inserting_header 的状态滞后，
            //导致输出有效信号（valid_out=1）延迟一个周期
          //  valid_out_reg <= valid_in;
        //end else begin
          //  valid_out_reg <= 1'b0;
        //end
    //end
    /*优先发送头部数据（buffer_valid）。
      当没有头部数据时，发送主数据流。
      如果没有有效数据，valid_out_reg=0。*/
    //改为：
      always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            valid_out_reg <= 1'b0;
        else if (buffer_valid || (valid_in && ready_in)) begin
            valid_out_reg <= 1'b1;  // 缓存或主数据有效
        end else begin
            valid_out_reg <= 1'b0;
        end
    end
    //增加了 (valid_in && ready_in) 条件，确保在主数据流可以继续传输时，valid_out 能立即拉高
    ///////////////////////////////////////////////////////////////////
    // 5. 判断 keep_out 输出
    ///////////////////////////////////////////////////////////////////
    //always @(posedge clk or negedge rst_n) begin
      //  if (~rst_n)
        //    keep_out_reg <= 0;
        //else if (valid_out && inserting_header) begin
            // 在插入 header 时，保持 keep_out 信号与 keep_insert 相一致
          //  keep_out_reg <= keep_insert;
        //end else if (valid_out && !inserting_header) begin
            // 正常传输时，保持输入的 keep_in
          //  keep_out_reg <= keep_in;
        //end
    //end
    //改为
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            keep_out_reg <= 0;
        else if (buffer_valid) begin
            keep_out_reg <= keep_insert;  // 缓存头部时，使用头部的 keep
        end else if (valid_in && ready_out) begin
            keep_out_reg <= keep_in;  // 确保最后一拍的有效字节正确传递
        end
    end
    /*优先处理缓存数据的 keep_insert。
     在 valid_in && ready_out 时更新 keep_out，确保最后一拍的字节有效性*/

    ///////////////////////////////////////////////////////////////////
    // 6. 判断 last_out
    ///////////////////////////////////////////////////////////////////
    //always @(posedge clk or negedge rst_n) begin
      //  if (~rst_n)
        //    last_out_reg <= 0;
        //else if (valid_out && inserting_header) begin
            // 在插入 header 时，last_out 永远为 0
          //  last_out_reg <= 0;
        //end else if (valid_out && !inserting_header && last_in) begin
            // 如果不是插入 header 的状态，则按照 last_in 的值设置 last_out
          //  last_out_reg <= last_in;
        //end
    //end
    //改为：
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            last_out_reg <= 1'b0;
        else if (buffer_valid) begin
            last_out_reg <= 1'b0;  // 缓存头部时，last_out 置 0
        end else if (valid_in && last_in && ready_out) begin
            last_out_reg <= 1'b1;  // 确保最后一拍正确传递
        end else begin
            last_out_reg <= 1'b0;
        end
    end
    /*优先处理 buffer_valid，保证头部插入时 last_out=0。
     添加 valid_in && last_in && ready_out 的条件，确保最后一拍在下游准备好时能正确输出。
     默认情况 last_out=0，避免意外干扰。*/

endmodule

