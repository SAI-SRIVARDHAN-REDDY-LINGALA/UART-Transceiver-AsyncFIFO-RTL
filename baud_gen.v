// =============================================================================
// File: baud_gen.v
// Description: Baud Rate Generator with 16x oversampling
//
// For Basys3 (100 MHz clock), 9600 baud, 16x oversample:
//   DIVISOR = 100_000_000 / (16 * 9600) = 651
//   Fires one 'tick' pulse every 651 clock cycles
//   Each bit period = 16 ticks = 16 * 651 * 10ns = 104,160 ns ≈ 104.17 µs
//   Baud error = (104,160 - 104,167) / 104,167 = ~0.007% (negligible)
// =============================================================================
module baud_gen #(
    parameter CLK_FREQ   = 100_000_000,
    parameter BAUD_RATE  = 9600,
    parameter OVERSAMPLE = 16
)(
    input  clk,
    input  rst,
    output reg tick
);
    localparam DIVISOR = CLK_FREQ / (BAUD_RATE * OVERSAMPLE);
    reg [$clog2(DIVISOR)-1:0] counter;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            tick    <= 0;
        end else begin
            if (counter == DIVISOR - 1) begin
                counter <= 0;
                tick    <= 1;
            end else begin
                counter <= counter + 1;
                tick    <= 0;
            end
        end
    end
endmodule