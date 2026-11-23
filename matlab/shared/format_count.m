% -------------------------------------------------------------------------
% FUNCTION  format_count        Reformat integer with thousands separators,
%                               e.g. 60898 -> '60,898'
% -------------------------------------------------------------------------
function s = format_count(n)
s = fliplr(regexprep(fliplr(sprintf('%d', n)), '(\d{3})(?=\d)', '$1,'));
end
