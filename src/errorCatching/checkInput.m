function [  ] = checkInput( sProb )
% script to check plausibility of input variables
[ ffifun ggifun hhifun ] =  ...
               deal(sProb.locFuns.ffi, sProb.locFuns.ggi, sProb.locFuns.hhi);


%% dimension check of number of subsystems
size_ffi = size(ffifun);
size_ggi = size(ggifun);
size_hhi = size(hhifun);

assert(all(size_ffi == size_ggi) & all(size_hhi == size_ffi), ...
    ['ERROR: Mismatching dimensions of the number of subsystems.' ...
    'The sizes of the cells respectively containing the ' ...
    'objective functions f_i, the inequality contraints h_i'...
    'and the equality constraints g_i must be equal']);

%% dimension check of matrix A
assert(all(size_ffi == size(sProb.AA)), ...
    ['ERROR: Mismatching number of coupling matrices.' ...
    'The number of coupling matrices is supposed to be equal to the' ...
    'number of subsystems']);

%% dimension check of initial value

size_x = 0;
size_A = 0;
for i = 1 : size_ffi
    size_x = size_x + length(sProb.zz0{i});
    size_A = size_A + size(sProb.AA{i},2);
end

assert((size_x == size_A), ...
   ['ERROR: please recheck the dimensions of the inital value of x' ...
   ' it should be equal to the dimension of the concatented' ...
   'coupling matrices']);

%% check rank of AA
AA_concat = horzcat(sProb.AA{:});
size_AA = size(AA_concat);

assert(rank(full(AA_concat)) == size_AA(1), ... 
       ['ERROR: rank of AA should be equal to its number of rows.' ...
       'otherwise no full coupling is possible']);

%% dimension check of lambda
size_AA = size(sProb.AA{1},1);

assert(size_AA(1) == length(sProb.lam0), ...
    ['Mismatch of dimension of lam0.' ...
    'Dimension should be equal to number of rows of he coupling matrices']);


end