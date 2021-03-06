function [rst, rsf] = aud2rst(y, rv, sv, STF, SRF)
% AUD2RST Rate-scale matrix of an auditory spectrogram (without .cor file)
%   [rst, rsf] = aud2rst(y, rv, sv, STF, SRF);
%	y   : auditory spectrogram, N-by-M, where
%		N = # of samples, M = # of channels
%	rst : rate-scale-time matrix, S-by-R-by-N, where 
%		S = # of scale, R = # of rate ([upward, downward])
%	rsf : rate-scale-frequency matrix, S-by-R-by-M, where 
%		S = # of scale, R = # of rate ([upward, downward])
%	rv  : rate vector in Hz, e.g., 2.^(1:.5:5).
%	sv  : scale vector in cyc/oct, e.g., 2.^(-2:.5:3).
%	STF	: sample temporal frequency, e.g., 125 Hz for 8 ms
%	SRF	: sample ripple frequency, e.g., 24 ch/oct or 20 ch/oct
%
%   AUD2RST generate rate-scale matrices according to the auditory 
%   spectrogram Y which was generated by WAV2AUD. RST, RSF can be read by
%	RST_VIEW. RV (SV) is the characteristic frequency vector.
%	See also: WAV2AUD, RST_VIEW, COR2RST

% Auther: Powen Ru (powen@isr.umd.edu), NSL, UMD
% v1.00: 01-Jun-97
% v1.01: 03-Oct-97, add causal option
% v1.02: 12-Apr-98, remove non-causal option

% Revision: Taishih Chi (tschi@isr.umd.edu), NSL, UMD
% v1.10: 14-Dec-98, make [rst, rsf] 3 dimensional representation

if nargin < 5, SRF = 24; end;

dr = mean(diff(log2(rv)));
ds = mean(diff(log2(sv)));

% mean removal (for test only)
%meany   = mean(mean(y));
%y	   = y - meany;

% dimensions
K1 	= length(rv);	% # of rate channel
K2	= length(sv);	% # of scale channel
[N, M]	= size(y);	% dimensions of auditory spectrogram

% spatial, temporal zeros padding 
N1 = 2^nextpow2(N);	N2 = N1*2;
M1 = 2^nextpow2(M);	M2 = M1*2;

% first fourier transform (w.r.t. temporal axis)
Y = zeros(N2, M1);
for n = 1:N,
	R1 = fft(y(n, :), M2);
	Y(n, :) = R1(1:M1);
end;

% second fourier transform (w.r.t. frequency axis)
for m = 1:M1,
	R1 = fft(Y(1:N, m), N2);
	Y(:, m) = R1;
end;

% allocate memory
clear y;
z		= zeros(N, M);
z_size  = N*M*2;
Ktmp	= 2*K1;
rst	= zeros(K2, Ktmp, N);
rsf	= zeros(K2, Ktmp, M);

t0 = clock;

for rdx = 1:K1,
	% rate filtering
	fc_rt = rv(rdx);
	HR = gen_cort(fc_rt, N1, STF);

	for sgn = [1 -1],

		% rate filtering modification
		if sgn > 0,
				HR = [HR; zeros(N1, 1)];
		else,
				HR = [0; conj(flipud(HR(2:N2)))];
				HR(N1+1) = abs(HR(N1+2));
		end;

		for sdx = 1:K2,
			% scale filtering
			fc_sc = sv(sdx);
			HS = gen_corf(fc_sc, M1, SRF);

			% spatiotemporal response
			Z = (HR*HS') .* Y;

			% first inverse fft (w.r.t. time axis)
			for m = 1:M,
				R1 = ifft(Z(:, m));
				z(1:N, m) = R1(1:N);
			end;

			% second inverse fft (w.r.t frequency axis)
			for n = 1:N,
				R1 = ifft(z(n, :), M2);
				z(n, :) = R1(1:M);
			end;

			rs_gain = 1;
%			rs_gain = (1 - exp(-(rdx-.9)*dr))*(1 - exp(-(sdx)*ds));

			% collasp freq. axis
			rst(sdx, rdx+(sgn==1)*K1, :) = mean((abs(z))')*rs_gain;

			% collasp time axis
			rsf(sdx, rdx+(sgn==1)*K1, :) = mean(abs(z))*rs_gain;
		end;
	end;
	time_est(rdx, K1, 1, t0);

end;
