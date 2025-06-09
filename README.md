# Simple Switch Fabric

A parameterizable network switch fabric implementation in SystemVerilog that routes data between multiple inputs and outputs based on destination addressing.

## Overview

This design implements a simple but functional switch fabric that can handle multiple simultaneous data flows with minimal latency. The switch uses input buffering and priority-based arbitration to manage contention while supporting both parallel and serialized data routing.

## Features

- **Parameterizable Design**: Configurable number of inputs, outputs, and data width
- **Low Latency**: 1-cycle FIFO latency plus combinational routing logic  
- **Input Buffering**: Each input has dedicated FIFO to prevent data loss
- **Priority Arbitration**: Lower-indexed inputs have priority during contention
- **Parallel Processing**: Multiple non-conflicting flows processed simultaneously
- **Serialization**: Automatic serialization when multiple inputs target same output
- **No Data Loss**: Buffering prevents dropping except during sustained oversubscription

## Architecture

### Core Components

1. **Input FIFOs**: 16-deep buffers for each input storing data + destination
2. **Request Matrix**: Combinational logic identifying input→output requests  
3. **Priority Arbiters**: Per-output arbitration selecting lowest-index requester
4. **Output Multiplexers**: Route selected input data to appropriate outputs

### Data Flow

```
Input → FIFO → Request Matrix → Priority Arbiter → Output Mux → Output
         ↑           ↓              ↓
      Buffer      Identify       Select
      + Dest      Conflicts      Winner
```

## Module Interface

### Parameters
- `DATA_WIDTH`: Width of data words (default: 64, max: 64)
- `INPUT_QTY`: Number of input ports (default: 8, max: 64)  
- `OUTPUT_QTY`: Number of output ports (default: 8, max: 64)

### Ports

#### Inputs
- `clk`: System clock
- `reset`: Synchronous active-high reset
- `data_in_valid[INPUT_QTY-1:0]`: Valid signal for each input
- `data_in[INPUT_QTY-1:0][DATA_WIDTH-1:0]`: Input data words
- `data_in_destination[INPUT_QTY-1:0][$clog2(OUTPUT_QTY)-1:0]`: Destination for each input

#### Outputs  
- `data_out_valid[OUTPUT_QTY-1:0]`: Valid signal for each output
- `data_out[OUTPUT_QTY-1:0][DATA_WIDTH-1:0]`: Output data words

## Usage Example

```systemverilog
// Instantiate 4x4 switch with 32-bit data
very_simple_switch #(
    .DATA_WIDTH(32),
    .INPUT_QTY(4), 
    .OUTPUT_QTY(4)
) switch_inst (
    .clk(clk),
    .reset(reset),
    .data_in_valid(in_valid),
    .data_in(in_data),
    .data_in_destination(in_dest),
    .data_out_valid(out_valid),
    .data_out(out_data)
);
```

## Behavioral Characteristics

### Parallel Operation
When inputs target different outputs, data flows in parallel:
```
Input 0 → Output 2 ┐
Input 1 → Output 0 ├─ All simultaneous  
Input 2 → Output 3 ┘
```

### Serialized Operation  
When inputs target the same output, priority arbitration applies:
```
Input 0 → ┐
Input 2 → ├─ Output 1 (Input 0 wins, Input 2 queued)
Input 5 → ┘
```

### Priority Order
Lower-indexed inputs always have priority:
- Input 0 > Input 1 > Input 2 > ... > Input N

## File Structure

```
├── very_simple_switch.sv    # Main switch fabric module + FIFO
├── tb_very_simple_switch.sv # Comprehensive testbench
└── README.md               # This file
```

## Testing

The included testbench (`tb_very_simple_switch.sv`) provides comprehensive verification:

### Test Cases
1. **Reset Test**: Verify clean reset behavior
2. **Single Routing**: Basic input→output functionality  
3. **Parallel Routing**: Multiple non-conflicting flows
4. **Serialization**: Multiple inputs to same output
5. **Mixed Scenarios**: Combination of parallel and serialized
6. **Burst Traffic**: High-throughput sustained traffic
7. **Edge Cases**: Invalid destinations, boundary conditions
8. **Continuous Traffic**: Random traffic patterns

### Running Tests

Using Icarus Verilog:
```bash
iverilog -g2012 -o switch_test very_simple_switch.sv tb_very_simple_switch.sv
vvp switch_test
```

With waveform viewing:
```bash
gtkwave switch_fabric.vcd
```

## Performance Characteristics

### Latency
- **Minimum**: 1 clock cycle (FIFO latency)
- **Typical**: 1 clock cycle for non-conflicting traffic
- **Maximum**: 1 + N cycles where N is serialization depth

### Throughput
- **Peak**: 1 word per cycle per output  
- **Sustained**: Depends on traffic pattern and conflicts
- **Bottleneck**: Input priority during contention

### Resource Usage
- **Memory**: 16 × INPUT_QTY × (DATA_WIDTH + log₂(OUTPUT_QTY)) bits
- **Logic**: Combinational arbiters + muxes, minimal sequential logic

## Design Decisions

### Input Buffering
- Chose input-side buffering over output-side for simpler arbitration
- 16-deep FIFOs provide reasonable buffering for most scenarios
- Show-ahead mode minimizes latency

### Priority Arbitration  
- Simple fixed-priority scheme for deterministic behavior
- Could be enhanced with round-robin for fairness if needed
- Lowest-index priority matches typical hardware conventions

### Combinational Outputs
- Output data/valid generated combinationally for minimum latency
- Trade-off: More complex timing but better performance

## Limitations

1. **Fixed Priority**: No fairness mechanism between inputs
2. **No Flow Control**: Outputs cannot backpressure inputs
3. **Buffer Depth**: Fixed 16-entry FIFOs may not suit all applications
4. **No QoS**: All traffic treated equally

## Future Enhancements

- Round-robin arbitration for fairness
- Configurable FIFO depths
- Output flow control/backpressure
- Traffic shaping and QoS features
- Performance counters and monitoring

## License

This design is provided as-is for educational and development purposes.
