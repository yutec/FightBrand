clear all;
cd ~/work/kantar/brand/workfiles/simdraws;

for i=1:4
  for j = [2e2 1e3]
    sampleDraws(i,j);
  end
end
sampleDraws(4,3000);
