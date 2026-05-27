# 📡 OFDM Transceiver System Simulation

> A complete end-to-end **Orthogonal Frequency Division Multiplexing (OFDM)** transceiver simulation implemented in GNU Octave, featuring **BPSK**, **QPSK**, and **8-PSK** modulation schemes with AWGN and Rayleigh fading channel models.

---

## 📌 Project Description

This project simulates a full **PHY (Physical Layer)** pipeline of a modern wireless communication system, closely modelled after the **IEEE 802.11a (Wi-Fi)** standard. It demonstrates the entire transmitter–channel–receiver chain from random bit generation to BER analysis.

The simulation covers:
- **M-PSK Modulation** with Gray coding (BPSK, QPSK, 8-PSK)
- **IFFT-based OFDM** signal generation with subcarrier allocation
- **Cyclic prefix** insertion and removal to combat Inter-Symbol Interference (ISI)
- **AWGN and Rayleigh fading** channel models
- **Pilot-based LS (Least Squares)** channel estimation with linear interpolation
- **Frequency-domain equalization** (one-tap per subcarrier)
- **BER vs SNR** performance analysis with theoretical overlay curves
- **EVM (Error Vector Magnitude)** analysis
- **Spectral efficiency** comparison against Shannon bound
- **Constellation diagram** visualization at multiple SNR points

---

## 🖼️ Preview
<img width="1165" height="900" alt="fig4_constellations" src="https://github.com/user-attachments/assets/c3d389f0-0d95-4100-b87e-b12b69f316bc" />


## 📊 Results

### BER vs SNR — AWGN Channel

<img width="872" height="654" alt="fig1_ber_awgn" src="https://github.com/user-attachments/assets/17be0b0e-296a-4b43-bd34-18d1df174abb" />


The simulated BER curves closely match the theoretical formulas, confirming the correctness of the implementation:

| Modulation | Bits/Symbol | SNR for BER < 10⁻³ (AWGN) | Spectral Efficiency |
|:---:|:---:|:---:|:---:|
| BPSK | 1 | ~8 dB | Low — most robust |
| QPSK | 2 | ~12 dB | 2× BPSK throughput, same BER |
| 8-PSK | 3 | > 30 dB | High throughput, noise-sensitive |

---

### BER vs SNR — Rayleigh Fading Channel

<img width="872" height="654" alt="fig2_ber_rayleigh" src="https://github.com/user-attachments/assets/6542146e-1a9b-4876-8649-bae6c6401214" />


### AWGN vs Rayleigh — Side-by-Side Comparison

<img width="1271" height="402" alt="fig3_awgn_vs_rayleigh" src="https://github.com/user-attachments/assets/46c30a72-f00c-45d0-91c9-1b5cdbf77d01" />


---

### Constellation Diagrams (TX · AWGN RX · Rayleigh RX)
<img width="1165" height="900" alt="fig4_constellations" src="https://github.com/user-attachments/assets/827d0401-ad64-4284-baaf-963e78227fc7" />

---

### Error Vector Magnitude (EVM) vs SNR

<img width="872" height="654" alt="fig5_evm" src="https://github.com/user-attachments/assets/5fb2f1fd-71a1-47ba-958f-38152ae6c076" />


---

### OFDM Signal Analysis

<img width="1165" height="794" alt="fig6_signal_analysis" src="https://github.com/user-attachments/assets/9b572b3d-1a5f-455d-81f3-1d0ef02622b2" />


---

### Spectral Efficiency vs Shannon Bound

<img width="872" height="654" alt="fig7_spectral_efficiency" src="https://github.com/user-attachments/assets/bd096ae7-f618-4656-9db7-4a76858d1769" />


---

### BER Heatmap


<img width="1059" height="402" alt="fig8_ber_heatmap" src="https://github.com/user-attachments/assets/6c2e2cf7-70ac-4ce8-8199-326940d4fd10" />

---

### SNR Requirements for BER Targets


<img width="953" height="529" alt="fig9_snr_requirements" src="https://github.com/user-attachments/assets/da90dba3-1a93-4400-873f-80415ae52e9b" />

---

## ⚙️ System Architecture

```
┌─────────────────────────────── TRANSMITTER ───────────────────────────────┐
│                                                                             │
│  Random Bits → M-PSK Mod → S2P + Subcarrier Map → IFFT → CP Insert → TX  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                          ┌───────────▼───────────┐
                          │   CHANNEL MODEL        │
                          │  AWGN  /  Rayleigh     │
                          └───────────┬───────────┘
                                      │
┌─────────────────────────────── RECEIVER ──────────────────────────────────┐
│                                                                             │
│  RX → CP Remove → FFT → LS Channel Est. → Equalize → M-PSK Demod → Bits  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📐 System Parameters

| Parameter | Value | Description |
|:---|:---:|:---|
| FFT Size (N) | 64 | Total subcarriers |
| Cyclic Prefix | 16 samples | 25% of FFT size (ISI guard) |
| Data Subcarriers | 48 | Active data-carrying subcarriers |
| Pilot Subcarriers | 4 | At indices 7, 21, 43, 57 |
| Guard Bands + DC | 12 | Prevent aliasing and DC offset |
| OFDM Symbols/SNR | 80 | Per simulation point |
| SNR Range | 0 to 30 dB | Step size: 2 dB |
| Modulation Schemes | BPSK, QPSK, 8-PSK | M = 2, 4, 8 |
| Channel Models | AWGN, Rayleigh | With LS equalization |

---


### Step 4 — View Results

All output figures are saved as `.png` files in the `ofdm_results/` folder:

```
ofdm_results/
├── fig1_ber_awgn.png            ← BER vs SNR (AWGN)
├── fig2_ber_rayleigh.png        ← BER vs SNR (Rayleigh + equalization)
├── fig3_awgn_vs_rayleigh.png    ← Side-by-side channel comparison
├── fig4_constellations.png      ← 3×3 constellation grid
├── fig5_evm.png                 ← Error Vector Magnitude vs SNR
├── fig6_signal_analysis.png     ← Time domain, PSD, CP verification
├── fig7_spectral_efficiency.png ← Spectral efficiency vs Shannon bound
├── fig8_ber_heatmap.png         ← BER heatmap (log scale)
└── fig9_snr_requirements.png    ← SNR targets bar chart
```

Expected runtime: **1–3 minutes** depending on hardware.

---

## 📁 Repository Structure

```
ofdm-transceiver-simulation/
│
├── ofdm_transceiver.m           ← Main simulation script
│
├── images/                      ← (Add your output PNGs here for README)
│   ├── fig1_ber_awgn.png
│   ├── fig2_ber_rayleigh.png
│   ├── fig3_awgn_vs_rayleigh.png
│   ├── fig4_constellations.png
│   ├── fig5_evm.png
│   ├── fig6_signal_analysis.png
│   ├── fig7_spectral_efficiency.png
│   ├── fig8_ber_heatmap.png
│   └── fig9_snr_requirements.png
│
├── ofdm_results/                ← Output folder (auto-created by script)
│
└── README.md                    ← This file
```

---

## 🧠 Key Concepts Implemented

### OFDM Modulation
OFDM converts a high-speed serial data stream into many parallel low-speed streams transmitted on orthogonal subcarriers. Orthogonality is enforced by the IFFT/FFT pair — at the peak of each subcarrier's frequency, all other subcarriers have zero amplitude.

### Cyclic Prefix
The last `N_cp = 16` samples of each IFFT output are copied and prepended. This absorbs multipath-induced Inter-Symbol Interference (ISI) and converts linear channel convolution into circular convolution, enabling simple one-tap frequency-domain equalization.

### Gray Coding
Adjacent constellation points differ by exactly 1 bit. A noise-induced wrong decision to the nearest neighbor causes only 1 bit error instead of multiple — critical for achieving theoretical BER performance.

### Pilot-Based LS Channel Estimation
Four pilot subcarriers at known positions transmit `1+0j`. The receiver computes `Ĥ = Y_pilot / X_pilot = Y_pilot`. Linear interpolation then estimates the channel at all 64 subcarrier positions for equalization.

### EVM Analysis
Error Vector Magnitude measures the RMS deviation of received symbols from ideal constellation points — the industry-standard quality metric used in Wi-Fi and cellular hardware certification.

---

## 📈 Performance Summary

```
Modulation | SNR @ BER<1e-3 | Throughput  | Robustness
-----------|----------------|-------------|------------
BPSK       |     ~8 dB      |  48 bits/sym |  ★★★★★
QPSK       |    ~12 dB      |  96 bits/sym |  ★★★★☆
8-PSK      |    >30 dB      | 144 bits/sym |  ★★☆☆☆
```

**Key findings:**
- BPSK and QPSK achieve identical BER per bit — QPSK doubles throughput at no BER cost
- 8-PSK requires excessively high SNR for reliable communication in this channel
- Rayleigh fading causes severe performance degradation; advanced equalization (MMSE) or channel coding is needed
- Simulated BER matches theoretical predictions with high accuracy, validating the implementation

---



## 👨‍💻 Author

**[Nandhini V]**
- Department of Electronics and Communication Engineering
- Project: OFDM Transceiver System Simulation
- Tools: Matlab or GNU Octave 8.x

---


