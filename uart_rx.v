// =============================================================================
// File: uart_rx.v
// Description: UART Receiver with 16x oversampling and start-bit noise rejection
//
// How it works:
//  1. Idle: wait for RX line to go LOW (start bit detected)
//  2. At tick 8 (mid-start-bit): confirm line is still LOW (noise check)
//     If HIGH again → was noise, abort back to idle
//  3. For each data bit: capture at tick 8 (center of bit period)
//     Shift incoming bit into shift_reg from MSB side (LSB first on wire)
//  4. After 8 data bits + stop bit: output data_out and pulse valid=1
//
// Frame timing (9600 baud, 16x oversample, 100 MHz clock):
//   tick_count 0..15 = one bit period (16 ticks × 651 clk = 104.16 µs)
//   Capture point = tick_count == HALF_SAMPLE (== 8)

// Features:
//   - 16× oversampling with sampling at the middle of each bit.
//   - Verifies start bit is still low at mid‑point (noise rejection).
//   - Parity check (even parity) and framing error (stop bit must be 1).
//   - Outputs rx_done, parity_error, framing_error.
// =============================================================================
module uart_rx #(
    parameter DATA_BITS  = 8,      // number of data bits per frame
    parameter OVERSAMPLE = 16      // oversampling factor (baud_tick rate)
)(
    input  clk,
    input  rst,
    input  rx,                     // serial input
    input  baud_tick,              // pulses at OVERSAMPLE × baud rate
    output reg [7:0] data_out,     // received data byte
    output reg rx_done,            // pulsed when frame is complete
    output reg parity_error,       // pulsed if parity check fails
    output reg framing_error       // pulsed if stop bit is not '1'
);

    localparam HALF_SAMPLE = OVERSAMPLE / 2;   // mid-point of each bit

    // state encoding
    localparam IDLE   = 3'b000,
               START  = 3'b001,
               DATA   = 3'b010,
               PARITY = 3'b011,
               STOP   = 3'b100;

    reg [2:0] ps, ns;             // present / next state
    reg [3:0] tick_count;         // counts baud_tick pulses within one bit
    reg [3:0] bit_count;          // counts received data bits (0..DATA_BITS-1)
    reg [7:0] shift_reg;          // incoming bits shifted in LSB first
    reg       parity_bit;         // sampled parity bit

    // --------------------------------------------------------------
    // Sequential logic: update state, sample rx, generate outputs
    // --------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ps          <= IDLE;
            tick_count  <= 0;
            bit_count   <= 0;
            shift_reg   <= 0;
            data_out    <= 0;
            parity_bit  <= 0;
            rx_done     <= 0;
            parity_error<= 0;
            framing_error<=0;
        end else begin
            ps <= ns;                     // move to next state

            // clear pulsed outputs (they stay high for only one clock)
            rx_done      <= 0;
            parity_error <= 0;
            framing_error<=0;

             if (ps == IDLE && rx == 1'b0)  tick_count <= 0; 

            // ========== baud_tick processing ==========
            else if (baud_tick) begin
                // update tick counter, wrap around after OVERSAMPLE ticks
                tick_count <= tick_count + 1;
                if (tick_count == OVERSAMPLE - 1)
                    tick_count <= 0;

                // sample rx at the middle of each bit (best noise immunity)
                if (tick_count == HALF_SAMPLE - 1) begin
                    case (ps)
                        DATA : begin
                            shift_reg <= {rx, shift_reg[7:1]}; // store LSB first
                            bit_count <= bit_count + 1;     // count received bits
                        end
                        PARITY : begin
                            parity_bit <= rx;              // capture parity bit
                        end
                        STOP : begin
                            // stop bit must be '1' – else framing error
                            framing_error <= (rx != 1'b1);
                            data_out      <= shift_reg;   // present received data
                            
                    // even parity check: parity_bit should equal XOR of data bits
                    
                            parity_error  <= (parity_bit != ^shift_reg);
                            rx_done       <= 1;                // pulse frame done
                        end
                    endcase
                end
            end

            // reset bit_count as soon as we enter START state
            // this ensures a fresh count for the new frame
            if (ps == START)
                bit_count <= 0;

        end
    end

    // --------------------------------------------------------------
    // Next‑state logic (combinational)
    // --------------------------------------------------------------
    always @(*) begin
        case (ps)
            IDLE : begin
                // falling edge on rx indicates start bit
                if (rx == 0)
                    ns = START;
                else
                    ns = IDLE;
            end

            START : begin
                // verify start bit is still low at its mid‑point
                if (baud_tick && tick_count == HALF_SAMPLE - 1) begin
                    if (rx == 0)
                        ns = DATA;          // valid start bit
                    else
                        ns = IDLE;          // false start, abort
                end else
                    ns = START;
            end

            DATA : begin
                // at the end of each bit period, decide next state
                if (baud_tick && tick_count == OVERSAMPLE - 1) begin
                    if (bit_count < DATA_BITS)   // more data bits to come
                        ns = DATA;
                    else                         // all data bits received → parity
                        ns = PARITY;
                end else
                    ns = DATA;
            end

            PARITY : begin
                // after one full bit period, move to STOP
                if (baud_tick && tick_count == OVERSAMPLE - 1)
                    ns = STOP;
                else
                    ns = PARITY;
            end

            STOP : begin
                // after the stop bit period, frame is done → go idle
                if (baud_tick && tick_count == OVERSAMPLE - 1)
                    ns = IDLE;
                else
                    ns = STOP;
            end

            default: ns = IDLE;
        endcase
    end

endmodule