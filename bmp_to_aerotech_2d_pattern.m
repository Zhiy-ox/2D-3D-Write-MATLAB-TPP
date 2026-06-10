function summary = bmp_to_aerotech_2d_pattern(cfg)
%BMP_TO_AEROTECH_2D_PATTERN Compatibility wrapper for the renamed generator.
%
% Use twoD_arbitary_printing_generate for new work.

if nargin < 1
    summary = twoD_arbitary_printing_generate();
else
    summary = twoD_arbitary_printing_generate(cfg);
end
end
