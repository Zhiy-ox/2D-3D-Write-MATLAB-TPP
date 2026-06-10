function run_aerotech_chunks(manifestPath, options)
%RUN_AEROTECH_CHUNKS Compatibility wrapper for the renamed runner.
%
% Use twoD_arbitary_printing_run for new work.

if nargin < 1
    twoD_arbitary_printing_run();
elseif nargin < 2
    twoD_arbitary_printing_run(manifestPath);
else
    twoD_arbitary_printing_run(manifestPath, options);
end
end
