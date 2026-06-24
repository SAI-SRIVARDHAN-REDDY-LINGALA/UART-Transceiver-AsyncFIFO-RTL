// =============================================================================
// File: uart_tx.v
// Description: UART Transmitter with 16x oversampling
//
// How it works:
//  1. Idle: tx=1 (HIGH), waiting for start=1
//  2. On start pulse: load frame {1'b1, data_in[7:0], 1'b0} into shift_reg
//     This packs: stop=1, 8 data bits, start=0
//     Order in shift_reg (bit 9 down to bit 0):
//       [9]=stop  [8:1]=data  [0]=start-bit
//  3. Immediately output start bit: tx <= 0 (shift_reg[0])
//  4. Each OVERSAMPLE ticks = one bit period → shift right, output next bit
//  5. After 10 bits (start + 8 data + stop): busy=0, tx=1 (idle)
//
// Frame = { STOP(1), D7, D6, D5, D4, D3, D2, D1, D0, START(0) }
//         Transmitted LSB first → START bit goes out first on wire

// Features:
//   - 8N1 or 8E1 (even parity optional via PARITY_ENABLE parameter).
//   - Outputs tx_done (pulse when frame completes) and tx_count (frames sent).
//   - LSB‑first transmission, start bit (0), data, parity (if enabled), stop (1).
//   - Uses oversampling tick for bit timing.
// =============================================================================
module uart_tx #(
    parameter PARITY_ENABLE = 1,   // 1 = even parity, 0 = no parity
    parameter OVERSAMPLE    = 16   // oversampling factor (baud_tick rate)
)(
    input  clk,
    input  rst,
    input  tx_start,               // pulse to start transmission
    input  [7:0] data_in,          // byte to send
    input  baud_tick,              // pulses at OVERSAMPLE × baud rate
    output reg tx,                 // serial output
    output reg tx_done,            // pulsed when frame is complete
    output reg tx_busy,            // high while transmitting
    output reg [7:0] tx_count      // number of transmitted frames (optional)
);

    localparam IDLE  = 3'b000,
               START = 3'b001,
               DATA  = 3'b010,
               PARITY= 3'b011,
               STOP  = 3'b100;

    reg [2:0] ps, ns;              // present / next state
    reg [3:0] tick_count;          // counts baud_tick pulses within one bit period
    reg [3:0] bit_count;           // counts data bits sent (0..7)
    reg [7:0] data_reg;            // shift register for data bits (LSB first)
    reg       parity_bit;          // computed parity

    // --------------------------------------------------------------
    // Sequential logic: update counters, shift data, generate flags
    // --------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ps         <= IDLE;
            tick_count <= 0;
            bit_count  <= 0;
            data_reg   <= 0;
            tx_count   <= 0;
            parity_bit <= 0;
            tx         <= 1;
            tx_done    <= 0;
            tx_busy    <= 0;
        end else begin
            ps <= ns;                     // state transition

            // clear pulsed outputs
            tx_done <= 0;

            if(ps == IDLE && tx_start) tick_count <= 0;    
            
            // ========== baud_tick processing ==========

            else if (baud_tick) begin
                // update tick counter, wrap after OVERSAMPLE ticks
                tick_count <= tick_count + 1;
                if (tick_count == OVERSAMPLE - 1)
                    tick_count <= 0;

                // only act at the end of each bit period
                if (tick_count == OVERSAMPLE - 1) begin
                    case (ps)
                        START : begin
                            // latch data and compute parity at start of frame
                            data_reg   <= data_in;
                            parity_bit <= ^data_in;       // even parity
                            bit_count  <= 0;
                        end
                        DATA : begin
                            data_reg  <= data_reg >> 1;   // shift out LSB first
                            bit_count <= bit_count + 1;
                        end
                        STOP : begin
                            tx_count <= tx_count + 1;     // count completed frames
                            tx_done  <= 1;                // pulse frame done
                        end
                    endcase
                end
            end

            // tx_busy is derived from state (see combinational output logic)
        end
    end

    // --------------------------------------------------------------
    // Next‑state logic (combinational), gated by tick_count
    // --------------------------------------------------------------
    always @(*) begin
        case (ps)
            IDLE : begin
                // start when tx_start is asserted
                if (tx_start)
                    ns = START;
                else
                    ns = IDLE;
            end

            START : begin
                // stay in START for one full bit period, then move to DATA
                if (baud_tick && tick_count == OVERSAMPLE - 1)
                    ns = DATA;
                else
                    ns = START;
            end

            DATA : begin
                // at the end of each bit period, decide next state
                if (baud_tick && tick_count == OVERSAMPLE - 1) begin
                    if (bit_count < 7)           // more data bits to send
                        ns = DATA;
                    else                       // all 8 bits sent → parity or stop
                        ns = PARITY_ENABLE ? PARITY : STOP;
                end else
                    ns = DATA;
            end

            PARITY : begin
                // parity bit lasts one full bit period
                if (baud_tick && tick_count == OVERSAMPLE - 1)
                    ns = STOP;
                else
                    ns = PARITY;
            end

            STOP : begin
                // stop bit lasts one full bit period, then back to idle
                if (baud_tick && tick_count == OVERSAMPLE - 1)
                    ns = IDLE;
                else
                    ns = STOP;
            end

            default: ns = IDLE;
        endcase
    end

    // --------------------------------------------------------------
    // Output logic (combinational) – sets tx line and busy flag
    // --------------------------------------------------------------
    always @(*) begin
        // default values
        tx      = 1;
        tx_busy = 0;

        case (ps)
            IDLE : begin
                tx      = 1;        // idle line high
                tx_busy = 0;
            end
            START: begin
                tx      = 0;        // start bit low
                tx_busy = 1;
            end
            DATA : begin
                tx      = data_reg[0];   // send LSB first
                tx_busy = 1;
            end
            PARITY: begin
                tx      = parity_bit;    // send parity bit
                tx_busy = 1;
            end
            STOP : begin
                tx      = 1;        // stop bit high
                tx_busy = 1;
                // tx_done is pulsed in sequential block
            end
        endcase
    end

endmodule