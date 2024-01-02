# RISC-V-CPU

[Project Introduction](https://github.com/ACMClassCourse-2022/RISC-V-CPU-2023)

## Design

```mermaid
flowchart TD
    A(RAM) --- B(Memory Controller)
    B --- C(ICache)
    C --> D(IFetcher)
    D --> E(Dispatcher)
    D --- M(Decoder)
    D --- N(Predictor)
    E --> F(Reservation Station)
    E --> G(Reorder Buffer)
    F --> G
    G --- H(Register File)
    E --> H
    G --> I(Load Store Buffer)
    I --> B
    I --> J(CDB-L)
    F --> K(ALU)
    K --> L(CDB-A)
```
