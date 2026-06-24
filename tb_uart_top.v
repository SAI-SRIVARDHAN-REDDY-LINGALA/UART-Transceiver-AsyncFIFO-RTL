// ============================================================================
// tb_uart_top.v – Loopback test for uart_top
// ============================================================================
// Connects tx to rx internally, sends a byte, verifies reception with errors.
// ============================================================================
`timescale 1ns / 1ps

module tb_uart_top;
    reg         clk, rst, tx_start;
    reg  [7:0]  tx_data;
    
    wire        tx;             // Transmitter output
    wire        rx;             // Loopback receiver input
    wire        tx_busy, tx_done;
    wire [7:0]  tx_count;
    wire [7:0]  rx_data;
    wire        rx_valid, parity_error, framing_error;

  

    // NEW (breaks the delta‑cycle race)
assign #1 rx = tx;   // 1 ns transport delay

    // --- Unit Under Test ---
    uart_top uut (
        .clk(clk), .rst(rst),
        .rx(rx),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done),
        .tx_count(tx_count),
        .rx_data(rx_data), .rx_valid(rx_valid),
        .parity_error(parity_error), .framing_error(framing_error)
    );

    // 100 MHz clock generation (10ns period)
    always #5 clk = ~clk;

 initial begin
        $display("=== Starting UART Top Loopback Test ===");
        
        // --- 1. SYSTEM INITIALIZATION & RESET ---
        clk = 0; rst = 1; tx_start = 0; tx_data = 0;
        #200;
        rst = 0;
        #100_000; 

        // ------------------------------------------------------------------
        // TEST 1: Transmit & Receive 8'hA5
        // ------------------------------------------------------------------
        $display("[%0t ns] Test 1: Sending 0xA5 over Loopback", $time);
        tx_data  = 8'hA5;
        tx_start = 1;
        #50;                 
        tx_start = 0;
        
        // Dynamic wait: Wait exactly until the RX engine signals completion
        wait (rx_valid);
        #10; // Small step to let data settle on the bus cleanly

        if (!parity_error && !framing_error && (rx_data == 8'hA5))
            $display("  => PASS: Loopback received 0x%h accurately!", rx_data);
        else
            $display("  => FAIL: Frame 1 Error. rx_valid=%b, parity_err=%b, data=0x%h", rx_valid, parity_error, rx_data);

        // Wait for the TX hardware to completely unwind to idle before starting next test
        wait (!tx_busy);
        #200_000;

        // ------------------------------------------------------------------
        // TEST 2: Transmit & Receive 8'h5A
        // ------------------------------------------------------------------
        $display("[%0t ns] Test 2: Sending 0x5A over Loopback", $time);
        tx_data  = 8'h5A;
        tx_start = 1;
        #50;
        tx_start = 0;
        
        // Dynamic wait for receiver path
        wait (rx_valid);
        #10;

        if (!parity_error && !framing_error && (rx_data == 8'h5A))
            $display("  => PASS: Loopback received 0x%h accurately!", rx_data);
        else
            $display("  => FAIL: Frame 2 Error. rx_valid=%b, parity_err=%b, data=0x%h", rx_valid, parity_error, rx_data);

        #100_000;
        $display("=== UART TOP LOOPBACK COMPLETED ===");
        $finish;
    end

    // --- Waveform Dumps for EPWave ---
    initial begin
        $dumpfile("tb_uart_top.vcd");
        $dumpvars(0, tb_uart_top);
    end

    // --- Track updates live in console logs ---
    initial begin
        $monitor("Time=%0t ns | tx_busy=%b | tx_done=%b | rx_valid=%b | rx_data=0x%h",
                  $time, tx_busy, tx_done, rx_valid, rx_data);
    end

endmodule