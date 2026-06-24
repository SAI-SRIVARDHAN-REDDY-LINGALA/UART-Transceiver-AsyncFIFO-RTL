// =============================================================================
// File: uart_top.v
// Description: UART Transceiver Core — combines baud_gen, uart_rx, uart_tx
//
// This is the "engine" layer. It handles all low-level UART bit timing.
// The higher-level application module sits on top of this and only deals
// with bytes, not individual bits.
//
// Features:
//   - Instantiates baud_gen, uart_tx, uart_rx.
//   - Exposes all useful signals: tx_busy, tx_done, tx_count,
//     rx_data, rx_valid, parity_error, framing_error.
// =============================================================================
module uart_top (
    input  clk,
    input  rst,
    input  rx,
    input  tx_start,
    input  [7:0] tx_data,
    output tx,
    output tx_busy,
    output tx_done,
    output [7:0] tx_count,
    output [7:0] rx_data,
    output rx_valid,
    output parity_error,
    output framing_error
);
    wire baud_tick;
    baud_gen brg (.clk(clk), .rst(rst), .tick(baud_tick));
    
    
    uart_rx rx_inst (
        .clk(clk), .rst(rst), .rx(rx), .baud_tick(baud_tick),
        .data_out(rx_data), .rx_done(rx_valid),
        .parity_error(parity_error), .framing_error(framing_error)
    );
    
    
    uart_tx tx_inst (
        .clk(clk), .rst(rst), .tx_start(tx_start), .data_in(tx_data),
        .baud_tick(baud_tick),
        .tx(tx), .tx_done(tx_done), .tx_busy(tx_busy), .tx_count(tx_count)
    );
    
    
endmodule