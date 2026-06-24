// `timescale 1ns / 1ps

// module tb_uart_rx;
//     reg         clk, rst, rx;
//     wire        baud_tick;
//     wire [7:0]  data_out;
//     wire        rx_done, parity_error, framing_error;

//     // Instantiate baud generator (Assumes default 9600 baud, 16x oversample from your project)
//     baud_gen bg (.clk(clk), .rst(rst), .tick(baud_tick));

//     // Unit under test
//     uart_rx uut (
//         .clk(clk), .rst(rst),
//         .rx(rx), .baud_tick(baud_tick),
//         .data_out(data_out), .rx_done(rx_done),
//         .parity_error(parity_error), .framing_error(framing_error)
//     );

//     // Clock generation (100 MHz clock -> 10ns period)
//     always #5 clk = ~clk;

//     // Task to send a standard UART frame
//     task send_frame(input [7:0] data, input parity, input stop);
//         integer i;
//         begin
//             // 1. Start bit (0)
//             rx = 0;
//             #104170;  // Exact bit period for 9600 baud 
//                         // (1 / 9600 ~ 104.167 us)
        
//             // 2. Data bits (LSB first)
//             for (i=0; i<8; i=i+1) begin
//                 rx = data[i];
//                 #104170;
//             end
            
//             // 3. Parity bit
//             rx = parity;
//             #104170;
            
//             // 4. Stop bit
//             rx = stop;
//             #104170;
            
//             // 5. Force clear back to Idle (1)
//             rx = 1;
//             #104170;
//         end
//     endtask

//     initial begin
//         $display("=== Starting UART RX Test ===");
        
//         // --- System Initialization ---
//         clk = 0; rst = 1; rx = 1;
//         #200;                    // Hold reset visibly on the waveform
//         rst = 0;
//         #50_000;                 // Let the system settle in IDLE

//         // ------------------------------------------------------------------
//         // Test 1: Good Frame (0xAA)
//         // Expected Parity bit: 0xAA (10101010) has an even number of 1s (4).
//         // Therefore, Even Parity bit = ^(8'hAA) = 0.
//         // ------------------------------------------------------------------
//         $display("[%0t] Test 1: Sending Good Frame (0xAA, Parity=0, Stop=1)", $time);
//         send_frame(8'hAA, 1'b0, 1'b1); 
        
//         wait(rx_done);           // Wait for FSM to capture the stop bit and pulse rx_done
//         #100;                    // Small hold time
//         if (!parity_error && !framing_error && (data_out == 8'hAA))
//             $display("  => PASS: Good frame received. data=0x%h", data_out);
//         else
//             $display("  => FAIL: Good frame error. parity_err=%b, framing_err=%b, data=0x%h", 
//                      parity_error, framing_error, data_out);

//         #300_000;                // Waveform buffer space to clearly visualize IDLE state

//         // ------------------------------------------------------------------
//         // Test 2: Bad Parity Frame
//         // Sending 0xAA but forcing an incorrect parity bit of '1'.
//         // ------------------------------------------------------------------
//         $display("[%0t] Test 2: Sending Frame with Intentional Parity Error", $time);
//         send_frame(8'hAA, 1'b1, 1'b1); 
        
//         wait(rx_done);
//         #100;
//         if (parity_error)
//             $display("  => PASS: Parity error correctly detected!");
//         else
//             $display("  => FAIL: Parity error went unnoticed.");

//         #300_000;                // Waveform buffer space

//         // ------------------------------------------------------------------
//         // Test 3: Framing Error
//         // Sending 0x55 with valid parity (0x55 has four 1s -> Parity=0), 
//         // but forcing an invalid Stop bit ('0').
//         // ------------------------------------------------------------------
//         $display("[%0t] Test 3: Sending Frame with Intentional Framing Error (Stop=0)", $time);
//         send_frame(8'h55, 1'b0, 1'b0); 
        
//         wait(rx_done);
//         #100;
//         if (framing_error)
//             $display("  => PASS: Framing error correctly detected!");
//         else
//             $display("  => FAIL: Framing error went unnoticed.");

//         #300_000;                // Waveform buffer space

//         // ------------------------------------------------------------------
//         // Test 4: Noise Glitch Rejection
//         // Pulling RX low for 10 us, which is significantly below the half-bit
//         // window (~52 us). FSM should sample it at tick 7/8, detect noise, and abort.
//         // ------------------------------------------------------------------
//         $display("[%0t] Test 4: Generating an RX Noise Glitch (10 us low pulse)", $time);
//         rx = 0;
//         #10_000;                 // 10 microseconds low pulse
//         rx = 1;                  // Line pulls back high before the mid-point check
        
//         #250_000;                // Wait long enough to verify the receiver safely stays in IDLE
//         if (!rx_done)
//             $display("  => PASS: Noise glitch successfully ignored. Receiver remained safe.");
//         else
//             $display("  => FAIL: Noise glitch accidentally triggered a data frame capture.");

//         #100_000;
//         $display("=== UART RX Test Bench Completed ===");
//         $finish;
//     end

//     // --- Waveform Generation Output Block ---
//     initial begin
//         $dumpfile("tb_uart_rx.vcd");
//         $dumpvars(0, tb_uart_rx);
//     end

//     // --- System Status Monitor ---
//     initial begin
//         $monitor("[%0t ns] rx=%b | state=%b | data_out=0x%h | rx_done=%b | parity_err=%b | framing_err=%b",
//                   $time, rx, uut.ps, data_out, rx_done, parity_error, framing_error);
//     end

// endmodule




// SIMPLE ONE 

`timescale 1ns / 1ps

module tb_uart_rx;
    reg         clk, rst, rx;
    wire        baud_tick;
    wire [7:0]  data_out;
    wire        rx_done;

    // Instantiate simple baud generator
    baud_gen bg (.clk(clk), .rst(rst), .tick(baud_tick));

    // Unit under test
    uart_rx uut (
        .clk(clk), .rst(rst), .rx(rx), .baud_tick(baud_tick),
        .data_out(data_out), .rx_done(rx_done),
        .parity_error(), .framing_error() 
    );

    // 100 MHz clock generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        // --- 1. SYSTEM INITIALIZATION & RESET ---
        clk = 0; rst = 1; rx = 1;
        #200;
        rst = 0;
        
        // --- 2. PROPER VISIBLE INITIAL IDLE STATE ---
        // Holding rx high for 2 full bit periods so you can see IDLE (State 000) cleanly on EPWave
        #208340; 

        $display("=== STARTING SINGLE FRAME TEST ===");

        // --- 3. TRANSMIT UART FRAME (8'hA5) ---
        // Start bit (0)
        rx = 0; #104170;

        // Send Data 8'hA5 (LSB to MSB: 1, 0, 1, 0, 0, 1, 0, 1)
        rx = 1; #104170; // bit 0
        rx = 0; #104170; // bit 1
        rx = 1; #104170; // bit 2
        rx = 0; #104170; // bit 3
        rx = 0; #104170; // bit 4
        rx = 1; #104170; // bit 5
        rx = 0; #104170; // bit 6
        rx = 1; #104170; // bit 7

        // Parity bit (Even parity = 0)
        rx = 0; #104170;

        // Stop bit (1)
        rx = 1; #104170;

        // --- 4. PROPER VISIBLE ENDING IDLE STATE ---
        // Keep rx high for another 2 bit periods after the frame completes 
        // This lets you see the FSM fall back to state 000 and rest there.
        #208340; 

        $display("=== TEST COMPLETED ===");
        $finish;
    end

    initial begin
        $monitor("Time=%0t ns | RX=%b | State=%b | Data_Out=0x%h | RX_Done=%b", 
                 $time, rx, uut.ps, data_out, rx_done);
    end

        //    Waveform Generation Output Block 
    initial begin
        $dumpfile("tb_uart_rx.vcd");
        $dumpvars(0, tb_uart_rx);
    end


endmodule

