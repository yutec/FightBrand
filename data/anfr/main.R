# Import ANFR data 2016
dat = read.csv(file="Cartoradio2016.csv",head=TRUE,sep=";",dec=",",encoding="latin1")
colnames(dat) = c('operator', 'id', 'system', 'datestr', 'department', 'generation', 'lat', 'lon','address', 'postal', 'ville', 'insee')
dat$datestr = as.Date(dat$datestr, format="%d/%m/%y")

# Size of dataset
dim(dat)

# Number & percentage of observations with missing dates
dim(dat[is.na(dat$date),])[1] # 17806
dim(dat[is.na(dat$date),])[1]/dim(dat)[1] # 0.1131927

antennaMiss = matrix(0, 3, 4)
antennaTotal = matrix(0, 3, 4)
network = c("ORANGE","SFR","BOUYGUES TELECOM","FREE MOBILE")
generation = c("2G","3G","4G")
for (i in 1:length(network)){
	for (j in 1:3){
		antennaMiss[j,i] = length(dat$id[dat$operator==network[i] & is.na(dat$date) & dat$generation==generation[j]])
		antennaTotal[j,i] = length(dat$id[dat$operator==network[i] & dat$generation==generation[j]])
	}
}
colnames(antennaMiss) = network
colnames(antennaTotal) = network

# Export dataset after dropping observations with missing dates
dat = dat[is.na(dat$datestr) == FALSE,c(1,2,3,4,5,6)]
write.csv(dat, "anfr2016.csv", row.names=FALSE)
