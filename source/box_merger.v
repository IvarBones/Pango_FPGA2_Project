module box_merger #(
    parameter MAX_BOX_NUM = 10,
    parameter BOX_WIDTH   = 38
)(
    input  wire clk,
    input  wire rst_n,

    input  wire vs_in,                 // 帧同步
    input  wire eoc_in,                // box有效脉冲
    input  wire [BOX_WIDTH-1:0] box_in,

    output reg  [3:0] box_count_out,   // 有效 box 数 (0~10)
    output wire [MAX_BOX_NUM*BOX_WIDTH-1:0] box_all_out
);

    // ==============================
    // 10 个独立寄存器
    // ==============================
    reg [BOX_WIDTH-1:0] box0;
    reg [BOX_WIDTH-1:0] box1;
    reg [BOX_WIDTH-1:0] box2;
    reg [BOX_WIDTH-1:0] box3;
    reg [BOX_WIDTH-1:0] box4;
    reg [BOX_WIDTH-1:0] box5;
    reg [BOX_WIDTH-1:0] box6;
    reg [BOX_WIDTH-1:0] box7;
    reg [BOX_WIDTH-1:0] box8;
    reg [BOX_WIDTH-1:0] box9;

    reg [3:0] box_count; // 0~10

    // ==============================
    // 写入 / 清零逻辑
    // ==============================
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            box_count <= 4'd0;
            // box0~box9 不清零，避免图像缓慢渐变出现/消失问题
        end
        else if(vs_in) begin
            // 新帧开始，只清计数，不动历史数据
            box_count <= 4'd0;
        end
        else if(eoc_in && box_count < MAX_BOX_NUM) begin
            case(box_count)
                4'd0: box0 <= box_in;
                4'd1: box1 <= box_in;
                4'd2: box2 <= box_in;
                4'd3: box3 <= box_in;
                4'd4: box4 <= box_in;
                4'd5: box5 <= box_in;
                4'd6: box6 <= box_in;
                4'd7: box7 <= box_in;
                4'd8: box8 <= box_in;
                4'd9: box9 <= box_in;
            endcase
            box_count <= box_count + 1'b1;
        end
    end

    // 输出 box 数（同步输出即可）
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            box_count_out <= 4'd0;
        else if(vs_in)
            box_count_out <= box_count;
    end

    // 拼接成扁平输出，顺序为 box0 在最低位
    assign box_all_out = {
        box9, box8, box7, box6, box5,
        box4, box3, box2, box1, box0
    };

endmodule
