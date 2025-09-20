# MATLAB Port Architecture Proposal

This directory contains a proposed MATLAB® object-oriented architecture for a
future re-implementation of PyRPL.  The goal is to retain the modular, hardware
agnostic design of the Python project while providing classes that follow MATLAB
OOP best practices.  The proposal focuses on three layers:

1. **Core services** (configuration and logging).
2. **Hardware abstraction** for the Red Pitaya / STEMlab platform.
3. **Software modules** that implement measurement and control features such as
   the network analyzer, spectrum analyzer, and lockbox.

The classes are delivered as MATLAB packages (e.g. `+pyrpl/+modules`) so that
name spaces mirror the Python package structure.  Each class contains rich
documentation and inline comments to describe how the MATLAB implementation can
interact with existing FPGA bitstreams or with simulated hardware for offline
development.

To try the architecture from MATLAB, add the `matlab` directory to the path and
instantiate the main application object:

```matlab
addpath(genpath('path/to/pyrpl/matlab'));
app = pyrpl.PyrplApp();
app.initialize();
app.start();
network = app.getModule('NetworkAnalyzer');
sweep = network.sweep(logspace(2, 5, 200));
```

The configuration file `config/default_config.json` can be edited to adapt the
hardware connection parameters or to change which software modules are
initialized at start-up.
