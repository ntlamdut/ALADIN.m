classdef  PrintDM < SwigRef
    %PRINTDM Base class for objects that have a natural string representation.
    %
    %
    %
    %Joel Andersson
    %
    %C++ includes: printable_object.hpp 
    %
  methods
    function this = swig_this(self)
      this = casadiMEX(3, self);
    end
    function varargout = getDescription(self,varargin)
    %GETDESCRIPTION 
    %
    %  char = GETDESCRIPTION(self)
    %
    %
      [varargout{1:nargout}] = casadiMEX(33, self, varargin{:});
    end
    function varargout = getRepresentation(self,varargin)
    %GETREPRESENTATION 
    %
    %  char = GETREPRESENTATION(self)
    %
    %
      [varargout{1:nargout}] = casadiMEX(34, self, varargin{:});
    end
    function self = PrintDM(varargin)
    %PRINTDM 
    %
    %  new_obj = PRINTDM()
    %
    %
      if nargin==1 && strcmp(class(varargin{1}),'SwigRef')
        if ~isnull(varargin{1})
          self.swigPtr = varargin{1}.swigPtr;
        end
      else
        tmp = casadiMEX(35, varargin{:});
        self.swigPtr = tmp.swigPtr;
        tmp.swigPtr = [];
      end
    end
    function delete(self)
      if self.swigPtr
        casadiMEX(36, self);
        self.swigPtr=[];
      end
    end
  end
  methods(Static)
  end
end
