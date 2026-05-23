% =========================================================================
%  OFDM TRANSCEIVER SYSTEM SIMULATION
%  M-PSK Modulation: BPSK, QPSK, 8-PSK
%  Channels: AWGN and Rayleigh Fading
%  Features: BER vs SNR, Constellation Diagrams, EVM, PSD, Spectral Eff.
%  Author: OFDM Simulation Project
%  Run with: octave ofdm_transceiver.m
% =========================================================================

clear all; close all; clc;


fprintf('=============================================================\n');
fprintf('   OFDM TRANSCEIVER SYSTEM SIMULATION\n');
fprintf('   M-PSK: BPSK | QPSK | 8-PSK\n');
fprintf('   Channels: AWGN | Rayleigh Fading\n');
fprintf('=============================================================\n\n');

% -------------------------------------------------------------------------
% SYSTEM PARAMETERS
% -------------------------------------------------------------------------
N_fft       = 64;
N_cp        = 16;
N_symbols   = 80;
SNR_dB_vec  = 0:2:30;
mod_schemes = {'BPSK','QPSK','8PSK'};

pilot_idx  = [7, 21, 43, 57];          % 1-indexed pilot subcarriers
active_idx = [2:27, 39:64];            % active subcarriers (no DC, no guard)
data_idx   = setdiff(active_idx, pilot_idx);

fprintf('System Parameters:\n');
fprintf('  FFT Size         : %d\n', N_fft);
fprintf('  Cyclic Prefix    : %d samples (25%% overhead)\n', N_cp);
fprintf('  Active Carriers  : %d (%d data + %d pilots)\n', length(active_idx), length(data_idx), length(pilot_idx));
fprintf('  OFDM Symbols/SNR : %d\n', N_symbols);
fprintf('  SNR Range        : %d to %d dB\n', SNR_dB_vec(1), SNR_dB_vec(end));
fprintf('\n');

% =========================================================================
% MODULATION FUNCTIONS
% =========================================================================
function syms = mpsk_mod(bits, M)
  bps = round(log2(M));
  pad = mod(-length(bits), bps);
  if pad > 0; bits = [bits, zeros(1,pad)]; end
  bits_mat = reshape(bits, bps, [])';
  % Manual bi2de (left-MSB)
  N = rows(bits_mat);
  idx = zeros(N, 1);
  for k = 1:bps
    idx = idx + bits_mat(:,k) * 2^(bps-k);
  end
  idx = idx(:)';
  % Gray decode
  gray = idx;
  temp = floor(gray ./ 2);
  while any(temp > 0)
    gray = bitxor(gray, temp);
    temp = floor(temp ./ 2);
  end
  phases = 2*pi/M * gray;
  syms = exp(1j * phases);
end

function bits = mpsk_demod(syms, M)
  bps = round(log2(M));
  ph  = angle(syms);
  ph(ph < 0) = ph(ph < 0) + 2*pi;
  idx = mod(round(ph * M / (2*pi)), M);
  % Inverse Gray
  gray = idx;
  temp = floor(gray ./ 2);
  while any(temp > 0)
    gray = bitxor(gray, temp);
    temp = floor(temp ./ 2);
  end
  % Manual de2bi (left-MSB)
  N = length(gray);
  bits_mat = zeros(N, bps);
  for k = 1:bps
    bits_mat(:,k) = floor(mod(gray(:), 2^(bps-k+1)) / 2^(bps-k));
  end
  bits = reshape(bits_mat', 1, []);
end

function y = awgn_ch(x, snr_lin)
  np = 1 / snr_lin;
  n  = sqrt(np/2) * (randn(1,length(x)) + 1j*randn(1,length(x)));
  y  = x + n;
end

function [y, h] = rayleigh_ch(x, snr_lin)
  N = length(x);
  h = (randn(1,N) + 1j*randn(1,N)) / sqrt(2);
  np = 1 / snr_lin;
  n  = sqrt(np/2) * (randn(1,N) + 1j*randn(1,N));
  y  = h .* x + n;
end

function evm = calc_evm(tx, rx)
  err = mean(abs(rx - tx).^2);
  ref = mean(abs(tx).^2);
  evm = sqrt(err/ref) * 100;
end

% =========================================================================
% PRE-ALLOCATE RESULTS
% =========================================================================
n_snr  = length(SNR_dB_vec);
n_mod  = length(mod_schemes);
BER_A  = zeros(n_mod, n_snr);   % AWGN BER
BER_R  = zeros(n_mod, n_snr);   % Rayleigh BER
EVM_A  = zeros(n_mod, n_snr);   % AWGN EVM

% Collect constellations @ SNR=20dB
snr20_idx = find(SNR_dB_vec == 20, 1);
CTX = cell(n_mod,1); CRX_A = cell(n_mod,1); CRX_R = cell(n_mod,1);

% =========================================================================
% MAIN SIMULATION LOOP
% =========================================================================
for m = 1:n_mod
  M   = 2^m;
  bps = m;  % BPSK=1, QPSK=2, 8PSK=3
  n_bits = length(data_idx) * bps;
  fprintf('[%s] M=%d, %d bits/OFDM symbol...\n', mod_schemes{m}, M, n_bits);

  for s = 1:n_snr
    snr_dB  = SNR_dB_vec(s);
    snr_lin = 10^(snr_dB/10);
    e_a = 0; e_r = 0; tb = 0; ev = 0;
    do_save = (s == snr20_idx);
    tx_c=[]; ra_c=[]; rr_c=[];

    for sym = 1:N_symbols

      % --- 1. Random Bits ---
      bits_tx = randi([0 1], 1, n_bits);

      % --- 2. M-PSK Modulation ---
      d_syms = mpsk_mod(bits_tx, M);

      % --- 3. Subcarrier Mapping (S2P) ---
      fd = zeros(1, N_fft);
      fd(data_idx)  = d_syms;
      fd(pilot_idx) = 1+0j;

      % --- 4. IFFT (OFDM Modulation) ---
      td = ifft(fd, N_fft) * sqrt(N_fft);

      % --- 5. Cyclic Prefix Insertion ---
      tx = [td(end-N_cp+1:end), td];

      % --- 6. Channel ---
      rx_a = awgn_ch(tx, snr_lin);
      [rx_r, h_r] = rayleigh_ch(tx, snr_lin);

      % --- 7. CP Removal ---
      rx_a = rx_a(N_cp+1:end);
      rx_r = rx_r(N_cp+1:end);
      h_r  = h_r(N_cp+1:end);

      % --- 8. FFT ---
      fd_a = fft(rx_a, N_fft) / sqrt(N_fft);
      fd_r = fft(rx_r, N_fft) / sqrt(N_fft);

      % --- 9. Channel Estimation & Equalization (Rayleigh, LS) ---
      H_fd_r = fft(h_r, N_fft);
      H_est_pilots = fd_r(pilot_idx) ./ 1;   % LS at pilots
      % Interpolate H across all subcarriers
      H_est = interp1([1, pilot_idx, N_fft], ...
        [H_est_pilots(1), H_est_pilots, H_est_pilots(end)], ...
        1:N_fft, 'linear');
      % Equalize
      fd_r_eq = fd_r ./ H_est;

      % --- 10. Extract Data Subcarriers ---
      da = fd_a(data_idx);
      dr = fd_r_eq(data_idx);

      % --- 11. Demodulation ---
      bits_a = mpsk_demod(da, M)(1:n_bits);
      bits_r = mpsk_demod(dr, M)(1:n_bits);

      % --- 12. Accumulate Errors ---
      e_a += sum(bits_tx ~= bits_a);
      e_r += sum(bits_tx ~= bits_r);
      tb  += n_bits;
      ev  += calc_evm(d_syms, da);

      if do_save
        tx_c = [tx_c, d_syms];
        ra_c = [ra_c, da];
        rr_c = [rr_c, dr];
      end
    end

    BER_A(m,s) = e_a / tb;
    BER_R(m,s) = e_r / tb;
    EVM_A(m,s) = ev  / N_symbols;
  end

  CTX{m}   = tx_c;
  CRX_A{m} = ra_c;
  CRX_R{m} = rr_c;

  fprintf('  Done. BER@20dB -> AWGN: %.2e | Rayleigh+EQ: %.2e\n', ...
    BER_A(m, snr20_idx), BER_R(m, snr20_idx));
end

fprintf('\nGenerating plots...\n');
outdir = fullfile(pwd, 'ofdm_results');

% =========================================================================
% THEORETICAL BER CURVES
% =========================================================================
snr_lin_v = 10.^(SNR_dB_vec/10);
BER_th_BPSK = 0.5 * erfc(sqrt(snr_lin_v));
BER_th_QPSK = 0.5 * erfc(sqrt(snr_lin_v));
BER_th_8PSK = (2/3) * erfc(sqrt(snr_lin_v .* log2(8)) * sin(pi/8));

colors  = {'b','r','g'};
markers = {'-o','-s','-^'};
lstr    = {'-','--',':'};

% =========================================================================
% FIG 1 — BER vs SNR: AWGN
% =========================================================================
fh = figure('visible','off');
semilogy(SNR_dB_vec, BER_th_BPSK, 'b:', 'LineWidth',1.2); hold on;
semilogy(SNR_dB_vec, BER_th_QPSK, 'r:', 'LineWidth',1.2);
semilogy(SNR_dB_vec, BER_th_8PSK, 'g:', 'LineWidth',1.2);
for m=1:n_mod
  semilogy(SNR_dB_vec, max(BER_A(m,:),1e-6), [colors{m}, markers{m}], ...
    'LineWidth',2,'MarkerSize',6);
end
grid on;
xlabel('SNR (dB)','FontSize',12); ylabel('Bit Error Rate','FontSize',12);
title('BER vs SNR — OFDM M-PSK (AWGN Channel)','FontSize',13,'FontWeight','bold');
legend({'BPSK Theory','QPSK Theory','8PSK Theory','BPSK Sim','QPSK Sim','8PSK Sim'}, ...
  'Location','southwest','FontSize',9);
xlim([0 30]); ylim([1e-6 1]);
print([outdir '/fig1_ber_awgn.png'], '-dpng', '-r150');
close(fh);

% =========================================================================
% FIG 2 — BER vs SNR: Rayleigh Fading
% =========================================================================
fh = figure('visible','off');
for m=1:n_mod
  semilogy(SNR_dB_vec, max(BER_R(m,:),1e-6), [colors{m}, markers{m}], ...
    'LineWidth',2,'MarkerSize',6); hold on;
end
semilogy(SNR_dB_vec, BER_th_BPSK, 'k--', 'LineWidth',1.5);
grid on;
xlabel('SNR (dB)','FontSize',12); ylabel('Bit Error Rate','FontSize',12);
title('BER vs SNR — OFDM M-PSK (Rayleigh + LS Equalization)','FontSize',13,'FontWeight','bold');
legend({'BPSK','QPSK','8PSK','BPSK AWGN Ref.'}, ...
  'Location','southwest','FontSize',10);
xlim([0 30]); ylim([1e-6 1]);
print([outdir '/fig2_ber_rayleigh.png'], '-dpng', '-r150');
close(fh);

% =========================================================================
% FIG 3 — AWGN vs Rayleigh per scheme
% =========================================================================
fh = figure('visible','off','Position',[0 0 1200 380]);
for m=1:n_mod
  subplot(1,3,m);
  semilogy(SNR_dB_vec, max(BER_A(m,:),1e-6),'b-o','LineWidth',2,'MarkerSize',5); hold on;
  semilogy(SNR_dB_vec, max(BER_R(m,:),1e-6),'r-s','LineWidth',2,'MarkerSize',5);
  grid on; xlabel('SNR (dB)'); ylabel('BER');
  title(mod_schemes{m},'FontWeight','bold');
  legend({'AWGN','Rayleigh+EQ'},'Location','southwest','FontSize',8);
  xlim([0 30]); ylim([1e-6 1]);
end
print([outdir '/fig3_awgn_vs_rayleigh.png'], '-dpng', '-r150');
close(fh);

% =========================================================================
% FIG 4 — Constellation Diagrams (3x3 grid)
% =========================================================================
fh = figure('visible','off','Position',[0 0 1100 850]);
sch_full = {'BPSK (M=2)','QPSK (M=4)','8-PSK (M=8)'};
th = linspace(0,2*pi,200);
for m=1:n_mod
  subplot(3,3,(m-1)*3+1);
  plot(real(CTX{m}), imag(CTX{m}), 'b.','MarkerSize',10); hold on;
  plot(cos(th), sin(th), 'k--','LineWidth',0.8);
  plot(0,0,'k+','MarkerSize',10,'LineWidth',1.5);
  axis([-1.8 1.8 -1.8 1.8]); grid on;
  xlabel('I'); ylabel('Q');
  title([sch_full{m},' — TX'],'FontSize',10,'FontWeight','bold');

  subplot(3,3,(m-1)*3+2);
  plot(real(CRX_A{m}), imag(CRX_A{m}), 'r.','MarkerSize',4); hold on;
  plot(cos(th), sin(th), 'k--','LineWidth',0.8);
  plot(real(CTX{m}), imag(CTX{m}), 'b+','MarkerSize',6,'LineWidth',1);
  axis([-2 2 -2 2]); grid on;
  xlabel('I'); ylabel('Q');
  title([sch_full{m},' — AWGN RX (20dB)'],'FontSize',10);

  subplot(3,3,(m-1)*3+3);
  plot(real(CRX_R{m}), imag(CRX_R{m}), 'g.','MarkerSize',4); hold on;
  plot(cos(th), sin(th), 'k--','LineWidth',0.8);
  plot(real(CTX{m}), imag(CTX{m}), 'b+','MarkerSize',6,'LineWidth',1);
  axis([-2 2 -2 2]); grid on;
  xlabel('I'); ylabel('Q');
  title([sch_full{m},' — Rayleigh+EQ RX (20dB)'],'FontSize',10);
end
print([outdir '/fig4_constellations.png'], '-dpng', '-r150');
close(fh);

% =========================================================================
% FIG 5 — EVM vs SNR
% =========================================================================
fh = figure('visible','off');
for m=1:n_mod
  semilogy(SNR_dB_vec, EVM_A(m,:), [colors{m}, markers{m}], ...
    'LineWidth',2,'MarkerSize',7); hold on;
end
yline_val = 1; yline_val5 = 5;
semilogy([SNR_dB_vec(1) SNR_dB_vec(end)], [1 1], 'k--','LineWidth',1);
semilogy([SNR_dB_vec(1) SNR_dB_vec(end)], [5 5], 'm--','LineWidth',1);
text(SNR_dB_vec(end)-2, 1.3, '1% EVM','FontSize',9);
text(SNR_dB_vec(end)-2, 6.5, '5% EVM','FontSize',9,'Color','m');
grid on;
xlabel('SNR (dB)','FontSize',12); ylabel('EVM (%)','FontSize',12);
title('Error Vector Magnitude vs SNR — AWGN Channel','FontSize',13,'FontWeight','bold');
legend({'BPSK','QPSK','8PSK'}, 'Location','northeast','FontSize',10);
print([outdir '/fig5_evm.png'], '-dpng', '-r150');
close(fh);

% =========================================================================
% FIG 6 — OFDM Signal Analysis
% =========================================================================
% Generate demo QPSK OFDM symbol
M_d = 4;
bits_d = randi([0 1], 1, length(data_idx)*2);
syms_d = mpsk_mod(bits_d, M_d);
fd_d   = zeros(1, N_fft);
fd_d(data_idx)  = syms_d;
fd_d(pilot_idx) = 1;
td_d   = ifft(fd_d, N_fft) * sqrt(N_fft);
tx_d   = [td_d(end-N_cp+1:end), td_d];

fh = figure('visible','off','Position',[0 0 1100 750]);

subplot(3,2,1);
t_ax = 0:length(tx_d)-1;
plot(t_ax, real(tx_d),'b-','LineWidth',1.2); hold on;
plot(t_ax, imag(tx_d),'r--','LineWidth',1.2);

plot([N_cp N_cp], [-1.5 1.5], 'k--','LineWidth',2);
xlabel('Sample Index'); ylabel('Amplitude'); grid on;
legend({'Real','Imag'},'FontSize',9);
title('OFDM Time-Domain Signal (QPSK)','FontWeight','bold');
text(N_cp/2, max(real(tx_d))*0.9, 'CP','HorizontalAlignment','center','FontSize',10,'Color','k');

subplot(3,2,2);
stem(0:N_fft-1, abs(fd_d), 'b','MarkerSize',4,'LineWidth',1); hold on;
stem(pilot_idx-1, abs(fd_d(pilot_idx)), 'rv','MarkerSize',8,'LineWidth',2);
xlabel('Subcarrier Index'); ylabel('|Amplitude|');
title('Subcarrier Allocation (Freq. Domain)','FontWeight','bold'); grid on;
legend({'Data','Pilots'},'FontSize',9);

subplot(3,2,[3 4]);
Nwin = length(tx_d);
win  = 0.5*(1 - cos(2*pi*(0:Nwin-1)/(Nwin-1)))';
X    = fft(tx_d .* win, 1024);
PSD  = 10*log10(abs(X).^2 / 1024 + 1e-10);
f_ax = linspace(-0.5, 0.5, 1024);
plot(f_ax, fftshift(PSD),'b-','LineWidth',1.5);
xlabel('Normalized Frequency'); ylabel('PSD (dB)'); grid on;
title('Power Spectral Density — OFDM Signal','FontWeight','bold');

subplot(3,2,5);
% CP verification: first N_cp samples == last N_cp of td_d
plot(real(tx_d(1:N_cp)),'r-o','MarkerSize',5,'DisplayName','CP'); hold on;
plot(real(td_d(end-N_cp+1:end)),'b-s','MarkerSize',5,'DisplayName','Last N_{cp} of IFFT');
xlabel('Sample'); ylabel('Amplitude'); grid on;
title('Cyclic Prefix Verification','FontWeight','bold');
legend({'CP','Last N_{cp} of IFFT'},'FontSize',9);

subplot(3,2,6);
labels = {'Guard\n(Low)','DC\nNull','Pilots','Data','Guard\n(High)'};
counts = [7, 1, length(pilot_idx), length(data_idx), 7];
clrs = [0.3 0.7 0.9; 0.7 0.7 0.7; 1.0 0.5 0.1; 0.2 0.8 0.3; 0.3 0.7 0.9];
bar_clrs = clrs;
for k=1:5
  bar(k, counts(k), 'FaceColor', bar_clrs(k,:)); hold on;
end
set(gca,'XTick',1:5,'XTickLabel',{'Guard-Lo','DC','Pilots','Data','Guard-Hi'},'XTickLabelRotation',20);
ylabel('# Subcarriers'); grid on;
title('Subcarrier Breakdown','FontWeight','bold');
for k=1:5; text(k, counts(k)+0.5, num2str(counts(k)), 'HorizontalAlignment','center','FontWeight','bold'); end

print([outdir '/fig6_signal_analysis.png'], '-dpng', '-r150');
close(fh);

% =========================================================================
% FIG 7 — Spectral Efficiency vs SNR
% =========================================================================
fh = figure('visible','off');
bps_v = [1 2 3];
for m=1:n_mod
  pkt_ok = 1 - BER_A(m,:);
  se = bps_v(m) * (length(data_idx)/N_fft) * (N_fft/(N_fft+N_cp)) .* pkt_ok;
  plot(SNR_dB_vec, se, [colors{m}, markers{m}], 'LineWidth',2,'MarkerSize',7); hold on;
end
shannon = log2(1 + snr_lin_v) * (length(data_idx)/(N_fft+N_cp));
plot(SNR_dB_vec, shannon, 'k-','LineWidth',2,'DisplayName','Shannon Bound');
grid on;
xlabel('SNR (dB)','FontSize',12); ylabel('Spectral Efficiency (bits/s/Hz)','FontSize',12);
title('Spectral Efficiency vs SNR — AWGN Channel','FontSize',13,'FontWeight','bold');
legend({'BPSK','QPSK','8PSK','Shannon Bound'},'Location','northwest','FontSize',10);
print([outdir '/fig7_spectral_efficiency.png'], '-dpng', '-r150');
close(fh);

% =========================================================================
% FIG 8 — BER Heatmap
% =========================================================================
fh = figure('visible','off','Position',[0 0 1000 380]);
subplot(1,2,1);
imagesc(SNR_dB_vec, 1:n_mod, log10(max(BER_A, 1e-6)));
colorbar; colormap(jet);
set(gca,'YTick',1:n_mod,'YTickLabel',mod_schemes,'FontSize',11);
xlabel('SNR (dB)','FontSize',11);
title('log_{10}(BER) — AWGN','FontSize',12,'FontWeight','bold');

subplot(1,2,2);
imagesc(SNR_dB_vec, 1:n_mod, log10(max(BER_R, 1e-6)));
colorbar; colormap(jet);
set(gca,'YTick',1:n_mod,'YTickLabel',mod_schemes,'FontSize',11);
xlabel('SNR (dB)','FontSize',11);
title('log_{10}(BER) — Rayleigh+EQ','FontSize',12,'FontWeight','bold');

print([outdir '/fig8_ber_heatmap.png'], '-dpng', '-r150');
close(fh);

% =========================================================================
% FIG 9 — SNR Required for BER Targets (Bar Chart)
% =========================================================================
ber_targets = [1e-2, 1e-3, 1e-4];
fh = figure('visible','off','Position',[0 0 900 500]);
snr_req = zeros(n_mod, length(ber_targets));
for m=1:n_mod
  for t=1:length(ber_targets)
    idx_g = find(BER_A(m,:) < ber_targets(t), 1);
    if ~isempty(idx_g)
      snr_req(m,t) = SNR_dB_vec(idx_g);
    else
      snr_req(m,t) = SNR_dB_vec(end) + 2;
    end
  end
end
bar(snr_req, 'grouped');
set(gca,'XTick',1:n_mod,'XTickLabel',mod_schemes,'FontSize',12);
xlabel('Modulation Scheme','FontSize',12); ylabel('Required SNR (dB)','FontSize',12);
title('SNR Required for BER Targets (AWGN)','FontSize',13,'FontWeight','bold');
legend({'BER<10^{-2}','BER<10^{-3}','BER<10^{-4}'},'Location','northwest','FontSize',10);
grid on;
print([outdir '/fig9_snr_requirements.png'], '-dpng', '-r150');
close(fh);

% =========================================================================
% PRINT SUMMARY TABLE
% =========================================================================
fprintf('\n=============================================================\n');
fprintf('               PERFORMANCE SUMMARY TABLE\n');
fprintf('=============================================================\n');
fprintf('%-6s | %6s | %12s | %12s | %10s\n', ...
  'Scheme','SNR(dB)','BER (AWGN)','BER (Rayl.)','EVM (%)');
fprintf('%s\n', repmat('-',1,56));
report_snrs = [5 10 15 20 25];
for m=1:n_mod
  for rs=report_snrs
    idx_s = find(SNR_dB_vec == rs, 1);
    fprintf('%-6s | %6d | %12.2e | %12.2e | %10.2f\n', ...
      mod_schemes{m}, rs, BER_A(m,idx_s), BER_R(m,idx_s), EVM_A(m,idx_s));
  end
  fprintf('%s\n', repmat('-',1,56));
end

fprintf('\nSNR required for BER < 1e-3 (AWGN channel):\n');
for m=1:n_mod
  idx_g = find(BER_A(m,:) < 1e-3, 1);
  if ~isempty(idx_g)
    fprintf('  %-6s : %d dB\n', mod_schemes{m}, SNR_dB_vec(idx_g));
  else
    fprintf('  %-6s : > %d dB\n', mod_schemes{m}, SNR_dB_vec(end));
  end
end

fprintf('\n=============================================================\n');
fprintf('All figures saved to: %s\n', outdir);
fprintf('  fig1_ber_awgn.png          — BER vs SNR (AWGN)\n');
fprintf('  fig2_ber_rayleigh.png      — BER vs SNR (Rayleigh)\n');
fprintf('  fig3_awgn_vs_rayleigh.png  — Side-by-side comparison\n');
fprintf('  fig4_constellations.png    — 3x3 constellation grid\n');
fprintf('  fig5_evm.png               — EVM vs SNR\n');
fprintf('  fig6_signal_analysis.png   — Signal & PSD analysis\n');
fprintf('  fig7_spectral_efficiency.png — Spectral efficiency\n');
fprintf('  fig8_ber_heatmap.png       — BER heatmap\n');
fprintf('  fig9_snr_requirements.png  — SNR target bar chart\n');
fprintf('=============================================================\n');
