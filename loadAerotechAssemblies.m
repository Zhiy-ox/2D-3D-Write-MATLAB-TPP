function loadAerotechAssemblies(aerotechDotNetDir)
%LOADAEROTECHASSEMBLIES Load Aerotech .NET assemblies from a known folder.
%
% The Aerotech managed assemblies call native DLLs from the same folder, so
% the folder also needs to be on PATH before connecting or building.

persistent loadedDir

if nargin < 1 || isempty(aerotechDotNetDir)
    thisFileDir = fileparts(mfilename('fullpath'));
    aerotechDotNetDir = fullfile(thisFileDir, 'Aerotech_DotNet');
end

aerotechDotNetDir = char(aerotechDotNetDir);
if ~exist(aerotechDotNetDir, 'dir')
    error('loadAerotechAssemblies:MissingDirectory', ...
        'Aerotech .NET directory not found: %s', aerotechDotNetDir);
end

commonDll = fullfile(aerotechDotNetDir, 'Aerotech.Common.dll');
ensembleDll = fullfile(aerotechDotNetDir, 'Aerotech.Ensemble.dll');
requiredFiles = {commonDll, ensembleDll, ...
    fullfile(aerotechDotNetDir, 'EnsembleCore64.dll'), ...
    fullfile(aerotechDotNetDir, 'AeroBasic64.dll')};

for k = 1:numel(requiredFiles)
    if ~exist(requiredFiles{k}, 'file')
        error('loadAerotechAssemblies:MissingFile', ...
            'Required Aerotech file not found: %s', requiredFiles{k});
    end
end

if ~isempty(loadedDir)
    if ~strcmpi(loadedDir, aerotechDotNetDir)
        warning('loadAerotechAssemblies:AlreadyLoaded', ...
            'Aerotech assemblies were already loaded from %s. MATLAB cannot unload .NET assemblies during this session.', ...
            loadedDir);
    end
    return;
end

addFolderToPath(aerotechDotNetDir);

try
    NET.addAssembly(commonDll);
    NET.addAssembly(ensembleDll);
catch err
    error('loadAerotechAssemblies:LoadFailed', ...
        ['Could not load Aerotech .NET assemblies from:%s%s%s%s' ...
         'Original error:%s%s'], ...
        newline, aerotechDotNetDir, newline, newline, newline, err.message);
end

loadedDir = aerotechDotNetDir;
end

function addFolderToPath(folderPath)
currentPath = getenv('PATH');
pathParts = regexp(currentPath, pathsep, 'split');

if ~any(strcmpi(pathParts, folderPath))
    if isempty(currentPath)
        setenv('PATH', folderPath);
    else
        setenv('PATH', [folderPath pathsep currentPath]);
    end
end
end
