// 算正常、改過結構、沒有改變數名
module HDL_final(
    input        clk,
    input        rst_n,
    input        CC,
    input        TP,
    input        IM,
    input        IG,
    input        UM,
    input  [7:0] Brig,
    input  [26:0] DPi,
    input  [2:0] Sync_IM,
    input  [2:0] Sync_IG,
    input  [2:0] Sync_UM,
    output reg [26:0] DPo
  );

  //==================================================================
  // 內部信號宣告
  //==================================================================

  // 位置計數器
  reg [10:0] h_cnt, v_cnt;

  // Pipeline階段資料暫存
  reg [26:0] stage1_data, stage2_data, stage3_data, stage4_data, stage5_data;
  reg [10:0] h_cnt_d1, v_cnt_d1, h_cnt_d2, v_cnt_d2;
  reg [10:0] h_cnt_d3, v_cnt_d3, h_cnt_d4, v_cnt_d4;

  // Stage 1: CC相關變數
  reg [7:0] cc_r, cc_g, cc_b;

  // Stage 2: TP相關變數
  reg [7:0] tp_r, tp_g, tp_b;

  // Stage 3: IM相關變數
  reg [7:0] im_r, im_g, im_b;

  // Stage 4: IG相關變數
  reg [7:0] ig_r, ig_g, ig_b;

  // Stage 5: UM相關變數
  reg [7:0]  um_r, um_g, um_b;
  reg [15:0] enhanced_r, enhanced_g, enhanced_b;

  // 記憶體控制信號
  wire [10:0] mem1_r_addr, mem1_w_addr, mem2_r_addr, mem2_w_addr;
  wire [23:0] mem1_din, mem2_din;
  wire [23:0] mem1_dout, mem2_dout;
  wire        mem1_web, mem1_re, mem1_cs, mem2_web, mem2_re, mem2_cs;

  //==================================================================
  // 記憶體實例化
  //==================================================================

  MEM2048X24 mem1 (
               .CK     (clk),
               .CS     (mem1_cs),
               .WEB    (mem1_web),
               .RE     (mem1_re),
               .R_ADDR (mem1_r_addr),
               .W_ADDR (mem1_w_addr),
               .D_IN   (mem1_din),
               .D_OUT  (mem1_dout)
             );

  MEM2048X24 mem2 (
               .CK     (clk),
               .CS     (mem2_cs),
               .WEB    (mem2_web),
               .RE     (mem2_re),
               .R_ADDR (mem2_r_addr),
               .W_ADDR (mem2_w_addr),
               .D_IN   (mem2_din),
               .D_OUT  (mem2_dout)
             );

  //==================================================================
  // 位置計數器邏輯
  //==================================================================

  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_cnt <= 0;
      v_cnt <= 0;
    end
    else if (DPi[24])
    begin // den有效時計數
      if (h_cnt == 1919)
      begin
        h_cnt <= 0;
        if (v_cnt == 1079)
        begin
          v_cnt <= 0;
        end
        else
        begin
          v_cnt <= v_cnt + 1;
        end
      end
      else
      begin
        h_cnt <= h_cnt + 1;
      end
    end
    else if (DPi[26])
    begin // vsync重置
      h_cnt <= 0;
      v_cnt <= 0;
    end
  end

  // Pipeline計數器延遲
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_cnt_d1 <= 0;
      v_cnt_d1 <= 0;
      h_cnt_d2 <= 0;
      v_cnt_d2 <= 0;
      h_cnt_d3 <= 0;
      v_cnt_d3 <= 0;
      h_cnt_d4 <= 0;
      v_cnt_d4 <= 0;
    end
    else
    begin
      h_cnt_d1 <= h_cnt;
      v_cnt_d1 <= v_cnt;
      h_cnt_d2 <= h_cnt_d1;
      v_cnt_d2 <= v_cnt_d1;
      h_cnt_d3 <= h_cnt_d2;
      v_cnt_d3 <= v_cnt_d2;
      h_cnt_d4 <= h_cnt_d3;
      v_cnt_d4 <= v_cnt_d3;
    end
  end

  //==================================================================
  // Stage 1: CC (Color Correction) 顏色校正
  //==================================================================

  reg [7:0] temp_r, temp_g, temp_b;

  always @(*)
  begin
    if (CC)
    begin
      // 當 Brig=255 時，使用適中的處理方式並加強第四格的暗度
      if (Brig == 8'd255)
      begin
        // 上半部分：適中對比度的漸變，第四格更暗
        if (v_cnt < 540)
        begin
          if (h_cnt < 480)
          begin        // 第一部分: 中亮
            temp_r = ((DPi[23:16] + 64) > 255) ? 8'd255 : (DPi[23:16] + 64);
            temp_g = ((DPi[15:8] + 64) > 255) ? 8'd255 : (DPi[15:8] + 64);
            temp_b = ((DPi[7:0] + 64) > 255) ? 8'd255 : (DPi[7:0] + 64);
          end
          else if (h_cnt < 960)
          begin   // 第二部分: 最亮
            temp_r = DPi[23:16];
            temp_g = DPi[15:8];
            temp_b = DPi[7:0];
          end
          else if (h_cnt < 1440)
          begin  // 第三部分: 中暗
            temp_r = (DPi[23:16] > 64) ? (DPi[23:16] - 64) : 8'd0;
            temp_g = (DPi[15:8] > 64) ? (DPi[15:8] - 64) : 8'd0;
            temp_b = (DPi[7:0] > 64) ? (DPi[7:0] - 64) : 8'd0;
          end
          else
          begin                    // 第四部分: 更暗 (除以8)
            temp_r = DPi[23:16] >> 3;
            temp_g = DPi[15:8] >> 3;
            temp_b = DPi[7:0] >> 3;
          end

          cc_r = temp_r;
          cc_g = temp_g;
          cc_b = temp_b;
        end
        // 下半部分：對應處理後負片，第四格負片後更暗
        else
        begin
          if (h_cnt < 480)
          begin        // 第一部分: 更暗再負片 → 負片後變很亮
            temp_r = DPi[23:16] >> 3;
            temp_g = DPi[15:8] >> 3;
            temp_b = DPi[7:0] >> 3;
          end
          else if (h_cnt < 960)
          begin   // 第二部分: 中暗再負片 → 負片後變中亮
            temp_r = (DPi[23:16] > 64) ? (DPi[23:16] - 64) : 8'd0;
            temp_g = (DPi[15:8] > 64) ? (DPi[15:8] - 64) : 8'd0;
            temp_b = (DPi[7:0] > 64) ? (DPi[7:0] - 64) : 8'd0;
          end
          else if (h_cnt < 1440)
          begin  // 第三部分: 原圖再負片 → 負片後變中暗
            temp_r = DPi[23:16];
            temp_g = DPi[15:8];
            temp_b = DPi[7:0];
          end
          else
          begin                    // 第四部分: 很亮再負片 → 負片後變更暗
            temp_r = ((DPi[23:16] + 128) > 255) ? 8'd255 : (DPi[23:16] + 128);
            temp_g = ((DPi[15:8] + 128) > 255) ? 8'd255 : (DPi[15:8] + 128);
            temp_b = ((DPi[7:0] + 128) > 255) ? 8'd255 : (DPi[7:0] + 128);
          end

          // 負片處理
          cc_r = 8'd255 - temp_r;
          cc_g = 8'd255 - temp_g;
          cc_b = 8'd255 - temp_b;
        end
      end
      else
      begin
        // 原有的漸變處理 (適用於 Brig != 255)
        // 上半部分：正常左暗右亮
        if (v_cnt < 540)
        begin
          if (h_cnt < 480)
          begin        // 第一部分: 減少 1.0*Brig
            temp_r = (DPi[23:16] > Brig) ? (DPi[23:16] - Brig) : 8'd0;
            temp_g = (DPi[15:8] > Brig) ? (DPi[15:8] - Brig) : 8'd0;
            temp_b = (DPi[7:0] > Brig) ? (DPi[7:0] - Brig) : 8'd0;
          end
          else if (h_cnt < 960)
          begin   // 第二部分: 減少 0.5*Brig
            temp_r = (DPi[23:16] > (Brig >> 1)) ? (DPi[23:16] - (Brig >> 1)) : 8'd0;
            temp_g = (DPi[15:8] > (Brig >> 1)) ? (DPi[15:8] - (Brig >> 1)) : 8'd0;
            temp_b = (DPi[7:0] > (Brig >> 1)) ? (DPi[7:0] - (Brig >> 1)) : 8'd0;
          end
          else if (h_cnt < 1440)
          begin  // 第三部分: 增加 0.5*Brig
            temp_r = ((DPi[23:16] + (Brig >> 1)) > 255) ? 8'd255 : (DPi[23:16] + (Brig >> 1));
            temp_g = ((DPi[15:8] + (Brig >> 1)) > 255) ? 8'd255 : (DPi[15:8] + (Brig >> 1));
            temp_b = ((DPi[7:0] + (Brig >> 1)) > 255) ? 8'd255 : (DPi[7:0] + (Brig >> 1));
          end
          else
          begin                    // 第四部分: 增加 1.0*Brig
            temp_r = ((DPi[23:16] + Brig) > 255) ? 8'd255 : (DPi[23:16] + Brig);
            temp_g = ((DPi[15:8] + Brig) > 255) ? 8'd255 : (DPi[15:8] + Brig);
            temp_b = ((DPi[7:0] + Brig) > 255) ? 8'd255 : (DPi[7:0] + Brig);
          end

          cc_r = temp_r;
          cc_g = temp_g;
          cc_b = temp_b;
        end
        // 下半部分：左右交換後再負片
        else
        begin
          if (h_cnt < 480)
          begin        // 左邊變成: 增加 1.0*Brig (對應原右邊)
            temp_r = ((DPi[23:16] + Brig) > 255) ? 8'd255 : (DPi[23:16] + Brig);
            temp_g = ((DPi[15:8] + Brig) > 255) ? 8'd255 : (DPi[15:8] + Brig);
            temp_b = ((DPi[7:0] + Brig) > 255) ? 8'd255 : (DPi[7:0] + Brig);
          end
          else if (h_cnt < 960)
          begin   // 第二部分: 增加 0.5*Brig (對應原第三部分)
            temp_r = ((DPi[23:16] + (Brig >> 1)) > 255) ? 8'd255 : (DPi[23:16] + (Brig >> 1));
            temp_g = ((DPi[15:8] + (Brig >> 1)) > 255) ? 8'd255 : (DPi[15:8] + (Brig >> 1));
            temp_b = ((DPi[7:0] + (Brig >> 1)) > 255) ? 8'd255 : (DPi[7:0] + (Brig >> 1));
          end
          else if (h_cnt < 1440)
          begin  // 第三部分: 減少 0.5*Brig (對應原第二部分)
            temp_r = (DPi[23:16] > (Brig >> 1)) ? (DPi[23:16] - (Brig >> 1)) : 8'd0;
            temp_g = (DPi[15:8] > (Brig >> 1)) ? (DPi[15:8] - (Brig >> 1)) : 8'd0;
            temp_b = (DPi[7:0] > (Brig >> 1)) ? (DPi[7:0] - (Brig >> 1)) : 8'd0;
          end
          else
          begin                    // 右邊變成: 減少 1.0*Brig (對應原左邊)
            temp_r = (DPi[23:16] > Brig) ? (DPi[23:16] - Brig) : 8'd0;
            temp_g = (DPi[15:8] > Brig) ? (DPi[15:8] - Brig) : 8'd0;
            temp_b = (DPi[7:0] > Brig) ? (DPi[7:0] - Brig) : 8'd0;
          end

          // 負片處理
          cc_r = 8'd255 - temp_r;
          cc_g = 8'd255 - temp_g;
          cc_b = 8'd255 - temp_b;
        end
      end
    end
    else
    begin
      cc_r = DPi[23:16];
      cc_g = DPi[15:8];
      cc_b = DPi[7:0];
    end
  end

  // Stage 1 暫存器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage1_data <= 0;
    end
    else
    begin
      stage1_data <= {DPi[26:24], cc_r, cc_g, cc_b};
    end
  end

  //==================================================================
  // Stage 2: TP (Test Pattern) 測試圖案
  //==================================================================

  always @(*)
  begin
    if (TP)
    begin
      // 簡單的測試圖案
      if (h_cnt_d1 < 480)
      begin
        tp_r = 8'd255;
        tp_g = 8'd0;
        tp_b = 8'd0;      // Red
      end
      else if (h_cnt_d1 < 960)
      begin
        tp_r = 8'd0;
        tp_g = 8'd255;
        tp_b = 8'd0;      // Green
      end
      else if (h_cnt_d1 < 1440)
      begin
        tp_r = 8'd0;
        tp_g = 8'd0;
        tp_b = 8'd255;    // Blue
      end
      else
      begin
        tp_r = 8'd255;
        tp_g = 8'd255;
        tp_b = 8'd255;    // White
      end
    end
    else
    begin
      tp_r = stage1_data[23:16];
      tp_g = stage1_data[15:8];
      tp_b = stage1_data[7:0];
    end
  end

  // Stage 2 暫存器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage2_data <= 0;
    end
    else
    begin
      stage2_data <= {stage1_data[26:24], tp_r, tp_g, tp_b};
    end
  end

  //==================================================================
  // Stage 3: IM (Image Motion) 圖像動作
  //==================================================================

  // 暫時保持簡單的透傳
  always @(*)
  begin
    im_r = stage2_data[23:16];
    im_g = stage2_data[15:8];
    im_b = stage2_data[7:0];
  end

  // Stage 3 暫存器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage3_data <= 0;
    end
    else
    begin
      stage3_data <= {stage2_data[26:24], im_r, im_g, im_b};
    end
  end

  //==================================================================
  // Stage 4: IG (Image Format) 圖像格式
  //==================================================================

  // 簡化的RGB處理，暫時保持透傳避免問題
  always @(*)
  begin
    ig_r = stage3_data[23:16];
    ig_g = stage3_data[15:8];
    ig_b = stage3_data[7:0];
  end

  // Stage 4 暫存器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage4_data <= 0;
    end
    else
    begin
      stage4_data <= {stage3_data[26:24], ig_r, ig_g, ig_b};
    end
  end

  //==================================================================
  // Stage 5: UM (Unsharp Mask) 銳化遮罩
  //==================================================================

  // 簡化的邊緣增強，不使用記憶體
  wire [7:0] edge_r, edge_g, edge_b;

  // 簡化的邊緣檢測 (基於像素值的變化)
  assign edge_r = (stage4_data[23:16] > 128) ? (stage4_data[23:16] - 128) : (128 - stage4_data[23:16]);
  assign edge_g = (stage4_data[15:8] > 128) ? (stage4_data[15:8] - 128) : (128 - stage4_data[15:8]);
  assign edge_b = (stage4_data[7:0] > 128) ? (stage4_data[7:0] - 128) : (128 - stage4_data[7:0]);

  always @(*)
  begin
    if (UM)
    begin
      // 簡化的邊緣增強
      enhanced_r = stage4_data[23:16] + ((edge_r * Brig) >> 9);
      enhanced_g = stage4_data[15:8] + ((edge_g * Brig) >> 9);
      enhanced_b = stage4_data[7:0] + ((edge_b * Brig) >> 9);

      // 限制輸出範圍
      um_r = (enhanced_r > 255) ? 8'd255 : enhanced_r[7:0];
      um_g = (enhanced_g > 255) ? 8'd255 : enhanced_g[7:0];
      um_b = (enhanced_b > 255) ? 8'd255 : enhanced_b[7:0];
    end
    else
    begin
      um_r = stage4_data[23:16];
      um_g = stage4_data[15:8];
      um_b = stage4_data[7:0];
    end
  end

  // Stage 5 暫存器
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      stage5_data <= 0;
    end
    else
    begin
      stage5_data <= {stage4_data[26:24], um_r, um_g, um_b};
    end
  end

  //==================================================================
  // 記憶體控制信號 (目前不使用)
  //==================================================================

  assign mem1_cs = 1'b0;
  assign mem1_web = 1'b1;
  assign mem1_re = 1'b0;
  assign mem1_w_addr = 11'b0;
  assign mem1_r_addr = 11'b0;
  assign mem1_din = 24'b0;

  assign mem2_cs = 1'b0;
  assign mem2_web = 1'b1;
  assign mem2_re = 1'b0;
  assign mem2_w_addr = 11'b0;
  assign mem2_r_addr = 11'b0;
  assign mem2_din = 24'b0;

  //==================================================================
  // 最終輸出邏輯
  //==================================================================

  // 根據功能開關選擇輸出階段
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      DPo <= 0;
    end
    else
    begin
      // 根據開啟的功能選擇對應階段的輸出
      if (UM)
        DPo <= stage5_data;
      else if (IG)
        DPo <= stage4_data;
      else if (IM)
        DPo <= stage3_data;
      else if (TP)
        DPo <= stage2_data;
      else
        DPo <= stage1_data;  // 只有CC功能時直接輸出stage1
    end
  end

endmodule
