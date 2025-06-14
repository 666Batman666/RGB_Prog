//version2
module timing_generator(
    input             clk,
    input             rst_n,
    input  [11:0]     h_total,
    input  [11:0]     h_size,
    input  [10:0]     h_sync,
    input  [10:0]     h_start,
    input  [10:0]     v_total,
    input  [10:0]     v_size,
    input  [ 9:0]     v_sync,
    input  [ 9:0]     v_start,
    input  [22:0]     vs_reset,

    output reg [26:24] Synco
  );

  reg [11:0] h_cnt;
  reg [10:0] v_cnt;
  reg vsync, hsync, den;

  // 水平計數器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_cnt <= 0;
    end
    else
    begin
      if (h_cnt == h_total - 1)
      begin
        h_cnt <= 0;
      end
      else
      begin
        h_cnt <= h_cnt + 1;
      end
    end
  end

  // 垂直計數器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      v_cnt <= 0;
    end
    else
    begin
      if (h_cnt == h_total - 1)
      begin
        if (v_cnt == v_total - 1)
        begin
          v_cnt <= 0;
        end
        else
        begin
          v_cnt <= v_cnt + 1;
        end
      end
    end
  end

  // 同步信號生成
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      vsync <= 0;
      hsync <= 0;
      den <= 0;
    end
    else
    begin
      // Vsync: 垂直同步 (active high)
      vsync <= (v_cnt < v_sync) ? 1'b1 : 1'b0;

      // Hsync: 水平同步 (active high)
      hsync <= (h_cnt < h_sync) ? 1'b1 : 1'b0;

      // Den: 有效資料區間
      den <= (h_cnt >= h_start && h_cnt < (h_start + h_size) &&
              v_cnt >= v_start && v_cnt < (v_start + v_size)) ? 1'b1 : 1'b0;
    end
  end

  // 輸出
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      Synco <= 3'b0;
    end
    else
    begin
      Synco <= {vsync, hsync, den};
    end
  end

endmodule
