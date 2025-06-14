//MEM2048X24.v already include in tb
//沒用的城市 先給你們撐場面用

module HDL_final(
    input clk,
    input rst_n,
    input CC,
    input TP,
    input IM,
    input IG,
    input UM,
    input [7:0] Brig,
    input [26:0] DPi,

    input [2:0] Sync_IM,
    input [2:0] Sync_IG,
    input [2:0] Sync_UM,

    output reg [26:0] DPo
  );

  // Pipeline stages
  reg [26:0] pipe_stage1, pipe_stage2, pipe_stage3, pipe_stage4;

  // Counters for pixel position tracking
  reg [10:0] h_cnt, v_cnt;

  // Memory interface for IM function
  reg [10:0] mem_addr_w, mem_addr_r;
  reg [23:0] mem_data_in, mem_data_out;
  reg mem_web, mem_cs, mem_re;

  // Buffer for IG function (2x2 grid)
  reg [23:0] grid_buf [0:3];
  reg [1:0] grid_idx;
  reg [9:0] grid_avg_r, grid_avg_g, grid_avg_b;

  // Position tracking
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      h_cnt <= 0;
      v_cnt <= 0;
    end
    else
    begin
      if (DPi[26])
      begin // VSync
        h_cnt <= 0;
        v_cnt <= 0;
      end
      else if (DPi[25])
      begin // HSync
        h_cnt <= 0;
        if (v_cnt < 1079)
          v_cnt <= v_cnt + 1;
      end
      else if (DPi[24])
      begin // Data Enable
        if (h_cnt < 1919)
          h_cnt <= h_cnt + 1;
      end
    end
  end

  // Memory for IM function
  MEM2048X24 mem_inst (
               .CK(clk),
               .CS(mem_cs),
               .WEB(mem_web),
               .RE(mem_re),
               .R_ADDR(mem_addr_r),
               .W_ADDR(mem_addr_w),
               .D_IN(mem_data_in),
               .D_OUT(mem_data_out)
             );

  // Stage 1: Color Correction (CC)
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      pipe_stage1 <= 0;
    end
    else
    begin
      pipe_stage1[26:24] <= DPi[26:24]; // Always pass sync signals

      if (CC && DPi[24])
      begin
        reg [7:0] R, G, B, Y, U, V;
        reg [7:0] R_new, G_new, B_new;

        R = DPi[23:16];
        G = DPi[15:8];
        B = DPi[7:0];

        // RGB to YUV (simplified)
        Y = (R >> 2) + (G >> 1) + (B >> 3);
        U = B - Y + 128;
        V = R - Y + 128;

        // Brightness adjustment based on position
        if (v_cnt >= 540)
        begin
          // Lower half: negative
          Y = 255 - Y;
        end
        else
        begin
          // Upper half: quadrant-based brightness adjustment
          if (h_cnt < 960 && v_cnt < 270)
            Y = (Y > Brig) ? Y - Brig : 0;
          else if (h_cnt >= 960 && v_cnt < 270)
            Y = (Y > (Brig>>1)) ? Y - (Brig>>1) : 0;
          else if (h_cnt < 960)
            Y = (Y + (Brig>>1) < 255) ? Y + (Brig>>1) : 255;
          else
            Y = (Y + Brig < 255) ? Y + Brig : 255;
        end

        // YUV to RGB (simplified)
        R_new = Y + (V > 128 ? (V-128)>>1 : 0);
        G_new = Y - ((U > 128 ? (U-128)>>2 : 0) + (V > 128 ? (V-128)>>2 : 0));
        B_new = Y + (U > 128 ? (U-128)>>1 : 0);

        pipe_stage1[23:0] <= {R_new, G_new, B_new};
      end
      else
      begin
        pipe_stage1[23:0] <= DPi[23:0];
      end
    end
  end

  // Stage 2: Test Pattern (TP)
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      pipe_stage2 <= 0;
    end
    else
    begin
      pipe_stage2[26:24] <= pipe_stage1[26:24]; // Pass sync signals

      if (TP && pipe_stage1[24])
      begin
        if (h_cnt < 960)
        begin
          // Situation 1: R,B gradient
          pipe_stage2[23:16] <= 255 - h_cnt[7:0]; // R
          pipe_stage2[15:8] <= 0;                 // G
          pipe_stage2[7:0] <= 255 - h_cnt[7:0];   // B
        end
        else
        begin
          // Situation 2: Circle pattern
          reg [10:0] dx, dy;
          reg [21:0] dist_sq;
          reg [7:0] gray_val;

          dx = (h_cnt > 960) ? h_cnt - 960 : 960 - h_cnt;
          dy = (v_cnt > 540) ? v_cnt - 540 : 540 - v_cnt;
          dist_sq = dx*dx + dy*dy;

          if (dist_sq < 65536) // R=256
            pipe_stage2[23:0] <= 0;
          else
          begin
            gray_val = (dist_sq < 131072) ? (255 - dist_sq[15:8]) : 255;
            pipe_stage2[23:0] <= {gray_val, gray_val, gray_val};
          end
        end
      end
      else
      begin
        pipe_stage2[23:0] <= pipe_stage1[23:0];
      end
    end
  end

  // Stage 3: Image Mirror (IM) - Simplified version
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      pipe_stage3 <= 0;
      mem_addr_w <= 0;
      mem_addr_r <= 0;
      mem_web <= 0;
      mem_cs <= 1;
      mem_re <= 1;
    end
    else
    begin
      pipe_stage3[26:24] <= pipe_stage2[26:24]; // Pass sync signals

      // For now, just pass through data to avoid hanging
      // TODO: Implement proper line buffering for horizontal flip
      pipe_stage3[23:0] <= pipe_stage2[23:0];

      mem_web <= 0; // Disable memory write for now
    end
  end

  // Stage 4: Image Grid (IG) - Simplified
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      pipe_stage4 <= 0;
      grid_idx <= 0;
    end
    else
    begin
      pipe_stage4[26:24] <= pipe_stage3[26:24]; // Pass sync signals

      if (IG && pipe_stage3[24])
      begin
        // Simple 2x2 averaging (simplified implementation)
        if (h_cnt[0] == 0 && v_cnt[0] == 0)
        begin
          // Even pixel positions - store for averaging
          grid_buf[0] <= pipe_stage3[23:0];
          pipe_stage4[23:0] <= pipe_stage3[23:0];
        end
        else
        begin
          // For now, just pass through
          pipe_stage4[23:0] <= pipe_stage3[23:0];
        end
      end
      else
      begin
        pipe_stage4[23:0] <= pipe_stage3[23:0];
      end
    end
  end

  // Final Stage: Unsharp Mask (UM) and Output
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      DPo <= 0;
    end
    else
    begin
      DPo[26:24] <= pipe_stage4[26:24]; // Always pass sync signals

      if (UM && pipe_stage4[24])
      begin
        // Simplified unsharp mask: enhance edges
        reg [7:0] enhanced_r, enhanced_g, enhanced_b;
        reg [7:0] edge_r, edge_g, edge_b;

        // Simple edge detection (difference from half intensity)
        edge_r = (pipe_stage4[23:16] > 128) ? (pipe_stage4[23:16] - 128) : (128 - pipe_stage4[23:16]);
        edge_g = (pipe_stage4[15:8] > 128) ? (pipe_stage4[15:8] - 128) : (128 - pipe_stage4[15:8]);
        edge_b = (pipe_stage4[7:0] > 128) ? (pipe_stage4[7:0] - 128) : (128 - pipe_stage4[7:0]);

        // Enhanced = Original + (alpha/256) * Edge
        enhanced_r = (pipe_stage4[23:16] + ((edge_r * Brig) >> 8) < 255) ?
                   pipe_stage4[23:16] + ((edge_r * Brig) >> 8) : 255;
        enhanced_g = (pipe_stage4[15:8] + ((edge_g * Brig) >> 8) < 255) ?
                   pipe_stage4[15:8] + ((edge_g * Brig) >> 8) : 255;
        enhanced_b = (pipe_stage4[7:0] + ((edge_b * Brig) >> 8) < 255) ?
                   pipe_stage4[7:0] + ((edge_b * Brig) >> 8) : 255;

        DPo[23:0] <= {enhanced_r, enhanced_g, enhanced_b};
      end
      else
      begin
        DPo[23:0] <= pipe_stage4[23:0];
      end
    end
  end

endmodule
