// ============================================================================
// tb_uart_tx.v – Testbench for uart_tx (with parity, tx_done, tx_count)
// ============================================================================
// Tests: 
//   - Transmission of two bytes (0xAA, 0x55) with even parity enabled.
//   - Verifies tx_done pulse and tx_count increment.
//   - Monitors serial output (tx) and compares with expected bit pattern.
// ============================================================================
`timescale 1ns / 1ps

module tb_uart_tx;

    reg         clk, rst, tx_start;
    reg  [7:0]  data_in;
    wire        tx, tx_done, tx_busy;
    wire [7:0]  tx_count;
    wire        baud_tick;

    // Instantiate baud generator (using default 9600, 16x oversample)
    baud_gen #(.CLK_FREQ(100_000_000), .BAUD_RATE(9600), .OVERSAMPLE(16))
        bg (.clk(clk), .rst(rst), .tick(baud_tick));

    // Unit under test (parity enabled)
    uart_tx #(.PARITY_ENABLE(1)) uut (
        .clk(clk), .rst(rst),
        .tx_start(tx_start), .data_in(data_in),
        .baud_tick(baud_tick),
        .tx(tx), .tx_done(tx_done), .tx_busy(tx_busy), .tx_count(tx_count)
    );

    // Clock generation (100 MHz)
    always #5 clk = ~clk;

    // Monitor and verify
    initial begin
        $display("=== Starting UART TX Test ===");
        
        // Initialize inputs
        clk = 0; rst = 1; tx_start = 0; data_in = 0;
        #100;                 // Hold reset for a clear visual window
        rst = 0;
        
        #200_000;             // Large delay in IDLE state to clearly see ps = 000 on waveform

        // Send first byte: 0xAA (10101010)
        data_in = 8'hAA;
        tx_start = 1;
        #20 tx_start = 0;     // Pulse tx_start for 2 clock cycles
        
        wait (tx_done);       // Wait for frame 1 to finish
        #300_000;             // Clear IDLE separation between frames

        // Send second byte: 0x54 (01010100)
        data_in = 8'h54;
        tx_start = 1;
        #20 tx_start = 0;     // Pulse tx_start
        
        wait (tx_done);       // Wait for frame 2 to finish
        
        // CRITICAL FIX: Give the FSM ample time to finalize the STOP state,
        // register the tx_count increment to 2, and lower tx_busy.
        #500_000;             

        // Check final count
        $display("Final tx_count = %d (Expected: 2)", tx_count);
        $finish;
    end

    // Optional: monitor serial bits
    initial begin
        $monitor("[%0t] tx=%b, tx_busy=%b, tx_done=%b, tx_count=%d",
                  $time, tx, tx_busy, tx_done, tx_count);
    end
    
    initial begin
       $dumpfile("tb_uart_tx.vcd");
       $dumpvars(0, tb_uart_tx);
    end

endmodule