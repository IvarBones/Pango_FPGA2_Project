// 按键消抖模块（适配盘古100Pro+：低电平有效，27MHz时钟，20ms消抖）
module key#(
    parameter DEBOUNCE_CNT = 20'd540000  // 27MHz * 20ms = 540000，消抖阈值
)(
    input               sys_clk      ,  // 输入时钟：27MHz（来自顶层）
    input               rst_in       ,  // 输入复位：低电平有效（来自顶层rst_in）
    input               key_raw      ,  // 输入：原始按键信号（低电平有效）
    output reg          key_press    ,  // 输出：按键单次触发（高电平1个时钟周期）
    output reg          key_state     // 输出：按键当前状态（高=按下，低=未按下）
);

// 1. 两级寄存器同步（消除亚稳态，将按键信号同步到sys_clk域）
reg key_sync1, key_sync2;
always @(posedge sys_clk or negedge rst_in) begin
    if (!rst_in) begin  // 复位时，按键默认未按下（同步后为高电平）
        key_sync1 <= 1'b1;
        key_sync2 <= 1'b1;
    end else begin
        key_sync1 <= key_raw;       // 第一级同步
        key_sync2 <= key_sync1;     // 第二级同步（最终稳定的按键信号）
    end
end

// 2. 消抖计数器（检测按键稳定状态）
reg [19:0] debounce_cnt;  // 20位足够存储540000（最大值2^20=1,048,576）
always @(posedge sys_clk or negedge rst_in) begin
    if (!rst_in) begin
        debounce_cnt <= 20'd0;
    end else begin
        if (key_sync2 == 1'b1) begin  // 按键未按下（高电平），计数器清零
            debounce_cnt <= 20'd0;
        end else begin  // 按键按下（低电平），计数器累加，直到阈值
            debounce_cnt <= (debounce_cnt >= DEBOUNCE_CNT) ? DEBOUNCE_CNT : debounce_cnt + 1'b1;
        end
    end
end

// 3. 生成按键状态与单次触发信号
reg debounce_cnt_prev;  // 记录上一周期计数器是否满，用于生成单周期触发
always @(posedge sys_clk or negedge rst_in) begin
    if (!rst_in) begin
        key_state <= 1'b0;        // 复位时按键未按下
        debounce_cnt_prev <= 1'b0;
        key_press <= 1'b0;
    end else begin
        debounce_cnt_prev <= (debounce_cnt >= DEBOUNCE_CNT);  // 上周期是否稳定按下
        key_state <= (debounce_cnt >= DEBOUNCE_CNT);          // 当前稳定状态（高=按下）
        
        // 仅在“上周期未稳定，当前周期稳定”时，输出1个周期的key_press（单次触发）
        key_press <= (debounce_cnt >= DEBOUNCE_CNT) && (!debounce_cnt_prev);
    end
end

endmodule