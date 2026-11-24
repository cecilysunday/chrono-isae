% -------------------------------------------------------------------------
% FUNCTION  make_gif            Assemble image files into an animated GIF
% INPUTS    files               Image file paths, in frame order (cell
%                               array or string array)
%           gifname             Output file path (.gif)
% OPTS      'Delay'             Time each frame is shown (s). Default: 0.2
%           'EndDelay'          Time the last frame is shown (s), so the
%                               loop pauses at the end. Default: 1
% NOTES     - Frames of different sizes are padded with white at the
%             bottom and right to the largest size
%           - Each frame is reduced to 256 colors
%           - The GIF loops forever
% -------------------------------------------------------------------------
function make_gif(files, gifname, opts)

arguments
    files {mustBeText}
    gifname {mustBeTextScalar}
    opts.Delay (1,1) double {mustBeNonnegative} = 0.2
    opts.EndDelay (1,1) double {mustBeNonnegative} = 1
end
files = cellstr(files);
n = numel(files);
if n == 0
    error('make_gif:noFiles', 'No image files given.');
end

% Largest frame size
sz = zeros(n, 2);
for k = 1:n
    info = imfinfo(files{k});
    sz(k,:) = [info.Height, info.Width];
end
H = max(sz(:,1));
W = max(sz(:,2));

for k = 1:n
    im = imread(files{k});
    if size(im,3) == 1, im = repmat(im, 1, 1, 3); end
    if ~isequal(size(im,[1 2]), [H W])        % pad with white
        pad = 255 * ones(H, W, 3, 'like', im);
        pad(1:size(im,1), 1:size(im,2), :) = im;
        im = pad;
    end
    [A, map] = rgb2ind(im, 256);
    delay = opts.Delay;
    if k == n, delay = opts.EndDelay; end
    if k == 1
        imwrite(A, map, gifname, 'gif', 'LoopCount', inf, 'DelayTime', delay);
    else
        imwrite(A, map, gifname, 'gif', 'WriteMode', 'append', 'DelayTime', delay);
    end
end

end
