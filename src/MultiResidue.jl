module MultiResidue
using SymEngine
using LinearAlgebra
using InvertedIndices
using Combinatorics
export multiResidue, gd, 𝒟,degree, FrobeniusSolve, solve
export @varss
macro varss(x,n::Int64)
      q=Expr(:block)
      for i = 1:n
          push!(q.args, Expr(:(=), esc(Symbol("$x$i")), Expr(:call, :(SymEngine._symbol), Expr(:quote, Symbol("$x$i")))))
      end
      push!(q.args, Expr(:tuple, map(esc, "$x".*map(string,1:n).|>Symbol)...))
      q
  end
function degree(f::Basic)
      if SymEngine.get_symengine_class(f)==:Add
             ls=get_args(f); 
             degvec = Array{Int64}(undef, length(ls))
             for i=1:length(ls)
                  degvec[i]=degree(ls[i])
             end
             maximum(degvec)
      elseif SymEngine.get_symengine_class(f)==:Mul;
            ls=get_args(f); 
             degvec = Array{Int64}(undef, length(ls))
             for i=1:length(ls)
                  degvec[i]=degree(ls[i])
             end
             sum(degvec)
      elseif SymEngine.get_symengine_class(f)==:Pow
            ls=get_args(f); 
            ls[2]*degree(ls[1])
      elseif SymEngine.get_symengine_class(f)==:Symbol
            1
      else 
            0
      end
end
function degree(f::Basic,vars::Vector{Basic})
      #print("new");
      if SymEngine.get_symengine_class(f)==:Add
             ls=get_args(f); 
             degvec = Array{Int64}(undef, length(ls))
             for i=1:length(ls)
                  degvec[i]=degree(ls[i],vars)
             end
             maximum(degvec)
      elseif SymEngine.get_symengine_class(f)==:Mul;
            ls=get_args(f); 
             degvec = Array{Int64}(undef, length(ls))
             for i=1:length(ls)
                  degvec[i]=degree(ls[i],vars)
             end
             #print(degvec);
             sum(degvec)
      elseif SymEngine.get_symengine_class(f)==:Pow
            ls=get_args(f); 
            ls[2]*degree(ls[1],vars)
      elseif SymEngine.get_symengine_class(f)==:Symbol && (f in vars)
            1
      else 
            0
      end
end

function int(x) 
      floor(Int, x)
end
function FrobeniusSolve(vec::Vector{Int64},vs::Int64)
     res=[];
     js=vs ./vec.|>int;
     for i in Iterators.product((0:k for k in js)...)
            dot(vec,i)==vs ? push!(res,collect(i)) : nothing
     end
     res
end
function gd(f::Basic,var::Basic,order::Int64)
     if order==0
           f
     else
           xs=fill(var,order);
           diff(f,xs...)
     end
end
function gd(f::Basic,vars::Vector{Basic},orders::Vector{Int64})
     g=f
     for i=1:length(vars)
           g=gd(g,vars[i],orders[i])
     end
     g
end
function  𝒟(f::Basic,vars::Vector{Basic},deg::Int64)
     n=length(vars);
     par=FrobeniusSolve(fill(1,n),deg);
     a=SymFunction("a");
     res=0;
     for i=1:length(par)
          res+=a(par[i]...)gd(f,vars,par[i])
     end
     res
end  
function  𝒟(f::Basic,deg::Int64)
     vars=f|>get_args;
     n=length(vars);
     par=FrobeniusSolve(fill(1,n),deg);
     a=SymFunction("a");
     res=0;
     for i=1:length(par)
          res+=a(par[i]...)gd(f,vars,par[i])
     end
     res
end  

function monoGen(vars::Vector{Basic},orders::Vector{Int64})
      [vars[i]^orders[i] for i=1:length(vars)]|>prod
end
function localDual(f::Basic,vars::Vector{Basic},order::Int64)
   n=length(vars);
   deg=degree(f,vars);
   diffdeg=order-deg;
   comb=FrobeniusSolve(fill(1,n),diffdeg);
   v=SymFunction("v");
   [monoGen(vars,comb[i]) for i=1:length(comb)].*f
end

function homoEqn(ideal::Vector{Basic},vars::Vector{Basic},order::Int64)
      f = [localDual(ideal[i], vars, order) for i=1:length(ideal)]|>Iterators.flatten|>collect|>unique;
      [𝒟(f[i],vars,order) for i=1:length(f)]
end

function inhomoEqn(ideal::Vector{Basic},vars::Vector{Basic},order::Int64)
      mat=[diff(ideal[i],vars[j]) for i in 1:length(ideal), j in 1:length(vars)];
      𝒟(det(mat),vars,order)
end

function eqnAnsatz(ideal::Vector{Basic},vars::Vector{Basic},order::Int64)
      intersectionNumber=[degree(ideal[i],vars) for i=1:length(ideal)]|>prod;
      homo = homoEqn(ideal, vars, order);
      inhomo = inhomoEqn(ideal, vars, order);
      push!(homo,inhomo-intersectionNumber);
      homo
end

function solveold(ideal::Vector{Basic},vars::Vector{Basic})
      eqns=ideal;
      aVar=vars;
      aMat=[coeff(eqns[i],aVar[j])|>Int for i=1:length(eqns), j=1:length(aVar)];
      aMatrank=rank(aMat);
      aM=aMat;
      notlist=[];
      while length(aM[:,1])> aMatrank
            aMrank=rank(aM);
            for i=1:length(aM[:,1])
                  Mt=aM[Not(i), :];
                  if Mt|>rank == aMrank
                        push!(notlist,i+length(notlist))
                        aM=Mt;
                        break
                  end
            end
      end
      dimaM=size(aM)[1];
      aMSym=[Basic(aM[i,j]) for i=1:dimaM, j=1:dimaM];
      inhomTerm=eqns[Not(notlist)];
      for i=1:length(aVar)
            inhomTerm=[subs(inhomTerm[j],aVar[i],0)|>Basic for j=1:length(inhomTerm)]
      end
      inhomTerm=.-inhomTerm;
      invM=inv(aMSym);
      sol=[aVar[i]=>dot(invM[i,:],inhomTerm) for i=1:dimaM];
      sol=[Dict(sol...)]
end

function solve(ideal::Vector{Basic},vars::Vector{Basic})
      eqns=ideal;
      aVar=vars;
      aMat=[coeff(eqns[i],aVar[j]) for i=1:length(eqns), j=1:length(aVar)];
      #print(eqns,aVar);
      mId=powerset([i for i=1:length(eqns)], length(aVar), length(aVar))|>collect;
      if mId==[] 
            print("equantions are not enough to solve")
            return []
      end
      j=0;
      inlist=[];
      aM=[];
      #print("lengmId",length(mId),"end");
      for i=1:length(mId)
            derm=det(aMat[mId[i],:])|>expand;
            #print("fuuuut",derm,"nimamamamma");
            if derm!=Basic(0) 
                  inlist=mId[i];
                  aM=aMat[mId[i],:];
                  j=i;
                  break;
            end
      end
      if j==0
            print("not enough equantions to solve")
            return []
      else
            inhomTerm=eqns[inlist];
            for i=1:length(aVar)
                  inhomTerm=[subs(inhomTerm[j],aVar[i],0)|>Basic for j=1:length(inhomTerm)]
            end
            inhomTerm=.-inhomTerm;
            #print(aM);
            invM=inv(aM);
            dimaM=size(aM)[1];
            sol=[aVar[i]=>dot(invM[i,:],inhomTerm) for i=1:dimaM];
            sol=Dict(sol...)
      end     
end

function multiResidue(num::Basic,homoideal::Vector{Basic},vars::Vector{Basic})
      dOrder=[degree(homoideal[i],vars) for i=1:length(homoideal)]|>sum;
      dOrder=dOrder-length(vars);
      coeqn=eqnAnsatz(homoideal, vars, dOrder);
      par=FrobeniusSolve(fill(1,length(vars)),dOrder);
      a=SymFunction("a");
      aVar=[a(par[i]...) for i=1:length(par)]; 
      varszero=Dict([vars[i]=>0 for i=1:length(vars)]...);
      #print("befor solve");
      #print(coeqn);
      #print("befor solve");
      sola=solve(coeqn,aVar);
      if sola==[]
            print("no solution for the residue, check if the intersection is non-zero dimension")
            return false
      else
            res=𝒟(num,vars,dOrder);
            res=subs(res,varszero);
            res=subs(res,sola)
      end
end

end