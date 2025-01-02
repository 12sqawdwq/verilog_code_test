# README.md

# AXI Stream 插入头部模块

## 参数说明

- `DATA_WD`: 数据宽度，默认为32位。
- `DATA_BYTE_WD`: 数据字节宽度，等于`DATA_WD`除以8。
- `BYTE_CNT_WD`: 字节计数宽度，等于`DATA_BYTE_WD`的二进制对数。

## 端口定义

- `clk`: 时钟信号。
- `rst_n`: 异步复位信号，低电平有效。
- `valid_in`: 输入数据有效信号。
- `data_in`: 输入数据。
- `keep_in`: 输入数据有效字节信号。
- `last_in`: 输入数据包的最后一拍。
- `ready_in`: 输入就绪信号。
- `valid_out`: 输出数据有效信号。
- `data_out`: 输出数据。
- `keep_out`: 输出数据有效字节信号。
- `last_out`: 输出数据包的最后一拍。
- `ready_out`: 输出就绪信号。
- `valid_insert`: 插入头部数据有效信号。
- `data_insert`: 要插入的头部数据。
- `keep_insert`: 要插入的头部数据有效字节信号。
- `byte_insert_cnt`: 要插入的头部数据字节计数。

## 内部信号

- `valid_reg`, `valid_out_reg`: 有效信号寄存器。
- `data_out_reg`: 输出数据寄存器。
- `keep_out_reg`: 输出数据有效字节寄存器。
- `last_out_reg`: 输出数据包的最后一拍寄存器。
- `byte_cnt_reg`: 字节计数寄存器。
- `inserting_header`: 标记是否正在插入头部。
- `buffer_valid`: 缓存有效标志。
- `buffered_data`: 缓存数据。

##### 数据输出传输逻辑

1. **处理`ready_in`信号**：
   
   * `ready_in`信号用于指示输入端是否准备好接收数据。在插入头部数据或主数据流时，模块必须检查`ready_in`信号以确保数据可以顺利传输。
   * 如果`ready_in`为低（0），模块应该暂停数据输出，直到输入端准备好。

2. **实现数据缓存逻辑**：
   
   * 数据缓存用于存储即将输出的数据，以防止在数据流中产生空隙（即传输泡沫）。这确保了数据传输的连续性和效率。

### 头部数据处理

1. **检测有效的头部数据插入请求**：
   
   * 当模块检测到头部数据插入请求时（通常由某些条件或信号触发），它将开始插入头部数据到数据流中。

2. **在插入头部数据期间输出信号**：
   
   * 在插入头部数据期间，模块需要设置并输出以下信号：
     * `valid_out`：数据有效信号，表示当前输出数据是有效的。
     * `data_out`：实际的数据值。
     * `byteenable_out`：有效字节信号，指示哪些字节在数据中是有效的。
     * `last_out`：最后一拍信号，表示这是当前传输的最后一个数据包。

### 头部插入到数据

* **插入头部数据期间的流控制**：
  * 即使在插入头部数据期间，模块也必须能够接收并处理主数据流。这意味着模块需要能够同时处理头部数据和主数据流，并在适当的时候切换。

### 判断输出有效信号

1. **优先发送缓存中的头部数据**：
   
   * 如果有头部数据缓存，模块应该首先发送这些数据，而不是主数据流。

2. **发送主数据流**：
   
   * 当没有头部数据需要发送时，模块应该继续发送主数据流。

3. **没有有效数据时**：
   
   * 如果既没有头部数据也没有主数据流，模块应该将`valid_out`信号置为0，表示当前没有有效数据输出。

### 判断输出有效字节信号

1. **优先处理缓存数据的有效字节信号**：
   
   * 在处理有效字节信号时，如果缓存中有头部数据，应优先处理这些数据的字节使能信号。

2. **更新输出有效字节信号**：
   
   * 当主数据流有效且输出就绪时，模块需要更新`byteenable_out`信号，以反映当前输出数据的有效字节。

### 判断输出最后一拍信号

1. **插入头部数据时**：
   
   * 在插入头部数据期间，`last_out`信号应该始终为0，因为这不是数据流的结束。

2. **主数据流最后一拍**：
   
   * 当主数据流有效且当前数据包是最后一个时，模块应该将`last_out`信号置为1，正确传递最后一拍信号。 



### 测试台模块定义

```verilog
module tb_axi_stream_insert_header;

```

定义了一个名为 `tb_axi_stream_insert_header` 的测试台模块。

### 参数定义

```verilog
parameter DATA_WD = 32;
parameter DATA_BYTE_WD = DATA_WD / 8;
parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD);

```

这里定义了与 `axi_stream_insert_header` 模块相同的参数，用于设置数据宽度、字节宽度和字节计数宽度。

### 信号定义

```verilog
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

```

这里定义了用于测试的各种信号，包括时钟、复位、AXI Stream 输入/输出信号以及用于插入头部的信号。

### 设备实例化

```verilog
axi_stream_insert_header #(
    .DATA_WD(DATA_WD),
    .DATA_BYTE_WD(DATA_BYTE_WD),
    .BYTE_CNT_WD(BYTE_CNT_WD)
) dut (
    // 端口连接
);

```

这里实例化了 `axi_stream_insert_header` 模块，并将其命名为 `dut`（Device Under Test）。

### 时钟生成

```verilog
initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;  // 10ns period
end

```

这段代码生成一个周期为10纳秒的时钟信号。

### 复位生成

```verilog
initial begin
    rst_n = 1'b0;
    #15;
    rst_n = 1'b1;
end

```

这段代码在仿真开始时将复位信号拉低，并在15纳秒后释放复位。

### 随机激励生成

```verilog
initial begin
    // Initialize inputs
    // ...
    // Random stimulus loop
    repeat (200) begin
        @(posedge clk);
        // Generate random control signals and data
        // ...
    end
    // ...
end

```

这段代码初始化输入信号，并在一个循环中生成随机的控制信号和数据，以模拟不同的输入条件。

### 输出监控

```
initial begin
    $monitor("Time=%0d | valid_out=%b, data_out=0x%h, keep_out=0x%h, last_out=%b",
             $time, valid_out, data_out, keep_out, last_out);
end

```

使用 `$monitor` 系统任务来监控和打印输出信号的状态。

### 角落情况覆盖

```verilog
initial begin
    @(posedge rst_n);
    // Case 1: Insert header and immediately send a valid data stream
    // ...
    // Case 2: Handle partial valid bytes in the last data
    // ...
    // Case 3: Multiple headers with backpressure
    // ...
    // Case 4: Only headers, no data
    // ...
end

```

通过一系列特定的测试情况来覆盖模块可能遇到的各种角落情况，以确保模块在各种条件下都能正确工作。

### 停止仿真

```verilog
$stop;

```

使用 `$stop` 系统任务停止仿真。
