# twoD BMP to Aerotech DLW Toolpath

This workflow converts a black/white BMP into small AeroBasic `.ab` chunks for line-by-line DLW writing.

- White pixels: written at `writeSpeed_mm_s`
- Black pixels: traversed at `unwrittenSpeed_mm_s`
- Large patterns: split into many small `.ab` files so the controller is not fed one huge program

## Files

- `twoD_arbitary_printing.m`: user-friendly GUI for previewing BMPs, editing settings, generating scripts, and running chunks.
- `twoD_arbitary_printing_config.m`: edit all pattern, speed, and controller settings here.
- `twoD_arbitary_printing_generate.m`: reads the BMP and creates chunked `.ab` files.
- `twoD_arbitary_printing_run.m`: runs the generated chunks one by one on the Aerotech controller.
- `Generated_Scripts/`: generated `.ab` chunks and manifest files.
- `Preview/`: generated physical write-mask preview.

3D surface writing (a 2D phase/height matrix instead of a BMP mask) is provided by a parallel set of files:

- `threeD_arbitary_printing.m`: GUI for loading a matrix, previewing the height map, generating scripts, and running chunks.
- `threeD_arbitary_printing_config.m`: edit all surface, tilt, speed, and controller settings here.
- `threeD_arbitary_printing_generate.m`: loads the matrix and creates chunked `.ab` files whose Z tracks the surface.
- The chunk runner is shared: `twoD_arbitary_printing_run.m` executes the 3D manifest unchanged.

See [3D Arbitrary Surface Writing](#3d-arbitrary-surface-writing) below.

## GUI Use

In MATLAB:

```matlab
twoD_arbitary_printing
```

Typical workflow:

1. Choose the BMP file.
2. Set BMP pixel size, scan line spacing, Z position, speeds, lead-in/out, and chunk size.
3. Use the `Pattern`, `Motion`, and `Aerotech` tabs for detailed settings.
4. Click `Preview BMP` and check that white/black orientation is correct.
5. Click `Generate Scripts`.
6. Inspect the `Summary` and `Manifest` tabs, plus the first few `.ab` files.
7. Position the stage at the intended pattern origin.
8. Click `Run Chunks` only when ready for hardware motion.
9. Use `Stop / Laser Off` to request `PSOCONTROL <axis> OFF` and stop task T01.

The GUI keeps the hardware run behind a confirmation dialog by default.

## Script Use

In MATLAB:

```matlab
cfg = twoD_arbitary_printing_config();
cfg.bmpPath = fullfile(pwd, 'your_pattern.bmp');
cfg.pixelSize_um = 7.03125;   % 1800 um / 256 px for a 1.8 mm square pattern
cfg.lineSpacing_um = 1.0;     % physical scan-line spacing / writing resolution
cfg.writeSpeed_mm_s = 0.02;
cfg.unwrittenSpeed_mm_s = 10.0;
cfg.maxMotionCommandsPerScript = 300;

summary = twoD_arbitary_printing_generate(cfg);
```

Then inspect:

```matlab
summary
```

Also check:

- `Preview/twoD_arbitary_printing_physical_write_mask.png`
- `Generated_Scripts/twoD_arbitary_printing_manifest.txt`
- The first few generated `.ab` files

After checking the preview and positioning the stage at the intended pattern origin:

```matlab
twoD_arbitary_printing_run(summary.manifestPath);
```

The runner asks you to type `RUN` before hardware motion begins.

## Important Settings

`pixelSize_um` is the physical size of one BMP pixel in both X and Y. For a `256 x 256` BMP printed as `1.8 mm x 1.8 mm`, use:

```matlab
cfg.pixelSize_um = 1800 / 256;  % 7.03125 um
```

`lineSpacing_um` is the physical spacing between adjacent scan lines. It can be smaller than `pixelSize_um`; for example, `lineSpacing_um = 1.0` repeats/samples the BMP rows on roughly 1 um-spaced scan lines.

`leadIn_um` and `leadOut_um` add extra travel before and after each scan line. They let the stage settle before the written part of the line and continue just past the pattern edge before turning around. They do not count as part of the intended pattern size.

Check your laser blanking behavior before using large lead-in/out values. In this version, PSO is enabled at the chunk level, while written and unwritten parts are separated mainly by motion speed.

`coordinateMode` defaults to `relative`, because the existing `split_script.m` in this folder treats each `linear X/Y/Z/F` line as a relative displacement. If your Aerotech program expects absolute `LINEAR` targets, set:

```matlab
cfg.coordinateMode = 'absolute';
```

Keep `emitCoordinateModeCommand = false` unless you have confirmed the exact Aerotech syntax. The local Ensemble builder rejects `INCREMENTAL` before these `LINEAR` commands, which prevents later lines such as `PSOCONTROL X ON` from running.

`serpentine = true` is recommended. It avoids long return moves across the pattern.

`maxMotionCommandsPerScript` controls chunk size. Start conservative, for example 200 to 500, then increase only after the controller handles it reliably.

## 3D Arbitrary Surface Writing

The 3D pipeline writes a continuous surface instead of a binary mask. The source is a 2D matrix (loaded from a `.csv` or `.mat` file) where each cell is a phase / height value. Each cell is converted to a physical height with a linear multiplier, an optional X/Y tilt plane is added, and the surface is written line by line as relative `linear X Y Z F` moves with **Z tracking the surface**. The output `.ab` chunks use the same format as the 2D scripts, so `twoD_arbitary_printing_run.m` runs them unchanged.

### GUI use

```matlab
threeD_arbitary_printing
```

1. Choose the matrix file (`.csv` or `.mat`). For a `.mat` with several matrices, set `MAT var`.
2. On the `Geometry` tab set Target Size X/Y (the physical footprint), the X/Y sampling steps, origins, Z base, and interpolation method, plus the `Reverse X/Y stage axis` and `Height builds toward -Z` checkboxes to match your stage.
3. On the `Surface` tab set the phase→height slope/offset, X/Y tilt (slope and intrinsic), and NaN handling. The tilt sign convention is shown on the tab and in each field's tooltip.
4. On the `Motion` tab set write/reposition speeds, chunk size, and lead-in/out.
5. Click `Preview Matrix` for the 2D height map, or `3D View` for a rotatable 3D surface. Confirm the height range, orientation, and tilt direction.
6. Click `Generate Scripts`, inspect the `Summary` and `Manifest` tabs.
7. Position the stage at the intended surface origin, then `Run Selected Chunks`.

### Script use

```matlab
cfg = threeD_arbitary_printing_config();
cfg.matrixPath = fullfile(pwd, 'my_phase.csv');  % .csv or .mat 2D matrix
cfg.targetSizeX_um = 1800;       % physical footprint
cfg.targetSizeY_um = 1800;
cfg.pixelSize_um = 7.03125;      % X sampling step along each scan line
cfg.lineSpacing_um = 7.03125;    % Y scan-line spacing
cfg.phaseHeightSlope = 0.5;      % um of height per matrix unit (linear multiplier)
cfg.phaseHeightOffset_um = 0.0;
cfg.xTilt_um_per_mm = 0.0;       % tilt plane slope (um height per mm lateral)
cfg.yTilt_um_per_mm = 0.0;
cfg.writeSpeed_mm_s = 0.02;
cfg.maxMotionCommandsPerScript = 300;

summary = threeD_arbitary_printing_generate(cfg);
twoD_arbitary_printing_run(summary.manifestPath);
```

### 3D settings

- **Target Size sets the footprint.** `targetSizeX_um` / `targetSizeY_um` define the physical extent. The matrix is resampled (`interp2`, method `interpMethod`) onto a grid whose X step is `pixelSize_um` and whose Y step is `lineSpacing_um`, so data resolution and write resolution are independent. Effective steps are nudged so the footprint equals the target size exactly (reported in the summary).
- **Phase → height** is a linear multiplier: `height_um = phaseHeightSlope * value + phaseHeightOffset_um`. Optional `wrapPhase` applies `mod(value, wrapModulus)` first (off by default) for blazed / Fresnel profiles.
- **Tilt** has two independent controls that add together (both pivot at the origin edge, so Z is unchanged there):
  - `xTilt_um_per_mm` / `yTilt_um_per_mm` — a **slope** in µm of height per mm of lateral travel: `xTilt_um_per_mm*(x_mm - xOrigin) + yTilt_um_per_mm*(y_mm - yOrigin)`.
  - `xTiltIntrinsic_um` / `yTiltIntrinsic_um` — an **intrinsic tilt entered directly in µm**, as the total Z change across the whole footprint: it ramps from 0 at the origin edge to the full value at the far edge (`xTiltIntrinsic_um*(x_mm - xOrigin)/targetSizeX_mm`). Convenient for dialing in a measured substrate tilt as a height drop across the field.
  - **Sign convention:** a **positive** tilt raises the **+X (right of the preview)** / **+Y (top of the preview)** side of the surface; negative lowers it. Once the stage-axis reverse checkboxes are calibrated, the preview matches the physical sample, so e.g. to make the written surface 5 µm higher on the right edge, set `xTiltIntrinsic_um = +5` (or `xTilt_um_per_mm = +5 / field_width_mm`). Always confirm the direction in the `3D View`.
- **Final Z:** `z_mm = zBase_mm + heightZSign*(height_um + z_tilt_um) / 1000`, where `z_tilt_um` is the sum of the slope and intrinsic terms.
- **Stage axis conventions.** The stage moves the sample, so commanded coordinates can be reversed relative to the pattern. `xAxisSign` / `yAxisSign` (`+1` keep, `-1` negate) flip the motion away from `xOrigin` / `yOrigin`; the origin and `zBase_mm` stay as true stage positions. Because the objective is fixed, writing a taller feature moves the stage toward −Z, so `heightZSign = -1` maps positive height to negative Z motion. Defaults are `-1` for all three to match a reversed stage. In the GUI these are the `Reverse X stage axis`, `Reverse Y stage axis`, and `Height builds toward -Z` checkboxes on the `Geometry` tab. The preview always shows the surface in design (pattern) coordinates in µm; the signs apply only to the emitted `.ab`.
- **NaN cells are not written.** With `skipNaN = true`, non-finite samples (e.g. outside the data, or NaN in the source) become pen-up traverses; `liftHeight_um` lifts Z while crossing a gap. Set `skipNaN = false` to require a fully finite surface.
- **`mergeColinearTolerance_um`** optionally collapses consecutive samples that lie on a straight 3D line into one move, shrinking the output. `0` keeps one move per sample.
- `serpentine`, `flipY`, `coordinateMode`, PSO control, chunking, and build/run options behave exactly as in the 2D pipeline.

The matrix is interpreted as rows = Y (top to bottom) and columns = X. With `flipY = true` the physical bottom row is written first, matching a bottom-left XY view.

## Safety Notes

This first version uses speed difference only:

- white = slow write speed
- black = fast unwritten speed

Fast black moves can still expose material if the dose is not low enough. If your setup has laser shuttering or blanking, add that as a second protection layer before using high-value samples.

For relative scripts, resuming from the middle requires the stage to start at the correct chunk start position. The manifest records each chunk start and end position in mm.
