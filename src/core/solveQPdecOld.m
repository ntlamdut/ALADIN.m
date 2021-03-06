
function [ Lam, u ] = solveQPdecOld( cond, lamOld, opts, iter, sProb )
%SOLVEQPDECOLD Summary of this function goes here

NsubSys = size(cond.AAred,2);
Ncons   = size(lamOld,1);

AA = sProb.AA;
xx = iter.loc.xx;
mu = iter.stepSizes.mu;

maxComm = 0;
%% local precomputation
for i=1:NsubSys
   % local nullspace method   
%    ZZ{i}    = null(full(CC{i}));
%    HHred{i} = ZZ{i}'*(full(HH{i}))*ZZ{i};
%    
%    % regularization if needed
%    [V,D]            = eig(full(HHred{i}));
%    e                = diag(D);
%     
%    if min(e) < 1e-6
%        e(abs(e)<1e-4)   = 1e-4;
%        % flip the eigenvalues 
%        HHred{i} = V*diag(e)*transpose(V);
%        keyboard
%    end

   AAred{i} = cond.AAred{i};
   ggred{i} = cond.ggred{i};
   
   % Schur-complement
   HHredInv{i} = cond.HHredInv{i};
   SS{i}       = AAred{i}*HHredInv{i}*AAred{i}';
   
   rrhs{i}     = AAred{i}*HHredInv{i}*ggred{i};
   rrhsNoSl{i} = AA{i}*xx{i} - AAred{i}*HHredInv{i}*(ggred{i});
   AAx{i}      = AA{i}*xx{i};

   % maximum communication overhead
   maxComm = maxComm + nnz(diag(SS{i})) + nnz(SS{i}-diag(diag(SS{i})))/2 + nnz(rrhs{i});
   
end
SSslack     = (1/iter.stepSizes.mu)*eye(Ncons);

%% solution of LES
S0      = zeros(Ncons);
Ax      = zeros(Ncons,1);
rhs0    = zeros(Ncons,1);
rhsNoSl = zeros(Ncons,1);
for i=1:NsubSys
    S0      = S0   + SS{i};
    Ax      = Ax   + AAx{i};
    rhs0    = rhs0 + rrhs{i};
    rhsNoSl = rhsNoSl + rrhsNoSl{i};
end
S = - S0 - SSslack;
rhs = rhs0 - (1/iter.stepSizes.mu)*lamOld;

rhsS =  -Ax + rhs;

% solve LES
u = S\rhsS;
% 
% %% solve via ADMM without slack
% % solution without slack 
% uNoSl  = (S0+SSslack)\(rhsNoSl + (1/mu)*lam); % uNoSl
% 

%% run with default ADMM
% for i=1:NsubSys
%    ff{i} = @(x)0.5*x'*(SS{i} + 1/(NsubSys)*SSslack)*x - x'*(rrhsNoSl{i} +1/(NsubSys*mu)*lam);
%    AAadm{i} = zeros(Ncons*(NsubSys-1),Ncons);
%    if i==1
%        AAadm{i}(1:Ncons,1:Ncons)                  =   eye(Ncons);
%    elseif i==NsubSys
%        AAadm{i}(end-Ncons+1:end,end-Ncons+1:end)  =  -eye(Ncons);
%    else
%        AAadm{i}((i-2)*Ncons+1:i*Ncons,:)          = [-eye(Ncons); eye(Ncons)];     
%    end
%    Sig{i} = eye(Ncons);
%    yy0{i} = zeros(Ncons,1);
%    ll0{i} = zeros(Ncons*(NsubSys-1),1);
%    ggAdm{i}  = @(x) [];
%    hhAdm{i}  = @(x) [];
%    llbx{i}= -inf*ones(Ncons,1);
%    uubx{i}= inf*ones(Ncons,1);
% end
% 
% [lamADM, loggADM] = run_ADMM(ff,ggAdm,hhAdm,AAadm,yy0,ll0,llbx,uubx,0.001,Sig,100)
% 
% [lamADM(1:Ncons) u]

%% distributed ADMM

% find zero rows of Ai (check assignement)
Jc = cell(Ncons,1);
for i=1:NsubSys
    J{i} = find(~all(AA{i}==0,2));
    
    for j=1:Ncons
       if sum(J{i}==j)
          Jc{j} = [Jc{j} i];
       end
    end

    % set up slack matrices for LES
    ss{i}       = zeros(Ncons,1);
    ss{i}(J{i}) = 1/2;
end



if  strcmp(opts.innerAlg,'D-ADMM')
% initialize z_i and y_i
% rhoADM = 2e-2; %no preconditioning

T = eye(Ncons);


% distributed
z = zeros(Ncons,1);
z = lamOld; %warmstart
[yy{1:NsubSys,1}] = deal(zeros(Ncons,1));
Z = [];
Rho=[];
rhoADM = opts.rhoADM;    %1e-1; % for robot example
for j = 1:opts.innerIter
    zOld = z;
    
    for i=1:NsubSys
        xx{i} = inv(T'*(SS{i} + 1/mu*diag(ss{i}))*T + rhoADM*eye(Ncons))*(-yy{i} + rhoADM*z + T'*rrhsNoSl{i} + T'*1/mu*ss{i}.*lamOld );  
    end
 %   z = 1/NsubSys*(sum([xx{:}]')') + 1/rhoADM*sum([yy{:}]')';
     z = sum(([ss{:}].*[xx{:}])')';   
    for i=1:NsubSys
        yy{i} = yy{i} + rhoADM*(xx{i} - z);
    end

%     % rho update according to Boyd paper
%     r = norm(vertcat(xx{:}) - repmat(eye(Ncons),NsubSys,1)*z);
%     s = norm(rhoADM*repmat(eye(Ncons),NsubSys,1)*(z-zOld));
%     if r > muADM*s
%         rhoADM = rhoADM*tauADM;
%     elseif s > muADM*r
%         rhoADM = 1/tauADM*rhoADM;
%     end
%     
    Rho = [Rho rhoADM];
    Z   = [Z z];
end
u=z;

% taking x or z makes a huge difference in bi-level AL convergence!!!
for i=1:NsubSys
    Lam{i} = xx{i}(J{i});%u(J{i}); %xx{i}(J{i});
end

% 
  figure
  semilogy(max(abs(S*Z-repmat(rhsS,[1,size(Z,2)]))))
%loglog(max(abs(S*Z-rhsS)))

end








% %% conjugate gradient
% zC = lam;%zeros(Ncons,1); % warm start
% Zcg = [];
% rC = rhsS - S*zC;
% pC = rC;
% for j=1:1000
%     alphaC = rC'*rC/(pC'*S*pC);
%     zC    = zC + alphaC*pC;
%     rOld  = rC;
%     rC    = rOld - alphaC*S*pC;
%     betaC  = rC'*rC/(rOld'*rOld);
%     pC     = rC + betaC*pC;
%     % logg
%     Zcg = [Zcg zC];
% end
% 
% semilogy(max(abs(S*Zcg-rhsS)))

% sparsity figures
% figure
% for i=1:NsubSys
%     subplot(2,2,i)
%     spy(SS{i});
%     
%     set(gca,'xticklabel',{[]})
%     set(gca,'yticklabel',{[]})
%     delete(findall(findall(gcf,'Type','axe'),'Type','text'))
% end

%% distributed CG
if strcmp(opts.innerAlg,'D-CG')

C=J;

% check assignements an neighborhood
ass       = [];
[Neig{1:NsubSys}] = deal([]);
for i=1:NsubSys
    ass = [ass; sum(abs(AA{i}'))];
    
%     for j=1:NsubSys
%         if sum((abs(sum(abs(AA{1}'))~=0) + abs(sum(abs(AA{4}'))~=0))>1)>0
%             Neig{i} = [Neig{i} j];
%         end
%     end
end
for i=1:Ncons
    R{i} = find(ass(:,i));
end


% new local Schurs including slack
for i=1:NsubSys
    SSn{i} = - SS{i} - 1/mu*diag(ss{i});
    ssn{i} = - rrhsNoSl{i} - 1/mu*ss{i};
end


% distributed CG iterations

ZcgD = [];
zDistr  = lamOld;%zeros(Ncons,1); % warm start
rNew    = rhsS - S*zDistr; 
p       = rNew;
for j=1:opts.innerIter
    ptSp = zeros(Ncons,1);
    rTr  = zeros(Ncons,1);
    % compute alpha components locally
    for i=1:Ncons
        Ss{i}   = [sparse(1,i,1,1,Ncons)*cellPlus({SSn{R{i}}})]';
        ptSp(i) = sparse(1,union(C{R{i}}),p(union(C{R{i}})),1,Ncons)*Ss{i}*p(i);
        rTr(i)  = rNew(i)^2;
    end
    % global sums
    ptSp  = sum(ptSp);
    rTr   = sum(rTr);
    alpha = rTr/ptSp;

    % local z and r updates
    rTr2  = zeros(Ncons,1);
    r     = rNew;
    for i=1:Ncons 
       zDistr(i) = zDistr(i) + alpha*p(i);
       rNew(i)   = r(i) - alpha*sparse(1,union(C{R{i}}),p(union(C{R{i}})),1,Ncons)*Ss{i};
       rTr2(i)   = rNew(i)^2;
    end
    % global sum
    rTr2   = sum(rTr2);
    beta   = rTr2/rTr;

    for i=1:Ncons
       p(i) = rNew(i) + beta*p(i);
    end
    
    % logg
    ZcgD = [ZcgD zDistr];
    
    % find NaNs in solution
    if sum(isnan(zDistr)) ~=0
        zDistr = ZcgD(:,end-1);
        break
        keyboard;
    end
end
% 
% figure
%semilogy(max(abs(S*ZcgD-repmat(rhsS,[1 size(ZcgD,2)]))))

u = zDistr;

%% divide into local multipliers
for i=1:NsubSys
    Lam{i} = u(J{i});
end

end






% % compare with D-ADMM
%  nPlot = 100; 
% % set(0,'defaultTextInterpreter','latex');
%  figure 
%  resCG = max(abs(S*ZcgD-repmat(rhsS,[1 size(ZcgD,2)])));
%  semilogy(1:nPlot,resCG(:,1:nPlot))
% hold on
% resADM = max(abs(S*Z-repmat(rhsS,[1,size(Z,2)])));
% semilogy(1:nPlot,resADM(:,1:nPlot))
% legend('D-CG','D-ADMM')
% ylabel('$\|\tilde S\lambda^k-\tilde s\|_\infty$')
% xlabel('k')
% ylim([1e-15 1e3])
% xlim([1 100])




end

