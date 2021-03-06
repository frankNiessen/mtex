function ebsdNew = interp(ebsd,xNew,yNew,varargin)
% interpolate at arbitrary points (x,y)
%
% Syntax
%   ebsdNew = interp(ebsd,xNew,yNew)
%
% Input
%   ebsd - @ebsdSquare
%   xNew, yNew - new x,y coordinates
%
% Output
%   ebsdNew - @ebsd with coordinates (xNew,yNew)
%
% See also
%  

% find nearest neighbour first
ix = 1 + (xNew-ebsd.xmin)./ebsd.dx;
iy = 1 + (yNew-ebsd.ymin)./ebsd.dy;

ixn = round(ix); iyn = round(iy);

% check nearest is inside the box
isIndexed = ixn > 0 & iyn > 0 & ixn <= size(ebsd,2) & iyn <= size(ebsd,1);

% check nearest is indexed
isIndexed(isIndexed) = ebsd.isIndexed(sub2ind(size(ebsd), iyn(isIndexed), ixn(isIndexed)));
idNearest = sub2ind(size(ebsd), iyn(isIndexed), ixn(isIndexed));


% nearest neighbor interpolation first
rot = rotation.nan(size(xNew));
rot(isIndexed) = ebsd.rotations(idNearest);

phaseId = ones(size(xNew));
phaseId(isIndexed) = ebsd.phaseId(idNearest);

% copy properties
prop = struct('x',xNew,'y',yNew);
for fn = fieldnames(ebsd.prop).'
  if any(strcmp(char(fn),{'x','y','z'})), continue;end

  if isnumeric(ebsd.prop.(char(fn))) || islogical(ebsd.prop.(char(fn)))
    prop.(char(fn)) = nan(size(xNew));
  else
    prop.(char(fn)) = ebsd.prop.(char(fn)).nan(size(xNew));
  end
  prop.(char(fn))(isIndexed) = ebsd.prop.(char(fn))(idNearest);
end

ebsdNew = EBSD(rot,phaseId,ebsd.CSList,prop);

% more advanced interpolation methods

method = get_option(varargin,'method','invDist');

ix = ix(isIndexed); iy = iy(isIndexed);

switch method
  
  case 'invDist'

    delta = min(ebsd.dx,ebsd.dy)/10;
    
    % set up the interpolation matrix
    M = sparse(nnz(isIndexed),length(ebsd));
  
    % go through all first order neighbours
    M = M + updateM(floor(ix),floor(iy));
    M = M + updateM(ceil(ix),floor(iy));
    M = M + updateM(floor(ix),ceil(iy));
    M = M + updateM(ceil(ix),ceil(iy));
    
    ebsdNew.rotations(isIndexed) = M * ebsd.rotations(:);
    
  case 'nearest'
    
  case ''
    
end

  function Mdelta = updateM(ixn,iyn)
    
    doInclude = ixn > 0 & iyn > 0 & ixn <= size(ebsd,2) & iyn <= size(ebsd,1);      
    idn = ones(size(doInclude));
    idn(doInclude) = sub2ind(size(ebsd), iyn(doInclude), ixn(doInclude));
    
    dist = sqrt((xNew(isIndexed) - ebsd.prop.x(idn)).^2 + ...
      (yNew(isIndexed) - ebsd.prop.y(idn)).^2);
    
    weights = 1./ (delta + dist);
    if isfield(prop,'grainId')
      doInclude = doInclude & (ebsd.prop.grainId(idn) == prop.grainId(isIndexed)) & ...
        angle(ebsd.rotations(idn),rot(isIndexed)) < 2.5*degree;
    else
      doInclude = doInclude & (ebsd.prop.phaseId(idn) == prop.phaseId(isIndexed)) & ...
        angle(ebsd.rotations(idn),rot(isIndexed)) < 5*degree;
    end
    
    Mdelta = sparse(1:nnz(isIndexed),idn,doInclude .* weights,...
      nnz(isIndexed),length(ebsd));
  end

end