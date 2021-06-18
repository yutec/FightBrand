function sampleDraws(d,ndraw)

rng(1);
rgrid = lhsnorm(zeros(d,1),eye(d),ndraw);
fid = fopen(strcat('lhsnorm',num2str(d),'d',num2str(ndraw),'.csv'),'w');
for i=1:ndraw
  for k=1:d-1
    fprintf(fid,'%19.15f, ',rgrid(i,k));
  end
  fprintf(fid,'%19.15f\n',rgrid(i,d));
end
fclose(fid);

end